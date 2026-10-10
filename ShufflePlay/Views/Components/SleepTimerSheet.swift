import SwiftUI

struct SleepTimerSheet: View {
    @ObservedObject var timerManager: SleepTimerManager
    @Environment(\.dismiss) private var dismiss

    @State private var customMinutes: Double = 20
    @State private var showCustomSlider: Bool = false

    private let presetMinutes = [15, 30, 45, 60]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if timerManager.isTimerActive {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("当前定时运行中")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("剩余时间: \(timerManager.formattedRemainingTime)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                timerManager.stopTimer()
                            } label: {
                                Text("取消定时")
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("常用定时时长")) {
                    ForEach(presetMinutes, id: \.self) { mins in
                        Button {
                            timerManager.startTimer(option: .minutes(mins))
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "timer")
                                    .foregroundColor(.blue)
                                Text("\(mins) 分钟")
                                    .foregroundColor(.primary)
                                Spacer()
                                if isSelected(mins: mins) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }

                    Button {
                        timerManager.startTimer(option: .endOfVideo)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle")
                                .foregroundColor(.orange)
                            Text("当前视频播放结束时")
                                .foregroundColor(.primary)
                            Spacer()
                            if case .endOfVideo = timerManager.selectedOption, timerManager.isTimerActive {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                Section(header: Text("自定义时长")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("设定时长: \(Int(customMinutes)) 分钟")
                                .font(.body)
                            Spacer()
                            Button("确定启动") {
                                timerManager.startTimer(option: .custom(Int(customMinutes)))
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        Slider(value: $customMinutes, in: 1...180, step: 1)
                            .tint(.blue)

                        HStack {
                            Text("1分钟")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("180分钟")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("睡眠体验选项"), footer: Text("定时关闭前 10 秒会自动平滑降低音量，避免声音骤停打扰休息。")) {
                    Toggle("结束前音量平滑渐弱", isOn: $timerManager.fadeOutAudio)
                }
            }
            .navigationTitle("定时关闭播放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func isSelected(mins: Int) -> Bool {
        if case .minutes(let current) = timerManager.selectedOption, timerManager.isTimerActive {
            return current == mins
        }
        return false
    }
}
