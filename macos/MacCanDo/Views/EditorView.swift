// [FEATURE] 게시글 에디터 — MD 전용 2칸 (좌: 마크다운 / 우: 실시간 HTML 미리보기) (T-10)
// 로컬 초안(SQLite) 3초 디바운스 자동저장, 삽입 툴바(커서 위치), MD 사용법 시트
import SwiftUI
import WebKit
import UniformTypeIdentifiers

// ---------- NSTextView 래퍼 (코드 에디터) — NSScrollView 필수 (휠 스크롤) ----------
struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    // 커서 위치 삽입용 — 마지막 활성 에디터 참조
    static weak var activeTextView: NSTextView?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true

        let tv = NSTextView()
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textContainerInset = NSSize(width: 12, height: 12)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        // T-27: macOS 내장 철자/문법 검사 (오프라인 물결 밑줄) — 한국어 사전 기반
        tv.isContinuousSpellCheckingEnabled = true
        tv.isGrammarCheckingEnabled = true
        tv.delegate = context.coordinator
        scrollView.documentView = tv
        EditorTextView.activeTextView = tv
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        if tv.string != text {
            tv.string = text
        }
        EditorTextView.activeTextView = tv
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView
        init(_ parent: EditorTextView) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            if let tv = notification.object as? NSTextView {
                parent.text = tv.string
            }
        }
    }
}

// ---------- WKWebView 미리보기 래퍼 ----------
// T-48: 다크모드 대응 + 입력 중 스크롤 위치 유지 (리로드 후 복원)
struct PreviewWebView: NSViewRepresentable {
    let html: String
    var scrollRestoreY: CGFloat = 0
    var onScrollChange: ((CGFloat) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isInspectable = true
        webView.navigationDelegate = context.coordinator
        // 유튜브 iframe 임베드가 WKWebView 기본 UA에서 거부되는 문제 → Safari UA로 설정
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        context.coordinator.lastLoadedHTML = html
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 현재 스크롤 위치 캡처 (입력 중 스크롤 유지용)
        nsView.evaluateJavaScript("window.scrollY") { result, _ in
            var y: CGFloat = 0
            if let cg = result as? CGFloat {
                y = cg
            } else if let num = result as? NSNumber {
                y = CGFloat(truncating: num)
            }
            onScrollChange?(y)
        }
        // HTML이 바뀌었을 때만 리로드 (스크롤 리셋 최소화)
        if context.coordinator.lastLoadedHTML != html {
            context.coordinator.lastLoadedHTML = html
            context.coordinator.pendingScrollY = scrollRestoreY
            nsView.loadHTMLString(html, baseURL: APIClient.baseURL)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: PreviewWebView
        var lastLoadedHTML: String?
        var pendingScrollY: CGFloat = 0
        init(_ parent: PreviewWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if pendingScrollY > 0 {
                webView.evaluateJavaScript("window.scrollTo(0, \(pendingScrollY))")
            }
        }
    }
}

// ---------- 에디터 메인 ----------
struct EditorView: View {
    let postId: String?
    // T-26: 새 글(POST) 성공 후 서버에서 받은 id — 같은 창에서 재저장 시 PUT으로 전환 (중복 생성 방지)
    @State private var savedPostId: String?
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)?
    var onClose: (() -> Void)?

    // T-24: 새 글 초안 키 (draft_<uuid>) — 로컬 초안 목록에서 이어쓰기용
    @State private var draftKey: String
    private let isSeeded: Bool // AI 도우미 등 시드된 새 글 = 초안 로드 안 함

