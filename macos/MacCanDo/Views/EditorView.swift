// [FEATURE] 게시글 에디터 — MD 전용 2칸 (좌: 마크다운 / 우: 실시간 HTML 미리보기) (T-10)
// 로컬 초안(SQLite) 3초 디바운스 자동저장, 삽입 툴바(커서 위치), MD 사용법 시트
import SwiftUI
import WebKit
import UniformTypeIdentifiers

// ---------- NSTextView 래퍼 (코드 에디터) ----------
struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    // 커서 위치 삽입용 — 마지막 활성 에디터 참조
    static weak var activeTextView: NSTextView?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextView {
        let tv = NSTextView()
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textContainerInset = NSSize(width: 12, height: 12)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.delegate = context.coordinator
        EditorTextView.activeTextView = tv
        return tv
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
        EditorTextView.activeTextView = nsView
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
struct PreviewWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isInspectable = true
        // 유튜브 iframe 임베드가 WKWebView 기본 UA에서 거부되는 문제 → Safari UA로 설정
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: APIClient.baseURL)
    }
}

// ---------- 에디터 메인 ----------
struct EditorView: View {
    let postId: String?
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)?
    var onClose: (() -> Void)?

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
    @State private var saveState = "초안 대기"
    @State private var previewHTML = ""
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var debounceTask: Task<Void, Never>?
    @State private var previewTask: Task<Void, Never>?
    // 삽입 다이얼로그
    @State private var showImagePicker = false
    @State private var showAppSheet = false // T-15: 앱 카드 시트
    @State private var appCards: [AppCardData] = []
    @State private var appURL = ""
    @State private var appFetching = false
    @State private var appFetchError: String?
    @State private var appMeta: AppStoreInfo?
    @State private var appHomepage = ""
    @State private var appDlLabel = ""
    @State private var appDlURL = ""
    @State private var showYoutubeDialog = false
    @State private var showVideoDialog = false
    @State private var insertURL = ""
    @State private var insertCaption = ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            editorBody
        }
        .frame(minWidth: 900, minHeight: 560)
        .task { await load() }
        .onChange(of: title) { scheduleAutoSave() }
        .onChange(of: content) {
            scheduleAutoSave()
            schedulePreview()
        }
        .onChange(of: status) { scheduleAutoSave() }
        .onAppear { DebugLogger.info("Editor", "에디터 표시됨 (\(postId ?? "새 글"))") }
        .alert("새 시리즈", isPresented: $showNewSeriesDialog) {
            TextField("시리즈 제목 (예: CleanMyMac 완벽 가이드)", text: $newSeriesTitle)
            Button("만들기") { Task { await createNewSeries() } }
            Button("취소", role: .cancel) {
                selectedSeriesId = seriesList.first?.id
            }
        } message: {
            Text("시리즈를 만들고 나서 글을 등록하면 시리즈에 묶입니다.")
        }
        .sheet(isPresented: $showHelp) { MarkdownHelpSheet() }
        .sheet(isPresented: $showSEO) { seoSheet }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerSheet(
                token: auth.token,
                onInsert: { markdown in
                    insertInline(markdown)
                },
                onUploaded: { url in
                    insertInline(url)
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
                    Text(err).font(.caption).foregroundStyle(.red)
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
            card.downloadLinks = [AppCardLink(id: UUID().uuidString, label: dl.isEmpty ? "다운로드" : dl)]
        }
        appCards.append(card)
        insertInline("[app]\n\n[/app]")
        appMeta = nil
        appURL = ""
        appHomepage = ""
        appDlLabel = ""
        appDlURL = ""
        showAppSheet = false
        DebugLogger.info("Editor", "앱 카드 삽입 (\(card.appName ?? "앱"), 총 \(appCards.count)개)")
    }

    // ---------- 헤더: 제목 + 도구 모음 ----------
    private var headerBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("제목", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.weight(.semibold))
                Text(saveState)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Markdown")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }
            HStack(spacing: 6) {
                Text("카테고리").font(.caption).foregroundStyle(.secondary)
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
                Spacer()
            }
            HStack(spacing: 8) {
                Picker("글 타입", selection: $contentType) {
                    Text("맥 앱").tag("ARTICLE")
                    Text("맥 팁").tag("TIP")
                    Text("맥 소식").tag("NEWS")
                    Text("페이지").tag("PAGE") // T-17: 정적 페이지 (About/Privacy 등)
                }
                .frame(width: 110)
                Picker("시리즈", selection: $selectedSeriesId) {
                    Text("없음").tag(String?.none)
                    ForEach(seriesList) { s in
                        Text(s.title).tag(String?.some(s.id))
                    }
                    Divider()
                    Text("＋ 새 시리즈…").tag(String?.some("__new__"))
                }
                .frame(width: 170)
                .onChange(of: selectedSeriesId) { _, v in
                    if v == "__new__" {
                        newSeriesTitle = ""
                        showNewSeriesDialog = true
                    }
                }
                TextField("태그 (쉼표 구분)", text: $tagsInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(width: 180)
                    .help("#태그 — 쉼표로 구분, 새 태그 자동 생성")
                TextField("주소(slug) — 비우면 자동 생성", text: $slug)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
                Spacer()
                // 삽입 툴바
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
                Divider().frame(height: 16)
                Button("미리보기 \(showPreview ? "숨김" : "보기")") {
                    showPreview.toggle()
                    DebugLogger.info("Editor", "미리보기 \(showPreview ? "열림" : "닫힘")")
                }
                .keyboardShortcut("p", modifiers: .command)
                Button("초안만 저장") { Task { await saveToServer(status: "DRAFT") } }
                    .disabled(isLoading)
                Button("발행") { Task { await saveToServer(status: "PUBLISHED") } }
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
        }
        .padding(12)
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
                    .foregroundStyle(.orange)
                Text(loadError)
                Button("닫기") { closeWindow() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                EditorTextView(text: $content)
                    .frame(minWidth: 320)
                if showPreview {
                    ScrollView {
                        PreviewWebView(html: previewHTML)
                            .frame(minWidth: 320, minHeight: 560)
                    }
                    .background(Color.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // ---------- 미리보기 HTML (300ms 디바운스 실시간) ----------
    private func buildPreviewHTML(_ md: String) -> String {
        let content = MarkdownRenderer.render(md, apps: appCards)
        let style = """
        <style>
          body { font-family: -apple-system, sans-serif; padding: 24px; line-height: 1.7; color: #1d1d1f; }
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
                appCards = post.apps ?? [] // T-15: 앱 카드 로드
                DebugLogger.info("Editor", "서버 글 로드 (\(postId), 앱 카드 \(appCards.count)개)")
            } catch {
                loadError = "게시글을 불러오지 못했습니다: \(error.localizedDescription)"
                return
            }
        }

        // 로컬 초안이 있으면 우선 복구 (오프라인/자동저장 대비)
        if let draft = DraftStore.load(postId: postId) {
            let hasContent = !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                DebugLogger.info("Editor", "로컬 초안 복구 (\(postId ?? "새 글"))")
            } else {
                DraftStore.clear(postId: postId)
                DebugLogger.debug("Editor", "빈 초안 폐기 (\(postId ?? "새 글"))")
            }
        }
    }

    // ---------- 자동저장 (3초 디바운스) ----------
    private func scheduleAutoSave() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            DraftStore.save(postId: postId, title: title, bodyFormat: "MD", body: content, status: status, slug: slug.isEmpty ? nil : slug, seoMeta: seoMeta)
            await MainActor.run { saveState = "초안 저장됨 \(Date().formatted(date: .omitted, time: .standard))" }
        }
    }

    // ---------- 삽입 툴바 ----------

    // 발행된 글을 웹에서 열기
    // AI 도우미 — 별도 창으로 열기 (참고 자료 생성, 복사해서 활용)
    private func openAssistant() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "AI 도우미"
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: AssistantView())
        win.center()
        win.makeKeyAndOrderFront(nil)
        DebugLogger.info("Editor", "AI 도우미 창 열림")
    }

    // 새 시리즈 생성 후 선택 (에디터 드롭다운)
    private func createNewSeries() async {
        let title = newSeriesTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            selectedSeriesId = seriesList.first?.id
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
            selectedSeriesId = seriesList.first?.id
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
            apps: appCards.isEmpty ? nil : appCards
        )
        do {
            let saved: Post
            if let postId {
                saved = try await APIClient.request("api/admin/posts/\(postId)", method: "PUT", token: auth.token, body: input)
            } else {
                saved = try await APIClient.request("api/admin/posts", method: "POST", token: auth.token, body: input)
            }
            DraftStore.clear(postId: postId)
            status = newStatus
            saveState = newStatus == "PUBLISHED" ? "발행 완료 ✅" : "저장 완료 ✅"
            DebugLogger.info("Editor", "서버 저장 완료 (\(newStatus))")
            onSaved?()
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
        saveState = "AI SEO 적용됨 ✨ (저장하면 웹 meta 태그에 반영)"
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
                        .foregroundStyle(.orange)
                    if seoError.contains("설정") {
                        Button("설정 열기") {
                            showSEO = false
                            NotificationCenter.default.post(name: .navigateToSettings, object: nil)
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

    // 대표 이미지 (og:image) 입력 — 본문 첫 이미지 자동 채움 + 수동 편집
    private func seoImageInput(_ suggested: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("대표 이미지 (og:image)").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
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
                        row("표준 문법", "![설명](URL) — 크기 조절 불가")
                    }
                    section("동영상 (MP4)") {
                        row("기본", "[video:https://.../video.mp4]")
                        row("사이즈", "[video:https://.../video.mp4 width=640]")
                        row("자동재생", "[video:https://.../video.mp4 autoplay=1]")
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
struct ImagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let token: String?
    let onInsert: (String) -> Void
    let onUploaded: (String) -> Void

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
                Text("이미지 삽입").font(.headline)
                Spacer()
                Button("닫기") { dismiss() }.controlSize(.small)
            }

            // 상단: 파일 선택 / URL 입력
            HStack(spacing: 8) {
                Button("파일 선택…") { pickImageFile() }
                    .disabled(busy)
                TextField("https://.../이미지.png", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                Button("URL로 삽입") { insertURLImage() }
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
            }
            HStack {
                TextField("캡션 (선택)", text: $captionInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
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
                    VStack(spacing: 10) {
                        Text(errorMessage).foregroundStyle(.orange)
                        Button("다시 시도") { Task { await load() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if images.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("업로드된 이미지가 없습니다\n'파일 선택…'으로 첫 이미지를 올려 보세요")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            Text("클릭하면 본문에 [img:URL]로 삽입됩니다. 크기는 [img:URL width=400~800]로 조절할 수 있습니다.")
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
        .onAppear { DebugLogger.info("Upload", "이미지 삽입 시트 표시됨") }
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
        let fullURL = URL(string: item.url, relativeTo: APIClient.baseURL)!
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
                    Text("💬 \(caption)")
                        .font(.caption2)
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(item.sizeLabel)
                    if let post = item.postTitle {
                        Text("· 📄 \(post)")
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
                            .foregroundStyle(.secondary, Color.red.opacity(0.3))
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
        let typed = captionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let dbCaption = item.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let caption = typed.isEmpty ? dbCaption : typed
        onInsert(caption.isEmpty ? "[img:\(item.url)]" : "[img:\(item.url) caption=\(caption)]")
        DebugLogger.info("Upload", "이미지 삽입 (\(item.name))")
        dismiss()
    }

    private func insertURLImage() {
        let url = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        let caption = captionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        onInsert(caption.isEmpty ? "[img:\(url)]" : "[img:\(url) caption=\(caption)]")
        DebugLogger.info("Upload", "URL 이미지 삽입")
        dismiss()
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
    static let navigateToSettings = Notification.Name("navigateToSettings")
}