// [FEATURE] 이야기 시리즈 마법사 — v2.11 (T-67)
// 5단계 위저드: 시리즈 정보 → 카테고리 → 글 초안(Gemini) → 이미지 생성/업로드 → 등록 확인
// 진입: 메뉴 바(파일 > 새 이야기 시리즈…) / SeriesView 버튼 / ⌘K 커맨드 팔레트
import SwiftUI

// ---------- 편 시드 데이터 — "그 이름, 뺏겼다" (검증된 팩트 + 출처) ----------
struct StorySeed: Identifiable {
    let id = UUID()
    let title: String
    let slug: String
    let summary: String
    let coverPrompt: String
    let bodyPrompts: [String]
}

extension StorySeed {
    static let all: [StorySeed] = [
        StorySeed(
            title: "Gemini가 둘? MacPaw와 Google의 우연한 동명이인",
            slug: "gemini-macpaw-google",
            summary: """
            - MacPaw Gemini: 맥용 중복 파일 정리 앱. 2016년 5월 'Gemini 2' 출시 (9to5Mac 리뷰). 2017년 2월 App Store 'Gemini 2: The Duplicate Finder' 정식 등록. CleanMyMac X 제작사 MacPaw(우크라이나/미국)의 제품. 우주 테마 디자인, 클린업 '임무'와 업적/랭크 시스템. Setapp 구독 서비스에 포함.
            - Google Gemini: 2023년 12월 Google DeepMind가 발표한 LLM. 2024년 2월 챗봇 'Bard'가 'Gemini'로 리브랜딩.
            - 두 제품 모두 '쌍둥이자리(Gemini)'에서 이름을 땄지만, 분야가 완전히 달라(파일 정리 유틸 vs AI) 상표 분쟁은 없음 — 우연한 동명이인의 대표 사례.
            - 출처:
            1. MacPaw Gemini 2 출시 — https://9to5mac.com/2016/05/10/macpaw-gemini-2/
            2. App Store 페이지 — https://apps.apple.com/app/gemini-2-the-duplicate-finder/id1090488118
            3. MacPaw 공식 소개 — https://macpaw.com/ko
            4. Google Gemini 발표 — https://blog.google/products/gemini/
            """,
            coverPrompt: "쌍둥이자리 별자리 두 개가 마주보며 대칭을 이루는 일러스트, 왼쪽은 파일 정리/청소 툴(디스크 청소기, 중복 파일)을, 오른쪽은 AI 뉴럴 네트워크(파란 보석, 신경망)을 상징, 다크 블루 그라데이션 배경, 미니멀하고 미래적인 스타일, 16:9",
            bodyPrompts: [
                "우주 공간에서 중복 파일을 청소하는 로봇, MacPaw Gemini 앱의 우주 테마 스타일, 다크 블루, 미니멀 일러스트",
                "파란 보석 형태의 AI 뉴럴 네트워크가 반짝이는 미래지향적 일러스트, Google Gemini 스타일"
            ]
        ),
        StorySeed(
            title: "애플이 'Apple'을 지키려 30년 싸운 이유",
            slug: "apple-vs-beatles-30years",
            summary: """
            - 1968년 비틀즈가 'Apple Corps' 설립 (음반 레이블, 그린 Granny Smith 사과 로고).
            - 1978년 조지 해리슨이 애플 컴퓨터(현 Apple Inc)의 광고를 보고 이름/로고 침해 최초 소송.
            - 1981년 합의: 애플 컴퓨터가 8만 달러 지불 + 음악 사업 진출 금지 조항.
            - 1989년 애플 컴퓨터의 MIDI 소프트웨어로 재소 → 1991년 합의: 2,650만 달러 지불, '컴퓨터/소프트웨어 = 애플, 음악 = 비틀즈' 영역 분할.
            - 2003년 iTunes Store 출시 → Apple Corps 재소 ('음악 사업 진출 위반').
            - 2006년 영국 법원 판결: iTunes는 음악을 '전달(distribution)'하는 것이지 '창작'하는 것이 아니므로 Apple Inc 승소.
            - 2007년 2월 5일 최종 합의: Apple Inc가 모든 'Apple' 상표를 소유, Apple Corps에 재라이선스. 합의금은 5천만~1억 달러로 추정 (법원 문서 공개분 기준). 스티브 잡스: "We love the Beatles."
            - 비틀즈 전 음원은 2010년 iTunes에 입점 (조지 해리슨 생전에는 불가).
            - 출처:
            1. Apple Newsroom 2007-02-05 — https://www.apple.com/newsroom/2007/02/05Apple-and-The-Beatles-Agree-to-Terminate-Litigation/
            2. NYT 2007-02-06 — https://www.nytimes.com/2007/02/06/technology/06apple.html
            3. BBC 2007-02-05 — http://news.bbc.co.uk/2/hi/business/6332319.stm
            4. NBC News — https://www.nbcnews.com/id/wbna16988500
            """,
            coverPrompt: "그린 사과(비틀즈 스타일)와 한 입 베어문 실버 사과(애플 스타일)가 법정 저울 위에서 마주 보는 일러스트, 레트로 레코드판과 현대 테크 기기가 배경, 클래식+모던 대비, 16:9",
            bodyPrompts: [
                "1968년 빈티지 레코드 스튜디오의 비닐 레코드와 오디오 장비, 따뜻한 갈색 톤 클래식 일러스트",
                "아이팟과 아이튠즈 뮤직 스토어 시대의 음악 재생 화면, 2000년대 초반 레트로 테크 스타일"
            ]
        ),
        StorySeed(
            title: "데이비드 vs 골리앗 — 'Threads' 이름 전쟁",
            slug: "threads-name-war-david-goliath",
            summary: """
            - Threads Software Ltd(영국, 이하 TSL): 지능형 메시지 허브 기업. 모기업 JPY Ltd가 2012년 'Threads' 상표 등록, 2014년부터 전 세계에서 브랜드 홍보, 2018년 스핀오프, 1,000개 이상 조직이 라이선스 사용, 연 200% 성장.
            - 2023년 4월경부터 메타가 'threads.app' 도메인 매수를 4차례 제안(6,000파운드 → 145,000파운드) — 모두 거절.
            - 2023년 7월 5일 메타가 Threads 출시 (100개국 동시, 5일 만에 1억 사용자 돌파).
            - 2023년 7월 7일 TSL의 페이스북 페이지가 삭제됨.
            - 2023년 10월 30일 TSL이 메타에 30일 내 사용 중지 경고 → 법원 injunction 예고 (언론은 '데이비드 vs 골리앗'으로 표현).
            - 메타는 TSL의 상표가 5년 이상 미사용됐다며 무효화를 시도 (미사용 무효 청구).
            - 추가: 미국 패션 브랜드 American Threads가 인스타그램 @Threads 핸들을 보유했고, 메타가 @threadsapp 사용 후 추후 @threads 핸들 확보.
            - 출처:
            1. The Register 2023-10-31 — https://www.theregister.com/2023/10/31/threads_software_meta_legal/
            2. BusinessWire 2023-10-30 — https://www.businesswire.com/news/home/20231030177404/en/
            3. Gizmodo 2023-10-30 — https://gizmodo.com/threads-software-meta-legal-threat-1850967810
            4. Trademark Lawyer Magazine 2024-02-29 — https://www.trademarklawyermagazine.com/threads-trademark-dispute/
            """,
            coverPrompt: "거대한 푸른 SNS 아이콘(골리앗)과 작은 영국식 사무실 건물(데이비드)이 슬링샷으로 대치하는 은유적 일러스트, 현대 플랫 스타일, 선명한 대비, 16:9",
            bodyPrompts: [
                "런던 사무실에서 상표 등록 문서를 든 작은 스타트업 팀, 영국식 빅토리아풍 건물 창문, 따뜻한 조명 일러스트",
                "스마트폰 화면 위로 쏟아지는 수많은 메시지 알림과 허브 아이콘, 현대 미니멀 일러스트"
            ]
        ),
    ]
}

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
    let seed: StorySeed
    @Published var body: String = ""
    @Published var coverURL: String?
    @Published var bodyImageURLs: [String] = []
    @Published var generating = false
    @Published var generatingCover = false
    @Published var generatingImages = false
    @Published var error: String?

    init(seed: StorySeed) {
        self.seed = seed
    }
}

