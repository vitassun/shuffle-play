import SwiftUI
import AVFoundation

struct VideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer?
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.videoGravity = videoGravity
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.videoGravity = videoGravity
        uiView.player = player
    }
}

final class PlayerContainerView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var storedPlayer: AVPlayer?

    var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    var player: AVPlayer? {
        get { storedPlayer }
        set {
            storedPlayer = newValue
            playerLayer.player = newValue
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
        setupBackgroundHandling()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    private func setupBackgroundHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 应用退入后台或锁屏时：解除 layer 绑定，防止 iOS 图层渲染引擎自动暂停 AVPlayer 音频！
    @objc private func appDidEnterBackground() {
        playerLayer.player = nil
    }

    /// 应用返回前台：重新绑定 layer，恢复画面渲染
    @objc private func appWillEnterForeground() {
        playerLayer.player = storedPlayer
    }
}
