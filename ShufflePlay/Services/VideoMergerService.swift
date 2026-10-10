import Foundation
import AVFoundation
import UIKit

enum MergeError: LocalizedError {
    case emptyVideos
    case trackCreationFailed
    case exportSessionCreationFailed
    case exportFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .emptyVideos:
            return "请至少导入两个视频以便打乱合成。"
        case .trackCreationFailed:
            return "无法创建合成轨道，视频格式可能不受支持。"
        case .exportSessionCreationFailed:
            return "无法创建视频导出任务。"
        case .exportFailed(let reason):
            return "合成导出失败：\(reason)"
        case .cancelled:
            return "合成任务已被用户取消。"
        }
    }
}

final class VideoMergerService {
    static let shared = VideoMergerService()

    private var activeExportSession: AVAssetExportSession?
    private var progressTimer: Timer?

    private init() {}

    /// 打乱视频顺序并合成一个大的视频
    /// - Parameters:
    ///   - videos: 导入的视频列表
    ///   - progressHandler: 进度回调 (0.0 ~ 1.0)
    ///   - completion: 成功返回合成文件 URL 及打乱后的视频列表，失败返回错误
    func shuffleAndMerge(
        videos: [VideoItem],
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<(outputURL: URL, shuffledItems: [VideoItem], duration: TimeInterval), Error>) -> Void
    ) {
        guard !videos.isEmpty else {
            completion(.failure(MergeError.emptyVideos))
            return
        }

        // 1. 随机打乱视频顺序
        let shuffled = videos.shuffled()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let composition = AVMutableComposition()

            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                DispatchQueue.main.async { completion(.failure(MergeError.trackCreationFailed)) }
                return
            }

            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                DispatchQueue.main.async { completion(.failure(MergeError.trackCreationFailed)) }
                return
            }

            var currentTime = CMTime.zero
            var instructions: [AVMutableVideoCompositionInstruction] = []

            // 计算目标画布尺寸：
            // 检测视频大多数是竖屏还是横屏
            let targetSize = self.determineOptimalRenderSize(from: shuffled)

            for videoItem in shuffled {
                let asset = AVURLAsset(url: videoItem.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                guard let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
                    continue
                }

                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)

                do {
                    // 插入视频轨道
                    try compositionVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)

                    // 插入音频轨道 (若存在音频)
                    if let assetAudioTrack = asset.tracks(withMediaType: .audio).first {
                        try compositionAudioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                    }

                    // 创建单段视频的指令与画幅自适应居中变换
                    let segmentInstruction = AVMutableVideoCompositionInstruction()
                    segmentInstruction.timeRange = CMTimeRange(start: currentTime, duration: asset.duration)

                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
                    let transform = self.transformForTrack(assetVideoTrack, targetSize: targetSize)
                    layerInstruction.setTransform(transform, at: currentTime)

                    segmentInstruction.layerInstructions = [layerInstruction]
                    instructions.append(segmentInstruction)

                    currentTime = CMTimeAdd(currentTime, asset.duration)
                } catch {
                    print("[VideoMerger] Error inserting track for \(videoItem.filename): \(error)")
                }
            }

            guard currentTime > .zero else {
                DispatchQueue.main.async { completion(.failure(MergeError.trackCreationFailed)) }
                return
            }

            // 配置视频合成属性
            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = instructions
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            videoComposition.renderSize = targetSize

            // 准备导出路径
            let outputDir = self.getOrCreateExportDirectory()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let filename = "Shuffle_\(formatter.string(from: Date())).mp4"
            let outputURL = outputDir.appendingPathComponent(filename)

            // 如果文件已存在则先删除
            try? FileManager.default.removeItem(at: outputURL)

            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                DispatchQueue.main.async { completion(.failure(MergeError.exportSessionCreationFailed)) }
                return
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.videoComposition = videoComposition
            exportSession.shouldOptimizeForNetworkUse = true

            self.activeExportSession = exportSession

            // 启动进度轮询定时器
            DispatchQueue.main.async {
                self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self, let session = self.activeExportSession else { return }
                    progressHandler(session.progress)
                }
            }

            let totalDuration = CMTimeGetSeconds(currentTime)

            exportSession.exportAsynchronously { [weak self] in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.progressTimer?.invalidate()
                    self.progressTimer = nil
                    self.activeExportSession = nil

                    switch exportSession.status {
                    case .completed:
                        progressHandler(1.0)
                        completion(.success((outputURL: outputURL, shuffledItems: shuffled, duration: totalDuration)))
                    case .failed:
                        let reason = exportSession.error?.localizedDescription ?? "未知错误"
                        completion(.failure(MergeError.exportFailed(reason)))
                    case .cancelled:
                        completion(.failure(MergeError.cancelled))
                    default:
                        completion(.failure(MergeError.exportFailed("合成未能成功结束")))
                    }
                }
            }
        }
    }

    /// 取消当前导出任务
    func cancelExport() {
        activeExportSession?.cancelExport()
        progressTimer?.invalidate()
        progressTimer = nil
        activeExportSession = nil
    }

    // MARK: - 私有辅助函数

    /// 导出视频存储目录 Documents/ExportedVideos
    func getOrCreateExportDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ExportedVideos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 根据所有待拼接视频计算统一渲染画布尺寸 (统一为 1080P 水平或垂直)
    private func determineOptimalRenderSize(from videos: [VideoItem]) -> CGSize {
        var portraitCount = 0
        var landscapeCount = 0

        for item in videos {
            if item.resolution.height >= item.resolution.width {
                portraitCount += 1
            } else {
                landscapeCount += 1
            }
        }

        // 多数为竖屏时使用 1080x1920，否则使用 1920x1080
        if portraitCount >= landscapeCount {
            return CGSize(width: 1080, height: 1920)
        } else {
            return CGSize(width: 1920, height: 1080)
        }
    }

    /// 计算 Aspect Fit 居中平移和缩放变换
    private func transformForTrack(_ track: AVAssetTrack, targetSize: CGSize) -> CGAffineTransform {
        let naturalSize = track.naturalSize
        let preferredTransform = track.preferredTransform

        // 计算源视频经过自身 transform 之后的真实可见尺寸和朝向
        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let actualSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))

        guard actualSize.width > 0, actualSize.height > 0 else {
            return preferredTransform
        }

        // 计算 Aspect Fit 缩放比例
        let scaleX = targetSize.width / actualSize.width
        let scaleY = targetSize.height / actualSize.height
        let scale = min(scaleX, scaleY)

        let scaledWidth = actualSize.width * scale
        let scaledHeight = actualSize.height * scale

        // 计算居中偏移
        let xOffset = (targetSize.width - scaledWidth) / 2.0
        let yOffset = (targetSize.height - scaledHeight) / 2.0

        // 最终变换：原变换 -> 缩放 -> 居中平移
        var finalTransform = preferredTransform
        finalTransform = finalTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))

        // 修正原变换带来的坐标轴平移
        if transformedRect.minX < 0 {
            finalTransform = finalTransform.concatenating(CGAffineTransform(translationX: -transformedRect.minX * scale, y: 0))
        }
        if transformedRect.minY < 0 {
            finalTransform = finalTransform.concatenating(CGAffineTransform(translationX: 0, y: -transformedRect.minY * scale))
        }

        // 应用居中偏移
        finalTransform = finalTransform.concatenating(CGAffineTransform(translationX: xOffset, y: yOffset))

        return finalTransform
    }
}