struct SeriesWizardView: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    // 시리즈 정보
    @State private var seriesTitle = "그 이름, 뺏겼다"
    @State private var seriesDescription = "똑같은 이름을 두고 벌어진 상표권 전쟁 이야기"
    @State private var seriesIntro = "MacPaw의 Gemini와 Google의 Gemini, 애플과 비틀즈, 메타와 영국의 작은 회사까지 — '같은 이름'을 두고 벌어진 재미난 대결을 따라가 봅니다."
    @State private var bannerOrder = 1
    @State private var seriesCoverPrompt = "쌍둥이자리 별자리와 상표 각인 도장, 법정 망치가 어우러진 일러스트, 진보라-남색 그라데이션, 미니멀, 16:9"
    @State private var seriesCoverURL: String?
    @State private var generatingCover = false

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
        _drafts = State(initialValue: StorySeed.all.map { StoryDraft(seed: $0) })
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

    // 1단계: 시리즈 정보
    private var seriesStep: some View {
        Form {
            Section("시리즈") {
                TextField("시리즈 제목", text: $seriesTitle)
                TextField("한 줄 설명", text: $seriesDescription)
                TextField("홈 배너 순서 (1이 맨 앞)", value: $bannerOrder, format: .number)
                    .frame(maxWidth: 160)
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
                                Text(draft.seed.title).font(.headline)
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
                        Text(draft.seed.title).font(.headline)
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

    private var canProceed: Bool {
        switch step {
        case .series: return !seriesTitle.trimmingCharacters(in: .whitespaces).isEmpty
        case .category: return storyCategory != nil
        case .drafts: return true
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
                draft.coverURL = try await generateAndUpload(prompt: draft.seed.coverPrompt)
            }
            for prompt in draft.seed.bodyPrompts where draft.bodyImageURLs.count < draft.seed.bodyPrompts.count {
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
        let (data, provider) = try await GeminiService.generateImage(prompt: prompt)
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
            let text = try await GeminiService.generateStoryDraft(title: draft.seed.title, summary: draft.seed.summary)
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
                    title: draft.seed.title,
                    slug: draft.seed.slug,
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
                Text(draft.seed.title).font(.headline)
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