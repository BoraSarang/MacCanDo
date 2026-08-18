// [FEATURE] 글 관리 — 목록 + 새 글/편집/삭제 (T-07)
// GET /api/admin/posts?all=1 (DRAFT 포함) — API 토큰 필요
// T-49: v2.7.0 — 96px 표준 행 + 툴바 필터(전체/초안/발행) + ⌘R 새로고침 + 상태 바 + 삭제 실패 피드백 + 클릭=선택/더블클릭·Return=열기 + hover 액션 + 공통 컴포넌트(ErrorState/EmptyState/StatusBar)
import SwiftUI
import AppKit

struct PostsView: View {
    @EnvironmentObject var auth: AuthStore
    @AppStorage("posts.filter") private var filterRaw = PostFilter.all.rawValue // T-49: 필터 유지
    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var deleteErrorMessage: String?
    @State private var deletingPost: Post?
    @State private var searchText = "" // T-21: 검색 (제목/슬러그/태그/카테고리/설명)
    @State private var drafts: [DraftRecord] = [] // T-24: 로컬 임시 저장 초안
    @State private var hoveredPostID: String? // T-39: 목록 행 hover
    @State private var selectedPostID: String? // T-49: 클릭=선택, 더블클릭/Return=열기

    enum PostFilter: String, CaseIterable, Identifiable {
        case all = "전체"
        case draft = "초안"
        case published = "발행"
        var id: String { rawValue }
    }

    private var filter: PostFilter { PostFilter(rawValue: filterRaw) ?? .all }

