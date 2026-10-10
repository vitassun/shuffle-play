import Foundation
import SwiftUI
import AVFoundation

final class MergeViewModel: ObservableObject {
    @Published var selectedVideos: [VideoItem] = []
    @Published var isLoadingVideos: Bool = false
    @Published var isExporting: Bool = false
    @Published var exportProgress: Float = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false

    // 合成成功产物
    @Published var latestExportedVideo: ExportedVideo?
    @Published var showSuccessSheet: Bool = false

    init() {}

    // MARK: - 视频列表操作

    func removeVideo(at offsets: IndexSet) {
        selectedVideos.remove(atOffsets: offsets)
    }

    func removeVideo(item: VideoItem) {
        selectedVideos.removeAll { $0.id == item.id }
    }

    func clearVideos() {
        selectedVideos.removeAll()
    }

    func moveVideos(from source: IndexSet, to destination: Int) {
        selectedVideos.move(fromOffsets: source, toOffset: destination)
    }

    var totalDuration: TimeInterval {
        selectedVideos.reduce(0) { $0 + $1.duration }
    }

    var formattedTotalDuration: String {
        let total = Int(totalDuration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d小时%02d分%02d秒", h, m, s)
        } else {
            return String(format: "%02d分%02d秒", m, s)
        }
    }

    // MARK: - 从相册或文件导入视频文件

    func handlePickedFileURLs(_ urls: [URL], sourceName: String = "视频") {
        guard !urls.isEmpty else { return }
        isLoadingVideos = true
        statusMessage = "正在解析导入的视频..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var importedItems: [VideoItem] = []

            for (idx, url) in urls.enumerated() {
                let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let tempDir = FileManager.default.temporaryDirectory
                let targetURL = tempDir.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")

                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: url, to: targetURL)
                    let displayName = "\(sourceName)_\(self?.selectedVideos.count ?? 0 + idx + 1)"
                    if let item = self?.createVideoItem(from: targetURL, originalFilename: displayName) {
                        importedItems.append(item)
                    }
                } catch {
                    print("[MergeVM] Failed copying file from URL \(url): \(error)")
                }
            }

            DispatchQueue.main.async {
                self?.isLoadingVideos = false
                self?.statusMessage = ""
                self?.selectedVideos.append(contentsOf: importedItems)
            }
        }
    }

    // MARK: - 随机打乱并合成大视频

    func startShuffleAndMerge() {
        guard selectedVideos.count >= 2 else {
            errorMessage = "请至少导入 2 个视频以进行随机打乱和拼接。"
            showErrorAlert = true
            return
        }

        isExporting = true
        exportProgress = 0.0
        statusMessage = "正在随机打乱顺序并合成大视频..."

        VideoMergerService.shared.shuffleAndMerge(
            videos: selectedVideos,
            progressHandler: { [weak self] progress in
                self?.exportProgress = progress
                let percent = Int(progress * 100)
                self?.statusMessage = "正在导出大视频 (\(percent)%)..."
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                self.isExporting = false
                self.statusMessage = ""

                switch result {
                case .success(let output):
                    let relativePath = "ExportedVideos/\(output.outputURL.lastPathComponent)"
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: output.outputURL.path)[.size] as? Int64) ?? 0

                    let exported = ExportedVideo(
                        filename: output.outputURL.lastPathComponent,
                        relativePath: relativePath,
                        createdAt: Date(),
                        duration: output.duration,
                        originalVideoCount: output.shuffledItems.count,
                        fileSize: fileSize
                    )

                    LibraryViewModel.shared.addExportedVideo(exported)
                    self.latestExportedVideo = exported
                    self.showSuccessSheet = true

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        )
    }

    func cancelExport() {
        VideoMergerService.shared.cancelExport()
        isExporting = false
        statusMessage = "合成已取消"
    }

    // MARK: - 辅助解析

    private func createVideoItem(from url: URL, originalFilename: String? = nil) -> VideoItem? {
        let asset = AVURLAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        guard durationSeconds.isFinite && durationSeconds > 0 else { return nil }

        var resolution: CGSize = .zero
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            resolution = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
            resolution = CGSize(width: abs(resolution.width), height: abs(resolution.height))
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        var thumbnail: UIImage? = nil
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)
        let sampleTime = CMTime(seconds: min(1.0, durationSeconds / 2.0), preferredTimescale: 600)
        if let cgImg = try? generator.copyCGImage(at: sampleTime, actualTime: nil) {
            thumbnail = UIImage(cgImage: cgImg)
        }

        return VideoItem(
            url: url,
            filename: originalFilename ?? url.lastPathComponent,
            duration: durationSeconds,
            resolution: resolution,
            fileSize: fileSize,
            thumbnail: thumbnail
        )
    }
}
