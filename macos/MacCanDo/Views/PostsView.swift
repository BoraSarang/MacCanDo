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
    @State private var editorWindows: [NSWindow] = []

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
    private func openEditor(postId: String?) {
        if postId == nil {
            DraftStore.clear(postId: nil)  // 새 글: 이전 "__new__" 초안 오염 제거
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 680),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = postId == nil ? "새 글 작성" : "글 편집"
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(
            rootView: EditorView(postId: postId) {
                Task { await load() }
            } onClose: { [weak win] in
                win?.close()
            }
            .environmentObject(auth)
        )
        win.center()
        win.makeKeyAndOrderFront(nil)
        editorWindows.append(win)
        DebugLogger.info("Posts", "에디터 새 창 열림 (\(postId ?? "새 글"))")
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
                } else {
                    List(posts) { post in
                        HStack(spacing: 10) {
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
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundStyle(.orange)
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
                                    Text("👁 \(post.viewCount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                deletingPost = post
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openEditor(postId: post.id)
                        }
                    }
                }
            }
            .navigationTitle("글 관리")
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
        .onAppear { DebugLogger.info("Posts", "글 관리 화면 표시됨") }
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
            DebugLogger.error("Posts", "목록 로드 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    private func delete(_ id: String) async {
        do {
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