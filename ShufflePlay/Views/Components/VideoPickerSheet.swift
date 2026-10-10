import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct VideoPickerSheet: UIViewControllerRepresentable {
    var onSelected: ([URL]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 0 // 0 表示允许多选，无数量上限
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPickerSheet

        init(_ parent: VideoPickerSheet) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            let group = DispatchGroup()
            let lock = NSLock()
            var collectedURLs: [URL] = []
            let tempDir = FileManager.default.temporaryDirectory

            for result in results {
                let provider = result.itemProvider
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                        defer { group.leave() }
                        guard let url = url else { return }
                        let dest = tempDir.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")
                        do {
                            if FileManager.default.fileExists(atPath: dest.path) {
                                try FileManager.default.removeItem(at: dest)
                            }
                            try FileManager.default.copyItem(at: url, to: dest)
                            lock.lock()
                            collectedURLs.append(dest)
                            lock.unlock()
                        } catch {
                            print("[VideoPickerSheet] Copy error: \(error)")
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                self.parent.onSelected(collectedURLs)
            }
        }
    }
}
