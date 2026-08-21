// [FEATURE] T-87: WorkspaceView — 글쓰기 워크스페이스 메인 3열 레이아웃 (v2.15)
// ContentView 완전 대체: 사이드바(170pt) + 에디터(가변) + 인스펙터(280pt)
import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var auth: AuthStore
    @AppStorage("workspace.sidebar.selection") private var selectionRaw = WorkspaceSidebarItem.posts.rawValue
    @AppStorage("workspace.inspector.tab") private var inspectorTabRaw = InspectorTab.research.rawValue
    @State private var sidebarWidth: CGFloat = 170
    @State private var inspectorWidth: CGFloat = 280
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showPalette = false
    @State private var showStoryWizard = false
    
    // 파이프라인 상태
    @StateObject private var pipeline = WritingPipeline.shared
    @State private var researchBundle: ResearchBundle?
    @State private var postPlan: PostPlan?
    @State private var draftPackage: DraftPackage?
    
    // 에디터 상태 (기존 EditorView 상태 병합)
    @State private var title = ""
    @State private var slug = ""
    @State private var excerpt = ""
    @State private var thumbnailUrl: String?
    @State private var content = ""
    @State private var status = "DRAFT"
    @State private var categories: [PostCategory] = []
    @State private var selectedCategoryIds: Set<String> = []
    @State private var tagsInput = ""
    @State private var contentType = "ARTICLE"
    @State private var seoMeta: SEOSuggestion?
    @State private var htmlPreview = ""
    
    // 이미지/미디어 상태
    @State private var imagePromptItems: [GeminiService.ImagePromptItem] = []
    @State private var generatingImagePrompts = false
    @State private var imagePromptError: String?
    @State private var showImagePromptGen = false
    
    // 도우미/알트 상태
    @State private var coverAltText = ""
    @State private var bodyImageAltText = ""
    @State private var assistantResult: String?
    
    // 발행 상태
    @State private var validationResults: [CheckItem] = []
    
    // 에디터 분할/포커스
    @State private var splitRatio: CGFloat = 0.5
    @State private var focusMode: EditorCoreView.FocusMode = .split
    
    private var selection: Binding<WorkspaceSidebarItem?> {
        Binding(
            get: { WorkspaceSidebarItem(rawValue: selectionRaw) },
            set: { selectionRaw = $0?.rawValue ?? WorkspaceSidebarItem.posts.rawValue }
        )
    }
    
    private var inspectorTab: Binding<InspectorTab> {
        Binding(
            get: { InspectorTab(rawValue: inspectorTabRaw) ?? .research },
            set: { inspectorTabRaw = $0.rawValue }
        )
    }
    
    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // ===== 사이드바 (170pt) =====
                sidebarView
                    .navigationSplitViewColumnWidth(min: 48, ideal: sidebarWidth, max: 240)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { sidebarWidth = geo.size.width }
                                .onChange(of: geo.size.width) { _, w in sidebarWidth = w }
                        }
                    )
            } detail: {
                // ===== 메인 + 인스펙터 (가변 + 280pt) =====
                HSplitView {
                    // 메인: 에디터
                    editorView
                        .frame(minWidth: 480, idealWidth: 700)
                    
                    // 인스펙터 (우측 패널)
                    inspectorView
                        .frame(minWidth: 240, idealWidth: inspectorWidth, maxWidth: 360)
                }
                .navigationSplitViewColumnWidth(min: 720, idealWidth: 1000)
            }
            .navigationTitle("MacCanDo 워크스페이스")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // 파이프라인 액션바는 에디터 하단에 별도 배치
                    Button { showPalette = true } label: {
                        Label("팔레트", systemImage: "command")
                    }
                    .help("커맨드 팔레트 (⌘K)")
                    .keyboardShortcut("k", modifiers: .command)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .newPostRequested)) { _ in
                newPost()
            }
            .onReceive(NotificationCenter.default.publisher(for: .newStoryWizardRequested)) { _ in
                showStoryWizard = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .pipelineDraftReady)) { notification in
                if let draft = notification.userInfo?["draft"] as? DraftPackage {
                    injectDraft(draft)
                }
            }
        }
        .sheet(isPresented: $showPalette) {
            CommandPaletteView(selection: Binding(
                get: { selection.wrappedValue },
                set: { selection.wrappedValue = $0 }
            )) {
                withAnimation(.easeOut(duration: 0.15)) { showPalette = false }
            }
            .environmentObject(auth)
            .transition(.opacity)
        }
        .sheet(isPresented: $showStoryWizard) {
            SeriesWizardView()
                .environmentObject(auth)
        }
    }
    
    // MARK: - 사이드바
    
    private var sidebarView: some View {
        List(WorkspaceSidebarItem.allCases, selection: selection) { item in
            sidebarRow(item)
                .tag(item)
                .contextMenu { sidebarContextMenu(item) }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            // 하단 버전/로그인 상태
            HStack {
                Text("v2.15-dev")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if auth.isLoggedIn {
                    Label("관리자", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.caption2)
                        .foregroundStyle(Color.dsSuccess)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }
    
    private func sidebarRow(_ item: WorkspaceSidebarItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 22)
                .foregroundStyle(selection.wrappedValue == item ? Color.dsPrimary : .secondary)
            Text(item.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            // 배지 (댓글 대기/초안 수)
            if item == .comments, let count = pendingCommentCount, count > 0 {
                Text("\(count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.dsWarning)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            if item == .posts, draftsCount > 0 {
                Text("\(draftsCount)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.dsPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selection.wrappedValue == item ? Color.dsPrimary.opacity(0.1) : Color.clear)
        )
    }
    
    @ViewBuilder
    private func sidebarContextMenu(_ item: WorkspaceSidebarItem) -> some View {
        switch item {
        case .posts:
            Button("새 글 (⌘N)") { newPost() }
            Button("초안 목록 열기") { /* TODO */ }
        case .series:
            Button("새 시리즈") { /* TODO */ }
        case .comments:
            Button("새로고침") { loadBadges() }
        case .macNews:
            Button("새로 수집") { Task { await collectNews() } }
        case .references:
            Button("참고 자료 열기") { /* TODO */ }
        default:
            EmptyView()
        }
    }
    
    // MARK: - 에디터 영역
    
    private var editorView: some View {
        VStack(spacing: 0) {
            // 에디터 툴바
            EditorToolbar(
                title: $title,
                content: $content,
                slug: $slug,
                excerpt: $excerpt,
                thumbnailUrl: $thumbnailUrl,
                status: $status,
                categories: $categories,
                selectedCategoryIds: $selectedCategoryIds,
                tagsInput: $tagsInput,
                contentType: $contentType,
                seoMeta: $seoMeta,
                showHelp: .constant(false),
                showSEO: .constant(false),
                showImagePicker: .constant(false),
                showYoutubeDialog: .constant(false),
                showVideoDialog: .constant(false),
                showAppSheet: .constant(false),
                showCoverImagePrompt: .constant(false),
                showBodyImageGen: .constant(false),
                showImagePromptGen: $showImagePromptGen,
                insertURL: .constant(""),
                insertCaption: .constant(""),
                imagePromptItems: $imagePromptItems,
                generatingImagePrompts: $generatingImagePrompts,
                imagePromptError: $imagePromptError,
                onBold: { insertInline("**텍스트**") },
                onItalic: { insertInline("*텍스트*") },
                onStrikethrough: { insertInline("~~텍스트~~") },
                onHeading: { insertInline("## 제목") },
                onLink: { insertInline("[텍스트](https://)") },
                onImageInsert: { /* TODO */ },
                onYoutube: { /* TODO */ },
                onVideo: { /* TODO */ },
                onAppCard: { /* TODO */ },
                onHelp: { /* TODO */ },
                onSEO: { /* TODO */ },
                onOpenAssistant: { openAssistantWindow() },
                onSpellingCheck: { /* TODO */ },
                onPublish: { publishPost() },
                onSaveDraft: { saveDraft() },
                onGenerateImagePrompts: { Task { await generateImagePrompts() } }
            )
            
            // 메인 에디터 (분할 뷰)
            EditorCoreView(
                title: $title,
                content: $content,
                htmlPreview: $htmlPreview,
                splitRatio: $splitRatio,
                focusMode: $focusMode
            )
            .onChange(of: content) { _, new in
                updateHTMLPreview(new)
            }
            
            // 액션바 (파이프라인 6단계)
            ActionBar(
                currentStep: $currentPipelineStep,
                stepStatuses: $pipelineStepStatuses,
                canProceed: $canProceedPipeline,
                onStepTap: { step in currentPipelineStep = step },
                onExecuteStep: { step in executePipelineStep(step) },
                onReset: { resetPipeline() }
            )
        }
    }
    
    // MARK: - 인스펙터 (우측 패널)
    
    private var inspectorView: some View {
        VStack(spacing: 0) {
            // 탭 선택
            Picker("", selection: inspectorTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)
            .background(Color.dsSurface)
            
            Divider()
            
            // 탭 콘텐츠
            TabView(selection: inspectorTab) {
                ResearchPanel(
                    researchBundle: $researchBundle,
                    selectedItems: .constant([]),
                    onItemSelected: { _ in },
                    onAppSelected: { _ in },
                    onAddToPlan: { _ in }
                )
                .tag(InspectorTab.research)
                
                AssistantPanel(
                    assistantResult: $assistantResult,
                    coverAltText: $coverAltText,
                    bodyImageAltText: $bodyImageAltText,
                    isLoading: .constant(false),
                    onCopyResult: { /* TODO */ },
                    onApplyToEditor: { applyAssistantToEditor() },
                    onGenerateCoverAlt: { /* TODO */ },
                    onGenerateBodyAlt: { /* TODO */ },
                    onOpenAssistantWindow: { openAssistantWindow() }
                )
                .tag(InspectorTab.assistant)
                
                ImagePromptPanel(
                    imagePromptItems: $imagePromptItems,
                    generatingImagePrompts: $generatingImagePrompts,
                    imagePromptError: $imagePromptError,
                    title: $title,
                    content: $content,
                    onGeneratePrompts: { Task { await generateImagePrompts() } },
                    onCopyPrompt: { prompt in NSPasteboard.general.clearContents(); NSPasteboard.general.setString(prompt, forType: .string) },
                    onGenerateImage: { _ in /* TODO */ }
                )
                .tag(InspectorTab.imagePrompts)
                
                SEOPanel(
                    seoMeta: $seoMeta,
                    title: $title,
                    content: $content,
                    slug: $slug,
                    thumbnailUrl: $thumbnailUrl
                )
                .tag(InspectorTab.seo)
                
                PublishChecklist(
                    post: $postPlan,
                    draft: $draftPackage,
                    seoMeta: $seoMeta,
                    thumbnailUrl: $thumbnailUrl,
                    imagePromptItems: $imagePromptItems,
                    appCards: .constant([]),
                    onFixSEO: { /* TODO */ },
                    onFixSlug: { /* TODO */ },
                    onFixCategory: { /* TODO */ },
                    onFixTags: { /* TODO */ },
                    onFixThumbnail: { /* TODO */ },
                    onFixImageAlts: { /* TODO */ },
                    onFixAppCards: { /* TODO */ },
                    onFixBody: { /* TODO */ }
                )
                .tag(InspectorTab.publish)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: inspectorWidth)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { inspectorWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in inspectorWidth = w }
            }
        )
    }
    
    // MARK: - 상태/액션 (임시 구현 - 추후 분리)
    
    @State private var currentPipelineStep: PipelineStep = .research
    @State private var pipelineStepStatuses: [PipelineStep: StepStatus] = [:]
    @State private var canProceedPipeline = true
    @State private var pendingCommentCount: Int?
    @State private var draftsCount = 0
    
    private func executePipelineStep(_ step: PipelineStep) {
        pipelineStepStatuses[step] = .inProgress
        currentPipelineStep = step
        
        Task {
            switch step {
            case .research:
                await runResearch()
            case .plan:
                await runPlan()
            case .draft:
                await runDraft()
            case .images:
                await runImages()
            case .prepare:
                await runPrepare()
            case .publish:
                await runPublish()
            }
        }
    }
    
    private func runResearch() async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        do {
            let bundle = try await pipeline.collectAndNormalize(topic: title.isEmpty ? content : title)
            researchBundle = bundle
            pipelineStepStatuses[.research] = .completed
            canProceedPipeline = true
        } catch {
            pipelineStepStatuses[.research] = .failed
        }
    }
    
    private func runPlan() async {
        guard let bundle = researchBundle else { return }
        do {
            let plan = try await pipeline.planStructure(bundle: bundle)
            postPlan = plan
            pipelineStepStatuses[.plan] = .completed
        } catch {
            pipelineStepStatuses[.plan] = .failed
        }
    }
    
    private func runDraft() async {
        guard let plan = postPlan else { return }
        do {
            let draft = try await pipeline.generateDraft(plan: plan)
            draftPackage = draft
            // 에디터에 주입
            title = draft.title
            content = draft.bodyMarkdown
            imagePromptItems = draft.imagePrompts
            seoMeta = draft.seoMeta
            pipelineStepStatuses[.draft] = .completed
        } catch {
            pipelineStepStatuses[.draft] = .failed
        }
    }
    
    private func runImages() async {
        await generateImagePrompts()
        pipelineStepStatuses[.images] = .completed
    }
    
    private func runPrepare() async {
        // 발행 전 검증 실행
        pipelineStepStatuses[.prepare] = .completed
    }
    
    private func runPublish() async {
        // 발행 실행
        pipelineStepStatuses[.publish] = .completed
    }
    
    private func generateImagePrompts() async {
        generatingImagePrompts = true
        imagePromptError = nil
        defer { generatingImagePrompts = false }
        
        do {
            let items = try await GeminiService.generateImagePrompts(title: title, body: content)
            imagePromptItems = items
        } catch {
            imagePromptError = (error as? APIError)?.message ?? error.localizedDescription
        }
    }
    
    private func applyAssistantToEditor() {
        guard let result = assistantResult else { return }
        content += "\n\n---\n\n" + result
    }
    
    private func injectDraft(_ draft: DraftPackage) {
        title = draft.title
        content = draft.bodyMarkdown
        imagePromptItems = draft.imagePrompts
        seoMeta = draft.seoMeta
        postPlan = draft.plan
        draftPackage = draft
    }
    
    private func resetPipeline() {
        currentPipelineStep = .research
        pipelineStepStatuses = [:]
        canProceedPipeline = true
        researchBundle = nil
        postPlan = nil
        draftPackage = nil
    }
    
    // MARK: - 헬퍼 (기존 EditorView에서 이동)
    
    private func updateHTMLPreview(_ markdown: String) {
        // TODO: 마크다운 → HTML 변환
        htmlPreview = markdown // 임시
    }
    
    private func insertInline(_ text: String) {
        content += text
    }
    
    private func saveDraft() {
        // TODO
    }
    
    private func publishPost() {
        // TODO
    }
    
    private func newPost() {
        title = ""
        content = ""
        slug = ""
        // 새 글 초기화
    }
    
    private func openAssistantWindow() {
        WindowManager.openEditor(
            key: "assistant",
            title: "AI 도우미",
            rootView: AssistantView().environmentObject(auth)
        )
    }
    
    private func loadBadges() {
        // TODO
    }
    
    private func collectNews() async {
        // TODO
    }
}

// MARK: - 사이드바 아이템

enum WorkspaceSidebarItem: String, CaseIterable, Identifiable {
    case posts = "글 관리"
    case series = "시리즈"
    case comments = "댓글"
    case stats = "통계"
    case ads = "광고"
    case macNews = "맥 소식"
    case references = "참고 자료"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .posts: return "square.and.pencil"
        case .series: return "books.vertical"
        case .comments: return "bubble.left.and.bubble.right"
        case .stats: return "chart.bar"
        case .ads: return "megaphone"
        case .macNews: return "newspaper"
        case .references: return "doc.text.magnifyingglass"
        }
    }
}

// MARK: - 인스펙터 탭

enum InspectorTab: String, CaseIterable, Identifiable {
    case research = "리서치"
    case assistant = "도우미"
    case imagePrompts = "이미지"
    case seo = "SEO"
    case publish = "발행"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .research: return "magnifyingglass"
        case .assistant: return "wand.and.stars"
        case .imagePrompts: return "photo.badge.sparkles"
        case .seo: return "magnifyingglass"
        case .publish: return "checkmark.seal"
        }
    }
}