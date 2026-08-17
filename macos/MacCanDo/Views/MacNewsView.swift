// [FEATURE] 맥 소식 리포트 탭 (T-23) — AI 도우미 창 내 "맥 소식" 섹션
// 소스 RSS 수집 → AI 요약 리포트 리스트 (로컬 저장) → "글 작성에 사용"으로 에디터 새 창 시드
import SwiftUI
import AppKit

struct MacNewsView: View {
    @State private var reports: [NewsReport] = []
    @State private var sources: [NewsSource] = []
    @State private var isCollecting = false
    @State private var progress = ""
    @State private var lastError: String?
    @State private var showSourceManager = false
    @State private var newSourceName = ""
    @State private var newSourceURL = ""
    @State private var hoveredItemID: String? // T-39: 소식 항목 hover

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("맥 소식 리포트", systemImage: "newspaper")
                    .font(.headline)
                Spacer()
                Button("소스 관리") { showSourceManager.toggle() }
                    .controlSize(.small)
                Button("새로 수집") { Task { await collect() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isCollecting)
            }
            if isCollecting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(progress).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let lastError {
                Label(lastError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.dsWarning) // T-36
            }
            if showSourceManager { sourceManagerView }
            if reports.isEmpty && !isCollecting {
                VStack(spacing: 10) {
                    Image(systemName: "newspaper").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text("소식 리포트가 없습니다.\n'새로 수집'을 누르면 RSS 소스에서 최신 맥 소식을 모아\nAI가 요약·평가해 저장합니다.")
                        .font(.dsBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(reports) { report in
                            reportSection(report)
                        }
                    }
                    .padding(4)
                }
            }
        }
        .onAppear {
            reports = MacNewsStore.loadReports()
            sources = MacNewsStore.loadSources()
            DebugLogger.info("Feature", "맥 소식 리포트 표시됨 (리포트 \(reports.count)개)")
        }
    }

    // ---------- 소스 관리 ----------
    private var sourceManagerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("소스 관리 (\(sources.count))").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(sources) { source in
                        HStack {
                            Image(systemName: source.isActive ? "dot.radiowaves.left.and.right" : "slash.circle")
                                .foregroundStyle(source.isActive ? Color.dsSuccess : .secondary)
                            Text(source.name).font(.dsBody)
                            Text(source.url).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            Button {
                                MacNewsStore.deleteSource(id: source.id)
                                sources = MacNewsStore.loadSources()
                                DebugLogger.info("News", "소스 삭제: \(source.name)")
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("소스 삭제")
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .frame(height: 170)
            HStack(spacing: 6) {
                TextField("이름 (예: 9to5Mac)", text: $newSourceName)
                    .textFieldStyle(.roundedBorder)
                TextField("RSS 주소 (https://…)", text: $newSourceURL)
                    .textFieldStyle(.roundedBorder)
                Button("추가") { addSource() }
                    .controlSize(.small)
                    .disabled(newSourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || newSourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("RSS 피드를 제공하는 사이트만 추가하세요 (예: 사이트/feed, 사이트/rss).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color(nsColor: .textBackgroundColor)))
    }

    private func addSource() {
        let name = newSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = newSourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        MacNewsStore.addSource(name: name, url: url)
        newSourceName = ""
        newSourceURL = ""
        sources = MacNewsStore.loadSources()
        DebugLogger.info("News", "소스 추가 완료: \(name)")
    }

    // ---------- 수집 ----------
    private func collect() async {
        isCollecting = true
        lastError = nil
        progress = "소스 확인 중…"
        do {
            let (report, failed) = try await NewsCollector.collect { msg in
                Task { @MainActor in progress = msg }
            }
            reports = MacNewsStore.loadReports()
            if report.items.isEmpty {
                lastError = failed.isEmpty ? "새 소식이 없습니다 (이미 수집한 항목만 존재)." : "수집 실패 소스: \(failed.joined(separator: ", ")) — 새 소식 없음."
            } else if !failed.isEmpty {
                lastError = "일부 소스 실패: \(failed.joined(separator: ", "))"
            }
            DebugLogger.info("News", "수집 완료: \(report.items.count)건 (실패 \(failed.count)개 소스)")
        } catch {
            let e = error as? APIError
            lastError = e?.message ?? error.localizedDescription
            DebugLogger.error("News", "수집 실패: \(e?.code ?? "unknown")")
        }
        isCollecting = false
        progress = ""
    }

    // ---------- 리포트 섹션 ----------
    private func reportSection(_ report: NewsReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.bold())
                    .foregroundStyle(Color.dsTextSecondary)
                Text("\(report.items.count)건")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    MacNewsStore.deleteReport(id: report.id)
                    reports = MacNewsStore.loadReports()
                    DebugLogger.info("News", "리포트 삭제 (\(report.id.prefix(8)))")
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("리포트 삭제")
            }
            ForEach(report.items) { item in
                itemRow(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // ---------- 소식 항목 행 ----------
    // 왼쪽: 제목/소스/요약 텍스트, 오른쪽: 버튼 2개(원문, 글 작성에 사용) 세로 배치
    private func itemRow(_ item: NewsItem) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // T-38: 별점 이모지 → SF Symbol
            Image(systemName: item.rating == "추천" ? "star.fill" : "minus")
                .font(.caption)
                .foregroundStyle(item.rating == "추천" ? Color.dsWarning : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.dsBody.bold())
                    .lineLimit(2)
                Text("\(item.source) · \(item.published)")
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
            VStack(spacing: 4) {
                if let url = URL(string: item.url) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text("원문")
                            .frame(maxWidth: .infinity) // 라벨이 칸 폭 100% 채움
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered) // 회색 중립
                    .help("원문 페이지 열기")
                }
                Button {
                    openEditor(with: item)
                } label: {
                    Text("글 작성에 사용")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity) // 라벨이 칸 폭 100% 채움
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent) // 강조색
                .help("새 글 에디터를 열어 제목·본문을 미리 채웁니다")
            }
            .frame(width: 150) // 버튼 칸 고정 — 두 버튼 동일 폭 (가로 100%)
        }
        .padding(.vertical, 4)
        // T-39: 항목 hover (리포트 카드 안에서 구분)
        .background(hoveredItemID == item.id ? Color.dsSurfaceHover : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .contentShape(RoundedRectangle(cornerRadius: Radius.sm))
        .onHover { hovering in
            if hovering { hoveredItemID = item.id } else if hoveredItemID == item.id { hoveredItemID = nil }
        }
        // T-40: 항목 우클릭 메뉴
        .contextMenu {
            if let url = URL(string: item.url) {
                Button("원문 열기") { NSWorkspace.shared.open(url) }
            }
            Button("글 작성에 사용") { openEditor(with: item) }
        }
    }

    // "글 작성에 사용" — 에디터 새 창 (제목 + 요약/링크 시드) — T-25: 소식당 1개 창만
    private func openEditor(with item: NewsItem) {
        let body = """
        > 원문: \(item.url)
        > 소스: \(item.source) (\(item.published))
        > 소재 평가: \(item.rating == "추천" ? "⭐ 추천" : "보통")

        \(item.summary)

        이 글에서 다룰 내용을 작성해 주세요.
        """
        let editor = EditorView(postId: nil, seedTitle: item.title, seedBody: body) {
            // T-26: 저장 성공 → 글 관리 목록 즉시 갱신 알림 (시드 경로에도 onSaved 연결)
            NotificationCenter.default.post(name: .postSaved, object: nil)
        } onClose: {}
            .environmentObject(AuthStore())
        WindowManager.openEditor(
            key: "seed:\(item.url)",
            title: "새 글 — \(item.title)",
            rootView: editor,
            width: 1000,
            height: 640
        )
        DebugLogger.info("News", "글 작성에 사용 — 에디터 창 요청 (제목: \(item.title))")
    }
}
