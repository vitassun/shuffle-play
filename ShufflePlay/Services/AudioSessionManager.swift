import Foundation
import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private init() {
        setupNotifications()
    }

    /// 配置全局音频会话以支持后台与锁屏播放
    func configureForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback 允许在静音开关打开或应用进入后台/锁屏时继续播放音频
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
            print("[AudioSession] Configured successfully for background playback.")
        } catch {
            print("[AudioSession] Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("[AudioSession] Audio interruption began.")
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("[AudioSession] Audio interruption ended, should resume.")
                    try? AVAudioSession.sharedInstance().setActive(true)
                }
            }
        @unknown default:
            break
        }
    }
}
