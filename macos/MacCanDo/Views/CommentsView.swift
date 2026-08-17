// [FEATURE] 댓글 승인 — 목록 + 승인/스팸 처리 (T-08)
// GET /api/admin/comments?status= / PATCH /api/admin/comments/[id]
import SwiftUI

struct CommentsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var comments: [AdminComment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var statusFilter = "PENDING"
    @State private var workingId: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("댓글 불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.dsWarning) // T-36
                        Text(errorMessage)
                        Button("다시 시도") { Task { await load() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.dsBrandGradient)
                        Text("\(statusFilter == "PENDING" ? "승인 대기" : "등록된") 댓글이 없습니다")
                            .font(.dsTitle)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(comments) { comment in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                if let image = comment.user.image, let url = URL(string: image) {
                                    AsyncImage(url: url) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Circle().fill(Color.gray.opacity(0.2))
                                    }
                                    .frame(width: 22, height: 22)
                                    .clipShape(Circle())
                                }
                                Text(comment.user.name ?? "익명")
                                    .font(.dsBody.weight(.semibold))
                                Text(comment.post.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(relativeTime(comment.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(comment.content)
                                .font(.dsBody)
                                .textSelection(.enabled)
                            HStack(spacing: 8) {
                                if comment.status == "PENDING" {
                                    Button("승인") {
                                        workingId = comment.id
                                        Task { await setStatus(comment.id, "APPROVED") }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    Button("스팸") {
                                        workingId = comment.id
                                        Task { await setStatus(comment.id, "SPAM") }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .foregroundStyle(Color.dsDanger) // T-36
                                } else if comment.status == "APPROVED" {
                                    // T-38: 이모지 → SF Symbol
                                    Label("승인됨", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.dsSuccess)
                                    Button("스팸 처리") {
                                        workingId = comment.id
                                        Task { await setStatus(comment.id, "SPAM") }
                                    }
                                    .buttonStyle(.plain).font(.caption).foregroundStyle(Color.dsDanger)
                                } else {
                                    Label("스팸", systemImage: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.dsDanger)
                                    Button("복구") {
                                        workingId = comment.id
                                        Task { await setStatus(comment.id, "PENDING") }
                                    }
                                    .buttonStyle(.plain).font(.caption)
                                }
                                if workingId == comment.id {
                                    ProgressView().controlSize(.small)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        // T-40: 댓글 우클릭 컨텍스트 메뉴 (기존 인라인 버튼과 동일 동작)
                        .contextMenu {
                            if comment.status != "APPROVED" {
                                Button("승인") {
                                    workingId = comment.id
                                    Task { await setStatus(comment.id, "APPROVED") }
                                }
                            }
                            if comment.status != "SPAM" {
                                Button("스팸 처리") {
                                    workingId = comment.id
                                    Task { await setStatus(comment.id, "SPAM") }
                                }
                            }
                            if comment.status == "SPAM" {
                                Button("복구") {
                                    workingId = comment.id
                                    Task { await setStatus(comment.id, "PENDING") }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("댓글 승인")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker("", selection: $statusFilter) {
                        Text("대기").tag("PENDING")
                        Text("전체").tag("")
                        Text("승인").tag("APPROVED")
                        Text("스팸").tag("SPAM")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    .onChange(of: statusFilter) { _ in
                        Task { await load() }
                    }
                }
            }
        }
        .task { await load() }
        .onAppear { DebugLogger.info("Comments", "댓글 승인 화면 표시됨") }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let path = statusFilter.isEmpty ? "api/admin/comments" : "api/admin/comments?status=\(statusFilter)"
            let result: [AdminComment] = try await APIClient.request(path, token: auth.token)
            comments = result
            DebugLogger.info("Comments", "댓글 \(result.count)개 로드 (\(statusFilter.isEmpty ? "전체" : statusFilter))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.code == "E-MAC-AUTH-1001" || e?.status == 401
                ? "관리자 인증이 필요합니다. 설정에서 API 토큰을 입력하세요."
                : "댓글을 불러오지 못했습니다: \(e?.message ?? error.localizedDescription)"
            DebugLogger.error("Comments", "목록 로드 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    private func setStatus(_ id: String, _ status: String) async {
        struct StatusBody: Encodable { let status: String }
        do {
            let _: AdminComment = try await APIClient.request(
                "api/admin/comments/\(id)", method: "PATCH", token: auth.token,
                body: StatusBody(status: status)
            )
            DebugLogger.info("Comments", "댓글 상태 변경 → \(status) (\(id))")
            // 서버 기준으로 목록 다시 읽기 (승인/스팸 처리된 댓글은 현재 목록에서 사라짐)
            await load()
        } catch {
            let e = error as? APIError
            DebugLogger.error("Comments", "상태 변경 실패: \(e?.code ?? "unknown")")
        }
        workingId = nil
    }

    private func relativeTime(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: iso) else { return iso }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ko_KR")
        return f.localizedString(for: date, relativeTo: Date())
    }
}