// [FEATURE] 댓글 승인 — 목록 + 승인/스팸 처리 (T-08)
// GET /api/admin/comments?status= / PATCH /api/admin/comments/[id]
// T-51: v2.7.0 — segmented 필터 AppStorage 유지 + 상태 변경 로컬 반영(스크롤 유지) + ⌘R 새로고침 + 공통 컴포넌트/상태 바
import SwiftUI

struct CommentsView: View {
    @EnvironmentObject var auth: AuthStore
    @AppStorage("comments.filter") private var statusFilter = "PENDING" // T-51: 필터 유지
    @State private var comments: [AdminComment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var actionErrorMessage: String?
    @State private var workingId: String?

    private var filterLabel: String {
        switch statusFilter {
        case "PENDING": return "대기"
        case "APPROVED": return "승인"
        case "SPAM": return "스팸"
        default: return "전체"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && comments.isEmpty {
                    ProgressView("댓글 불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, comments.isEmpty {
                    ErrorState(message: errorMessage) { Task { await load() } }
                } else if comments.isEmpty {
                    EmptyState(
                        icon: "bubble.left.and.bubble.right",
                        title: "\(filterLabel) 댓글이 없습니다",
                        subtitle: statusFilter == "PENDING" ? "새 댓글이 오면 여기에 표시됩니다" : nil
                    )
                } else {
                    VStack(spacing: 0) {
                        List(comments) { comment in
                            commentRow(comment)
                        }
                        StatusBar(
                            left: "\(comments.count)개 댓글",
                            right: "\(filterLabel) 필터"
                        )
                    }
                }
            }
            .navigationTitle("댓글 승인")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Picker("", selection: $statusFilter) {
                        Text("대기").tag("PENDING")
                        Text("전체").tag("")
                        Text("승인").tag("APPROVED")
                        Text("스팸").tag("SPAM")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    .onChange(of: statusFilter) { _, _ in
                        Task { await load() }
                    }
                    Button {
                        Task { await load() }
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command) // ⌘R
                    .help("목록 새로고침 (⌘R)")
                }
            }
            .alert("처리 실패", isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { if !$0 { actionErrorMessage = nil } }
            )) {
                Button("확인") { actionErrorMessage = nil }
            } message: {
                Text(actionErrorMessage ?? "")
            }
        }
        .task { await load() }
        .onAppear { DebugLogger.info("Comments", "댓글 승인 화면 표시됨") }
    }

    private func commentRow(_ comment: AdminComment) -> some View {
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
                    .lineLimit(1)
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
                    .keyboardShortcut("a", modifiers: [.command, .option])
                    .help("승인 (⌥⌘A)")
                    Button("스팸") {
                        workingId = comment.id
                        Task { await setStatus(comment.id, "SPAM") }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(Color.dsDanger)
                } else if comment.status == "APPROVED" {
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

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let path = statusFilter.isEmpty ? "api/admin/comments" : "api/admin/comments?status=\(statusFilter)"
            let result: [AdminComment] = try await APIClient.request(path, token: auth.token)
            comments = result
            DebugLogger.info("Comments", "댓글 \(result.count)개 로드 (\(filterLabel))")
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
            let updated: AdminComment = try await APIClient.request(
                "api/admin/comments/\(id)", method: "PATCH", token: auth.token,
                body: StatusBody(status: status)
            )
            DebugLogger.info("Comments", "댓글 상태 변경 → \(status) (\(id))")
            // T-51: 로컬 반영 — 전체 재로드 없이 목록 갱신 (스크롤 위치 유지)
            if let idx = comments.firstIndex(where: { $0.id == id }) {
                comments[idx] = updated
            }
            // 현재 필터에 안 맞는 항목은 목록에서 제거 (대기 필터에서 승인하면 사라짐)
            if !statusFilter.isEmpty && updated.status != statusFilter {
                comments.removeAll { $0.id == id }
            }
        } catch {
            let e = error as? APIError
            actionErrorMessage = "댓글 처리 실패: \(e?.message ?? error.localizedDescription)"
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
