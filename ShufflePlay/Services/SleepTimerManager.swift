import Foundation
import Combine
import UIKit

enum SleepTimerOption: Hashable, Identifiable {
    case off
    case minutes(Int)
    case endOfVideo
    case custom(Int)

    var id: String {
        switch self {
        case .off: return "off"
        case .minutes(let m): return "min_\(m)"
        case .endOfVideo: return "end_of_video"
        case .custom(let m): return "custom_\(m)"
        }
    }

    var title: String {
        switch self {
        case .off: return "关闭"
        case .minutes(let m): return "\(m) 分钟"
        case .endOfVideo: return "当前视频结束时"
        case .custom(let m): return "自定义 (\(m) 分钟)"
        }
    }
}

final class SleepTimerManager: ObservableObject {
    @Published var selectedOption: SleepTimerOption = .off
    @Published var isTimerActive: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var fadeOutAudio: Bool = true

    private var timer: Timer?
    private var targetDate: Date?
    var onTimerTriggered: (() -> Void)?
    var onVolumeFade: ((Float) -> Void)?

    init() {}

    /// 启动定时器
    func startTimer(option: SleepTimerOption) {
        stopTimer()
        selectedOption = option

        switch option {
        case .off:
            return

        case .minutes(let mins), .custom(let mins):
            let seconds = mins * 60
            remainingSeconds = seconds
            targetDate = Date().addingTimeInterval(TimeInterval(seconds))
            isTimerActive = true

            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.tick()
            }

        case .endOfVideo:
            isTimerActive = true
            remainingSeconds = 0
            // 当视频自然结束时，由 PlayerViewModel 通知触发
        }
    }

    /// 停止定时器
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        targetDate = nil
        isTimerActive = false
        remainingSeconds = 0
        selectedOption = .off
        onVolumeFade?(1.0)
    }

    /// 每秒心跳更新
    private func tick() {
        guard let target = targetDate else {
            stopTimer()
            return
        }

        let diff = Int(target.timeIntervalSinceNow)
        if diff <= 0 {
            triggerTimerEnd()
        } else {
            remainingSeconds = diff

            // 如果最后 10 秒开启渐弱
            if fadeOutAudio && diff <= 10 {
                let volumeFactor = Float(diff) / 10.0
                onVolumeFade?(max(0.0, min(1.0, volumeFactor)))
            }
        }
    }

    /// 触发定时关闭
    func triggerTimerEnd() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stopTimer()
            // 触觉反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.onTimerTriggered?()
        }
    }

    /// 格式化倒计时文字，如 "14:59"
    var formattedRemainingTime: String {
        guard isTimerActive else { return "" }
        if case .endOfVideo = selectedOption {
            return "播完即停"
        }
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
