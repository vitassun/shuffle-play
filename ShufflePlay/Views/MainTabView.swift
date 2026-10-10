import SwiftUI

struct MainTabView: View {
    @StateObject private var mergeVM = MergeViewModel()
    @StateObject private var playerVM = PlayerViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MergeView(
                mergeVM: mergeVM,
                playerVM: playerVM,
                selectedTab: $selectedTab
            )
            .tabItem {
                Label("随机合成", systemImage: "shuffle.circle")
            }
            .tag(0)

            PlayerView(
                playerVM: playerVM
            )
            .tabItem {
                Label("正在播放", systemImage: "play.circle")
            }
            .tag(1)

            LibraryView(
                playerVM: playerVM,
                selectedTab: $selectedTab
            )
            .tabItem {
                Label("历史库", systemImage: "folder.circle")
            }
            .tag(2)
        }
    }
}
