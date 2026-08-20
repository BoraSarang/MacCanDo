// [FEATURE] 이야기 시리즈 마법사 — v2.11 (T-67) / v2.13 (T-73 개편)
// 5단계 위저드: 시리즈 정보+주제 → 카테고리 → 글 초안(Gemini) → 이미지 생성/업로드 → 등록 확인
// T-73: 하드코딩 시드 제거 → 주제 기반 AI 편 목록 기획 (GeminiService.StorySeedPlan/generateStorySeriesPlan)
// 진입: 메뉴 바(파일 > 새 이야기 시리즈…) / SeriesView 버튼 / ⌘K 커맨드 팔레트
import SwiftUI

// ---------- 마법사 단계 ----------
enum StoryWizardStep: Int, CaseIterable, Identifiable {
    case series = 1
    case category = 2
    case drafts = 3
    case images = 4
    case confirm = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .series: return "시리즈 정보"
        case .category: return "카테고리"
        case .drafts: return "글 초안"
        case .images: return "이미지"
        case .confirm: return "등록 확인"
        }
    }
}

// ---------- 편 생성 상태 ----------
class StoryDraft: ObservableObject, Identifiable {
    let id = UUID()
    let plan: GeminiService.StorySeedPlan
    @Published var body: String = ""
    @Published var coverURL: String?
    @Published var bodyImageURLs: [String] = []
    @Published var generating = false
    @Published var generatingCover = false
    @Published var generatingImages = false
    @Published var error: String?

    init(plan: GeminiService.StorySeedPlan) {
        self.plan = plan
    }
}

