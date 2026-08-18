// [FEATURE] 메인 콘텐츠 — NavigationSplitView 3열 (T-06)
// T-35: 사이드바 220pt + SF Symbols + 컨텍스트 메뉴 + ⌘1~7 화면 전환 + @SceneStorage 선택 복원
// T-42: ⌘K 커맨드 팔레트 오버레이
// T-45: 설정 → 별도 Settings scene(⌘,)으로 이동 — 사이드바에서 제거
// T-46: ⌘1~8 hidden Button 통일 + ⌥⌘S 사이드바 토글 + 사이드바 배지(댓글 대기/초안) + 맥 소식 탭(+⌘8)
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case posts = "글 관리"
    case series = "시리즈"
    case comments = "댓글 승인"
    case stats = "통계"
    case ads = "광고"
    case assistant = "AI 도우미" // T-21: 새 창으로 열리는 항목 (패널 전환 없음)
    case macNews = "맥 소식" // T-46: 도우미 창에서 사이드바 독립 탭으로 승격

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .posts: return "square.and.pencil"
        case .series: return "books.vertical"
        case .comments: return "bubble.left.and.bubble.right"
        case .stats: return "chart.bar"
        case .ads: return "megaphone"
        case .assistant: return "wand.and.stars"
        case .macNews: return "newspaper"
        }
    }

    // T-35/T-46: ⌘1~8 화면 전환 단축키 번호 (assistant는 새 창 열기, 설정은 ⌘,)
    var shortcutNumber: Int? {
        switch self {
        case .posts: return 1
        case .series: return 2
        case .comments: return 3
        case .stats: return 4
        case .ads: return 5
        case .assistant: return 6
        case .macNews: return 8
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var auth: AuthStore
    // T-33: 선택 화면 상태 복원 (앱 재시작 후 마지막 화면 유지)
    // SceneStorage는 macOS 종료 시 저장이 보장되지 않아 AppStorage(UserDefaults)로 변경 (통계 → 글 관리 리셋 버그 수정)
    @AppStorage("sidebar.selection") private var selectionRaw: String = SidebarItem.posts.rawValue
    @State private var sidebarWidth: CGFloat = 220
    @State private var showPalette = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all // T-46: ⌥⌘S 토글
    @State private var pendingCommentCount: Int? // T-46: 사이드바 배지
    @State private var draftsCount = 0
    @State private var badgeTimer: Timer?

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: { SidebarItem(rawValue: selectionRaw) },
            set: { selectionRaw = $0?.rawValue ?? SidebarItem.posts.rawValue }
        )
    }

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                List(SidebarItem.allCases, selection: selection) { item in
                    if item == .assistant {
                        // AI 도우미: 새 창으로 열기 — 오른쪽 패널 전환 없음 (에디터 창과 나란히 활용)
                        Button { openAssistantWindow() } label: { sidebarRow(item) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("AI 도우미 열기") { openAssistantWindow() }
                            }
                    } else {
                        sidebarRow(item)
                            .tag(item)
                            .contextMenu { sidebarContextMenu(item) }
                    }
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 48, ideal: 220, max: 300)
                .background(
                    // T-12: 사이드바 폭 감지 — 좁아지면 아이콘만 표시 (Finder 스타일)
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { sidebarWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, w in sidebarWidth = w }
                    }
                )
            } detail: {
                switch selection.wrappedValue ?? .posts {
                case .posts: PostsView()
                case .series: SeriesView()
                case .comments: CommentsView()
                case .stats: StatsView()
                case .ads: AdsView()
                case .assistant: EmptyView() // 새 창으로 열리므로 패널에는 표시 안 함
                case .macNews: MacNewsView() // T-46: 사이드바 독립 탭
                }
            }
            .navigationTitle("MacCanDo")
            .onReceive(NotificationCenter.default.publisher(for: .newPostRequested)) { _ in
                openNewPost()
            }

            // T-42: ⌘K 팔레트
            if showPalette {
                CommandPaletteView(selection: selection) {
                    withAnimation(.easeOut(duration: 0.15)) { showPalette = false }
                }
                .environmentObject(auth)
                .transition(.opacity)
            }
        }
        .background(
            // T-46: ⌘1~8 — 숨은 버튼 패턴으로 단축키 수신 (List 바인딩 keyboardShortcut 제거)
            VStack(spacing: 0) {
                ForEach(SidebarItem.allCases) { item in
                    Button("") { selectTab(item) }
                        .keyboardShortcut(shortcut(item))
                        .hidden()
                }
                Button("") { togglePalette() }
                    .keyboardShortcut("k", modifiers: .command)
                    .hidden()
                // T-46: ⌥⌘S — 사이드바 표시/숨김 (Xcode/Finder 패턴)
                Button("") { toggleSidebar() }
                    .keyboardShortcut("s", modifiers: [.command, .option])
                    .hidden()
            }
        )
        .onAppear {
            loadBadges()
            badgeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                Task { await loadPendingCount() }
            }
        }
        .onDisappear {
            badgeTimer?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .postSaved)) { _ in
            draftsCount = DraftStore.all().count
        }
    }

    // T-46: 사이드바 배지 — 댓글 대기 수(60초 타이머) + 초안 수(로컬 즉시)
    private func loadBadges() {
        draftsCount = DraftStore.all().count
        Task { await loadPendingCount() }
    }

    private func loadPendingCount() async {
        guard auth.isAuthed else {
            pendingCommentCount = nil
            return
        }
        do {
            let stats: AdminStats = try await APIClient.request("api/admin/stats", token: auth.token)
            pendingCommentCount = stats.pendingCommentCount
        } catch {
            pendingCommentCount = nil
        }
    }

    private func selectTab(_ item: SidebarItem) {
        if item == .assistant {
            openAssistantWindow()
        } else {
            selection.wrappedValue = item
        }
        DebugLogger.info("Nav", "화면 전환 → \(item.rawValue)")
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
        DebugLogger.info("Nav", "사이드바 \(columnVisibility == .detailOnly ? "숨김" : "표시")")
    }

    private func togglePalette() {
        withAnimation(.easeOut(duration: 0.15)) { showPalette.toggle() }
        DebugLogger.info("Palette", "팔레트 \(showPalette ? "열림" : "닫힘")")
    }

    private func shortcut(_ item: SidebarItem) -> KeyboardShortcut {
        KeyboardShortcut(KeyEquivalent(Character("\(item.shortcutNumber ?? 0)")), modifiers: .command)
    }

    // T-12: 폭 110 미만이면 아이콘만 (라벨 숨김, 툴팁으로 이름 표시)
    // T-46: 댓글 대기/초안 수 배지 (좁은 폭에서는 숨김)
    @ViewBuilder
    private func sidebarRow(_ item: SidebarItem) -> some View {
        if sidebarWidth < 110 {
            Image(systemName: item.icon)
                .frame(maxWidth: .infinity)
                .help(item.rawValue)
        } else {
            HStack(spacing: 6) {
                Label(item.rawValue, systemImage: item.icon)
                Spacer()
                if item == .comments, let n = pendingCommentCount, n > 0 {
                    badge("\(n)")
                }
                if item == .posts, draftsCount > 0 {
                    badge("\(draftsCount)")
                }
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.dsSurfaceHover))
            .help("대기 항목 수")
    }

    // T-35: 사이드바 우클릭 컨텍스트 메뉴
    @ViewBuilder
    private func sidebarContextMenu(_ item: SidebarItem) -> some View {
        if item == .posts {
            Button("새 글 작성") { openNewPost() }
            Divider()
        }
        Button("\(item.rawValue) 열기") { selection.wrappedValue = item }
    }

    // T-35: ⌘N 새 글 — 메뉴 바 File과 동일 동작 (NotificationCenter 경유)
    private func openNewPost() {
        let editor = EditorView(postId: nil) {} onClose: {}
            .environmentObject(auth)
        WindowManager.openEditor(key: "new", title: "새 글 작성", rootView: editor)
        DebugLogger.info("Posts", "에디터 창 요청 (new)")
    }

    // T-21: AI 도우미 — 에디터 툴바와 동일하게 별도 창으로 열기 (글 작성 창과 나란히 활용)
    // T-25: 중복 방지 — 이미 열려 있으면 앞으로 가져오기
    private func openAssistantWindow() {
        WindowManager.showAssistant()
    }
}