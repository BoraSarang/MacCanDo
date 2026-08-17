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
    @State private var newImageUrl = ""
    @State private var newIntro = ""
    @State private var generatingImage = false
    @State private var generatedImagePreview: URL?
    @State private var showPromptEditor = false
    @State private var promptText = ""
    @State private var showCoverPicker = false // T-30: 업로드 이미지에서 커버 수동 지정
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
        .sheet(isPresented: $showCreate) {
            seriesForm(isCreate: true)
        }
        .sheet(isPresented: $showEdit) {
            seriesForm(isCreate: false)
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

    private func seriesForm(isCreate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isCreate ? "새 시리즈" : "시리즈 수정")
                .font(.title3.bold())
            TextField("시리즈 제목", text: $newTitle)
                .textFieldStyle(.roundedBorder)
            TextField("설명 (선택)", text: $newDescription)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                TextField("커버 이미지 URL (선택, /uploads/… 또는 https://…)", text: $newImageUrl)
                    .textFieldStyle(.roundedBorder)
                // T-30: 업로드된 이미지 목록에서 커버 수동 지정
                Button("업로드에서 선택") { showCoverPicker = true }
                    .disabled(generatingImage)
            }
            // T-19: AI 이미지 생성 — 제목+설명 기반 16:9 커버 (프롬프트 확인/편집 → 생성 → 업로드 → URL 자동 입력)
            HStack(spacing: 8) {
                Button {
                    promptText = coverPrompt()
                    showPromptEditor = true
                } label: {
                    if generatingImage {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("생성 중…")
                        }
                    } else {
                        Label("AI 커버 생성", systemImage: "sparkles")
                    }
                }
                .disabled(generatingImage)
                if let preview = generatedImagePreview, !newImageUrl.isEmpty {
                    AsyncImage(url: preview) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 160, height: 90)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        Button {
                            newImageUrl = ""
                            generatedImagePreview = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(4),
                        alignment: .topTrailing
                    )
                } else if !generatingImage && !newImageUrl.isEmpty, let u = absoluteImageURL(newImageUrl) {
                    AsyncImage(url: u) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 160, height: 90)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
            }
            Text("AI 커버: 시리즈 제목·설명 기반으로 16:9 이미지를 만들어 자동 업로드합니다. 공급자는 설정에서 변경 가능 (무료 티어 종료 시 폴백).")
                .font(.caption)
                .foregroundStyle(.secondary)
            // 프롬프트 확인/편집 (T-19: 요청 내용을 사용자가 미리 보고 수정)
            if showPromptEditor {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("AI 요청 프롬프트 (수정 가능)").font(.caption.bold()).foregroundStyle(.secondary)
                        Text(GeminiService.imageGenProvider.label).font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Button("초기화") { promptText = coverPrompt() }.buttonStyle(.link).controlSize(.small)
                    }
                    TextEditor(text: $promptText)
                        .font(.body)
                        .frame(minHeight: 70)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                    HStack {
                        Spacer()
                        Button("취소") { showPromptEditor = false }.keyboardShortcut(.cancelAction)
                        // T-21: 시트 닫지 않음 — 생성 결과 미리보기를 본 뒤 재생성/완료 결정
                        Button("이 프롬프트로 생성") {
                            Task { await generateCoverImage(prompt: promptText) }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(generatingImage || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            Text("취지 소개 (선택, 마크다운 — 상세 페이지 상단에 표시)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $newIntro)
                .font(.body)
                .frame(minHeight: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            HStack {
                Spacer()
                Button("취소") {
                    if isCreate { showCreate = false } else { showEdit = false }
                }
                .keyboardShortcut(.cancelAction)
                Button(isCreate ? "만들기" : "저장") {
                    Task {
                        if isCreate { await create() } else { await update() }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
        // T-30: 업로드 이미지에서 커버 수동 지정 (폼 시트 위에 표시)
        .sheet(isPresented: $showCoverPicker) {
            ImagePickerSheet(
                token: auth.token,
                mode: .cover,
                onInsert: { _ in },
                onUploaded: { _ in },
                onSelect: { url in
                    newImageUrl = url
                    showCoverPicker = false
                    DebugLogger.info("Series", "[FEATURE] 시리즈 커버 수동 지정 (\(url))")
                }
            )
        }
    }

    private func seriesList(_ data: AdminSeriesData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            List(data.series, id: \.id, selection: $selectedSeriesId) { s in
                VStack(alignment: .leading, spacing: 2) {
                    // T-38: 이모지 → SF Symbol
                    Label(s.title, systemImage: "books.vertical")
                        .font(.body)
                    Text("글 \(s.posts.count)개\(s.description.map { " · \($0)" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .tag(s.id)
                // T-40: 시리즈 우클릭 컨텍스트 메뉴 (기존 버튼과 동일 동작)
                .contextMenu {
                    Button("편집") {
                        selectedSeriesId = s.id
                        newTitle = s.title
                        newDescription = s.description ?? ""
                        newImageUrl = s.imageUrl ?? ""
                        newIntro = s.intro ?? ""
                        generatedImagePreview = nil
                        showEdit = true
                        DebugLogger.info("Series", "컨텍스트: 편집 요청 (\(s.id))")
                    }
                    Divider()
                    Button("삭제", role: .destructive) {
                        selectedSeriesId = s.id
                        showDeleteConfirm = true
                        DebugLogger.info("Series", "컨텍스트: 삭제 요청 (\(s.id))")
                    }
                }
            }
            .listStyle(.sidebar)
            HStack(spacing: 6) {
                Button {
                    newTitle = ""
                    newDescription = ""
                    newImageUrl = ""
                    newIntro = ""
                    generatedImagePreview = nil
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
                    newImageUrl = s.imageUrl ?? ""
                    newIntro = s.intro ?? ""
                    generatedImagePreview = nil
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
                .help("이름/설명/커버/취지 수정")
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
                    if let url = absoluteImageURL(s.imageUrl) {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                        .frame(height: 130)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 4)
                    }
                    // T-38: 이모지 → SF Symbol
                    Label(s.title, systemImage: "books.vertical")
                        .font(.title3.bold())
                    if let desc = s.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let intro = s.intro, !intro.isEmpty {
                        Text(intro)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .padding(.top, 2)
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
                                        .background(Color.dsWarning.opacity(0.2), in: Capsule()) // T-36
                                        .foregroundStyle(Color.dsWarning)
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
                                        .background(Color.dsWarning.opacity(0.2), in: Capsule()) // T-36
                                        .foregroundStyle(Color.dsWarning)
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

    // T-19: 상대 경로(/uploads/...) → baseURL 기준 절대 URL (AsyncImage 로딩 실패 방지)
    private func absoluteImageURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if let u = URL(string: path), u.scheme != nil { return u }
        return URL(string: path, relativeTo: APIClient.baseURL)?.absoluteURL
    }

    // T-19: 커버 프롬프트 자동 구성 (제목+설명 기반)
    private func coverPrompt() -> String {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        \(title.isEmpty ? "macOS 앱" : title)\(newDescription.isEmpty ? "" : " — \(newDescription)") 시리즈의 커버 이미지를 만들어 주세요.
        macOS 앱 큐레이션 블로그 시리즈 표지, 깔끔하고 미니멀한 스타일, 부드러운 그라데이션, 한국어 또는 영어 텍스트 없이, 16:9 와이드 비율.
        """
    }

    // T-19: AI 커버 이미지 생성 → 임시 파일 → 업로드 → URL 자동 입력
    private func generateCoverImage(prompt: String) async {
        generatingImage = true
        errorMessage = nil
        do {
            DebugLogger.info("Series", "[FEATURE] AI 커버 생성 시작 provider=\(GeminiService.imageGenProvider.rawValue) prompt=\(String(prompt.prefix(60)))…")
            let (imageData, _) = try await GeminiService.generateImage(prompt: prompt)

            // 임시 파일 저장 후 기존 업로드 파이프라인 재사용 (확장자는 실제 포맷 기준)
            let dir = FileManager.default.temporaryDirectory
            let fileURL = dir.appendingPathComponent("series-cover-\(UUID().uuidString.prefix(8)).\(GeminiService.imageExtension(for: imageData))")
            try imageData.write(to: fileURL)

            let url = try await APIClient.uploadImage(token: auth.token, fileURL: fileURL)
            try? FileManager.default.removeItem(at: fileURL)

            newImageUrl = url
            generatedImagePreview = absoluteImageURL(url) // 상대 경로 → 절대 URL (AsyncImage 무한 로딩 방지)
            DebugLogger.info("Series", "[FEATURE] AI 커버 업로드 완료 (\(url))")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? error.localizedDescription
            DebugLogger.error("Series", "AI 커버 생성 실패: \(e?.code ?? "unknown") status=\(e?.status ?? -1) msg=\(e?.message ?? error.localizedDescription)")
        }
        generatingImage = false
    }

    private func create() async {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isLoading = true
        do {
            let s = try await APIClient.createSeries(
                token: auth.token,
                title: title,
                description: newDescription.isEmpty ? nil : newDescription,
                imageUrl: newImageUrl.isEmpty ? nil : newImageUrl,
                intro: newIntro.isEmpty ? nil : newIntro
            )
            selectedSeriesId = s.id
            showCreate = false
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
                description: newDescription.isEmpty ? nil : newDescription,
                imageUrl: newImageUrl.isEmpty ? nil : newImageUrl,
                intro: newIntro.isEmpty ? nil : newIntro
            )
            showEdit = false
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