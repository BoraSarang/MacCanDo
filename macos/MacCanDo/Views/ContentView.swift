// [FEATURE] 메인 콘텐츠 — NavigationSplitView 3열 (T-06)
// 사이드바: 글 관리 / 댓글 승인 / 통계 / 설정 (Music 앱 스타일)
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case posts = "글 관리"
    case series = "시리즈"
    case comments = "댓글 승인"
    case stats = "통계"
    case ads = "광고"
    case settings = "설정"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .posts: return "square.and.pencil"
        case .series: return "books.vertical"
        case .comments: return "bubble.left.and.bubble.right"
        case .stats: return "chart.bar"
        case .ads: return "megaphone"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .posts
    @State private var sidebarWidth: CGFloat = 190

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                sidebarRow(item)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 48, ideal: 190)
            .background(
                // T-12: 사이드바 폭 감지 — 좁아지면 아이콘만 표시 (Finder 스타일)
                GeometryReader { geo in
                    Color.clear
                        .onAppear { sidebarWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in sidebarWidth = w }
                }
            )
        } detail: {
            switch selection ?? .posts {
            case .posts: PostsView()
            case .series: SeriesView()
            case .comments: CommentsView()
            case .stats: StatsView()
            case .ads: AdsView()
            case .settings: SettingsView()
            }
        }
        .navigationTitle("MacCanDo")
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSettings)) { _ in
            selection = .settings
        }
    }

    // T-12: 폭 110 미만이면 아이콘만 (라벨 숨김, 툴팁으로 이름 표시)
    @ViewBuilder
    private func sidebarRow(_ item: SidebarItem) -> some View {
        if sidebarWidth < 110 {
            Image(systemName: item.icon)
                .frame(maxWidth: .infinity)
                .help(item.rawValue)
        } else {
            Label(item.rawValue, systemImage: item.icon)
        }
    }
}