    // T-23: 맥 소식 리포트 "글 작성에 사용" — 제목/본문 시드로 새 글 열기
    // T-24: initialDraftKey — 로컬 초안 목록에서 특정 초안을 이어서 열기
    init(postId: String?, seedTitle: String = "", seedBody: String = "", initialDraftKey: String? = nil, onSaved: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.postId = postId
        self.onSaved = onSaved
        self.onClose = onClose
        self.isSeeded = !seedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !seedBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        _title = State(initialValue: seedTitle)
        _content = State(initialValue: seedBody)
        // T-26: 새 글 초안은 단일 슬롯(draft_new) — 같은 글이 여러 개 쌓이지 않음
        _draftKey = State(initialValue: postId == nil ? (initialDraftKey ?? DraftStore.newPostKey) : "")
    }

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
    @State private var seriesList: [SeriesItem] = []
    @State private var selectedSeriesId: String?
    @State private var showNewSeriesDialog = false
    @State private var newSeriesTitle = ""
    @State private var showPreview = true
    @State private var showHelp = false
    @State private var showSEO = false
    @State private var seoSuggestion: SEOSuggestion?
    @State private var seoMeta: SeoMeta?
    @State private var seoImageInput = ""
    @State private var seoLoading = false
    @State private var seoError: String?
    @State private var generatingThumb = false // T-19: AI 썸네일 생성
    @State private var showThumbPrompt = false
    @State private var thumbPromptText = ""
    @State private var saveState = "초안 대기"
    @State private var previewHTML = ""
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var debounceTask: Task<Void, Never>?
    @State private var previewTask: Task<Void, Never>?
    // 삽입 다이얼로그
    @State private var showImagePicker = false
    @State private var showCoverPicker = false // T-30: 업로드 이미지에서 커버 수동 지정
    @State private var showAppSheet = false // T-15: 앱 카드 시트
    @State private var appCards: [AppCardData] = []
    @State private var appURL = ""
    @State private var appFetching = false
    @State private var appFetchError: String?
    @State private var appMeta: AppStoreInfo?
    @State private var appHomepage = ""
    @State private var appDlLabel = ""
    @State private var appDlURL = ""
    @State private var appMarkerIncludeUrl = true // T-20: [app:URL] 마커 포함 (기본) vs 위치만 [app]
    @State private var showYoutubeDialog = false
    @State private var showVideoDialog = false
    // T-21: AI 본문 이미지 생성 (툴바 직접 진입)
    @State private var showCoverImagePrompt = false
    @State private var imageGenPromptText = ""
    @State private var generatingCoverImage = false
    @State private var generatedCoverImageData: Data?
    @State private var lookedUpAppUrls: Set<String> = [] // [app:URL] App Store 조회 시도 완료 URL (반복 방지)
    @State private var coverImageError: String?
    @State private var insertURL = ""
    @State private var insertCaption = ""
    // T-27: 한글 맞춤법 검사 (Gemini) — 하단 패널 + 개별 적용
    @State private var spellingIssues: [SpellingIssue] = []
    @State private var isCheckingSpelling = false
    @State private var spellCheckError: String?
    // T-48: v2.7.0 — 우측 Inspector 토글(⌘⌥I) + 미리보기 스크롤 복원 + 제목 자동 포커스
    @State private var showInspector = true
    @State private var previewScrollY: CGFloat = 0
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            editorBody
            // T-27: 맞춤법 검사 결과 패널 (검사 중/결과/에러가 있을 때만 표시)
            if isCheckingSpelling || !spellingIssues.isEmpty || spellCheckError != nil {
                Divider()
                spellingPanel
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .task {
            await load()
            // T-23: "글 작성에 사용" 시드된 새 글 — onChange는 초기값에 안 걸려
            // 미리보기/자동저장이 즉시 동작하지 않음 → 수동 트리거
            if postId == nil && !content.isEmpty {
                scheduleAutoSave()
                schedulePreview()
                DebugLogger.info("Editor", "새 글 초기 미리보기 생성 (\(content.count)자)")
            }
        }
        .onChange(of: title) { scheduleAutoSave() }
        .onChange(of: content) {
            scheduleAutoSave()
            schedulePreview()
        }
        .onChange(of: status) { scheduleAutoSave() }
        .onAppear { DebugLogger.info("Editor", "에디터 표시됨 (\(postId ?? savedPostId ?? "새 글"))") }
        // T-48: 새 글은 제목에 자동 포커스
        .onAppear {
            if postId == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { titleFocused = true }
            }
        }
        .background(
            // T-48: ⌘⌥I — Inspector 표시/숨김 (Pages/Xcode 패턴)
            Button("") { toggleInspector() }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .hidden()
        )
        .alert("새 시리즈", isPresented: $showNewSeriesDialog) {
            TextField("시리즈 제목 (예: CleanMyMac 완벽 가이드)", text: $newSeriesTitle)
            Button("만들기") { Task { await createNewSeries() } }
            Button("취소", role: .cancel) {
                selectedSeriesId = nil
            }
        } message: {
            Text("시리즈를 만들고 나서 글을 등록하면 시리즈에 묶입니다.")
        }
        .sheet(isPresented: $showHelp) { MarkdownHelpSheet() }
        .sheet(isPresented: $showSEO) { seoSheet }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerSheet(
                token: auth.token,
                mode: .insert,
                onInsert: { markdown in
                    insertInline(markdown)
                },
                onUploaded: { url in
                    insertInline(url)
                },
                onSelect: nil
            )
        }
        // T-30: 업로드 이미지에서 커버 수동 지정 (AI 커버 시트의 "업로드 이미지에서 선택"에서 열림)
        .sheet(isPresented: $showCoverPicker) {
            ImagePickerSheet(
                token: auth.token,
                mode: .cover,
                onInsert: { _ in },
                onUploaded: { _ in },
                onSelect: { url in
                    thumbnailUrl = url
                    showCoverPicker = false
                    DebugLogger.info("Editor", "[FEATURE] 커버 이미지 수동 지정 (\(url))")
                }
            )
        }
        .alert("유튜브 URL 또는 영상 ID 입력", isPresented: $showYoutubeDialog) {
            TextField("https://youtube.com/watch?v=... 또는 11자리 ID", text: $insertURL)
            Button("삽입") { insertYoutube() }
            Button("취소", role: .cancel) { insertURL = "" }
        }
        .alert("동영상(MP4) URL 입력", isPresented: $showVideoDialog) {
            TextField("https://.../video.mp4", text: $insertURL)
            Button("삽입") { insertVideo() }
            Button("취소", role: .cancel) { insertURL = "" }
        }
        .sheet(isPresented: $showAppSheet) { appCardSheet } // T-15
        .sheet(isPresented: $showCoverImagePrompt) { imageGenSheet } // T-21: AI 커버 이미지
    }

    // ---------- 앱 카드 시트 (T-15): App Store URL → 자동 추출 → [app] 삽입 ----------
    private var appCardSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("앱 카드 삽입")
                .font(.headline)
            TextField("App Store URL (https://apps.apple.com/app/.../id123456789)", text: $appURL)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("정보 가져오기") { Task { await fetchAppMeta() } }
                    .disabled(appFetching || appURL.trimmingCharacters(in: .whitespaces).isEmpty)
                if appFetching { ProgressView().controlSize(.small) }
                if let err = appFetchError {
                    Text(err).font(.caption).foregroundStyle(Color.dsDanger)
                }
                Spacer()
            }
            if let meta = appMeta {
                Divider()
                HStack(spacing: 12) {
                    if let icon = meta.artworkUrl100, let url = URL(string: icon) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFit()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meta.appName ?? "앱").font(.headline)
                        Text([meta.sellerName, meta.version, meta.price].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("언어: \(meta.languages?.joined(separator: ", ") ?? "-")")
                    Spacer()
                    if let os = meta.minimumOsVersion { Text("macOS \(os) 이상") }
                }
                .font(.caption)
                Divider()
                TextField("홈페이지 URL (선택)", text: $appHomepage)
                    .textFieldStyle(.roundedBorder)
                TextField("다운로드 버튼 라벨", text: $appDlLabel)
                    .textFieldStyle(.roundedBorder)
                TextField("다운로드 URL (선택)", text: $appDlURL)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("삽입") { insertAppCard() }
                        .buttonStyle(.borderedProminent)
                        .disabled(appCards.count > 20)
                    Spacer()
                    Text("앱 카드 \(appCards.count)개")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("마커에 App Store URL 포함 ([app:URL])", isOn: $appMarkerIncludeUrl)
                    .font(.caption)
                    .help("끄면 위치 마커 [app]만 삽입 (등록 순서대로 매칭)")
                Text("본문에 [app:URL] 마커가 삽입됩니다 — 그 위치에 앱 카드가 표시되고, 앱 정보는 마커의 URL로 식별됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            appURL = ""
            appHomepage = ""
            appDlLabel = ""
            appDlURL = ""
            appMeta = nil
            appFetchError = nil
        }
    }

    private func fetchAppMeta() async {
        let url = appURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        appFetching = true
        appFetchError = nil
        defer { appFetching = false }
        do {
            let meta: AppStoreInfo = try await APIClient.request("api/admin/store-fetch", method: "POST", token: auth.token, body: ["url": url])
            appMeta = meta
            appDlLabel = meta.isFree == true ? "무료 다운로드" : "다운로드"
            DebugLogger.info("Editor", "앱 카드 정보 가져오기 성공 (\(meta.appName ?? url))")
        } catch {
            appFetchError = error.localizedDescription
        }
    }

    private func insertAppCard() {
        guard let meta = appMeta else { return }
        var card = AppCardData(
            appName: meta.appName,
            storeInfo: meta,
            homepageUrl: appHomepage.trimmingCharacters(in: .whitespaces).isEmpty ? nil : appHomepage.trimmingCharacters(in: .whitespaces),
            appUrl: appURL.trimmingCharacters(in: .whitespaces),
            downloadLinks: []
        )
        let dl = appDlLabel.trimmingCharacters(in: .whitespaces)
        let dlUrl = appDlURL.trimmingCharacters(in: .whitespaces)
        if !dl.isEmpty {
            var link = AppCardLink(id: UUID().uuidString, label: dl)
            if !dlUrl.isEmpty { link.url = dlUrl }
            card.downloadLinks = [link]
        }
        appCards.append(card)
        if appMarkerIncludeUrl, let u = card.appUrl, !u.isEmpty {
            insertInline("[app:\(u)]\n\n")
        } else {
            insertInline("[app]\n\n[/app]")
        }
        appMeta = nil
        appURL = ""
        appHomepage = ""
        appDlLabel = ""
        appDlURL = ""
        showAppSheet = false
        DebugLogger.info("Editor", "앱 카드 삽입 (\(card.appName ?? "앱"), 총 \(appCards.count)개)")
    }

    // ---------- 헤더: 제목 + 저장 상태 + 액션 (T-48: 1줄로 통합, 메타는 Inspector로 이동) ----------
    private var headerBar: some View {
        VStack(spacing: 0) {
            // 1줄: 제목 + 저장 상태 + 미리보기/저장/발행/웹
            HStack(spacing: 8) {
                TextField("제목", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.weight(.semibold))
                    .focused($titleFocused)
                saveStateIndicator
                Text("Markdown")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                    .help("Markdown 형식으로 작성됩니다")
                Spacer()
                Button {
                    showPreview.toggle()
                    DebugLogger.info("Editor", "미리보기 \(showPreview ? "열림" : "닫힘")")
                } label: {
                    Image(systemName: showPreview ? "eye" : "eye.slash")
                }
                .help("미리보기 \(showPreview ? "숨기기" : "보기")")
                Button("초안만 저장") { Task { await saveToServer(status: "DRAFT") } }
                    .keyboardShortcut("s", modifiers: .command) // T-41: ⌘S 저장
                    .disabled(isLoading)
                Button("발행") { Task { await saveToServer(status: "PUBLISHED") } }
                    .keyboardShortcut(.return, modifiers: .command) // T-41: ⌘Return 발행
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                Button {
                    openOnWeb()
                } label: {
                    Image(systemName: "safari")
                }
                .help("웹에서 보기 (발행된 글)")
                .disabled(isLoading || status != "PUBLISHED")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // 2줄: 마크다운 삽입 + AI 포맷 바 (T-48: 카테고리/태그/시리즈/slug/커버는 Inspector로)
            HStack(spacing: 6) {
                Divider().frame(height: 16)
                Button { insertInline("**텍스트**") } label: { Label("B", systemImage: "").font(.caption.bold()) }
                    .help("굵게")
                Button { insertInline("*텍스트*") } label: { Label("I", systemImage: "").font(.caption.italic()).help("기울임") }
                Button { insertInline("~~텍스트~~") } label: { Label("S", systemImage: "").font(.caption).help("취소선") }
                Button { insertInline("## 제목") } label: { Label("H", systemImage: "").font(.caption.bold()).help("제목") }
                Button { insertInline("[텍스트](https://)") } label: { Image(systemName: "link").help("링크") }
                Button { showImagePicker = true } label: { Image(systemName: "photo").help("이미지 삽입") }
                Button { insertURL = ""; showYoutubeDialog = true } label: { Image(systemName: "play.rectangle").help("유튜브 삽입") }
                Button { insertURL = ""; showVideoDialog = true } label: { Image(systemName: "film").help("동영상(MP4) 삽입") }
                Button { showAppSheet = true } label: { Image(systemName: "square.grid.2x2").help("앱 카드 삽입") }
                Button { showHelp = true } label: { Image(systemName: "questionmark.circle").help("MD 사용법") }
                Spacer()
                Divider().frame(height: 16)
                Button { startSEO() } label: {
                    if seoMeta != nil {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.dsPrimary)
                        Text("SEO ✓")
                            .font(.caption.bold())
                            .foregroundStyle(Color.dsPrimary)
                    } else {
                        Image(systemName: "sparkles")
                    }
                }
                .help(seoMeta != nil ? "AI SEO — 저장된 메타 적용됨 (클릭 시 확인/재생성)" : "AI SEO — 제목/설명/키워드 생성")
                Button { openAssistant() } label: {
                    Image(systemName: "wand.and.stars")
                }
                .help("AI 도우미 — 프로그램/웹사이트 소개 참고 자료 생성")
                // T-27: 한글 맞춤법 검사 (Gemini) — 하단 패널에 오류 목록 → 개별 적용
                Button { checkSpelling() } label: {
                    if isCheckingSpelling {
                        ProgressView().controlSize(.mini)
                    } else if !spellingIssues.isEmpty {
                        Image(systemName: "text.badge.checkmark")
                            .foregroundStyle(Color.dsPrimary)
                        Text("맞춤법 \(spellingIssues.count)")
                            .font(.caption.bold())
                            .foregroundStyle(Color.dsPrimary)
                    } else {
                        Image(systemName: "text.badge.checkmark")
                    }
                }
                .help(spellingIssues.isEmpty ? "한글 맞춤법 검사 (Gemini) — 띄어쓰기/문법 오류 찾기" : "맞춤법 오류 \(spellingIssues.count)건 — 하단 패널에서 개별 적용")
                .disabled(!GeminiService.hasKey || isCheckingSpelling
                    || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                // T-48: 커버 버튼 → Inspector 커버 섹션으로 이동 (헤더 정리)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    // T-48: 저장 상태 표시 — 상태별 아이콘+색 (이모지 텍스트 → SF Symbol 표준화)
    @ViewBuilder
    private var saveStateIndicator: some View {
        if saveState.contains("저장 중") {
            ProgressView().controlSize(.mini)
                .help(saveState)
        } else {
            HStack(spacing: 4) {
                if saveState.contains("완료") || saveState.contains("복구됨") {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.dsSuccess)
                } else if saveState.contains("실패") || saveState.contains("없습니다")
                            || saveState.contains("찾을 수") || saveState.contains("입력해")
                            || saveState.contains("저장 차단") || saveState.contains("생성 실패") {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.dsWarning)
                } else {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(Color.dsTextMuted)
                }
                Text(saveState)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .help(saveState)
        }
    }

    // T-48: 우측 Inspector (⌘⌥I) — 글 설정/카테고리/커버 메타 (Pages/Xcode 패턴)
    private var inspectorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 카테고리 — FlowLayout 토큰 선택 (줄바꿈, 중복 선택 가능)
            VStack(alignment: .leading, spacing: 6) {
                Text("카테고리").font(.caption.bold()).foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(categories) { c in
                        Button {
                            if selectedCategoryIds.contains(c.id) {
                                selectedCategoryIds.remove(c.id)
                            } else {
                                selectedCategoryIds.insert(c.id)
                            }
                            scheduleAutoSave()
                        } label: {
                            Text(c.name)
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(
                                    Capsule().fill(selectedCategoryIds.contains(c.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .overlay(Capsule().strokeBorder(selectedCategoryIds.contains(c.id) ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1))
                                .foregroundStyle(selectedCategoryIds.contains(c.id) ? Color.primary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("카테고리 중복 선택 가능")
                    }
                }
                if categories.isEmpty {
                    Text("카테고리가 없습니다 (웹에서 생성)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Form {
                Picker("글 타입", selection: $contentType) {
                    Text("맥 앱").tag("ARTICLE")
                    Text("맥 팁").tag("TIP")
                    Text("맥 소식").tag("NEWS")
                    Text("페이지").tag("PAGE") // T-17: 정적 페이지 (About/Privacy 등)
                }
                Picker("시리즈", selection: $selectedSeriesId) {
                    Text("없음").tag(String?.none)
                    ForEach(seriesList) { s in
                        Text(s.title).tag(String?.some(s.id))
                    }
                    Divider()
                    Text("＋ 새 시리즈…").tag(String?.some("__new__"))
                }
                .onChange(of: selectedSeriesId) { _, v in
                    if v == "__new__" {
                        newSeriesTitle = ""
                        showNewSeriesDialog = true
                    }
                }
                TextField("태그 (쉼표 구분)", text: $tagsInput)
                    .help("#태그 — 쉼표로 구분, 새 태그 자동 생성")
                TextField("주소(slug)", text: $slug)
                    .font(.dsMono)
                    .help("비우면 자동 생성 — 저장 후 고정")
            }
            .formStyle(.grouped)

            // 커버 이미지 (T-21: AI 생성 / T-30: 업로드 이미지에서 선택)
            VStack(alignment: .leading, spacing: 6) {
                Text("커버 이미지").font(.caption.bold()).foregroundStyle(.secondary)
                if let url = absoluteImageURL(thumbnailUrl) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.15))
                    }
                    .frame(maxWidth: .infinity, maxHeight: 80, alignment: .top)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
                HStack(spacing: 6) {
                    Button {
                        imageGenPromptText = coverImagePrompt()
                        showCoverImagePrompt = true
                    } label: {
                        if generatingCoverImage {
                            ProgressView().controlSize(.mini)
                        } else {
                            Label("AI 생성", systemImage: "photo.badge.plus")
                        }
                    }
                    .controlSize(.small)
                    .disabled(generatingCoverImage || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("제목+본문으로 AI 커버 생성 (16:9)")
                    Button("이미지에서…") { showCoverPicker = true }
                        .controlSize(.small)
                        .help("업로드 이미지 중에서 커버 지정")
                    if thumbnailUrl != nil {
                        Button("제거") {
                            thumbnailUrl = nil
                            seoImageInput = ""
                            saveState = "커버 제거됨 — 저장 시 반영"
                        }
                        .controlSize(.small)
                        .help("커버 이미지 제거")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Spacer()
        }
        .frame(minWidth: 280, maxWidth: 280)
        .background(.bar)
        .overlay(alignment: .leading) { Divider() }
    }

    private func toggleInspector() {
        showInspector.toggle()
        DebugLogger.info("Editor", "Inspector \(showInspector ? "열림" : "닫힘")")
    }

    // ---------- 본문: 좌 MD 에디터 / 우 실시간 미리보기 ----------
    @ViewBuilder
    private var editorBody: some View {
        if isLoading {
            ProgressView("불러오는 중…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadError {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.dsWarning)
                Text(loadError)
                Button("닫기") { closeWindow() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // T-58: 에디터/미리보기 50:50 고정 (HSplitView는 스플리터로 비율 어긋남 — HStack으로 동일 사이즈 유지)
            HStack(spacing: 0) {
                EditorTextView(text: $content)
                    .frame(minWidth: 320, maxWidth: .infinity)
                Divider()
                if showPreview {
                    // T-57 수정: WKWebView는 자체 스크롤 보유 — ScrollView로 감싸면
                    // 리사이즈 시 내부 레이아웃이 고정되어 미리보기가 늘어나지 않는 문제 수정
                    PreviewWebView(html: previewHTML, scrollRestoreY: previewScrollY) { y in
                        previewScrollY = y
                    }
                    .frame(minWidth: 300, maxWidth: .infinity)
                    // T-48: 다크모드 — 흰색 하드코딩 제거 (웹 프리뷰 배경은 CSS 미디어 쿼리 대응)
                    .background(Color(nsColor: .textBackgroundColor))
                    .background(
                        // T-57: 리사이즈 검증용 — 미리보기 영역 크기 로그
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { DebugLogger.info("Preview", "미리보기 영역 \(Int(geo.size.width))×\(Int(geo.size.height))") }
                                .onChange(of: geo.size) { _, s in
                                    DebugLogger.info("Preview", "미리보기 리사이즈 → \(Int(s.width))×\(Int(s.height))")
                                }
                        }
                    )
                }
                if showInspector {
                    Divider()
                    inspectorView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // ---------- T-27: 맞춤법 검사 (Gemini) ----------
    private func checkSpelling() {
        let target = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            spellCheckError = "검사할 본문이 없습니다"
            return
        }
        spellCheckError = nil
        spellingIssues = []
        isCheckingSpelling = true
        DebugLogger.info("Editor", "[FEATURE] 맞춤법 검사 실행됨 (본문 \(target.count)자)")
        Task {
            defer { isCheckingSpelling = false }
            do {
                let issues = try await GeminiService.checkKoreanSpelling(text: String(target.prefix(8000)))
                await MainActor.run {
                    spellingIssues = issues
                    if issues.isEmpty {
                        spellCheckError = nil
                        DebugLogger.info("Editor", "맞춤법 검사 완료 — 이상 없음")
                    } else {
                        DebugLogger.info("Editor", "맞춤법 검사 완료 — 오류 \(issues.count)건")
                    }
                }
            } catch {
                DebugLogger.error("Editor", "맞춤법 검사 실패: \(error.localizedDescription)")
                await MainActor.run {
                    spellCheckError = error.localizedDescription
                }
            }
        }
    }

    // 항목별 적용 — 제목/본문에서 원문과 동일한 조각을 수정문으로 치환
    private func applySpelling(_ issue: SpellingIssue) {
        var applied = false
        if title.contains(issue.original) {
            title = title.replacingOccurrences(of: issue.original, with: issue.fixed)
            applied = true
        }
        if content.contains(issue.original) {
            content = content.replacingOccurrences(of: issue.original, with: issue.fixed)
            applied = true
        }
        if applied {
            spellingIssues.removeAll { $0.id == issue.id }
            DebugLogger.info("Editor", "맞춤법 적용됨: \(issue.original) → \(issue.fixed)")
        }
    }

    // 맞춤법 검사 결과 패널 (하단)
    private var spellingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "text.badge.checkmark")
                    .foregroundStyle(Color.dsPrimary)
                Text("맞춤법 검사").font(.headline)
                Spacer()
                Button("닫기") {
                    spellingIssues = []
                    spellCheckError = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("결과 패널 닫기")
            }
            if let err = spellCheckError {
                Text(err).font(.caption).foregroundStyle(Color.dsDanger)
            } else if isCheckingSpelling {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Gemini가 검사 중입니다… (최대 8,000자)").font(.caption).foregroundStyle(.secondary)
                }
            } else if spellingIssues.isEmpty {
                Text("이상 없음").font(.caption).foregroundStyle(Color.dsSuccess)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(spellingIssues) { issue in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.original)
                                        .font(.caption)
                                        .strikethrough()
                                        .foregroundStyle(Color.dsDanger)
                                        .textSelection(.enabled)
                                    Text(issue.fixed)
                                        .font(.caption.bold())
                                        .textSelection(.enabled)
                                    Text(issue.reason)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("적용") { applySpelling(issue) }
                                    .controlSize(.small)
                                    .disabled(isCheckingSpelling)
                                    .help("원문을 수정문으로 교체")
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color(nsColor: .controlBackgroundColor)))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(10)
    }

    // ---------- 미리보기 HTML (300ms 디바운스 실시간) ----------
    private func buildPreviewHTML(_ md: String) -> String {
        let content = MarkdownRenderer.render(md, apps: appCards)
        let style = """
        <style>
          body { font-family: -apple-system, sans-serif; padding: 24px; line-height: 1.7; color: #1d1d1f; background: #fff; }
          pre { background: #f5f5f7; padding: 12px; border-radius: 8px; overflow-x: auto; }
          code { background: #f5f5f7; padding: 2px 5px; border-radius: 4px; font-size: 0.9em; }
          pre code { background: none; padding: 0; }
          img { max-width: 100%; }
          figure { margin: 12px 0; }
          figcaption { font-size: 0.85em; color: #6e6e73; text-align: center; margin-top: 4px; }
          blockquote { border-left: 3px solid #007aff; margin-left: 0; padding-left: 12px; color: #555; }
          a { color: #007aff; }
          .youtube-embed { margin: 16px 0; }
          .youtube-embed iframe { max-width: 100%; border-radius: 8px; }
          video { max-width: 100%; border-radius: 8px; }
          table { border-collapse: collapse; }
          th, td { border: 1px solid #d2d2d7; padding: 6px 10px; }
          /* 앱 카드 (T-15, 웹 globals.css .app-card 동일 스타일) */
          .app-card { margin: 16px 0; border: 1px solid #d2d2d7; border-radius: 12px; background: #fff; padding: 16px 20px; }
          .app-card-top { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
          .app-card .app-icon { width: 56px; height: 56px; border-radius: 12px; object-fit: cover; border: 1px solid #d2d2d7; }
          .app-icon-placeholder { width: 56px; height: 56px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 20px; font-weight: bold; color: #fff; background: #007aff; }
          .app-card-title { min-width: 0; }
          .app-name { font-weight: bold; font-size: 17px; line-height: 1.2; }
          .app-seller { font-size: 13px; color: #6e6e73; }
          .app-desc { font-size: 13px; color: #6e6e73; line-height: 1.5; margin: 8px 0; }
          .app-specs { display: grid; grid-template-columns: 1fr 1fr; gap: 4px 24px; font-size: 13px; margin: 12px 0; }
          .spec-row { display: flex; justify-content: space-between; gap: 8px; padding: 2px 0; border-bottom: 1px dashed #d2d2d7; }
          .spec-k { color: #86868b; flex-shrink: 0; }
          .spec-v { color: #1d1d1f; text-align: right; }
          .app-actions { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-top: 12px; }
          .app-dl { display: inline-block; padding: 8px 16px; border-radius: 8px; background: #007aff; color: #fff; font-size: 13px; font-weight: 500; text-decoration: none; }
          .app-home { display: inline-block; padding: 7px 12px; border-radius: 8px; border: 1px solid #d2d2d7; font-size: 13px; color: #6e6e73; text-decoration: none; }
          /* T-48: 다크모드 대응 (앱 시스템 다크 모드 연동) */
          @media (prefers-color-scheme: dark) {
            body { color: #f5f5f7; background: #1e1e1e; }
            pre { background: #2a2a2c; }
            code { background: #2a2a2c; }
            blockquote { color: #b0b0b8; }
            th, td { border-color: #3a3a3c; }
            .app-card { background: #262628; border-color: #3a3a3c; }
            .app-icon { border-color: #3a3a3c; }
            .app-seller, .app-desc, .app-specs { color: #b0b0b8; }
            .spec-k { color: #86868b; }
            .spec-v { color: #f5f5f7; }
            .spec-row { border-bottom-color: #3a3a3c; }
            .app-home { border-color: #3a3a3c; color: #b0b0b8; }
          }
        </style>
        """
        return "<html><head><meta charset=\"utf-8\">\(style)</head><body>\(content)</body></html>"
    }

    private func schedulePreview() {
        previewTask?.cancel()
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let html = buildPreviewHTML(content)
            await MainActor.run { previewHTML = html }
            // T-20: [app:URL] 마커 → App Store 조회 → 앱 카드 자동 보강 (미리보기 정식 카드)
            await enrichAppCardsFromMarkers()
        }
    }

    // 본문에서 [app:URL] 마커 URL 추출
    private func extractAppMarkerUrls() -> [String] {
        var urls: [String] = []
        let pattern = #"\[app:([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = content as NSString
            for m in regex.matches(in: content, range: NSRange(location: 0, length: ns.length)) {
                let u = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if u.hasPrefix("http") { urls.append(u) }
            }
        }
        return urls
    }

    // T-20: 마커 URL 중 보강 안 된 앱 → App Store lookup → appCards에 추가 (웹 저장 시 보강과 동일 결과)
    private func enrichAppCardsFromMarkers() async {
        let markerURLs = extractAppMarkerUrls()
        guard !markerURLs.isEmpty else { return }
        let pending = markerURLs.filter { url in
            !lookedUpAppUrls.contains(url)
                && !appCards.contains(where: { $0.appUrl == url || $0.homepageUrl == url })
        }
        guard !pending.isEmpty else { return }
        lookedUpAppUrls.formUnion(pending)
        for url in pending {
            let card: AppCardData
            if let meta = try? await AppStoreLookup.lookup(url: url) {
                card = AppCardData(
                    appName: meta.appName,
                    storeInfo: AppStoreInfo(
                        appName: meta.appName,
                        version: meta.version,
                        sellerName: meta.sellerName,
                        price: meta.price,
                        isFree: meta.isFree,
                        languages: meta.languages,
                        minimumOsVersion: meta.minimumOsVersion,
                        currentVersionReleaseDate: meta.currentVersionReleaseDate,
                        rating: meta.rating,
                        ratingCount: meta.ratingCount,
                        artworkUrl100: meta.artworkUrl100,
                        fileSizeBytes: meta.fileSizeBytes,
                        sellerUrl: meta.sellerUrl
                    ),
                    homepageUrl: nil,
                    appUrl: url,
                    downloadLinks: []
                )
                DebugLogger.info("Editor", "[app:URL] 앱 정보 조회 성공: \(meta.appName)")
            } else {
                // T-29: App Store URL이 아니면 appUrl(→"App Store ↗")가 아니라 homepageUrl로 저장
                let isStore = url.hasPrefix("https://apps.apple.com/")
                card = AppCardData(appName: nil, storeInfo: nil, homepageUrl: isStore ? nil : url, appUrl: isStore ? url : nil, downloadLinks: [])
                DebugLogger.warn("Editor", "[app:URL] 앱 정보 조회 실패 — \(isStore ? "App Store" : "홈페이지") URL만 카드 (\(url))")
            }
            await MainActor.run {
                if !appCards.contains(where: { $0.appUrl == url || $0.homepageUrl == url }) {
                    appCards.append(card)
                }
                previewHTML = buildPreviewHTML(content)
            }
        }
    }

    // ---------- 로드 (서버 데이터 + 로컬 초안 우선) ----------
    // 새 창(sheet 아님)에서 닫기 — onClose 콜백 우선, 없으면 dismiss
    private func closeWindow() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func load() async {
        defer { isLoading = false }
        do {
            let cats: [PostCategory] = try await APIClient.request("api/categories", token: auth.token)
            categories = cats
        } catch {
            DebugLogger.warn("Editor", "카테고리 로드 실패: \(error.localizedDescription)")
        }
        do {
            let seriesData = try await APIClient.fetchSeries(token: auth.token)
            seriesList = seriesData.series
        } catch {
            DebugLogger.warn("Editor", "시리즈 로드 실패: \(error.localizedDescription)")
        }

        if let postId {
            do {
                let post: Post = try await APIClient.request("api/admin/posts/\(postId)", token: auth.token)
                title = post.title
                slug = post.slug
                excerpt = post.excerpt ?? ""
                seoMeta = post.seoMeta
                thumbnailUrl = post.thumbnailUrl // T-21: 저장된 커버 이미지 (버튼 "커버 ✓" 표시용)
                if let thumb = post.thumbnailUrl, !thumb.isEmpty {
                    seoImageInput = thumb
                }
                selectedSeriesId = post.seriesId
                contentType = post.contentType ?? "ARTICLE"
                // 카테고리: slug → id 매핑 (다대다)
                if let cats = post.categories {
                    for ref in cats {
                        if let c = categories.first(where: { $0.slug == ref.slug }) {
                            selectedCategoryIds.insert(c.id)
                        }
                    }
                }
                tagsInput = (post.tags ?? []).map { $0.name }.joined(separator: ", ")
                if post.bodyFormat == "HTML" {
                    content = HTMLToMarkdown.convert(post.body)
                    DebugLogger.info("Editor", "HTML 글 → MD 변환 (\(postId))")
                } else {
                    content = post.body
                }
                status = post.status
                // T-29: 서버 앱 카드 정규화 — appUrl이 App Store가 아니면 homepageUrl로 이동
                // (과거 옛 서버가 appUrl로 저장한 데이터 방어 — "App Store ↗" 오표시 방지)
                appCards = (post.apps ?? []).map { app in
                    var a = app
                    if let u = a.appUrl, !u.hasPrefix("https://apps.apple.com/") {
                        a.homepageUrl = a.homepageUrl ?? u
                        a.appUrl = nil
                    }
                    return a
                }
                DebugLogger.info("Editor", "서버 글 로드 (\(postId), 앱 카드 \(appCards.count)개)")
            } catch {
                loadError = "게시글을 불러오지 못했습니다: \(error.localizedDescription)"
                return
            }
        }

        // T-32: 기존 글은 서버 우선 — 로컬 초안이 서버 본문을 덮지 않음
        // (구버전 버그: title만 있고 body가 빈 초안이 서버 본문을 지워 "글 내용이 사라진 것처럼" 보였음)
        if let postId {
            if DraftStore.load(postId: postId) != nil {
                DraftStore.clear(postId: postId)
                DebugLogger.info("Editor", "기존 글 초안 정리 (서버 우선, \(postId))")
            }
            return
        }
        // 새 글만 로컬 초안 복구 (오프라인/자동저장 대비)
        // T-24: 시드된 새 글(AI 도우미 등)은 초안 로드 안 함 — 항상 새 글 시작
        if isSeeded { return }
        if let draft = DraftStore.load(postId: draftKey) {
            // T-32: 본문이 비어 있으면 폐기 — 제목만 있는 초안은 복구하지 않음
            let hasContent = !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasContent {
                title = draft.title
                content = draft.body
                status = draft.status
                if let draftSlug = draft.slug, !draftSlug.isEmpty {
                    slug = draftSlug
                }
                if let m = draft.seoMeta {
                    seoMeta = m
                    excerpt = m.description ?? excerpt
                }
                saveState = "초안 복구됨 (\(draft.savedAt.formatted(date: .omitted, time: .shortened)))"
                DebugLogger.info("Editor", "로컬 초안 복구 (\(draftKey))")
            } else {
                DraftStore.clear(postId: draftKey)
                DebugLogger.debug("Editor", "빈 초안 폐기 (\(draftKey))")
            }
        }
    }

    // ---------- 자동저장 (3초 디바운스) ----------
    private func scheduleAutoSave() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            // T-24: 새 글 초안은 제목 필수 (제목 없으면 저장 안 함 — 임시 저장 목록 오염 방지)
            if postId == nil && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await MainActor.run { saveState = "제목을 입력하면 초안이 저장됩니다" }
                return
            }
            DraftStore.save(postId: postId ?? savedPostId ?? draftKey, title: title, bodyFormat: "MD", body: content, status: status, slug: slug.isEmpty ? nil : slug, seoMeta: seoMeta)
            await MainActor.run { saveState = "초안 저장됨 \(Date().formatted(date: .omitted, time: .standard))" }
        }
    }

    // ---------- 삽입 툴바 ----------

    // 발행된 글을 웹에서 열기
    // AI 도우미 — 별도 창으로 열기 (참고 자료 생성, 복사해서 활용) — T-25: 중복 방지
    private func openAssistant() {
        WindowManager.showAssistant()
    }

    // 새 시리즈 생성 후 선택 (에디터 드롭다운)
    private func createNewSeries() async {
        let title = newSeriesTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            selectedSeriesId = nil
            return
        }
        do {
            let s = try await APIClient.createSeries(token: auth.token, title: title, description: nil)
            seriesList.append(s)
            selectedSeriesId = s.id
            DebugLogger.info("Editor", "시리즈 생성 (\(title))")
        } catch {
            let e = error as? APIError
            saveState = "시리즈 생성 실패: \(e?.message ?? error.localizedDescription)"
            selectedSeriesId = nil
            DebugLogger.error("Editor", "시리즈 생성 실패: \(e?.code ?? "unknown")")
        }
    }

    private func openOnWeb() {
        let currentSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentSlug.isEmpty else {
            saveState = "슬러그가 없습니다 — 저장 후 다시 시도하세요"
            return
        }
        guard let url = URL(string: "post/\(currentSlug)", relativeTo: APIClient.webURL) else { return }
        NSWorkspace.shared.open(url)
        DebugLogger.info("Editor", "웹에서 글 열기 (\(currentSlug))")
    }

    // 커서 위치에 텍스트 삽입
    private func insertInline(_ text: String) {
        if let tv = EditorTextView.activeTextView {
            let range = tv.selectedRange()
            tv.insertText(text, replacementRange: range)
            content = tv.string
        } else {
            content += text
        }
        DebugLogger.debug("Editor", "인라인 삽입 (\(text.prefix(12)))")
    }

    private func insertYoutube() {
        let raw = insertURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = youtubeID(from: raw) else {
            saveState = "유튜브 ID를 찾을 수 없습니다"
            return
        }
        insertInline("[youtube:\(id)]")
        insertURL = ""
    }

    private func insertVideo() {
        let url = insertURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard url.hasPrefix("http") else {
            saveState = "http(s) URL을 입력해 주세요"
            return
        }
        insertInline("[video:\(url)]")
        insertURL = ""
    }

    // 유튜브 URL → 11자리 ID 추출
    private func youtubeID(from raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count == 11, s.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) {
            return s
        }
        guard let range = s.range(
            of: #"(?:v=|embed/|shorts/|youtu\.be/)([A-Za-z0-9_-]{11})"#,
            options: .regularExpression
        ) else { return nil }
        return String(s[range])
    }

    // 상대 경로(/uploads/...) → 절대 URL (시트의 저장된 커버 미리보기용)
    private func absoluteImageURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if let u = URL(string: path), u.scheme != nil { return u }
        return URL(string: path, relativeTo: APIClient.baseURL)?.absoluteURL
    }

    // ---------- 서버 저장/발행 (MD 고정) ----------
    private func saveToServer(status newStatus: String) async {
        guard title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            saveState = "제목과 본문을 입력해 주세요"
            DebugLogger.warn("Editor", "저장 차단: 제목/본문 비어 있음")
            return
        }
        saveState = "저장 중…"
        let input = PostInput(
            title: title,
            slug: slug.isEmpty ? nil : slug,
            categoryIds: Array(selectedCategoryIds),
            tags: tagsInput.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "^#+", with: "", options: .regularExpression) }.filter { !$0.isEmpty },
            contentType: contentType,
            bodyFormat: "MD",
            body: content,
            excerpt: excerpt.isEmpty ? nil : excerpt,
            status: newStatus,
            seoMeta: seoMeta,
            seriesId: selectedSeriesId,
            apps: appCards.isEmpty ? nil : appCards,
            thumbnailUrl: thumbnailUrl
        )
        do {
            let saved: Post
            let serverPostId = postId ?? savedPostId
            if let serverPostId {
                saved = try await APIClient.request("api/admin/posts/\(serverPostId)", method: "PUT", token: auth.token, body: input)
            } else {
                saved = try await APIClient.request("api/admin/posts", method: "POST", token: auth.token, body: input)
            }
            // 서버 저장 성공 → 로컬 초안 정리 (신규 글은 단일 슬롯 draft_new 포함)
            DraftStore.clear(postId: serverPostId)
            if serverPostId == nil {
                DraftStore.clear(postId: DraftStore.newPostKey)
            }
            status = newStatus
            if postId == nil {
                savedPostId = saved.id // 신규 글: 이후 저장·자동저장은 PUT/서버 id 키 사용
                if slug.isEmpty { slug = saved.slug } // T-26: 서버가 만든 slug 유지 — 저장마다 URL이 바뀌는 문제 방지
            }
            saveState = newStatus == "PUBLISHED" ? "발행 완료" : "저장 완료"
            DebugLogger.info("Editor", "서버 저장 완료 (\(newStatus)) postId=\(saved.id)")
            onSaved?()
            // T-48: 모든 저장 경로(⌘N/⌘K/시드)에서 목록 갱신 알림 표준화 — ContentView onSaved 클로저 공백 버그 해결
            NotificationCenter.default.post(name: .postSaved, object: nil)
        } catch {
            let e = error as? APIError
            saveState = "저장 실패: \(e?.message ?? error.localizedDescription)"
            DebugLogger.error("Editor", "서버 저장 실패: \(e?.code ?? "unknown")")
        }
    }
    // ---------- AI SEO ----------
    private func startSEO() {
        guard !GeminiService.hasKey else {
            seoError = nil
            seoSuggestion = nil
            // 저장된 seoMeta가 있으면 생성 없이 저장값 표시 (재생성 버튼으로 새로 생성)
            if seoMeta != nil {
                showSEO = true
                return
            }
            showSEO = true
            Task { await generateSEO() }
            return
        }
        seoError = "Gemini API 키가 설정되지 않았습니다. 설정 → AI SEO (Gemini)에서 입력하세요."
        showSEO = true
    }

    private func generateSEO(forceRefresh: Bool = false) async {
        seoLoading = true
        seoError = nil
        do {
            let s = try await GeminiService.generateSEO(
                title: title,
                body: content,
                slug: slug.isEmpty ? nil : slug,
                imageCandidates: imageCandidates(),
                forceRefresh: forceRefresh
            )
            seoSuggestion = s
            DebugLogger.info("Editor", "AI SEO 생성 완료")
        } catch {
            let e = error as? APIError
            seoError = e?.message ?? error.localizedDescription
            DebugLogger.error("Editor", "AI SEO 실패: \(e?.code ?? "unknown")")
        }
        seoLoading = false
    }

    // 본문에서 [img:...] URL 목록 추출 (og:image 후보)
    private func imageCandidates() -> [String] {
        var urls: [String] = []
        let pattern = #"\[img:(\S+?)(?:\s|])"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = content as NSString
            for m in regex.matches(in: content, range: NSRange(location: 0, length: ns.length)) {
                let url = ns.substring(with: m.range(at: 1))
                if !urls.contains(url) { urls.append(url) }
            }
        }
        return urls
    }

    private func applySEO() {
        guard let s = seoSuggestion else { return }
        if let t = s.title, !t.isEmpty, t != title {
            title = t
        }
        if let sl = s.slug, !sl.isEmpty {
            slug = sl
        }
        if let ex = s.excerpt, !ex.isEmpty {
            excerpt = ex
        }
        if let img = s.image, !img.isEmpty {
            thumbnailUrl = img
        } else if !seoImageInput.isEmpty {
            thumbnailUrl = seoImageInput
        }
        // AI SEO 값 → seoMeta (웹 페이지 meta 태그 자동 구성에 사용)
        let finalImage = (s.image?.isEmpty == false ? s.image : (seoImageInput.isEmpty ? thumbnailUrl : seoImageInput))
        seoMeta = SeoMeta(
            title: s.title ?? title,
            description: s.excerpt ?? (excerpt.isEmpty ? nil : excerpt),
            tags: (s.keywords?.isEmpty == false ? s.keywords : nil),
            image: finalImage,
            appliedAt: ISO8601DateFormatter().string(from: Date())
        )
        showSEO = false
        saveState = "AI SEO 적용됨 (저장하면 웹 meta 태그에 반영)"
        DebugLogger.info("Editor", "AI SEO 제안 적용됨 (seoMeta 저장)")
    }

    private var seoSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AI SEO").font(.title3.bold())
                if let at = seoMeta?.appliedAt {
                    Text("적용: \(at.prefix(10))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("닫기") { showSEO = false }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            if seoLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("제목·설명·키워드·대표 이미지 생성 중…").font(.dsBody).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let seoError {
                VStack(alignment: .leading, spacing: 10) {
                    Label(seoError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color.dsWarning)
                    if seoError.contains("설정") {
                        Button("설정 열기") {
                            showSEO = false
                            // T-45: 설정이 별도 Settings scene(⌘,)으로 이동 — 표준 셀렉터로 열기
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let s = seoSuggestion {
                // 새 제안 표시
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        seoRow("제목", s.title)
                        seoRow("슬러그", s.slug)
                        seoRow("설명", s.excerpt)
                        if let keywords = s.keywords, !keywords.isEmpty {
                            seoRow("키워드", keywords.joined(separator: " · "))
                        }
                        seoImageInput(s.image)
                        metaPreview(
                            title: s.title ?? title,
                            description: s.excerpt ?? excerpt,
                            keywords: s.keywords,
                            image: s.image ?? seoImageInput
                        )
                    }
                }
                HStack {
                    Button("다시 생성") {
                        Task { await generateSEO(forceRefresh: true) }
                    }
                    Spacer()
                    Button("취소") { showSEO = false }
                    Button("적용") { applySEO() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            } else if let m = seoMeta {
                // 저장된 seoMeta 표시 (AI 호출 없이)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        seoRow("제목", m.title ?? title)
                        seoRow("설명", m.description ?? excerpt)
                        if let tags = m.tags, !tags.isEmpty {
                            seoRow("키워드", tags.joined(separator: " · "))
                        }
                        if let img = m.image, !img.isEmpty {
                            seoRow("대표 이미지 (og:image)", img)
                        }
                        metaPreview(
                            title: m.title ?? title,
                            description: m.description ?? excerpt,
                            keywords: m.tags,
                            image: m.image
                        )
                    }
                }
                HStack {
                    Button("재생성") {
                        seoSuggestion = nil
                        seoError = nil
                        Task { await generateSEO(forceRefresh: true) }
                    }
                    Spacer()
                    Button("닫기") { showSEO = false }
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 420)
    }

    // T-21: AI 커버 이미지 시트 — 프롬프트 확인/편집 → 생성 → 결과 미리보기 → 커버 적용 (시트 유지, 재생성 가능)
    private var imageGenSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI 커버 이미지 생성").font(.title3.bold())
                Spacer()
                Text(GeminiService.imageGenProvider.label).font(.caption2).foregroundStyle(.secondary)
            }
            Text("글 커버(대표 이미지, og:image)로 사용할 16:9 이미지를 만듭니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $imageGenPromptText)
                .font(.body)
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            HStack {
                Button("초기화") { imageGenPromptText = coverImagePrompt() }
                    .buttonStyle(.link)
                    .controlSize(.small)
                Spacer()
                if let data = generatedCoverImageData, let ns = NSImage(data: data) {
                    Text("\(Int(ns.size.width))×\(Int(ns.size.height))").font(.caption2).foregroundStyle(.secondary)
                }
                Button("다시 생성") {
                    Task { await generateCoverImage(prompt: imageGenPromptText) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(generatingCoverImage || generatedCoverImageData == nil || imageGenPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            // 생성 결과 미리보기 (T-21: 시트 유지, 생성 결과 확인 후 적용/재생성)
            Group {
                if generatingCoverImage {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("이미지 생성 중… (보통 10~30초)").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if let data = generatedCoverImageData, let ns = NSImage(data: data) {
                    Image(nsImage: ns)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                } else if let cover = absoluteImageURL(thumbnailUrl) {
                    // 저장된 커버 이미지 표시 (아직 새로 생성 안 한 상태)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("저장된 커버 이미지").font(.caption.bold()).foregroundStyle(.secondary)
                        AsyncImage(url: cover) { img in
                            img.resizable().scaledToFit().frame(maxWidth: .infinity)
                        } placeholder: {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.08))
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .overlay(Text("생성 결과가 여기에 표시됩니다").font(.caption).foregroundStyle(.secondary))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            if let err = coverImageError {
                Text(err).font(.caption).foregroundStyle(Color.dsDanger)
            }
            HStack {
                Button("취소") { showCoverImagePrompt = false }.keyboardShortcut(.cancelAction)
                // T-30: 업로드된 이미지 목록에서 커버 수동 지정
                Button("업로드 이미지에서 선택") {
                    showCoverImagePrompt = false
                    showCoverPicker = true
                }
                Spacer()
                Button("이 프롬프트로 생성") {
                    Task { await generateCoverImage(prompt: imageGenPromptText) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(generatingCoverImage || imageGenPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("커버 이미지로 사용") {
                    Task { await applyGeneratedCoverImage() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(generatingCoverImage || generatedCoverImageData == nil)
            }
        }
        .padding(20)
        .frame(width: 500, height: 580)
    }

    // T-21: 커버 이미지 프롬프트 자동 구성 (제목+본문 요약 기반)
    private func coverImagePrompt() -> String {
        let bodyExcerpt = String(content.replacingOccurrences(of: #"[\[\]]"#, with: " ", options: .regularExpression)
            .prefix(300))
        return """
        다음 글의 커버(대표) 이미지를 만들어 주세요: \(title)
        본문 요약: \(bodyExcerpt)
        macOS 앱 큐레이션 블로그 썸네일, 깔끔하고 미니멀한 스타일, 텍스트 없이, 16:9 와이드 비율.
        """
    }

    // T-21: AI 커버 이미지 생성 (업로드 없이 Data 유지 — 미리보기 후 "커버 이미지로 사용" 시 업로드)
    private func generateCoverImage(prompt: String) async {
        generatingCoverImage = true
        coverImageError = nil
        do {
            DebugLogger.info("Editor", "[FEATURE] AI 커버 이미지 생성 시작 provider=\(GeminiService.imageGenProvider.rawValue) prompt=\(String(prompt.prefix(60)))…")
            let (imageData, provider) = try await GeminiService.generateImage(prompt: prompt)
            generatedCoverImageData = imageData
            DebugLogger.info("Editor", "[FEATURE] AI 커버 이미지 생성 완료 provider=\(provider) bytes=\(imageData.count)")
        } catch {
            let e = error as? APIError
            coverImageError = e?.message ?? error.localizedDescription
            DebugLogger.error("Editor", "AI 커버 이미지 생성 실패: \(e?.code ?? "unknown") status=\(e?.status ?? -1) msg=\(e?.message ?? error.localizedDescription)")
        }
        generatingCoverImage = false
    }

    // T-21: 생성된 커버 이미지 업로드 → 대표 이미지(og:image)로 설정 (본문 삽입 없음) → 시트 닫기
    private func applyGeneratedCoverImage() async {
        guard let data = generatedCoverImageData else { return }
        do {
            let dir = FileManager.default.temporaryDirectory
            let fileURL = dir.appendingPathComponent("cover-img-\(UUID().uuidString.prefix(8)).\(GeminiService.imageExtension(for: data))")
            try data.write(to: fileURL)

            let url = try await APIClient.uploadImage(token: auth.token, fileURL: fileURL)
            try? FileManager.default.removeItem(at: fileURL)

            thumbnailUrl = url
            seoImageInput = url
            if seoMeta != nil {
                seoMeta?.image = url
                seoMeta?.appliedAt = ISO8601DateFormatter().string(from: Date())
            }
            generatedCoverImageData = nil
            showCoverImagePrompt = false
            saveState = "커버 이미지 적용됨 (저장하면 웹에 반영)"
            DebugLogger.info("Editor", "[FEATURE] 커버 이미지 적용 완료 (\(url))")
        } catch {
            let e = error as? APIError
            coverImageError = e?.message ?? error.localizedDescription
            DebugLogger.error("Editor", "AI 커버 이미지 업로드 실패: \(e?.code ?? "unknown")")
        }
    }

    // 대표 이미지 (og:image) 입력 — 본문 첫 이미지 자동 채움 + 수동 편집
    private func seoImageInput(_ suggested: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("대표 이미지 (og:image)").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                // T-19: AI 썸네일 생성 — 제목+본문 기반 16:9 (프롬프트 확인/편집)
                Button {
                    thumbPromptText = thumbnailPrompt()
                    showThumbPrompt = true
                } label: {
                    if generatingThumb {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text("생성 중…")
                        }
                    } else {
                        Label("AI 생성", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.link)
                .controlSize(.small)
                .disabled(generatingThumb || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("본문 첫 이미지") {
                    seoImageInput = imageCandidates().first ?? ""
                }
                .buttonStyle(.link)
                .controlSize(.small)
            }
            HStack(spacing: 6) {
                TextField("/uploads/... 또는 https://...", text: $seoImageInput)
                    .font(.dsMono)
                    .textFieldStyle(.roundedBorder)
                if !seoImageInput.isEmpty {
                    Button {
                        seoImageInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("비우기")
                }
            }
            Text("비워 두면 이 글은 og:image 없이 공유됩니다.")
                .font(.dsCaption)
                .foregroundStyle(.secondary)
            // 프롬프트 확인/편집 (T-19)
            if showThumbPrompt {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("AI 요청 프롬프트 (수정 가능)").font(.caption.bold()).foregroundStyle(.secondary)
                        Text(GeminiService.imageGenProvider.label).font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Button("초기화") { thumbPromptText = thumbnailPrompt() }.buttonStyle(.link).controlSize(.small)
                    }
                    TextEditor(text: $thumbPromptText)
                        .font(.body)
                        .frame(minHeight: 60)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                    HStack {
                        Spacer()
                        Button("취소") { showThumbPrompt = false }.keyboardShortcut(.cancelAction)
                        Button("이 프롬프트로 생성") {
                            showThumbPrompt = false
                            Task { await generateThumbnail(prompt: thumbPromptText) }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(generatingThumb || thumbPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color(nsColor: .controlBackgroundColor)))
        .onAppear {
            if let s = suggested, !s.isEmpty {
                seoImageInput = s
            } else if seoImageInput.isEmpty {
                seoImageInput = imageCandidates().first ?? ""
            }
        }
    }

    // T-19: 썸네일 프롬프트 자동 구성 (제목+본문 요약 기반)
    private func thumbnailPrompt() -> String {
        let bodyExcerpt = String(content.replacingOccurrences(of: #"[\[\]]"#, with: " ", options: .regularExpression)
            .prefix(300))
        return """
        다음 글의 대표 이미지 (og:image)를 만들어 주세요: \(title)
        본문 요약: \(bodyExcerpt)
        macOS 앱 큐레이션 블로그 썸네일, 깔끔하고 미니멀한 스타일, 텍스트 없이, 16:9 와이드 비율.
        """
    }

    // T-19: AI 썸네일 생성 → 임시 파일 → 업로드 → seoImageInput 자동 입력
    private func generateThumbnail(prompt: String) async {
        generatingThumb = true
        seoError = nil
        do {
            DebugLogger.info("Editor", "[FEATURE] AI 썸네일 생성 시작 provider=\(GeminiService.imageGenProvider.rawValue) prompt=\(String(prompt.prefix(60)))…")
            let (imageData, _) = try await GeminiService.generateImage(prompt: prompt)

            let dir = FileManager.default.temporaryDirectory
            let fileURL = dir.appendingPathComponent("post-thumb-\(UUID().uuidString.prefix(8)).\(GeminiService.imageExtension(for: imageData))")
            try imageData.write(to: fileURL)

            let url = try await APIClient.uploadImage(token: auth.token, fileURL: fileURL)
            try? FileManager.default.removeItem(at: fileURL)

            seoImageInput = url
            thumbnailUrl = url
            DebugLogger.info("Editor", "[FEATURE] AI 썸네일 업로드 완료 (\(url))")
        } catch {
            let e = error as? APIError
            seoError = e?.message ?? error.localizedDescription
            DebugLogger.error("Editor", "AI 썸네일 생성 실패: \(e?.code ?? "unknown")")
        }
        generatingThumb = false
    }

    // 실제 meta 태그 미리보기
    private func metaPreview(title: String, description: String?, keywords: [String]?, image: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("메타 태그 미리보기").font(.caption.bold()).foregroundStyle(.secondary)
            Text("<title>\(title) | MacCanDo</title>")
                .font(.dsMono)
            Text("<meta name=\"description\" content=\"\(description ?? "")\"/>")
                .font(.dsMono)
            Text("<meta name=\"keywords\" content=\"\(keywords?.joined(separator: ", ") ?? "")\"/>")
                .font(.dsMono)
            if let image, !image.isEmpty {
                Text("<meta property=\"og:image\" content=\"\(image)\"/>")
                    .font(.dsMono)
            }
        }
        .textSelection(.enabled)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func seoRow(_ label: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.dsBody)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

// ---------- MD 사용법 시트 ----------
struct MarkdownHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("마크다운 사용법").font(.headline)
                Spacer()
                Button("닫기") { dismiss() }.controlSize(.small)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("기본 문법") {
                        row("굵게", "**텍스트**")
                        row("기울임", "*텍스트*")
                        row("취소선", "~~텍스트~~")
                        row("제목", "# ~ ######  (제목 뒤 공백 필수)")
                        row("목록", "- 항목 / 1. 항목")
                        Text("2단 목록: 1단 항목 아래에 공백 2칸 + - 항목 (최대 4단) — 공백 4칸이면 3단")
                            .font(.caption).foregroundStyle(.secondary)
                        row("인용", "> 인용문")
                        row("코드", "`코드` / ```블록```")
                        row("링크", "[텍스트](https://...)")
                        row("이미지", "![설명](https://.../이미지.png)")
                        row("가로선", "---")
                    }
                    section("유튜브 영상") {
                        row("기본", "[youtube:VIDEO_ID]")
                        row("사이즈", "[youtube:VIDEO_ID width=800 height=450]")
                        row("자동재생", "[youtube:VIDEO_ID autoplay=1]")
                        row("시작 시간", "[youtube:VIDEO_ID start=90]  (90초부터)")
                        row("조합", "[youtube:VIDEO_ID width=800 height=450 autoplay=1 start=90]")
                        Text("URL로도 가능: [youtube:https://youtube.com/watch?v=ID]")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    section("이미지 (옵션)") {
                        row("기본", "[img:https://.../이미지.png]")
                        row("크기 조절", "[img:URL width=400] — 400~800px 권장 (px 단위)")
                        row("크기+캡션", "[img:URL width=600 caption=설명]")
                        row("가운데 정렬", "[img:URL align=center] — 이미지만 중앙 정렬")
                        row("표준 문법", "![설명](URL) — 크기 조절 불가")
                    }
                    section("가운데 정렬 (T-26)") {
                        row("블록 정렬", "[center] … [/center] — 안의 텍스트·이미지 모두 중앙 정렬")
                        Text("[center] 안에는 제목/문단/리스트/이미지/테이블 모두 사용 가능")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    section("동영상 (MP4)") {
                        row("기본", "[video:https://.../video.mp4]")
                        row("사이즈", "[video:https://.../video.mp4 width=640]")
                        row("자동재생", "[video:https://.../video.mp4 autoplay=1]")
                    }
                    section("앱 카드 (T-20)") {
                        row("위치 지정", "[app] … [/app] — 등록한 앱 순서대로")
                        row("앱 직접 지정", "[app:https://apps.apple.com/...] — App Store URL")
                        row("홈페이지 지정", "[app:https://iterm2.com]")
                        Text("저장 시 App Store 정보가 자동으로 채워집니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    section("폰트/색상 (HTML 인라인)") {
                        row("색상", "<span style=\"color:red\">빨간 글씨</span>")
                        row("색상+크기", "<font color=\"red\" size=\"4\">큰 빨간 글씨</font>")
                        Text("허용 속성: color / background-color / font-size / font-family / font-weight")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        }
        .padding(16)
        .frame(width: 560, height: 520)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.bold()).foregroundStyle(.secondary)
            content()
        }
    }

    private func row(_ label: String, _ code: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            Text(code).font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

}

// ---------- 이미지 삽입 시트 (업로드 + 목록 + 선택 삽입, T-08) ----------
// T-30: 이미지 선택 모드 — insert(본문 [img:URL] 삽입) / cover(커버 이미지 지정)
enum ImagePickerMode {
    case insert
    case cover
}

struct ImagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let token: String?
    let mode: ImagePickerMode
    let onInsert: (String) -> Void
    let onUploaded: (String) -> Void
    let onSelect: ((String) -> Void)? // T-30: cover 모드 — 선택/업로드한 이미지 URL을 커버로 지정

    @State private var images: [APIClient.UploadItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var urlInput = ""
    @State private var captionInput = ""
    @State private var sortBy = "latest"
    @State private var busy = false
    @State private var confirmDelete: APIClient.UploadItem?
    @State private var editingCaption: APIClient.UploadItem?
    @State private var captionText = ""

    enum SortOption: String, CaseIterable, Identifiable {
        case latest = "최신순"
        case name = "이름순"
        case size = "크기순"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(mode == .cover ? "커버 이미지 선택" : "이미지 삽입").font(.title3.bold())
                Spacer()
                Button("닫기") { dismiss() }.controlSize(.small)
            }

            // 상단: 파일 선택 / URL 입력
            HStack(spacing: 8) {
                Button("파일 선택…") { pickImageFile() }
                    .buttonStyle(.bordered)
                    .help("로컬 이미지 업로드 (최대 5MB)")
                    .disabled(busy)
                TextField("https://.../이미지.png", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { insertURLImage() }
                Button("URL로 삽입") { insertURLImage() }
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
            }
            HStack {
                // T-30: cover 모드에서는 캡션 불필요 (선택 즉시 커버 지정)
                if mode == .insert {
                    TextField("캡션 (선택)", text: $captionInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                }
                Spacer()
                Picker("정렬", selection: $sortBy) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading || busy)
                if busy {
                    ProgressView().controlSize(.small)
                }
            }

            // 목록
            Group {
                if isLoading {
                    ProgressView("이미지 목록 불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ErrorState(message: errorMessage) { Task { await load() } }
                } else if images.isEmpty {
                    EmptyState(
                        icon: "photo.on.rectangle.angled",
                        title: "업로드된 이미지가 없습니다",
                        subtitle: "위 '파일 선택…'으로 첫 이미지를 올려 보세요"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                            ForEach(sortedImages) { item in
                                imageCell(item)
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // T-30: cover 모드 — 클릭하면 커버로 지정됨
            Text(mode == .cover
                ? "클릭하면 커버 이미지로 지정됩니다. 권장 크기 1600×900 (16:9) — 목록·홈 배너·공유 카드에 표시됩니다."
                : "클릭하면 본문에 [img:URL]로 삽입됩니다. 크기는 [img:URL width=400~800]로 조절할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 600, height: 480)
        .task { await load() }
        .confirmationDialog("이 이미지를 삭제할까요?", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        ), titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if let item = confirmDelete {
                    Task { await delete(item) }
                }
            }
            Button("취소", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("삭제한 이미지는 복구할 수 없습니다.")
        }
        .alert("캡션 수정", isPresented: Binding(
            get: { editingCaption != nil },
            set: { if !$0 { editingCaption = nil } }
        )) {
            TextField("캡션", text: $captionText)
            Button("저장") {
                if let item = editingCaption {
                    Task { await saveCaption(item) }
                }
            }
            Button("취소", role: .cancel) { editingCaption = nil }
        }
        .onAppear { DebugLogger.info("Upload", mode == .cover ? "커버 이미지 선택 시트 표시됨" : "이미지 삽입 시트 표시됨") }
    }

    private var sortedImages: [APIClient.UploadItem] {
        switch sortBy {
        case "name":
            return images.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case "size":
            return images.sorted { $0.size > $1.size }
        default:
            return images // 서버가 최신순 정렬
        }
    }

    private func imageCell(_ item: APIClient.UploadItem) -> some View {
        let fullURL = URL(string: item.url, relativeTo: APIClient.baseURL) ?? URL(string: item.url) ?? APIClient.baseURL
        return Button {
            insert(item)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                AsyncImage(url: fullURL) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.15))
                        .overlay(ProgressView().controlSize(.small))
                }
                .frame(height: 90)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                Text(item.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let caption = item.caption, !caption.isEmpty {
                    Label(caption, systemImage: "text.bubble")
                        .font(.caption2)
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(item.sizeLabel)
                    if let post = item.postTitle {
                        Label(post, systemImage: "doc.text")
                            .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 2) {
                    Button {
                        captionText = item.caption ?? ""
                        editingCaption = item
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("캡션 수정")
                    Button {
                        confirmDelete = item
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary, Color.dsDanger.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .help("삭제")
                }
                .padding(6)
            }
        }
        .buttonStyle(.plain)
    }

    private func insert(_ item: APIClient.UploadItem) {
        // T-30: cover 모드 — URL만 전달 (커버 지정)
        if mode == .cover {
            onSelect?(item.url)
            DebugLogger.info("Upload", "커버 이미지 선택 (\(item.name))")
            dismiss()
            return
        }
        let typed = captionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let dbCaption = item.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let caption = typed.isEmpty ? dbCaption : typed
        onInsert(caption.isEmpty ? "[img:\(item.url)]" : "[img:\(item.url) caption=\(caption)]")
        DebugLogger.info("Upload", "이미지 삽입 (\(item.name))")
        // T-48: 삽입 모드는 시트 유지 — 연속 삽입 (닫기 버튼으로 닫음), 캡션만 초기화
        captionInput = ""
        urlInput = ""
    }

    private func insertURLImage() {
        let url = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        // T-30: cover 모드 — URL만 전달 (커버 지정)
        if mode == .cover {
            onSelect?(url)
            DebugLogger.info("Upload", "커버 이미지 선택 (URL: \(url))")
            dismiss()
            return
        }
        let caption = captionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        onInsert(caption.isEmpty ? "[img:\(url)]" : "[img:\(url) caption=\(caption)]")
        DebugLogger.info("Upload", "URL 이미지 삽입")
        // T-48: 삽입 모드는 시트 유지 — 연속 삽입
        captionInput = ""
        urlInput = ""
    }

    private func pickImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, UTType(filenameExtension: "webp") ?? .png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "업로드할 이미지를 선택하세요 (최대 5MB)"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            busy = true
            Task {
                do {
                    let uploaded = try await APIClient.uploadImage(token: token, fileURL: url)
                    // T-30: cover 모드 — 업로드 즉시 커버로 지정
                    if mode == .cover {
                        onSelect?(uploaded)
                        DebugLogger.info("Upload", "업로드 + 커버 지정 완료 (\(url.lastPathComponent))")
                        dismiss()
                        return
                    }
                    let caption = captionInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    onUploaded(caption.isEmpty ? "[img:\(uploaded)]" : "[img:\(uploaded) caption=\(caption)]")
                    DebugLogger.info("Upload", "업로드 + 삽입 완료 (\(url.lastPathComponent))")
                    dismiss()
                } catch {
                    let e = error as? APIError
                    errorMessage = "업로드 실패: \(e?.message ?? error.localizedDescription)"
                    DebugLogger.error("Upload", "업로드 실패: \(e?.code ?? "unknown")")
                    busy = false
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            images = try await APIClient.fetchUploads(token: token)
            DebugLogger.info("Upload", "이미지 목록 로드 (\(images.count)개)")
        } catch {
            let e = error as? APIError
            errorMessage = "목록을 불러오지 못했습니다: \(e?.message ?? error.localizedDescription)"
            DebugLogger.error("Upload", "목록 로드 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    private func delete(_ item: APIClient.UploadItem) async {
        busy = true
        do {
            let name = item.url.replacingOccurrences(of: "/uploads/", with: "")
            try await APIClient.deleteUpload(token: token, name: name)
            images.removeAll { $0.id == item.id }
            DebugLogger.info("Upload", "이미지 삭제 완료 (\(item.name))")
        } catch {
            let e = error as? APIError
            errorMessage = "삭제 실패: \(e?.message ?? error.localizedDescription)"
            DebugLogger.error("Upload", "삭제 실패: \(e?.code ?? "unknown")")
        }
        busy = false
        confirmDelete = nil
    }

    private func saveCaption(_ item: APIClient.UploadItem) async {
        busy = true
        do {
            let name = item.url.replacingOccurrences(of: "/uploads/", with: "")
            try await APIClient.updateUploadCaption(token: token, name: name, caption: captionText)
            if let i = images.firstIndex(where: { $0.id == item.id }) {
                images[i] = APIClient.UploadItem(
                    url: item.url, name: item.name, size: item.size, date: item.date,
                    caption: captionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : captionText,
                    postTitle: item.postTitle
                )
            }
            DebugLogger.info("Upload", "캡션 수정 완료 (\(item.name))")
        } catch {
            let e = error as? APIError
            errorMessage = "캡션 수정 실패: \(e?.message ?? error.localizedDescription)"
            DebugLogger.error("Upload", "캡션 수정 실패: \(e?.code ?? "unknown")")
        }
        busy = false
        editingCaption = nil
    }
}

extension Notification.Name {
    // T-45: 설정이 Settings scene으로 이동 — navigateToSettings 발행처 제거 (에디터는 showSettingsWindow 표준 셀렉터 사용)
    // T-26: 시드 에디터 등 외부 경로 저장 성공 → 글 관리 목록 갱신 알림
    static let postSaved = Notification.Name("MacCanDo.postSaved")
    // T-35: ⌘N 새 글 요청 (메뉴 바 → ContentView)
    static let newPostRequested = Notification.Name("MacCanDo.newPostRequested")
}