struct SeriesWizardView: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    // 시리즈 정보 — 매번 새로 입력
    @State private var seriesTitle = ""
    @State private var seriesDescription = ""
    @State private var seriesIntro = ""
    @State private var bannerOrder = 1
    @State private var seriesCoverPrompt = ""
    @State private var seriesCoverURL: String?
    @State private var generatingCover = false
    // T-73: 주제 기반 편 목록 AI 기획
    @State private var seriesTopic = ""
    @State private var planningSeries = false
    @State private var planError: String?

    // 카테고리
    @State private var categories: [APIClient.AdminCategory] = []
    @State private var storyCategory: APIClient.AdminCategory?
    @State private var categoryLoading = false
    @State private var categoryError: String?

    // 글
    @State private var drafts: [StoryDraft]

    // 등록
    @State private var step: StoryWizardStep = .series
    @State private var registering = false
    @State private var registerError: String?
    @State private var registerDone = false

    init() {
        _drafts = State(initialValue: [])
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if registerDone {
                doneView
            } else {
                stepContent
                Divider()
                footer
            }
        }
        .frame(minWidth: 700, minHeight: 580)
        .onAppear {
            Task { await loadCategories() }
            DebugLogger.info("Wizard", "[FEATURE] 이야기 시리즈 마법사 표시됨 (5단계)")
        }
    }

    // ---------- 상단: 단계 표시 ----------
    private var header: some View {
        HStack {
            Text("이야기 시리즈 마법사")
                .font(.title3.bold())
            Spacer()
            ForEach(StoryWizardStep.allCases) { s in
                stepDot(s)
            }
            Spacer()
            Button("닫기") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(12)
    }

    private func stepDot(_ s: StoryWizardStep) -> some View {
        let isCurrent = s == step
        let isDone = s.rawValue < step.rawValue
        return VStack(spacing: 2) {
            Text("\(s.rawValue)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(isCurrent || isDone ? Color.dsAccent : Color.dsSurfaceHover))
                .foregroundStyle(isCurrent || isDone ? .white : .secondary)
            Text(s.label)
                .font(.caption2)
                .foregroundStyle(isCurrent ? Color.dsText : .secondary)
        }
        .padding(.horizontal, 6)
    }

    // ---------- 단계별 콘텐츠 ----------
    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .series: seriesStep
        case .category: categoryStep
        case .drafts: draftsStep
        case .images: imagesStep
        case .confirm: confirmStep
        }
    }

    // 1단계: 시리즈 정보 + 주제
    private var seriesStep: some View {
        Form {
            Section("시리즈") {
                TextField("시리즈 제목", text: $seriesTitle)
                TextField("한 줄 설명", text: $seriesDescription)
                TextField("홈 배너 순서 (1이 맨 앞)", value: $bannerOrder, format: .number)
                    .frame(maxWidth: 160)
            }
            // T-73: 주제 → AI 편 목록 기획 (하드코딩 시드 제거)
            Section("이야기 주제 → 편 목록 기획") {
                TextField("주제 (예: '데이비드 vs 골리앗 — 이름 전쟁' 또는 '맥 생산성 앱의 역사')", text: $seriesTopic, axis: .vertical)
                    .lineLimit(2...4)
                HStack {
                    Button {
                        Task { await planSeries() }
                    } label: {
                        if planningSeries {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(drafts.isEmpty ? "편 목록 AI 기획" : "다시 기획", systemImage: "wand.and.stars")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(planningSeries || seriesTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !drafts.isEmpty {
                        Text("기획된 편 \(drafts.count)개").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let planError {
                    Text(planError).font(.caption).foregroundStyle(.red)
                }
                Text("주제를 입력하면 AI가 3~5편의 시리즈 편(제목/팩트/이미지 프롬프트)을 기획합니다. 결과는 다음 단계에서 확인·편집할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("인트로 (시리즈 소개 글)") {
                TextEditor(text: $seriesIntro)
                    .frame(minHeight: 90)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.dsSurfaceHover))
            }
            Section("시리즈 커버") {
                TextField("커버 이미지 프롬프트", text: $seriesCoverPrompt, axis: .vertical)
                    .lineLimit(2...4)
                HStack {
                    Button {
                        Task { await generateSeriesCover() }
                    } label: {
                        if generatingCover {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("시리즈 커버 생성", systemImage: "sparkles")
                        }
                    }
                    .disabled(generatingCover)
                    if let url = seriesCoverURL {
                        AsyncImage(url: URL(string: url)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.dsSurfaceHover
                        }
                        .frame(width: 140, height: 79)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // 2단계: 카테고리
    private var categoryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("글을 담을 '이야기' 카테고리를 준비합니다. 없으면 자동으로 생성합니다.")
                .foregroundStyle(.secondary)
            if categoryLoading {
                HStack { ProgressView(); Text("카테고리 확인 중…").foregroundStyle(.secondary) }
            } else if let cat = storyCategory {
                LabeledContent("카테고리", value: "\(cat.name) (\(cat.slug)) — 사용 가능")
                    .font(.dsBody)
            } else {
                if let err = categoryError {
                    Text(err).foregroundStyle(.red)
                }
                Button {
                    Task { await ensureCategory() }
                } label: {
                    Label("이야기 카테고리 만들기 (stories)", systemImage: "folder.badge.plus")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // 3단계: 글 초안
    private var draftsStep: some View {
        VStack(spacing: 10) {
            if drafts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "wand.and.stars").font(.system(size: 34)).foregroundStyle(.secondary)
                    Text("아직 기획된 편이 없습니다.").font(.headline)
                    Text("1단계로 돌아가 주제를 입력하고 [편 목록 AI 기획]을 눌러 편을 만드세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsSurfaceHover.opacity(0.4)))
            } else {
                HStack {
                    Text("각 편의 글 초안을 생성합니다. 생성 후 바로 편집할 수 있습니다.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("전체 초안 생성") {
                        Task { await generateAllDrafts() }
                    }
                    .disabled(drafts.contains { $0.generating })
                }
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(drafts) { draft in
                            StoryDraftRow(draft: draft) {
                                Task { await generateDraft(draft) }
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .padding(14)
    }

    // 4단계: 이미지
    private var imagesStep: some View {
        VStack(spacing: 10) {
            HStack {
                Text("시리즈 커버와 각 편의 커버/본문 이미지를 생성해 업로드합니다.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 시리즈 커버
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("시리즈 커버").font(.headline)
                            Text("홈 배너에 표시됩니다.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await generateSeriesCover() }
                        } label: {
                            if generatingCover {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("생성", systemImage: "sparkles")
                            }
                        }
                        .disabled(generatingCover)
                        if let url = seriesCoverURL {
                            AsyncImage(url: URL(string: url)) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.dsSurfaceHover
                            }
                            .frame(width: 180, height: 101)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsSurfaceHover.opacity(0.5)))

                    ForEach(drafts) { draft in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(draft.plan.title).font(.headline)
                                Spacer()
                                Button {
                                    Task { await generateAllImages(for: draft) }
                                } label: {
                                    if draft.generatingImages {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Label("커버+본문 생성", systemImage: "photo.on.rectangle.angled")
                                    }
                                }
                                .disabled(draft.generatingImages)
                            }
                            if let url = draft.coverURL {
                                AsyncImage(url: URL(string: url)) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Color.dsSurfaceHover
                                }
                                .frame(width: 180, height: 101)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            HStack {
                                ForEach(draft.bodyImageURLs, id: \.self) { url in
                                    AsyncImage(url: URL(string: url)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.dsSurfaceHover
                                    }
                                    .frame(width: 120, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsSurfaceHover.opacity(0.5)))
                    }
                }
                .padding(8)
            }
        }
        .padding(14)
    }

    // 5단계: 등록 확인
    private var confirmStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("아래 내용으로 일괄 등록합니다. [등록하기]를 누르면 카테고리 → 시리즈 → 글 → 홈 배너 순서로 진행됩니다.")
                    .foregroundStyle(.secondary)
                LabeledContent("시리즈", value: seriesTitle)
                LabeledContent("카테고리", value: storyCategory?.name ?? "이야기 (생성 예정)")
                LabeledContent("홈 배너 순서", value: "\(bannerOrder)")
                if let url = seriesCoverURL {
                    LabeledContent("시리즈 커버", value: "✓ 생성됨")
                }
                Divider()
                ForEach(drafts) { draft in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(draft.plan.title).font(.headline)
                        Text("본문 \(draft.body.count)자" + (draft.coverURL == nil ? " · 커버 없음" : " · 커버 ✓") + (draft.bodyImageURLs.isEmpty ? "" : " · 본문 이미지 \(draft.bodyImageURLs.count)장"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let err = registerError {
                    Text("등록 실패: \(err)").foregroundStyle(.red)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // ---------- 완료 화면 ----------
    private var doneView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.green)
            Text("시리즈 등록 완료!")
                .font(.title2.bold())
            Text("시리즈 '\(seriesTitle)'와 글 \(drafts.count)편이 발행되었고 홈 배너에 지정되었습니다.")
                .foregroundStyle(.secondary)
            Button("닫기") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ---------- 하단: 단계 이동 ----------
    private var footer: some View {
        HStack {
            Button("이전") { move(-1) }
                .disabled(step == .series || registering)
            Spacer()
            if step == .confirm {
                Button {
                    Task { await register() }
                } label: {
                    if registering {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("등록하기", systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(registering)
            } else {
                Button("다음") { move(1) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canProceed)
            }
        }
        .padding(12)
    }

    private func move(_ delta: Int) {
        let next = StoryWizardStep(rawValue: step.rawValue + delta)
        if let next { step = next }
        DebugLogger.info("Wizard", "마법사 단계 → \(step.label)")
    }

    // T-73: 주제 → 시리즈 편 목록 AI 기획 (GeminiService.generateStorySeriesPlan — .wizard 체인)
    private func planSeries() async {
        let topic = seriesTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty else { return }
        planningSeries = true
        planError = nil
        defer { planningSeries = false }
        do {
            let plans = try await GeminiService.generateStorySeriesPlan(topic: topic)
            drafts = plans.map { StoryDraft(plan: $0) }
            DebugLogger.info("Wizard", "[FEATURE] 시리즈 편 기획 완료 count=\(plans.count) topic=\(String(topic.prefix(40)))")
        } catch {
            planError = error is APIError ? (error as! APIError).message : error.localizedDescription
            DebugLogger.error("Wizard", "[ERROR] E-MAC-AI-1003 \(planError ?? "")")
        }
    }

    private var canProceed: Bool {
        switch step {
        case .series: return !seriesTitle.trimmingCharacters(in: .whitespaces).isEmpty && !drafts.isEmpty
        case .category: return storyCategory != nil
        case .drafts: return !drafts.isEmpty
        case .images: return true
        case .confirm: return true
        }
    }

    // ---------- 카테고리 ----------
    private func loadCategories() async {
        guard auth.isAuthed else { return }
        categoryLoading = true
        defer { categoryLoading = false }
        do {
            categories = try await APIClient.fetchAdminCategories(token: auth.token)
            storyCategory = categories.first { $0.slug == "stories" }
        } catch {
            categoryError = error.localizedDescription
        }
    }

    private func ensureCategory() async {
        categoryLoading = true
        categoryError = nil
        defer { categoryLoading = false }
        do {
            let cat = try await APIClient.createCategory(
                token: auth.token,
                name: "이야기",
                slug: "stories",
                description: "이야기/스토리텔링 콘텐츠",
                icon: "book",
                sort: 1
            )
            storyCategory = cat
            DebugLogger.info("Wizard", "[FEATURE] '이야기' 카테고리 생성됨 (stories)")
        } catch {
            categoryError = "카테고리 생성 실패: \(error.localizedDescription)"
        }
    }

    // ---------- 이미지 생성/업로드 ----------
    private func generateSeriesCover() async {
        generatingCover = true
        defer { generatingCover = false }
        do {
            seriesCoverURL = try await generateAndUpload(prompt: seriesCoverPrompt)
        } catch {
            registerError = "시리즈 커버 생성 실패: \(error.localizedDescription)"
        }
    }

    private func generateAllImages(for draft: StoryDraft) async {
        draft.generatingImages = true
        draft.error = nil
        defer { draft.generatingImages = false }
        do {
            if draft.coverURL == nil {
                draft.coverURL = try await generateAndUpload(prompt: draft.plan.coverPrompt)
            }
            for prompt in draft.plan.bodyPrompts where draft.bodyImageURLs.count < draft.plan.bodyPrompts.count {
                let url = try await generateAndUpload(prompt: prompt)
                if !draft.bodyImageURLs.contains(url) {
                    draft.bodyImageURLs.append(url)
                }
            }
        } catch {
            draft.error = "이미지 생성 실패: \(error.localizedDescription)"
        }
    }

    private func generateAndUpload(prompt: String) async throws -> String {
        let (data, provider) = try await GeminiService.generateImage(prompt: prompt, action: .coverImage)
        let ext = GeminiService.imageExtension(for: data)
        let dir = FileManager.default.temporaryDirectory
        let fileURL = dir.appendingPathComponent("wizard-\(UUID().uuidString).\(ext)")
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let url = try await APIClient.uploadImage(token: auth.token, fileURL: fileURL)
        DebugLogger.info("Wizard", "[FEATURE] 이미지 생성/업로드 완료 provider=\(provider) url=\(url)")
        return url
    }

    // ---------- 글 초안 ----------
    private func generateDraft(_ draft: StoryDraft) async {
        draft.generating = true
        draft.error = nil
        defer { draft.generating = false }
        do {
            let text = try await GeminiService.generateStoryDraft(title: draft.plan.title, summary: draft.plan.summary)
            draft.body = text
        } catch {
            draft.error = "초안 생성 실패: \(error.localizedDescription)"
        }
    }

    private func generateAllDrafts() async {
        for draft in drafts {
            if draft.body.isEmpty {
                await generateDraft(draft)
            }
        }
    }

    // ---------- 등록 ----------
    private func register() async {
        guard auth.isAuthed else {
            registerError = "로그인이 필요합니다."
            return
        }
        guard !drafts.isEmpty else {
            registerError = "기획된 편이 없습니다. 1단계에서 주제를 입력하고 편 목록을 기획해 주세요."
            return
        }
        registering = true
        registerError = nil
        defer { registering = false }
        do {
            // 1) 카테고리
            var categoryID = storyCategory?.id
            if categoryID == nil {
                let cat = try await APIClient.createCategory(
                    token: auth.token,
                    name: "이야기",
                    slug: "stories",
                    description: "이야기/스토리텔링 콘텐츠",
                    icon: "book",
                    sort: 1
                )
                categoryID = cat.id
            }

            // 2) 시리즈
            let series = try await APIClient.createSeries(
                token: auth.token,
                title: seriesTitle,
                description: seriesDescription,
                imageUrl: seriesCoverURL,
                intro: seriesIntro
            )

            // 3) 글 등록
            var postIDs: [String] = []
            for draft in drafts {
                var body = draft.body
                for url in draft.bodyImageURLs where !body.contains(url) {
                    body += "\n\n[img:\(url)]"
                }
                let input = PostInput(
                    title: draft.plan.title,
                    slug: draft.plan.slug,
                    categoryIds: [categoryID!],
                    tags: ["이야기"],
                    contentType: "ARTICLE",
                    bodyFormat: "MD",
                    body: body,
                    excerpt: nil,
                    status: "PUBLISHED",
                    seoMeta: nil,
                    seriesId: series.id,
                    apps: nil,
                    thumbnailUrl: draft.coverURL
                )
                let post: Post = try await APIClient.request("api/admin/posts", method: "POST", token: auth.token, body: input)
                postIDs.append(post.id)
            }

            // 4) 시리즈 순서 + 홈 배너
            try await APIClient.setSeriesOrder(token: auth.token, seriesId: series.id, postIds: postIDs)
            try await APIClient.setSeriesFeatured(token: auth.token, id: series.id, order: bannerOrder)

            NotificationCenter.default.post(name: .postSaved, object: nil)
            registerDone = true
            DebugLogger.info("Wizard", "[FEATURE] 이야기 시리즈 등록 완료: \(seriesTitle) (편 \(postIDs.count))")
        } catch {
            registerError = error is APIError ? (error as! APIError).message : error.localizedDescription
            DebugLogger.error("Wizard", "[ERROR] E-MAC-WIZ-1001 \(registerError ?? "")")
        }
    }
}

// 편별 초안 행 (초안 생성 버튼 + 편집 가능한 본문)
private struct StoryDraftRow: View {
    @ObservedObject var draft: StoryDraft
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(draft.plan.title).font(.headline)
                Spacer()
                if let err = draft.error {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                Button(action: onGenerate) {
                    if draft.generating {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(draft.body.isEmpty ? "초안 생성" : "다시 생성", systemImage: "sparkles")
                    }
                }
                .disabled(draft.generating)
            }
            if !draft.body.isEmpty {
                TextEditor(text: $draft.body)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.dsSurfaceHover))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsSurfaceHover.opacity(0.5)))
    }
}