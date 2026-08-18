// [FEATURE] 광고 관리 — 홈 광고 슬롯 (T-11)
// 시리즈 배너 지정(★) + 추천 글 지정(★) — 지정 없으면 홈에서 자동 채움 (전체/조회수 top)
// T-52: v2.7.0 — NavigationStack + 타이틀 + 재시도 + 토글 로컬 반영(스크롤 유지) + ⌘R + 상태 바
// (커스텀 카드 제거 → List 섹션 표준, setSeriesFeatured 응답/로컬 featuredOrder 교체로 재로드 없음)
import SwiftUI

struct AdsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var series: [SeriesItem] = []
    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var actionErrorMessage: String?
    @State private var busyID: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("광고 슬롯 불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ErrorState(message: errorMessage) { Task { await load() } }
                } else {
                    List {
                        Section {
                            if series.isEmpty {
                                Text("시리즈가 없습니다")
                                    .font(.dsBody)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(sortedSeries) { s in
                                    seriesRow(s)
                                }
                            }
                        } header: {
                            Label("시리즈 배너 (홈 상단)", systemImage: "books.vertical")
                        } footer: {
                            Text("★ 지정 시 먼저 노출 (순서), 미지정 시 최신순 자동 채움")
                        }
                        Section {
                            if posts.isEmpty {
                                Text("게시글이 없습니다")
                                    .font(.dsBody)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(sortedPosts) { p in
                                    postRow(p)
                                }
                            }
                        } header: {
                            Label("추천 게시글 (홈 추천 섹션)", systemImage: "star.fill")
                        } footer: {
                            Text("★ 지정 시 추천 노출 (최대 3개 권장), 미지정 시 조회수 top 자동 채움")
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("광고")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await load() }
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command) // ⌘R
                    .help("목록 새로고침 (⌘R)")
                    .disabled(isLoading)
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
    }

    private func seriesRow(_ s: SeriesItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title)
                    .font(.dsBody.weight(.medium))
                    .lineLimit(1)
                Text("\(s.posts.count)개의 글")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await toggleSeriesBanner(s) }
            } label: {
                Label(
                    s.featuredOrder != nil ? "홈 지정 \(s.featuredOrder!)" : "지정",
                    systemImage: s.featuredOrder != nil ? "star.fill" : "star"
                )
                .font(.caption.bold())
                .foregroundStyle(s.featuredOrder != nil ? Color.dsWarning : Color.secondary)
            }
            .buttonStyle(.bordered)
            .disabled(busyID == "s-\(s.id)")
            .help(s.featuredOrder != nil ? "홈 배너 지정 해제" : "홈 배너로 지정")
            if busyID == "s-\(s.id)" {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(s.featuredOrder != nil ? "홈 지정 해제" : "홈 지정") {
                Task { await toggleSeriesBanner(s) }
            }
        }
    }

    private func postRow(_ p: Post) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.title)
                    .font(.dsBody.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !p.isPublished {
                        StatusBadge(text: "초안", color: Color.dsWarning)
                    }
                    Label("\(p.viewCount)", systemImage: "eye")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                Task { await toggleFeatured(p) }
            } label: {
                Label(
                    p.featuredOrder != nil ? "추천 \(p.featuredOrder!)" : "지정",
                    systemImage: p.featuredOrder != nil ? "star.fill" : "star"
                )
                .font(.caption.bold())
                .foregroundStyle(p.featuredOrder != nil ? Color.dsWarning : Color.secondary)
            }
            .buttonStyle(.bordered)
            .disabled(busyID == "p-\(p.id)")
            .help(p.featuredOrder != nil ? "추천 해제" : "홈 추천 지정")
            if busyID == "p-\(p.id)" {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(p.featuredOrder != nil ? "추천 해제" : "홈 추천 지정") {
                Task { await toggleFeatured(p) }
            }
        }
    }

    private var sortedSeries: [SeriesItem] {
        series.sorted { ($0.featuredOrder ?? 999) < ($1.featuredOrder ?? 999) }
    }

    private var sortedPosts: [Post] {
        posts.sorted { ($0.featuredOrder ?? 999) < ($1.featuredOrder ?? 999) }
    }

    private var nextSeriesOrder: Int {
        (series.map { $0.featuredOrder ?? 0 }.max() ?? 0) + 1
    }

    private var nextPostOrder: Int {
        (posts.map { $0.featuredOrder ?? 0 }.max() ?? 0) + 1
    }

    // ---- 동작 ----

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let s: AdminSeriesData = APIClient.fetchSeries(token: auth.token)
            async let p: [Post] = APIClient.request("api/admin/posts?all=1", token: auth.token)
            let (sd, pd) = try await (s, p)
            series = sd.series
            posts = pd
            DebugLogger.info("Ads", "광고 화면 표시됨 (시리즈 \(sd.series.count), 글 \(pd.count))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? ErrorMessages.message("E-MAC-ADS-1001")
            DebugLogger.error("Ads", "광고 로드 실패: \(errorMessage ?? "")")
        }
    }

    // T-52: 토글 후 재로드 없이 서버 응답으로 로컬 반영 (스크롤 유지)
    private func toggleSeriesBanner(_ s: SeriesItem) async {
        busyID = "s-\(s.id)"
        defer { busyID = nil }
        do {
            let order = s.featuredOrder == nil ? nextSeriesOrder : nil
            let updated = try await APIClient.setSeriesFeatured(token: auth.token, id: s.id, order: order)
            if let idx = series.firstIndex(where: { $0.id == updated.id }) {
                series[idx] = updated
            }
            DebugLogger.info("Ads", "시리즈 배너 \(order == nil ? "해제" : "지정(\(order!))") — \(s.title)")
        } catch {
            actionErrorMessage = "배너 지정에 실패했습니다."
            DebugLogger.error("Ads", "배너 지정 실패: \(error.localizedDescription)")
        }
    }

    // T-52: 성공 시 로컬 featuredOrder 갱신 (Post.featuredOrder var — 재로드 없음)
    private func toggleFeatured(_ p: Post) async {
        busyID = "p-\(p.id)"
        defer { busyID = nil }
        do {
            let order = p.featuredOrder == nil ? nextPostOrder : nil
            try await APIClient.setPostFeatured(token: auth.token, id: p.id, order: order)
            if let idx = posts.firstIndex(where: { $0.id == p.id }) {
                posts[idx].featuredOrder = order
            }
            DebugLogger.info("Ads", "추천 \(order == nil ? "해제" : "지정(\(order!))") — \(p.title)")
        } catch {
            actionErrorMessage = "추천 지정에 실패했습니다."
            DebugLogger.error("Ads", "추천 지정 실패: \(error.localizedDescription)")
        }
    }
}
