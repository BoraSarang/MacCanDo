// [FEATURE] 통계 — 요약 카드 + 일별 차트 (T-08, Swift Charts)
// GET /api/admin/stats — 사이트 요약 + 최근 일별 통계
// T-53: v2.7.0 — 기간 선택(7/14/30) + ⌘R 새로고침 + 차트 기간 연동 + 카드 표준화(dsSurface) + 시리즈 색 ds 토큰 통일
import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var auth: AuthStore
    @AppStorage("stats.days") private var daysRaw = 14
    @State private var stats: AdminStats?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hoveredCardID: String? // T-39: 카드 hover

    // T-53: 기간 선택(7/14/30) — 서버가 준 데이터 범위 내에서 슬라이스, 날짜 오름차순으로 x축 정렬
    private var chartDaily: [DailyStat] {
        let sorted = stats?.daily.sorted { $0.date < $1.date } ?? []
        return Array(sorted.suffix(daysRaw))
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("통계 불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ErrorState(message: errorMessage) { Task { await load() } }
                } else if let stats {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 요약 카드 (T-53: dsSurface 시스템 표면 — 커스텀 카드 금지 원칙에 맞춤)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                summaryCard(id: "posts", icon: "square.and.pencil", label: "게시글", value: stats.postCount, color: Color.dsPrimary)
                                summaryCard(id: "comments", icon: "bubble.left.and.bubble.right", label: "댓글", value: stats.commentCount, color: Color.dsAccent)
                                summaryCard(id: "pending", icon: "hourglass", label: "대기 댓글", value: stats.pendingCommentCount, color: Color.dsWarning)
                                summaryCard(id: "views", icon: "eye", label: "총 조회수", value: stats.totalViews, color: Color.dsPrimary)
                                summaryCard(id: "clicks", icon: "arrow.down.circle", label: "다운로드 클릭", value: stats.clickCount, color: Color.dsSuccess)
                                summaryCard(id: "users", icon: "person", label: "사용자", value: stats.userCount, color: Color.dsAccent)
                            }

                            // 일별 차트 (T-53: 기간 연동)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("최근 \(chartDaily.count)일 추이").font(.headline)
                                Chart {
                                    ForEach(chartDaily) { d in
                                        LineMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("조회수", d.views)
                                        )
                                        .foregroundStyle(Color.dsPrimary)
                                        .lineStyle(StrokeStyle(lineWidth: 2))
                                        .interpolationMethod(.catmullRom)
                                        AreaMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("조회수", d.views)
                                        )
                                        .foregroundStyle(Color.dsPrimary.opacity(0.12))
                                    }
                                }
                                .chartYScale(domain: .automatic(includesZero: true))
                                .frame(height: 180)
                                .padding(.top, 8)

                                HStack(spacing: 16) {
                                    legendDot("조회수", .dsPrimary)
                                    legendDot("다운로드 클릭", .dsAccent)
                                    legendDot("댓글", .dsSuccess)
                                    legendDot("신규 사용자", .dsWarning)
                                }
                                .font(.caption)
                                .padding(.top, 4)

                                Chart {
                                    ForEach(chartDaily) { d in
                                        BarMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("클릭", d.clicks)
                                        )
                                        .foregroundStyle(Color.dsAccent.opacity(0.7))
                                        .position(by: .value("종류", "클릭"))
                                        BarMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("댓글", d.comments)
                                        )
                                        .foregroundStyle(Color.dsSuccess.opacity(0.7))
                                        .position(by: .value("종류", "댓글"))
                                        BarMark(
                                            x: .value("날짜", dayLabel(d.date)),
                                            y: .value("신규", d.newUsers)
                                        )
                                        .foregroundStyle(Color.dsWarning.opacity(0.7))
                                        .position(by: .value("종류", "신규"))
                                    }
                                }
                                .frame(height: 140)
                                .padding(.top, 4)
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.dsSurface))
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("통계")
            .toolbar {
                // T-53: 기간 선택 + 새로고침 (⌘R)
                ToolbarItemGroup(placement: .primaryAction) {
                    Picker("기간", selection: $daysRaw) {
                        Text("7일").tag(7)
                        Text("14일").tag(14)
                        Text("30일").tag(30)
                    }
                    .pickerStyle(.menu)
                    .help("차트 기간")
                    Button {
                        Task { await load() }
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command) // ⌘R
                    .help("통계 새로고침 (⌘R)")
                    .disabled(isLoading)
                }
            }
        }
        .task { await load() }
        .onAppear { DebugLogger.info("Stats", "통계 화면 표시됨 (기간 \(daysRaw)일)") }
    }

    private func summaryCard(id: String, icon: String, label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(hoveredCardID == id ? Color.dsSurfaceHover : Color.dsSurface)
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.md))
        .onHover { hovering in
            if hovering { hoveredCardID = id } else if hoveredCardID == id { hoveredCardID = nil }
        }
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
            DebugLogger.info("Stats", "통계 로드 완료 (게시글 \(result.postCount), 조회수 \(result.totalViews), 일별 \(result.daily.count)일)")
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
