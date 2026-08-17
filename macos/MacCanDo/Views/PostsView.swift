// [FEATURE] 글 관리 — 목록 + 새 글/편집/삭제 (T-07)
// GET /api/admin/posts?all=1 (DRAFT 포함) — API 토큰 필요
import SwiftUI
import AppKit

struct PostsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var deletingPost: Post?
    @State private var searchText = "" // T-21: 검색 (제목/슬러그/태그/카테고리/설명)
    @State private var drafts: [DraftRecord] = [] // T-24: 로컬 임시 저장 초안
    @State private var hoveredPostID: String? // T-39: 목록 행 hover

    // 검색 필터 — 제목/슬러그/태그/카테고리/설명 기준 부분 일치
    private var filteredPosts: [Post] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return posts }
        return posts.filter { p in
            p.title.localizedCaseInsensitiveContains(q)
                || p.slug.localizedCaseInsensitiveContains(q)
                || (p.excerpt ?? "").localizedCaseInsensitiveContains(q)
                || (p.tags ?? []).contains { $0.name.localizedCaseInsensitiveContains(q) }
                || (p.categories ?? []).contains { $0.name.localizedCaseInsensitiveContains(q) }
        }
    }

    // 목록에 쓰이는 공통 함수

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

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("게시글 불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                        Button("다시 시도") { Task { await load() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if posts.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.dsBrandGradient)
                        Text("게시글이 없습니다")
                            .font(.dsTitle)
                        Text("첫 글을 작성해 보세요!")
                            .font(.dsBody)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredPosts.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("'\(searchText)' 검색 결과가 없습니다")
                            .font(.dsTitle)
                        Text("제목, 슬러그, 태그, 카테고리, 설명으로 검색됩니다")
                            .font(.dsBody)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // T-24: 로컬 임시 저장 초안 (제목 입력 시 자동저장 — 이어서 작성 가능)
                        if !drafts.isEmpty {
                            Section("임시 저장 (\(drafts.count))") {
                                ForEach(drafts, id: \.postId) { draft in
                                    HStack(spacing: 10) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundStyle(Color.dsWarning) // T-36
                                            .font(.title3)
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
                                    .onTapGesture {
                                        openEditor(postId: nil, draftKey: draft.postId)
                                    }
                                }
                            }
                        }
                        ForEach(filteredPosts) { post in
                        HStack(spacing: 10) {
                            // 본문 대표 이미지 썸네일 (없으면 이미지 없음 표시) — T-21
                            Group {
                                if let url = absoluteImageURL(post.thumbnailUrl) {
                                    AsyncImage(url: url) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.15)
                                    }
                                    .frame(width: 48, height: 27)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 48, height: 27)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        )
                                        .help("대표 이미지 없음")
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(post.title)
                                        .font(.dsBody.weight(.semibold))
                                        .lineLimit(1)
                                    if post.seoMeta != nil {
                                        Image(systemName: "sparkles")
                                            .font(.caption)
                                            .foregroundStyle(Color.dsPrimary)
                                            .help(seoHelp(post.seoMeta))
                                    } else if let excerpt = post.excerpt, !excerpt.isEmpty {
                                        Image(systemName: "doc.text")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .help("설명(요약): \(excerpt)")
                                    }
                                    if post.isPublished {
                                        Text("발행")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.dsPrimary.opacity(0.15))
                                            .foregroundStyle(Color.dsPrimary)
                                            .clipShape(Capsule())
                                    } else {
                                        Text("초안")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.dsWarning.opacity(0.15)) // T-36
                                            .foregroundStyle(Color.dsWarning)
                                            .clipShape(Capsule())
                                    }
                                }
                                HStack(spacing: 8) {
                                    Text("/post/\(post.slug)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    ForEach(post.categories ?? []) { c in
                                        Text(c.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let tags = post.tags, !tags.isEmpty {
                                        Text(tags.map { "#\($0.name)" }.joined(separator: " "))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    // T-38: 조회수 이모지 → SF Symbol
                                    Label("\(post.viewCount)", systemImage: "eye")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            // T-26: 웹 사이트에서 보기 — 설정의 웹 주소 + 슬러그
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
                        }
                        // T-39: 행 hover + T-40: 우클릭 컨텍스트 메뉴
                        .background(hoveredPostID == post.id ? Color.dsSurfaceHover : Color.clear)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering { hoveredPostID = post.id } else if hoveredPostID == post.id { hoveredPostID = nil }
                        }
                        .onTapGesture {
                            openEditor(postId: post.id)
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
                }
            }
        }
            .navigationTitle("글 관리")
            .searchable(text: $searchText, placement: .toolbar, prompt: "제목 / 슬러그 / 태그 검색") // T-21
            .onReceive(NotificationCenter.default.publisher(for: .postSaved)) { _ in
                // T-26: 시드 에디터 등 외부 경로에서 저장 성공 → 목록 즉시 갱신
                Task { await load() }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openEditor(postId: nil)
                    } label: {
                        Label("새 글", systemImage: "square.and.pencil")
                    }
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
        }
        .task { await load() }
        .onAppear {
            drafts = DraftStore.loadDrafts() // T-24: 로컬 초안 목록
            DebugLogger.info("Posts", "글 관리 화면 표시됨 (임시 저장 \(drafts.count)개)")
        }
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

    private func delete(_ id: String) async {        do {
            // DELETE 응답 data는 { id } — Post 디코딩 실패 방지 (삭제 후 목록 갱신 안 되던 버그)
            let _: [String: String] = try await APIClient.request("api/admin/posts/\(id)", method: "DELETE", token: auth.token, body: EmptyBody())
            posts.removeAll { $0.id == id }
            DebugLogger.info("Posts", "삭제 완료 (\(id))")
        } catch {
            let e = error as? APIError
            DebugLogger.error("Posts", "삭제 실패: \(e?.code ?? "unknown")")
        }
    }
}

// DELETE 시 빈 body
struct EmptyBody: Encodable {}