// [FEATURE] 통계 — 요약 카드 + 일별 차트 (T-08, Swift Charts)
// GET /api/admin/stats — 사이트 요약 + 최근 14일 일별 통계
import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var stats: AdminStats?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("통계 불러오는 중…")
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
                } else if let stats {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 요약 카드
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                summaryCard("📝 게시글", stats.postCount, color: .blue)
                                summaryCard("💬 댓글", stats.commentCount, color: .green)
                                summaryCard("⏳ 대기 댓글", stats.pendingCommentCount, color: .orange)
                                summaryCard("👁 총 조회수", stats.totalViews, color: .purple)
                                summaryCard("⬇️ 다운로드 클릭", stats.clickCount, color: .pink)
                                summaryCard("👤 사용자", stats.userCount, color: .teal)
                            }

                            // 일별 차트
                            VStack(alignment: .leading, spacing: 8) {
                                Text("최근 14일 추이").font(.headline)
                                Chart {
                                    ForEach(stats.daily.reversed()) { d in
                                        LineMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("조회수", d.views)
                                        )
                                        .foregroundStyle(.blue)
                                        .lineStyle(StrokeStyle(lineWidth: 2))
                                        .interpolationMethod(.catmullRom)
                                        AreaMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("조회수", d.views)
                                        )
                                        .foregroundStyle(.blue.opacity(0.12))
                                    }
                                }
                                .chartYScale(domain: .automatic(includesZero: true))
                                .frame(height: 180)
                                .padding(.top, 8)

                                HStack(spacing: 16) {
                                    legendDot("조회수", .blue)
                                    legendDot("다운로드 클릭", .pink)
                                    legendDot("댓글", .green)
                                    legendDot("신규 사용자", .teal)
                                }
                                .font(.caption)
                                .padding(.top, 4)

                                Chart {
                                    ForEach(stats.daily.reversed()) { d in
                                        BarMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("클릭", d.clicks)
                                        )
                                        .foregroundStyle(.pink.opacity(0.7))
                                        .position(by: .value("종류", "클릭"))
                                        BarMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("댓글", d.comments)
                                        )
                                        .foregroundStyle(.green.opacity(0.7))
                                        .position(by: .value("종류", "댓글"))
                                        BarMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("신규", d.newUsers)
                                        )
                                        .foregroundStyle(.teal.opacity(0.7))
                                        .position(by: .value("종류", "신규"))
                                    }
                                }
                                .frame(height: 140)
                                .padding(.top, 4)
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color(nsColor: .controlBackgroundColor)))
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("통계")
        }
        .task { await load() }
        .onAppear { DebugLogger.info("Stats", "통계 화면 표시됨") }
    }

    private func summaryCard(_ label: String, _ value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func legendDot(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
        .foregroundStyle(.secondary)
    }

    private func dayLabel(_ iso: String) -> String {
        // "2026-08-16" → "08-16"
        return String(iso.dropFirst(5))
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result: AdminStats = try await APIClient.request("api/admin/stats", token: auth.token)
            stats = result
            DebugLogger.info("Stats", "통계 로드 완료 (게시글 \(result.postCount), 조회수 \(result.totalViews))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.code == "E-MAC-AUTH-1001" || e?.status == 401
                ? "관리자 인증이 필요합니다. 설정에서 API 토큰을 입력하세요."
                : "통계를 불러오지 못했습니다: \(e?.message ?? error.localizedDescription)"
            DebugLogger.error("Stats", "통계 로드 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }
}