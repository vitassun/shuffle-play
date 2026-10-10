import SwiftUI
import AVFoundation

@main
struct ShufflePlayApp: App {
    init() {
        // App 启动时配置后台播放音频会话
        AudioSessionManager.shared.configureForPlayback()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
