import SwiftUI
import PhotosUI

struct MergeView: View {
    @ObservedObject var mergeVM: MergeViewModel
    @ObservedObject var playerVM: PlayerViewModel
    @Binding var selectedTab: Int

    @State private var showDocumentPicker = false
    @State private var showPhotosPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部状态栏信息
                summaryHeaderView

                Divider()

                if mergeVM.selectedVideos.isEmpty {
                    emptyStateView
                } else {
                    videoListView
                }

                Divider()

                // 底部合成操作区
                bottomActionView
            }
            .navigationTitle("随机合成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !mergeVM.selectedVideos.isEmpty {
                        Button(role: .destructive) {
                            mergeVM.clearVideos()
                        } label: {
                            Text("清空")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { urls in
                    mergeVM.handlePickedFileURLs(urls)
                }
            }
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $mergeVM.photoPickerItems,
                matching: .videos
            )
            .onChange(of: mergeVM.photoPickerItems) { _ in
                mergeVM.handlePickedPhotos()
            }
            .sheet(isPresented: $mergeVM.showSuccessSheet) {
                if let video = mergeVM.latestExportedVideo {
                    successSheetView(for: video)
                }
            }
            .alert("提示", isPresented: $mergeVM.showErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(mergeVM.errorMessage ?? "未知错误")
            }
            .overlay {
                if mergeVM.isExporting {
                    exportingOverlayView
                }
            }
        }
    }

    // MARK: - 顶部统计栏
    private var summaryHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("待合成片段")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(mergeVM.selectedVideos.count) 个视频")
                    .font(.headline)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("预计总时长")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(mergeVM.formattedTotalDuration)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "shuffle.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue.opacity(0.8))

            VStack(spacing: 8) {
                Text("导入多个视频并打乱拼接")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("导入后程序将把视频顺序完全随机打乱\n并无缝拼接成一个单独的大视频")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("相册导入", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showDocumentPicker = true
                } label: {
                    Label("文件导入", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)
            .padding(.top, 10)

            Spacer()
        }
    }

    // MARK: - 视频列表
    private var videoListView: some View {
        List {
            Section {
                ForEach(mergeVM.selectedVideos) { video in
                    HStack(spacing: 12) {
                        VideoThumbnailView(
                            thumbnail: video.thumbnail,
                            durationText: video.formattedDuration
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.filename)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                if video.resolution != .zero {
                                    Text("\(Int(video.resolution.width))×\(Int(video.resolution.height))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(video.formattedFileSize)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .onDelete(perform: mergeVM.removeVideo)
                .onMove(perform: mergeVM.moveVideos)
            } header: {
                HStack {
                    Text("拖拽可微调，合成时会自动全随机打乱")
                    Spacer()
                    EditButton()
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 底部操作栏
    private var bottomActionView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("添加相册", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showDocumentPicker = true
                } label: {
                    Label("添加文件", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                mergeVM.startShuffleAndMerge()
            } label: {
                HStack {
                    Image(systemName: "shuffle")
                    Text("随机打乱并合成大视频")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(mergeVM.selectedVideos.count < 2 || mergeVM.isExporting)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - 导出中蒙层
    private var exportingOverlayView: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: mergeVM.exportProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                Text(mergeVM.statusMessage)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("正在打乱顺序并合并画轨与音轨，请稍候...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Button("取消合成", role: .destructive) {
                    mergeVM.cancelExport()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - 合成成功弹出页
    private func successSheetView(for video: ExportedVideo) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 70, height: 70)
                    .foregroundColor(.green)
                    .padding(.top, 20)

                VStack(spacing: 6) {
                    Text("大视频合成成功！")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("已打乱 \(video.originalVideoCount) 个视频并合成为一个整体")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 10) {
                    HStack {
                        Text("文件名称")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(video.filename)
                            .lineLimit(1)
                    }
                    HStack {
                        Text("总时长")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(video.formattedDuration)
                    }
                    HStack {
                        Text("文件大小")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(video.formattedFileSize)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Button {
                        mergeVM.showSuccessSheet = false
                        playerVM.loadVideo(url: video.fileURL, title: video.filename)
                        selectedTab = 1 // 切换至播放器 Tab
                    } label: {
                        Label("立即播放大视频", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        LibraryViewModel.shared.saveToPhotoLibrary(video: video)
                    } label: {
                        Label("保存至手机相册", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("合成完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        mergeVM.showSuccessSheet = false
                    }
                }
            }
        }
    }
}
