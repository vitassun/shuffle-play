# 🔀 ShufflePlay - iOS 视频随机打乱拼接与后台播放器

ShufflePlay 是一款专为 iOS 设计的视频拼接与睡眠听剧/伴睡播放工具。

它可以将你导入的多个视频片段**随机打乱顺序**并无缝合成拼接为一个完整的大视频；同时内置专业播放器，不仅拥有**定时自动关闭（睡眠定时器）**功能，更支持**即使在手机锁屏后也能持续在后台播放声音**，并可在锁屏界面进行控制。

---

## ✨ 核心功能亮点

1. **多途径视频导入**
   - 📸 **系统相册导入**：通过系统原生 PhotosPicker 批量选择视频，自动解析视频时长、分辨率与文件大小。
   - 📁 **“文件”App 导入**：支持从 iCloud Drive、本地“文件”App 导入任意视频文件。
   - 📋 **列表管理**：支持预览缩略图、拖拽调整顺序或删除特定片段。

2. **随机打乱 & 智能视频合成 (Shuffle & Merge)**
   - 🎲 **全随机顺序打乱**：点击一键对导入的视频片段进行无偏随机重排。
   - 🎬 **专业级画轨/音轨无缝拼接**：
     - 基于 Apple 原生 `AVFoundation` (`AVMutableComposition` + `AVMutableVideoComposition`)。
     - 智能计算渲染画布与 Aspect Fit 适配，自适应横竖屏方向变换 (`preferredTransform`)，彻底杜绝视频扭曲或方向倒置。
     - 健壮处理无音轨视频，确保拼接过程顺畅。
   - 📊 **实时进度反馈**：导出大视频时提供精准的百分比与进度条。

3. **内置播放器 (Player)**
   - ⏯️ **完整控制**：播放/暂停、快进 15 秒、快退 15 秒、精确滑动拖拽进度条。
   - 🔁 **循环播放**：支持大视频循环播放。
   - 📱 **手势与画幅适配**：内置基于 `AVPlayerLayer` 的轻量高性能渲染引擎。

4. **锁屏 & 后台声音播放 (Background Audio Playback)**
   - 🎧 **锁屏不断音**：配置了系统级 `UIBackgroundModes -> audio` 与 `AVAudioSession (.playback)` 模式。在手机锁屏或切换后台时，视频画面自动断开绑定，声音无缝持续输出！
   - 🎛️ **锁屏控制中心 (MPRemoteCommandCenter)**：锁屏界面支持显示视频标题、时长、进度条拖动，以及暂停、播放、快退 15 秒、快进 15 秒操作。

5. **智能睡眠定时关闭 (Sleep Timer)**
   - ⏱️ **丰富的时间预设**：支持 15分钟、30分钟、45分钟、60分钟，或 1~180 分钟自定义滑块选择。
   - ⏹️ **当前视频播完即停**：支持播放完毕自动停止。
   - 📉 **平滑音量渐弱**：定时关闭前最后 10 秒音量平滑渐弱，防止声音突停惊醒休息。

6. **历史合成库 (Library)**
   - 🗂️ 自动持久化保存历史生成的大视频。
   - 💾 支持一键保存大视频到系统相册。
   - 📤 支持系统原生分享面板 (AirDrop、微信等)。

---

## 🏗️ 架构设计与技术栈

- **语言**：Swift 5.0+
- **界面**：SwiftUI (iOS 16.0+) + UIKit Bridge
- **多媒体引擎**：
  - `AVFoundation` (`AVPlayer`, `AVPlayerLayer`, `AVURLAsset`, `AVAssetImageGenerator`)
  - `AVMutableComposition` + `AVAssetExportSession`
  - `AVAudioSession` + `MediaPlayer` (`MPRemoteCommandCenter`, `MPNowPlayingInfoCenter`)
- **构建系统**：XcodeGen + Xcode 15/16 + GitHub Actions CI/CD 自动编译并打包产出 IPA。

---

## 📲 如何安装生成的 IPA 文件

GitHub Actions 编译完成后，会在此仓库的 **Releases** 或 **Actions Artifacts** 中自动生成 `ShufflePlay.ipa`。

你可以通过以下常见途径安装到 iPhone/iPad：

1. **巨魔商店 (TrollStore)** *(推荐)*：
   - 使用 iOS 设备的 Safari 浏览器下载 `ShufflePlay.ipa`。
   - 点击“用 TrollStore 打开”，即可实现永久免越狱免掉签安装。
2. **AltStore / SideStore**：
   - 在手机或电脑上的 AltStore 中点击 `+` 导入下载的 `ShufflePlay.ipa`，输入个人 Apple ID 签名安装。
3. **爱思助手 / Sideloadly**：
   - 电脑端连接手机，选择 IPA 签名安装。
