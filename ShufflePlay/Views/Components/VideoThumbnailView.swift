import SwiftUI

struct VideoThumbnailView: View {
    let thumbnail: UIImage?
    let durationText: String
    var width: CGFloat = 80
    var height: CGFloat = 50

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "video.fill")
                            .foregroundColor(.secondary)
                    )
            }

            if !durationText.isEmpty {
                Text(durationText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(4)
                    .padding(4)
            }
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
