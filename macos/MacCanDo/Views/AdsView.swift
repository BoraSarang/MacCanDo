// [FEATURE] 광고 관리 — 홈 광고 슬롯 (T-11)
// 시리즈 배너 지정(★) + 추천 글 지정(★) — 지정 없으면 홈에서 자동 채움 (전체/조회수 top)
// 출처: Setapp 블로그 + 웨일 확장 스토어 구조 (광고 슬롯을 메뉴로 분리)
import SwiftUI

struct AdsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var series: [SeriesItem] = []
    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var busyID: String?
    @State private var hoveredID: String? // T-39: 행 hover

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isLoading {
                Spacer()
                ProgressView("광고 슬롯 로딩 중...")
                Spacer()
            } else {
                content
            }
        }
        .padding(20)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            // T-38: 이모지 → SF Symbol
            Label("광고", systemImage: "megaphone").font(.title2.bold())
            Text("홈 상단 시리즈 배너 + 추천 게시글 슬롯. 지정하지 않으면 전체 시리즈/조회수 top으로 자동 채움.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.bottom, 14)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
                seriesSection
                featuredSection
            }
        }
    }

    // ---- 시리즈 배너 ----
    private var seriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // T-38: 이모지 → SF Symbol
            Label("시리즈 배너 (홈 상단)", systemImage: "books.vertical").font(.headline)
            Text("★ 지정 시 먼저 노출 (순서), 미지정 시 최신순 자동 채움").font(.caption).foregroundStyle(.secondary)
            if series.isEmpty {
                Text("시리즈가 없습니다.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(sortedSeries) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title).font(.callout).lineLimit(1)
                                Text("\(s.posts.count)개의 글").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                Task { await toggleSeriesBanner(s) }
                            } label: {
                                Label(s.featuredOrder != nil ? "★ \(s.featuredOrder!)" : "☆ 지정",
                                      systemImage: s.featuredOrder != nil ? "star.fill" : "star")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                            .tint(s.featuredOrder != nil ? .orange : .secondary)
                            .disabled(busyID == "s-\(s.id)")
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        // T-39: 행 hover
                        .background(hoveredID == "s-\(s.id)" ? Color.dsSurfaceHover : Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .onHover { hovering in
                            if hovering { hoveredID = "s-\(s.id)" } else if hoveredID == "s-\(s.id)" { hoveredID = nil }
                        }
                        // T-40: 행 우클릭 메뉴
                        .contextMenu {
                            Button(s.featuredOrder != nil ? "홈 지정 해제" : "홈 지정") {
                                Task { await toggleSeriesBanner(s) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- 추천 글 ----
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("추천 게시글 (홈 추천 섹션)", systemImage: "star.fill").font(.headline) // T-38
            Text("★ 지정 시 추천 노출 (최대 3개 권장), 미지정 시 조회수 top 자동 채움").font(.caption).foregroundStyle(.secondary)
            if posts.isEmpty {
                Text("게시글이 없습니다.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(sortedPosts) { p in
                        HStack {
                            Text(p.title).font(.callout).lineLimit(1)
                            if !p.isPublished {
                                Text("초안").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                Task { await toggleFeatured(p) }
                            } label: {
                                Label(p.featuredOrder != nil ? "★ \(p.featuredOrder!)" : "☆ 지정",
                                      systemImage: p.featuredOrder != nil ? "star.fill" : "star")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                            .tint(p.featuredOrder != nil ? .orange : .secondary)
                            .disabled(busyID == "p-\(p.id)")
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        // T-39: 행 hover
                        .background(hoveredID == "p-\(p.id)" ? Color.dsSurfaceHover : Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .onHover { hovering in
                            if hovering { hoveredID = "p-\(p.id)" } else if hoveredID == "p-\(p.id)" { hoveredID = nil }
                        }
                        // T-40: 행 우클릭 메뉴
                        .contextMenu {
                            Button(p.featuredOrder != nil ? "추천 해제" : "홈 추천 지정") {
                                Task { await toggleFeatured(p) }
                            }
                        }
                    }
                }
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
        defer { isLoading = false }
        do {
            async let s: AdminSeriesData = APIClient.fetchSeries(token: auth.token)
            async let p: [Post] = APIClient.request("api/admin/posts?all=1", token: auth.token)
            let (sd, pd) = try await (s, p)
            series = sd.series
            posts = pd
            DebugLogger.info("FEATURE", "광고 탭 표시됨 (시리즈 \(sd.series.count), 글 \(pd.count))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? "광고 슬롯을 불러오지 못했습니다."
            DebugLogger.error("FEATURE", "광고 로드 실패: \(errorMessage ?? "")")
        }
    }

    private func toggleSeriesBanner(_ s: SeriesItem) async {
        busyID = "s-\(s.id)"
        defer { busyID = nil }
        do {
            let order = s.featuredOrder == nil ? nextSeriesOrder : nil
            _ = try await APIClient.setSeriesFeatured(token: auth.token, id: s.id, order: order)
            DebugLogger.info("FEATURE", "시리즈 배너 \(order == nil ? "해제" : "지정(\(order!))") — \(s.title)")
            await load()
        } catch {
            errorMessage = "배너 지정에 실패했습니다."
        }
    }

    private func toggleFeatured(_ p: Post) async {
        busyID = "p-\(p.id)"
        defer { busyID = nil }
        do {
            let order = p.featuredOrder == nil ? nextPostOrder : nil
            try await APIClient.setPostFeatured(token: auth.token, id: p.id, order: order)
            DebugLogger.info("FEATURE", "추천 \(order == nil ? "해제" : "지정(\(order!))") — \(p.title)")
            await load()
        } catch {
            errorMessage = "추천 지정에 실패했습니다."
        }
    }
}