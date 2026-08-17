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

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 190)
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
}