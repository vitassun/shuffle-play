import Foundation
import AVFoundation
import Combine
import UIKit

final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLooping: Bool = false
    @Published var currentTitle: String = "未选择视频"
    @Published var currentVideoURL: URL?
    @Published var currentThumbnail: UIImage?
    @Published var isMuted: Bool = false
    @Published var volume: Float = 1.0

    let sleepTimerManager = SleepTimerManager()
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    private var wasPlayingBeforeBackground: Bool = false

    init() {
        AudioSessionManager.shared.configureForPlayback()
        NowPlayingManager.shared.attach(playerViewModel: self)
        setupSleepTimerCallbacks()
        setupBackgroundObservers()
    }

    deinit {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }

    /// 加载视频进行播放
    func loadVideo(url: URL, title: String? = nil, thumbnail: UIImage? = nil) {
        // 清理旧状态
        stop()

        currentVideoURL = url
        currentTitle = title ?? url.lastPathComponent
        currentThumbnail = thumbnail

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.actionAtItemEnd = .none // 手动控制循环或播完行为
        newPlayer.preventsDisplaySleepDuringVideoPlayback = true
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        self.player = newPlayer

        // 读取时长
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        if durationSeconds.isFinite && durationSeconds > 0 {
            self.duration = durationSeconds
        } else {
            self.duration = 0
        }

        setupTimeObserver()
        setupItemEndNotification(for: playerItem)

        // 自动开始播放
        play()

        // 异步提取高清第一帧封面作为锁屏 Artwork
        if thumbnail == nil {
            generateThumbnailAsync(for: asset)
        } else {
            updateNowPlaying()
        }
    }

    func play() {
        guard let player = player else { return }
        AudioSessionManager.shared.configureForPlayback()
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        guard let player = player else { return }
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func stop() {
        removeTimeObserver()
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentVideoURL = nil
        currentThumbnail = nil
        NowPlayingManager.shared.clearNowPlaying()
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let clampedTime = max(0, min(time, duration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = clampedTime
            self.updateNowPlaying()
        }
    }

    func seekForward(by seconds: TimeInterval = 15) {
        seek(to: currentTime + seconds)
    }

    func seekBackward(by seconds: TimeInterval = 15) {
        seek(to: currentTime - seconds)
    }

    func toggleLoop() {
        isLooping.toggle()
    }

    func setVolume(_ newVolume: Float) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        player?.volume = clamped
    }

    // MARK: - 内部定时更新与观察

    private func setupTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                self.currentTime = seconds
            }

            // 同步 duration (部分网络或动态 asset 延迟获取 duration)
            if let currentItem = self.player?.currentItem {
                let dur = CMTimeGetSeconds(currentItem.duration)
                if dur.isFinite && dur > 0 && self.duration != dur {
                    self.duration = dur
                }
            }

            self.updateNowPlaying()
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func setupItemEndNotification(for item: AVPlayerItem) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    @objc private func playerItemDidReachEnd(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 检查定时器是否为“当前视频结束时关闭”
            if case .endOfVideo = self.sleepTimerManager.selectedOption {
                self.sleepTimerManager.triggerTimerEnd()
                return
            }

            if self.isLooping {
                self.seek(to: 0)
                self.play()
            } else {
                self.pause()
                self.seek(to: 0)
            }
        }
    }

    // MARK: - 定时关闭联动

    private func setupSleepTimerCallbacks() {
        sleepTimerManager.onTimerTriggered = { [weak self] in
            print("[Player] Sleep timer fired! Pausing playback.")
            self?.pause()
        }

        sleepTimerManager.onVolumeFade = { [weak self] factor in
            self?.player?.volume = factor
        }
    }

    // MARK: - 后台播放保护

    private func setupBackgroundObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleDidEnterBackground() {
        wasPlayingBeforeBackground = isPlaying
        // 确保后台音频会话激活，保证锁屏后声音不中断
        AudioSessionManager.shared.configureForPlayback()
        if wasPlayingBeforeBackground {
            player?.play()
            updateNowPlaying()
        }
    }

    @objc private func handleWillEnterForeground() {
        if wasPlayingBeforeBackground && isPlaying {
            player?.play()
        }
    }

    private func updateNowPlaying() {
        NowPlayingManager.shared.updateNowPlaying(
            title: currentTitle,
            duration: duration,
            currentTime: currentTime,
            isPlaying: isPlaying,
            artworkImage: currentThumbnail
        )
    }

    private func generateThumbnailAsync(for asset: AVAsset) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 500, height: 500)
            let time = CMTime(seconds: min(1.0, CMTimeGetSeconds(asset.duration) / 2.0), preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let img = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    self?.currentThumbnail = img
                    self?.updateNowPlaying()
                }
            }
        }
    }

    // MARK: - 辅助计算

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    var formattedRemainingTime: String {
        formatTime(max(0, duration - currentTime))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
