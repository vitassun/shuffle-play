import Foundation
import SwiftUI
import Photos
import AVFoundation

final class LibraryViewModel: ObservableObject {
    static let shared = LibraryViewModel()

    @Published var exportedVideos: [ExportedVideo] = []
    @Published var toastMessage: String?
    @Published var showToast: Bool = false

    private let userDefaultsKey = "ShufflePlay_ExportedVideos"

    private init() {
        loadFromStorage()
    }

    func addExportedVideo(_ video: ExportedVideo) {
        exportedVideos.insert(video, at: 0)
        saveToStorage()
    }

    func deleteVideo(at offsets: IndexSet) {
        for index in offsets {
            let video = exportedVideos[index]
            try? FileManager.default.removeItem(at: video.fileURL)
        }
        exportedVideos.remove(atOffsets: offsets)
        saveToStorage()
    }

    func deleteVideo(_ video: ExportedVideo) {
        try? FileManager.default.removeItem(at: video.fileURL)
        exportedVideos.removeAll { $0.id == video.id }
        saveToStorage()
    }

    func saveToPhotoLibrary(video: ExportedVideo) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self?.showFeedbackToast("未获得相册权限，无法保存")
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video.fileURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.showFeedbackToast("已成功保存大视频至相册！")
                    } else {
                        self?.showFeedbackToast("保存至相册失败：\(error?.localizedDescription ?? "未知错误")")
                    }
                }
            }
        }
    }

    private func showFeedbackToast(_ message: String) {
        self.toastMessage = message
        self.showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.showToast = false
        }
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let list = try? JSONDecoder().decode([ExportedVideo].self, from: data) {
            // 过滤掉实际磁盘中已不存在的文件
            self.exportedVideos = list.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        }
    }

    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(exportedVideos) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
