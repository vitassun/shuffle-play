import Foundation
import MediaPlayer
import UIKit

final class NowPlayingManager {
    static let shared = NowPlayingManager()

    private var playerViewModel: PlayerViewModel?

    private init() {
        setupRemoteCommands()
    }

    func attach(playerViewModel: PlayerViewModel) {
        self.playerViewModel = playerViewModel
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // 播放命令
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self, let vm = self.playerViewModel else { return .commandFailed }
            vm.play()
            return .success
        }

        // 暂停命令
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self, let vm = self.playerViewModel else { return .commandFailed }
            vm.pause()
            return .success
        }

        // 播放/暂停切换命令
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self, let vm = self.playerViewModel else { return .commandFailed }
            vm.togglePlayPause()
            return .success
        }

        // 快退 15 秒
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self = self, let vm = self.playerViewModel else { return .commandFailed }
            vm.seekBackward(by: 15)
            return .success
        }

        // 快进 15 秒
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            guard let self = self, let vm = self.playerViewModel else { return .commandFailed }
            vm.seekForward(by: 15)
            return .success
        }

        // 拖动锁屏进度条命令
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let vm = self.playerViewModel,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            vm.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    /// 更新锁屏 Now Playing 信息
    func updateNowPlaying(
        title: String,
        duration: TimeInterval,
        currentTime: TimeInterval,
        isPlaying: Bool,
        artworkImage: UIImage? = nil
    ) {
        var info = [String: Any]()

        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = "ShufflePlay"
        info[MPMediaItemPropertyPlaybackDuration] = max(0, duration)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, currentTime)
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let artworkImage = artworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                return artworkImage
            }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 清理锁屏信息
    func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