    // 필터 + 검색 — 제목/슬러그/태그/카테고리/설명 기준 부분 일치
    private var filteredPosts: [Post] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = posts
        switch filter {
        case .all: break
        case .draft: result = result.filter { !$0.isPublished }
        case .published: result = result.filter { $0.isPublished }
        }
        guard !q.isEmpty else { return result }
        return result.filter { p in
            p.title.localizedCaseInsensitiveContains(q)
                || p.slug.localizedCaseInsensitiveContains(q)
                || (p.excerpt ?? "").localizedCaseInsensitiveContains(q)
                || (p.tags ?? []).contains { $0.name.localizedCaseInsensitiveContains(q) }
                || (p.categories ?? []).contains { $0.name.localizedCaseInsensitiveContains(q) }
        }
    }

    private func seoHelp(_ meta: SeoMeta?) -> String {
        guard let meta else { return "" }
        var lines: [String] = []
        if let t = meta.title, !t.isEmpty { lines.append("SEO 제목: \(t)") }
        if let d = meta.description, !d.isEmpty { lines.append("설명: \(d)") }
        if let tags = meta.tags, !tags.isEmpty { lines.append("키워드: \(tags.joined(separator: ", "))") }
        if let at = meta.appliedAt { lines.append("적용: \(at.prefix(10))") }
        return lines.isEmpty ? "SEO 적용됨" : lines.joined(separator: "\n")
    }

    // 에디터를 새 창(NSWindow)으로 열기 — sheet(팝업) 대신 드래그/리사이즈 가능
    // T-24: initialDraftKey — 로컬 초안 이어쓰기 / nil이면 새 draft 키 생성
    // T-25: 키(postId/draftKey)당 창 1개만 — 중복 열기 시 앞으로 가져오기
    private func openEditor(postId: String?, draftKey: String? = nil) {
        let key = postId ?? draftKey ?? "new"
        let editor = EditorView(postId: postId, initialDraftKey: draftKey) {
            Task { await load() }
        } onClose: {}
            .environmentObject(auth)
        WindowManager.openEditor(key: key, title: postId == nil ? "새 글 작성" : "글 편집", rootView: editor)
        DebugLogger.info("Posts", "에디터 창 요청 (\(key))")
    }

    private func openSelected() {
        guard let id = selectedPostID else { return }
        openEditor(postId: id)
        DebugLogger.info("Posts", "Return/더블클릭 — 에디터 열기 (\(id))")
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("게시글 불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ErrorState(message: errorMessage) { Task { await load() } }
                } else if posts.isEmpty && drafts.isEmpty {
                    EmptyState(icon: "doc.text", title: "게시글이 없습니다", subtitle: "첫 글을 작성해 보세요!")
                } else if filteredPosts.isEmpty && drafts.isEmpty {
                    EmptyState(icon: "magnifyingglass", title: "검색 결과가 없습니다", subtitle: "제목, 슬러그, 태그, 카테고리, 설명으로 검색됩니다")
                } else {
                    VStack(spacing: 0) {
                        List(selection: $selectedPostID) {
                            // T-24: 로컬 임시 저장 초안 (제목 입력 시 자동저장 — 이어서 작성 가능)
                            if !drafts.isEmpty {
                                Section("임시 저장 (\(drafts.count))") {
                                    ForEach(drafts, id: \.postId) { draft in
                                        HStack(spacing: 10) {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundStyle(Color.dsWarning)
                                                .font(.title3)
                                                .frame(width: 20)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(draft.title)
                                                    .font(.dsBody.weight(.semibold))
                                                    .lineLimit(1)
                                                Text("수정 \(draft.savedAt.formatted(date: .abbreviated, time: .shortened)) · \(draft.body.count)자")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Button {
                                                openEditor(postId: nil, draftKey: draft.postId)
                                            } label: {
                                                Label("이어서 작성", systemImage: "pencil")
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            Button(role: .destructive) {
                                                if let key = draft.postId {
                                                    DraftStore.clear(postId: key)
                                                    drafts = DraftStore.loadDrafts()
                                                    DebugLogger.info("Posts", "임시 저장 삭제 (\(key))")
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                            .help("임시 저장 삭제")
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture(count: 2) {
                                            openEditor(postId: nil, draftKey: draft.postId)
                                        }
                                    }
                                }
                            }
                            ForEach(filteredPosts) { post in
                                postRow(post)
                            }
                        }
                        // T-49: 클릭=선택(유지), 더블클릭/Return=열기 (Finder 패턴)
                        .onTapGesture(count: 2) {
                            openSelected()
                        }
                        .onKeyPress(.return) {
                            openSelected()
                            return .handled
                        }
                        StatusBar(
                            left: "\(posts.count)개 글 · 임시 저장 \(drafts.count)개",
                            right: filter == .all ? "전체" : "\(filter.rawValue)만 표시"
                        )
                    }
                }
            }
            .navigationTitle("글 관리")
            .searchable(text: $searchText, placement: .toolbar, prompt: "제목 / 슬러그 / 태그 검색") // T-21
            .onReceive(NotificationCenter.default.publisher(for: .postSaved)) { _ in
                // T-26: 시드 에디터 등 외부 경로에서 저장 성공 → 목록 즉시 갱신
                // T-49: 임시 저장 목록도 함께 갱신
                drafts = DraftStore.loadDrafts()
                Task { await load() }
            }
            .toolbar {
                // T-49: 툴바 — 필터 메뉴 + 새로고침(⌘R) [좌측], 새 글(⌘N) [우측]
                ToolbarItemGroup(placement: .secondaryAction) {
                    Picker("필터", selection: $filterRaw) {
                        ForEach(PostFilter.allCases) { f in
                            Text(f.rawValue).tag(f.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .help("글 필터 (전체/초안/발행)")
                    Button {
                        Task { await load() }
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command) // ⌘R
                    .help("목록 새로고침 (⌘R)")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openEditor(postId: nil)
                    } label: {
                        Label("새 글", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(!auth.isAuthed)
                }
            }
            .confirmationDialog(
                "글을 삭제할까요?",
                isPresented: Binding(
                    get: { deletingPost != nil },
                    set: { if !$0 { deletingPost = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let p = deletingPost {
                        Task { await delete(p.id) }
                    }
                }
                Button("취소", role: .cancel) { deletingPost = nil }
            } message: {
                Text("'\(deletingPost?.title ?? "")' 글을 삭제합니다. 되돌릴 수 없습니다.")
            }
            // T-49: 삭제 실패 피드백
            .alert("삭제 실패", isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )) {
                Button("확인") { deleteErrorMessage = nil }
            } message: {
                Text(deleteErrorMessage ?? "")
            }
        }
        .task { await load() }
        .onAppear {
            drafts = DraftStore.loadDrafts()
            DebugLogger.info("Posts", "글 관리 화면 표시됨 (임시 저장 \(drafts.count)개)")
        }
    }

    // T-49: 표준 목록 행 — 96px 썸네일 + 제목/배지/서브라인 + hover 액션 (Finder/사진 패턴)
    private func postRow(_ post: Post) -> some View {
        HStack(spacing: 12) {
            Group {
                if let url = absoluteImageURL(post.thumbnailUrl) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.dsSurface
                    }
                    .frame(width: 144, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                } else {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color.dsSurface)
                        .frame(width: 144, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                        )
                        .help("대표 이미지 없음")
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(post.title)
                        .font(.dsBody.weight(.semibold))
                        .lineLimit(1)
                    if post.seoMeta != nil {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(Color.dsPrimary)
                            .help(seoHelp(post.seoMeta))
                    }
                    StatusBadge(
                        text: post.isPublished ? "발행" : "초안",
                        color: post.isPublished ? Color.dsPrimary : Color.dsWarning
                    )
                }
                HStack(spacing: 8) {
                    Text("/post/\(post.slug)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ForEach(post.categories ?? []) { c in
                        Text(c.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    if let tags = post.tags, !tags.isEmpty {
                        Text(tags.map { "#\($0.name)" }.joined(separator: " "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Label("\(post.viewCount)", systemImage: "eye")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(updatedDate(post.updatedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            // T-49: hover 시에만 액션 버튼 표시 (행 선택 상태에서는 항상 표시)
            Group {
                if let url = webURL(for: post.slug) {
                    Button {
                        NSWorkspace.shared.open(url)
                        DebugLogger.info("Posts", "웹에서 글 열기 (\(post.slug))")
                    } label: {
                        Image(systemName: "safari")
                    }
                    .buttonStyle(.borderless)
                    .help("웹 사이트에서 보기 (\(url.absoluteString))")
                }
                Button(role: .destructive) {
                    deletingPost = post
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("글 삭제")
            }
            .opacity(hoveredPostID == post.id || selectedPostID == post.id ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: hoveredPostID)
        }
        .padding(.vertical, 6)
        .tag(post.id)
        .background(hoveredPostID == post.id ? Color.dsSurfaceHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering { hoveredPostID = post.id } else if hoveredPostID == post.id { hoveredPostID = nil }
        }
        .contextMenu {
            Button("에디터에서 열기") {
                openEditor(postId: post.id)
                DebugLogger.info("Posts", "컨텍스트: 에디터 열기 (\(post.id))")
            }
            if let url = webURL(for: post.slug) {
                Button("웹에서 보기") {
                    NSWorkspace.shared.open(url)
                    DebugLogger.info("Posts", "컨텍스트: 웹에서 열기 (\(post.slug))")
                }
            }
            Divider()
            Button("삭제", role: .destructive) {
                deletingPost = post
                DebugLogger.info("Posts", "컨텍스트: 삭제 요청 (\(post.id))")
            }
        }
    }

    private func updatedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return String(iso.prefix(10)) }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    // 상대 경로(/uploads/...) → 절대 URL (SeriesView와 동일 규칙)
    private func absoluteImageURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if let u = URL(string: path), u.scheme != nil { return u }
        return URL(string: path, relativeTo: APIClient.baseURL)?.absoluteURL
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result: [Post] = try await APIClient.request("api/admin/posts?all=1", token: auth.token)
            posts = result
            DebugLogger.info("Posts", "게시글 \(result.count)개 로드")
        } catch {
            let e = error as? APIError
            errorMessage = e?.code == "E-MAC-AUTH-1001" || e?.status == 401
                ? "관리자 인증이 필요합니다. 설정에서 API 토큰을 입력하세요."
                : "게시글을 불러오지 못했습니다: \(e?.message ?? error.localizedDescription)"
            DebugLogger.error("Posts", "목록 로드 실패: \(e?.code ?? "unknown") — \(error.localizedDescription)")
        }
        isLoading = false
    }

    // 설정의 웹 주소(webURL) + 슬러그 → 사이트 글 URL
    private func webURL(for slug: String) -> URL? {
        guard !slug.isEmpty else { return nil }
        return URL(string: "post/\(slug)", relativeTo: APIClient.webURL)
    }

    private func delete(_ id: String) async {
        do {
            // DELETE 응답 data는 { id } — Post 디코딩 실패 방지 (삭제 후 목록 갱신 안 되던 버그)
            let _: [String: String] = try await APIClient.request("api/admin/posts/\(id)", method: "DELETE", token: auth.token, body: EmptyBody())
            posts.removeAll { $0.id == id }
            DebugLogger.info("Posts", "삭제 완료 (\(id))")
        } catch {
            let e = error as? APIError
            deleteErrorMessage = "삭제 실패: \(e?.message ?? error.localizedDescription)"
            DebugLogger.error("Posts", "삭제 실패: \(e?.code ?? "unknown")")
        }
    }
}

// DELETE 시 빈 body
struct EmptyBody: Encodable {}
