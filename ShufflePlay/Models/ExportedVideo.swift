import SwiftUI
import AVFoundation

struct ExportedVideo: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String
    let relativePath: String
    let createdAt: Date
    let duration: TimeInterval
    let originalVideoCount: Int
    let fileSize: Int64

    init(
        id: UUID = UUID(),
        filename: String,
        relativePath: String,
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        originalVideoCount: Int = 0,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.filename = filename
        self.relativePath = relativePath
        self.createdAt = createdAt
        self.duration = duration
        self.originalVideoCount = originalVideoCount
        self.fileSize = fileSize
    }

    var fileURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDir.appendingPathComponent(relativePath)
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

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    static func == (lhs: ExportedVideo, rhs: ExportedVideo) -> Bool {
        lhs.id == rhs.id
    }
}
