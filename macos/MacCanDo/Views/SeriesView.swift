// [FEATURE] 시리즈 관리 — 사용자 요청 (시리즈 묶기 + 드래그 순서 정렬)
// 좌: 시리즈 목록 (생성/수정/삭제) / 우: 시리즈 글 목록 (드래그 정렬 = 편 번호) + 시리즈 없는 글 추가
import SwiftUI

struct SeriesView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var data: AdminSeriesData?
    @State private var selectedSeriesId: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var newTitle = ""
    @State private var newDescription = ""
    @State private var picked: Set<String> = []
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?

    var selectedSeries: SeriesItem? {
        data?.series.first { $0.id == selectedSeriesId }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && data == nil {
                    ProgressView("시리즈 불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, data == nil {
                    VStack(spacing: 10) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Button("다시 시도") { Task { await load() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let data {
                    HSplitView {
                        seriesList(data)
                            .frame(minWidth: 110, idealWidth: 130, maxHeight: .infinity)
                        detail(data)
                            .frame(minWidth: 420, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("시리즈")
        }
        .task { await load() }
        .onChange(of: searchText) { _, newValue in
            // 300ms 디바운스 — 서버 검색 (최근 글부터)
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await searchLoose(newValue)
            }
        }
        .alert("새 시리즈", isPresented: $showCreate) {
            TextField("시리즈 제목 (예: CleanMyMac 완벽 가이드)", text: $newTitle)
            TextField("설명 (선택)", text: $newDescription)
            Button("만들기") { Task { await create() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("시리즈를 만들고 나서 글을 추가하세요.")
        }
        .alert("시리즈 수정", isPresented: $showEdit) {
            TextField("시리즈 제목", text: $newTitle)
            TextField("설명 (선택)", text: $newDescription)
            Button("저장") { Task { await update() } }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog(
            "시리즈 '\(selectedSeries?.title ?? "")'를 삭제할까요? (글은 유지됩니다)",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { Task { await delete() } }
            Button("취소", role: .cancel) {}
        }
    }

    // ---------- 좌: 시리즈 목록 ----------

    private func seriesList(_ data: AdminSeriesData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            List(data.series, id: \.id, selection: $selectedSeriesId) { s in
                VStack(alignment: .leading, spacing: 2) {
                    Text("📚 \(s.title)")
                        .font(.body)
                    Text("글 \(s.posts.count)개\(s.description.map { " · \($0)" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .tag(s.id)
            }
            .listStyle(.sidebar)
            HStack(spacing: 6) {
                Button {
                    newTitle = ""
                    newDescription = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("새 시리즈")
                .disabled(isLoading)
                Button {
                    guard let s = selectedSeries else { return }
                    newTitle = s.title
                    newDescription = s.description ?? ""
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
                .help("이름/설명 수정")
                .disabled(selectedSeries == nil || isLoading)
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("시리즈 삭제 (글은 유지)")
                .disabled(selectedSeries == nil || isLoading)
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(minWidth: 110)
    }

    // ---------- 우: 시리즈 상세 ----------

    private func detail(_ data: AdminSeriesData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let s = selectedSeries {
                // 헤더 (상단 정렬)
                VStack(alignment: .leading, spacing: 3) {
                    Text("📚 \(s.title)")
                        .font(.title3.bold())
                    if let desc = s.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

                // 시리즈 글 섹션
                HStack(spacing: 6) {
                    Text("시리즈 글")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("(\(s.posts.count)편 · 드래그로 순서 변경)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

                // 시리즈 글 목록 — 최대 5편 높이 (넘으면 스크롤)
                if s.posts.isEmpty {
                    Text("아직 글이 없습니다. 아래에서 시리즈에 추가하세요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 90)
                } else {
                    List {
                        ForEach(Array(s.posts.enumerated()), id: \.element.id) { _, p in
                            HStack(spacing: 8) {
                                Text("\(p.seriesOrder)편")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.dsPrimary)
                                    .frame(width: 34, alignment: .trailing)
                                Text(p.title)
                                    .lineLimit(1)
                                if !p.isPublished {
                                    Text("초안")
                                        .font(.caption2)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.orange.opacity(0.2), in: Capsule())
                                        .foregroundStyle(.orange)
                                }
                                Spacer()
                            }
                        }
                        .onMove { from, to in
                            move(from: from, to: to)
                        }
                    }
                    .listStyle(.inset)
                    .frame(height: min(CGFloat(s.posts.count), 5) * 34 + 8)
                }

                Divider()
                    .padding(.top, 8)

                // 시리즈 없는 글 섹션 (남은 공간 전체)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("시리즈에 없는 글")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("(\(data.loosePosts.count)개 — 체크 후 추가)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("제목 검색", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { searchTask?.cancel(); Task { await searchLoose(searchText) } }
                        if isLoading {
                            ProgressView().controlSize(.small)
                        }
                        if let s = selectedSeries {
                            Button("선택 \(picked.count)개 추가") { Task { await addPicked(s.id) } }
                                .disabled(picked.isEmpty || isLoading)
                        }
                    }
                    .padding(.horizontal, 14)

                    if data.loosePosts.isEmpty {
                        Text(searchText.isEmpty ? "시리즈 없는 글이 없습니다." : "검색 결과가 없습니다.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(data.loosePosts, id: \.id, selection: $picked) { p in
                            HStack(spacing: 6) {
                                Text(p.title)
                                    .lineLimit(1)
                                if !p.isPublished {
                                    Text("초안")
                                        .font(.caption2)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.orange.opacity(0.2), in: Capsule())
                                        .foregroundStyle(.orange)
                                }
                            }
                            .tag(p.id)
                        }
                        .listStyle(.inset)
                    }
                }
            } else {
                Text("시리즈를 선택하세요")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // ---------- 동작 ----------

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let d = try await APIClient.fetchSeries(token: auth.token)
            data = d
            if selectedSeriesId == nil || !d.series.contains(where: { $0.id == selectedSeriesId }) {
                selectedSeriesId = d.series.first?.id
            }
            picked = []
            DebugLogger.info("Series", "시리즈 목록 로드 (\(d.series.count)개)")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? error.localizedDescription
            DebugLogger.error("Series", "로드 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    // 서버 검색 (제목, 최근 글부터) — q 비우면 전체 목록
    private func searchLoose(_ q: String) async {
        isLoading = true
        do {
            let d = try await APIClient.fetchSeries(token: auth.token, q: q)
            data = d
            DebugLogger.info("Series", "검색 (\(q.isEmpty ? "전체" : q)) → \(d.loosePosts.count)개")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? error.localizedDescription
            DebugLogger.error("Series", "검색 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    private func create() async {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isLoading = true
        do {
            let s = try await APIClient.createSeries(token: auth.token, title: title, description: newDescription.isEmpty ? nil : newDescription)
            selectedSeriesId = s.id
            await load()
            DebugLogger.info("Series", "시리즈 생성 (\(title))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? error.localizedDescription
            DebugLogger.error("Series", "생성 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    private func update() async {
        guard let s = selectedSeries else { return }
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isLoading = true
        do {
            _ = try await APIClient.updateSeries(
                token: auth.token,
                id: s.id,
                title: title,
                description: newDescription.isEmpty ? nil : newDescription
            )
            await load()
            DebugLogger.info("Series", "시리즈 수정 (\(s.id))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? error.localizedDescription
            DebugLogger.error("Series", "수정 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    private func delete() async {
        guard let s = selectedSeries else { return }
        isLoading = true
        do {
            try await APIClient.deleteSeries(token: auth.token, id: s.id)
            selectedSeriesId = nil
            await load()
            DebugLogger.info("Series", "시리즈 삭제 (\(s.id))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? error.localizedDescription
            DebugLogger.error("Series", "삭제 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    private func addPicked(_ seriesId: String) async {
        guard !picked.isEmpty else { return }
        isLoading = true
        do {
            try await APIClient.addPostsToSeries(token: auth.token, seriesId: seriesId, postIds: Array(picked))
            await load()
            DebugLogger.info("Series", "글 추가 (\(picked.count)개 → \(seriesId))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? error.localizedDescription
            DebugLogger.error("Series", "글 추가 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    // 드래그 정렬 → 즉시 서버 저장
    private func move(from: IndexSet, to: Int) {
        guard let s = selectedSeries else { return }
        var ids = s.posts.map(\.id)
        ids.move(fromOffsets: from, toOffset: to)
        let ordered = ids
        Task {
            isLoading = true
            do {
                try await APIClient.setSeriesOrder(token: auth.token, seriesId: s.id, postIds: ordered)
                await load()
                DebugLogger.info("Series", "순서 저장 (\(ordered.count)개)")
            } catch {
                let e = error as? APIError
                errorMessage = e?.message ?? error.localizedDescription
                DebugLogger.error("Series", "순서 저장 실패: \(e?.code ?? "unknown")")
            }
            isLoading = false
        }
    }
}