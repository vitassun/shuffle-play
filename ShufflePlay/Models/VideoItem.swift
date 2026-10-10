import SwiftUI
import AVFoundation

struct VideoItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let filename: String
    let duration: TimeInterval
    let resolution: CGSize
    let fileSize: Int64
    var thumbnail: UIImage?

    init(
        id: UUID = UUID(),
        url: URL,
        filename: String? = nil,
        duration: TimeInterval = 0,
        resolution: CGSize = .zero,
        fileSize: Int64 = 0,
        thumbnail: UIImage? = nil
    ) {
        self.id = id
        self.url = url
        self.filename = filename ?? url.lastPathComponent
        self.duration = duration
        self.resolution = resolution
        self.fileSize = fileSize
        self.thumbnail = thumbnail
    }

    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        lhs.id == rhs.id
    }
}
