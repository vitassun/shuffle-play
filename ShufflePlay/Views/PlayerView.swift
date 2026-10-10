import SwiftUI
import AVFoundation

struct PlayerView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @State private var showSleepTimerSheet = false
    @State private var isSeeking = false
    @State private var seekSliderValue: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部状态提示条（后台播放状态指示）
                backgroundPlaybackBanner

                // 中间视频播放画面
                videoPlayerArea
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .background(Color.black)

                // 播放控制与设置区域
                ScrollView {
                    VStack(spacing: 20) {
                        // 视频标题与信息
                        videoMetaSection

                        // 进度条与时间显示
                        progressSliderSection

                        // 核心播放控制按钮
                        mainControlsSection

                        // 定时关闭与辅助功能卡片
                        sleepTimerAndToolsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("播放器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSleepTimerSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: playerVM.sleepTimerManager.isTimerActive ? "timer.circle.fill" : "timer")
                                .foregroundColor(playerVM.sleepTimerManager.isTimerActive ? .green : .primary)
                            if playerVM.sleepTimerManager.isTimerActive {
                                Text(playerVM.sleepTimerManager.formattedRemainingTime)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showSleepTimerSheet) {
                SleepTimerSheet(timerManager: playerVM.sleepTimerManager)
            }
        }
    }

    // MARK: - 后台播放提示横幅
    private var backgroundPlaybackBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text("后台/锁屏播放已就绪：即使锁屏也会持续播放声音")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Circle()
                .fill(playerVM.isPlaying ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - 视频渲染区域
    private var videoPlayerArea: some View {
        ZStack {
            if playerVM.player != nil {
                VideoPlayerRepresentable(player: playerVM.player)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "play.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("当前没有正在播放的视频")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("可在“合成”页面生成大视频或从“历史库”中选择")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
        }
    }

    // MARK: - 视频元信息
    private var videoMetaSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playerVM.currentTitle)
                .font(.headline)
                .lineLimit(2)

            HStack {
                Text("时长: \(playerVM.formattedDuration)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if playerVM.sleepTimerManager.isTimerActive {
                    HStack(spacing: 4) {
                        Image(systemName: "bed.double.fill")
                            .font(.caption2)
                        Text("定时剩余: \(playerVM.sleepTimerManager.formattedRemainingTime)")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - 进度条区域
    private var progressSliderSection: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: {
                        isSeeking ? seekSliderValue : playerVM.currentTime
                    },
                    set: { newValue in
                        seekSliderValue = newValue
                    }
                ),
                in: 0...max(1, playerVM.duration),
                onEditingChanged: { editing in
                    isSeeking = editing
                    if !editing {
                        playerVM.seek(to: seekSliderValue)
                    }
                }
            )
            .tint(.blue)

            HStack {
                Text(playerVM.formattedCurrentTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                Spacer()
                Text("-\(playerVM.formattedRemainingTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 主控制按钮
    private var mainControlsSection: some View {
        HStack(spacing: 36) {
            // 快退 15 秒
            Button {
                playerVM.seekBackward(by: 15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 28))
                    .foregroundColor(.primary)
            }
            .disabled(playerVM.player == nil)

            // 播放 / 暂停
            Button {
                playerVM.togglePlayPause()
            } label: {
                Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
            }
            .disabled(playerVM.player == nil)

            // 快进 15 秒
            Button {
                playerVM.seekForward(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 28))
                    .foregroundColor(.primary)
            }
            .disabled(playerVM.player == nil)
        }
        .padding(.vertical, 10)
    }

    // MARK: - 定时与辅助卡片
    private var sleepTimerAndToolsSection: some View {
        VStack(spacing: 12) {
            // 定时关闭设置按钮
            Button {
                showSleepTimerSheet = true
            } label: {
                HStack {
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.indigo)
                    Text("睡眠定时关闭")
                        .foregroundColor(.primary)
                    Spacer()
                    if playerVM.sleepTimerManager.isTimerActive {
                        Text(playerVM.sleepTimerManager.formattedRemainingTime)
                            .foregroundColor(.blue)
                            .font(.subheadline)
                    } else {
                        Text("未开启")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            // 循环播放切换
            HStack {
                Toggle(isOn: $playerVM.isLooping) {
                    HStack {
                        Image(systemName: "repeat")
                            .foregroundColor(.blue)
                        Text("循环播放大视频")
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}
