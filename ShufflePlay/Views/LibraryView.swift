import SwiftUI

struct LibraryView: View {
    @ObservedObject var libraryVM = LibraryViewModel.shared
    @ObservedObject var playerVM: PlayerViewModel
    @Binding var selectedTab: Int

    @State private var sharingVideoURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                if libraryVM.exportedVideos.isEmpty {
                    emptyLibraryView
                } else {
                    videoList
                }

                if libraryVM.showToast, let msg = libraryVM.toastMessage {
                    toastOverlay(message: msg)
                }
            }
            .navigationTitle("合成历史库")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                if let url = sharingVideoURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    private var emptyLibraryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundColor(.secondary.opacity(0.6))

            Text("暂无合成的大视频")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("前往“合成”页面导入视频并打乱拼接，\n生成的大视频会保存在这里。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var videoList: some View {
        List {
            ForEach(libraryVM.exportedVideos) { video in
                HStack(spacing: 12) {
                    // 缩略图占位
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 55)
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.filename)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(video.formattedDuration)
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(video.formattedFileSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(video.originalVideoCount)个片段")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Text(video.formattedDate)
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }

                    Spacer()

                    Menu {
                        Button {
                            playerVM.loadVideo(url: video.fileURL, title: video.filename)
                            selectedTab = 1
                        } label: {
                            Label("立即播放", systemImage: "play.circle")
                        }

                        Button {
                            libraryVM.saveToPhotoLibrary(video: video)
                        } label: {
                            Label("保存到相册", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            sharingVideoURL = video.fileURL
                            showShareSheet = true
                        } label: {
                            Label("分享视频", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            libraryVM.deleteVideo(video)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    playerVM.loadVideo(url: video.fileURL, title: video.filename)
                    selectedTab = 1
                }
            }
            .onDelete(perform: libraryVM.deleteVideo)
        }
        .listStyle(.insetGrouped)
    }

    private func toastOverlay(message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .padding(.bottom, 24)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: libraryVM.showToast)
    }
}
