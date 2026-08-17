// [FEATURE] ⌘K 커맨드 팔레트 (T-42) — 화면 전환 + 글 검색 + 액션 (Raycast/Linear 패턴)
// macOS 14+ : TextField onKeyPress 화살표 이동 + onSubmit 실행 + Esc 닫기
import SwiftUI

enum PaletteAction: Hashable {
    case newPost
    case assistant
    case debugPanel
}

enum PaletteEntry: Identifiable {
    case screen(SidebarItem)
    case action(PaletteAction)
    case post(Post)

    var id: String {
        switch self {
        case .screen(let s): return "screen:\(s.rawValue)"
        case .action(let a): return "action:\(String(describing: a))"
        case .post(let p): return "post:\(p.id)"
        }
    }
}

struct CommandPaletteView: View {
    @Binding var selection: SidebarItem?
    @EnvironmentObject var auth: AuthStore
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var posts: [Post] = []
    @State private var loaded = false
    @State private var selectedIndex = 0
    @FocusState private var fieldFocused: Bool

    // 팔레트 화면 목록 (AI 도우미는 창 열기 액션으로 별도 처리)
    private let screens: [SidebarItem] = [.posts, .series, .comments, .stats, .ads, .settings]
    private let actions: [PaletteAction] = [.newPost, .assistant, .debugPanel]

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                TextField("명령 또는 글 검색…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 19))
                    .focused($fieldFocused)
                    .onSubmit { run(results.indices.contains(selectedIndex) ? results[selectedIndex] : results.first) }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                Divider()

                if results.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("결과 없음")
                            .font(.dsBody)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { idx, entry in
                                    row(entry)
                                        .contentShape(Rectangle())
                                        .background(idx == selectedIndex ? Color.accentColor : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .onTapGesture { run(entry) }
                                        .id(idx)
                                }
                            }
                            .padding(6)
                        }
                        .onChange(of: selectedIndex) { _, new in
                            proxy.scrollTo(new, anchor: .center)
                        }
                    }
                }
            }
            .frame(width: 640, height: 460)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 28, y: 10)
        }
        .onAppear {
            fieldFocused = true
            Task { await loadPosts() }
            DebugLogger.info("Palette", "⌘K 팔레트 열림")
        }
        .onExitCommand { onDismiss() }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
    }

    // ---------- 검색 ----------
    var results: [PaletteEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            return screens.map { .screen($0) }
                + actions.map { .action($0) }
                + posts.prefix(5).map { .post($0) }
        }
        var out: [PaletteEntry] = []
        out += screens.filter { $0.rawValue.lowercased().contains(q) }.map { .screen($0) }
        out += actions.filter { actionName($0).contains(q) }.map { .action($0) }
        out += posts
            .filter { $0.title.lowercased().contains(q) || $0.slug.lowercased().contains(q) }
            .prefix(8)
            .map { .post($0) }
        return out
    }

    private func actionName(_ a: PaletteAction) -> String {
        switch a {
        case .newPost: return "새 글 작성"
        case .assistant: return "AI 도우미"
        case .debugPanel: return "DebugPanel"
        }
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + results.count) % results.count
    }

    // ---------- 행 렌더링 ----------
    private func isSelected(_ entry: PaletteEntry) -> Bool {
        guard results.indices.contains(selectedIndex) else { return false }
        return results[selectedIndex].id == entry.id
    }

    @ViewBuilder
    private func row(_ entry: PaletteEntry) -> some View {
        let selected = isSelected(entry)
        HStack(spacing: 10) {
            Image(systemName: icon(entry))
                .frame(width: 18)
                .foregroundStyle(selected ? Color.white : Color.accentColor)
            switch entry {
            case .screen(let s):
                Text(s.rawValue)
                    .font(.dsBody)
            case .action(let a):
                Text(actionName(a))
                    .font(.dsBody)
            case .post(let p):
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.title.isEmpty ? "(제목 없음)" : p.title)
                        .font(.dsBody.weight(selected ? .semibold : .regular))
                        .lineLimit(1)
                    Text(p.slug + (p.isPublished ? "" : " · 초안"))
                        .font(.caption)
                        .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if selected {
                Text("⏎")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .foregroundStyle(selected ? Color.white : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func icon(_ entry: PaletteEntry) -> String {
        switch entry {
        case .screen(let s): return s.icon
        case .action(let a):
            switch a {
            case .newPost: return "square.and.pencil"
            case .assistant: return "wand.and.stars"
            case .debugPanel: return "ladybug"
            }
        case .post: return "doc.text"
        }
    }

    // ---------- 실행 ----------
    private func run(_ entry: PaletteEntry?) {
        guard let entry else { return }
        onDismiss()
        switch entry {
        case .screen(let s):
            if s == .assistant {
                WindowManager.showAssistant()
            } else {
                selection = s
            }
            DebugLogger.info("Palette", "화면 전환 → \(s.rawValue)")
        case .action(let a):
            switch a {
            case .newPost: openEditor(key: "new", title: "새 글 작성", postId: nil)
            case .assistant:
                WindowManager.showAssistant()
                DebugLogger.info("Palette", "AI 도우미 열기")
            case .debugPanel:
                DebugPanelVM.shared.show()
                DebugLogger.info("Palette", "DebugPanel 열기")
            }
        case .post(let p):
            openEditor(key: "editor_\(p.id)", title: "글 편집", postId: p.id)
            DebugLogger.info("Palette", "글 편집 열기 (\(p.title))")
        }
    }

    private func openEditor(key: String, title: String, postId: String?) {
        let editor = EditorView(postId: postId) {} onClose: {}
            .environmentObject(auth)
        WindowManager.openEditor(key: key, title: title, rootView: editor)
    }

    // ---------- 글 목록 로드 (검색용) ----------
    private func loadPosts() async {
        guard auth.isAuthed, !loaded else { return }
        do {
            let list: [Post] = try await APIClient.request("api/admin/posts?all=1", token: auth.token)
            posts = list
            loaded = true
            DebugLogger.debug("Palette", "글 목록 로드 (\(list.count)건)")
        } catch {
            DebugLogger.warn("Palette", "글 목록 로드 실패: \(error.localizedDescription)")
        }
    }
}
