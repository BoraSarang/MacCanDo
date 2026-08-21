// [FEATURE] AI 도우미 — 글쓰기 참고용 제품 소개 생성 (사용자 요청)
// 프로그램 이름 또는 웹사이트 URL 입력 → Gemini가 소개/비교/장점/특이사항/추천 MD 생성
// 참고용 데이터 — 복사해서 에디터에서 수정해 사용
import SwiftUI
import AppKit
import WebKit

struct AssistantView: View {
    let seedQuery: String? // T-72: 맥 소식에서 넘어온 초기 쿼리 (자동 조회)

    @State private var query = ""
    @State private var compareWith = ""
    @State private var result = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cacheHit = false
    @State private var viewMode = "원문"
    // T-57 수정: 맥 소식은 사이드바 독립 탭(T-46)으로 분리 — 도우미 창의 segmented 제거
    @State private var savedEntries: [ReferenceEntry] = [] // T-26: 로컬 저장 리스트
    @State private var selectedID: String?
    // T-71: 커버 이미지 (AI 생성 / 업로드 이미지에서 수동 선택)
    @State private var showCoverGen = false
    @State private var coverImagePromptText = ""
    @State private var generatingCover = false
    @State private var generatedCoverData: Data?
    @State private var coverError: String?
    @State private var coverURL: String?
    @State private var coverAltText = "" // T-78: v2.13 — 커버 alt 설명 (클립보드 복사)
    @State private var generatingCoverAlt = false
    @State private var coverAltError: String?
    @State private var showCoverPicker = false
    // T-71: 본문 이미지 (AI 생성 / 업로드 이미지에서 수동 선택)
    @State private var showBodyGen = false
    @State private var generatingBodyImage = false
    @State private var generatedBodyImageData: Data?
    @State private var bodyImageError: String?
    @State private var bodyImageAltText = "" // T-78: v2.13 — 본문 이미지 alt 설명 (비전 AI)
    @State private var generatingBodyImageAlt = false
    @State private var bodyImageAltError: String?
    @State private var bodyImagePromptText = ""
    @State private var showBodyPicker = false
    // T-83: v2.14 — 이미지 프롬프트 생성 (복사 전용)
    @State private var showImagePromptGen = false
    @State private var imagePromptItems: [GeminiService.ImagePromptItem] = []
    @State private var generatingImagePrompts = false
    @State private var imagePromptError: String?
    // T-71: 게시글 초안(DRAFT) 등록
    @State private var registeringDraft = false
    @State private var draftError: String?
    @State private var registeredPostID: String?
    @State private var registeredTitle = ""

    init(seedQuery: String? = nil) {
        self.seedQuery = seedQuery
    }

    // 관리자 토큰 (UserDefaults "apiToken" — AuthStore 저장 값)
    private var token: String? {
        UserDefaults.standard.string(forKey: "apiToken")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI 도우미", systemImage: "wand.and.stars")
                    .font(.title3.bold())
                Spacer()
                Text("참고용 자료 — 복사해서 글에 활용하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            referenceView
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 520)
        .onAppear {
            ReferenceStore.open()
            savedEntries = ReferenceStore.loadAll()
            DebugLogger.info("Feature", "AI 도우미 창 표시됨 (저장된 참고 자료 \(savedEntries.count)건)")
            // T-72: 맥 소식 경유 시 시드 쿼리 자동 조회
            if let seedQuery, !seedQuery.isEmpty, query.isEmpty {
                query = seedQuery
                Task { await search() }
            }
        }
        // T-71: AI 커버/본문 이미지 생성 + 수동 선택 (업로드 이미지)
        .sheet(isPresented: $showCoverGen) { coverGenSheet }
        .sheet(isPresented: $showBodyGen) { bodyGenSheet }
        .sheet(isPresented: $showImagePromptGen) { imagePromptSheet }
        .sheet(isPresented: $showCoverPicker) {
            ImagePickerSheet(
                token: token,
                mode: .cover,
                onInsert: { _ in },
                onUploaded: { _ in },
                onSelect: { url in
                    coverURL = url
                    showCoverPicker = false
                    DebugLogger.info("Assistant", "[FEATURE] 커버 이미지 수동 지정 (\(url))")
                }
            )
        }
        .sheet(isPresented: $showBodyPicker) {
            ImagePickerSheet(
                token: token,
                mode: .insert,
                onInsert: { markdown in
                    result += "\n\n" + markdown
                    showBodyPicker = false
                    DebugLogger.info("Assistant", "[FEATURE] 본문 이미지 수동 삽입 (링크)")
                },
                onUploaded: { url in
                    result += "\n\n[img:\(url)]"
                    showBodyPicker = false
                    DebugLogger.info("Assistant", "[FEATURE] 본문 이미지 수동 삽입 url=\(url)")
                },
                onSelect: nil
            )
        }
    }

    // ---------- 참고 자료 (기존 기능) ----------
    // T-26: 좌측 저장 리스트 + 우측 검색/결과
    private var referenceView: some View {
        HStack(alignment: .top, spacing: 12) {
            savedListView
            rightPanel
        }
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // T-71: 입력 textbox (프로그램 이름 / 웹사이트 URL / 설명 여러 줄)
            VStack(alignment: .leading, spacing: 4) {
                Text("프로그램 이름 / 웹사이트 URL / 설명")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextEditor(text: $query)
                    .font(.body)
                    .frame(minHeight: 52, maxHeight: 96)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.dsSurfaceHover))
                    .disabled(isLoading)
            }
            HStack(spacing: 8) {
                TextField("비교 대상 (선택 — 비우면 AI가 유사 프로그램 선정)", text: $compareWith)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
                Button("조회") { Task { await search() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if cacheHit {
                    Label("캐시 표시됨", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.dsSuccess)
                    Button("재조회") { Task { await search(forceRefresh: true) } }
                        .controlSize(.small)
                }
            }
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("정보 조회 및 생성 중…").font(.dsBody).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color.dsWarning)
                    Button("다시 시도") { Task { await search() } }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if !result.isEmpty {
                HStack {
                    Picker("", selection: $viewMode) {
                        Text("원문 (MD)").tag("원문")
                        Text("미리보기").tag("미리보기")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    Spacer()
                    // T-56: ⌘C 충돌 제거 — 시스템 복사(⌘C)와 중복되어 텍스트 선택 복사 불가가 되던 문제
                    Button("복사") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                        DebugLogger.info("Assistant", "도우미 결과 복사됨")
                    }
                }
                // T-71: 글 작성 액션 바 (커버/본문 이미지 + 게시글 초안 등록)
                HStack(spacing: 8) {
                    Button {
                        showCoverGen = true
                    } label: {
                        Label(coverURL == nil ? "커버 이미지" : "커버 변경", systemImage: coverURL == nil ? "photo.badge.plus" : "photo.fill")
                    }
                    .controlSize(.small)
                    .disabled(registeringDraft)
                    if coverURL != nil {
                        Text("커버 지정됨").font(.caption2).foregroundStyle(Color.dsSuccess)
                    }
                    Button { showBodyGen = true } label: {
                        Label("본문 이미지", systemImage: "photo.on.rectangle.angled")
                    }
                    .controlSize(.small)
                    .disabled(registeringDraft)
                    Button { showImagePromptGen = true } label: {
                        Label("이미지 프롬프트", systemImage: "text.below.photo")
                    }
                    .controlSize(.small)
                    .disabled(registeringDraft)
                    Spacer()
                    if registeredPostID != nil {
                        Text("초안 등록 완료").font(.caption2).foregroundStyle(Color.dsSuccess)
                        Button("편집기에서 열기") { openInEditor() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    } else {
                        Button {
                            Task { await registerDraft() }
                        } label: {
                            Label(registeringDraft ? "등록 중…" : "게시글 초안으로 등록", systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(registeringDraft)
                    }
                }
                if let draftError {
                    Label(draftError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Color.dsDanger)
                }
                Group {
                    if viewMode == "원문" {
                        ScrollView {
                            Text(result)
                                .font(.dsMono)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                    } else {
                        AssistantPreview(html: assistantHTML(result))
                    }
                }
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.dsSurface))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("프로그램 이름이나 웹사이트 주소를 입력하면\n소개·비교·장점·특이사항·추천 이유를 생성합니다.\n조회 결과는 자동 저장되어 왼쪽 목록에서 다시 볼 수 있고,\n게시글 초안으로 등록해 편집기에서 이어서 수정할 수 있습니다.")
                        .font(.dsBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
    }

    // ---------- 저장된 참고 자료 리스트 (T-26) ----------
    private var savedListView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("저장된 자료")
                    .font(.caption.bold())
                Text("\(savedEntries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if savedEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("조회 결과가\n자동 저장됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(savedEntries) { entry in
                            savedRow(entry)
                        }
                    }
                }
            }
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.dsSurface))
    }

    private func savedRow(_ entry: ReferenceEntry) -> some View {
        HStack(spacing: 4) {
            Button {
                selectSaved(entry)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.query)
                        .font(.dsBody)
                        .lineLimit(1)
                    Text("\(entry.createdAt.formatted(date: .abbreviated, time: .shortened))\(entry.compareWith.isEmpty ? "" : " vs \(entry.compareWith)")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("이 결과 불러오기 (AI 재호출 없음)")
            Button {
                ReferenceStore.delete(id: entry.id)
                savedEntries.removeAll { $0.id == entry.id }
                if selectedID == entry.id {
                    selectedID = nil
                    result = ""
                    viewMode = "원문"
                }
                DebugLogger.info("Reference", "리스트에서 삭제 (\(entry.query))")
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("삭제")
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 6).fill(selectedID == entry.id ? Color.dsAccent.opacity(0.15) : Color.clear))
    }

    // 저장된 항목 선택 → AI 재호출 없이 DB 결과 표시
    private func selectSaved(_ entry: ReferenceEntry) {
        selectedID = entry.id
        query = entry.query
        compareWith = entry.compareWith
        result = entry.result
        errorMessage = nil
        cacheHit = false
        DebugLogger.info("Reference", "저장 자료 불러옴 (\(entry.query))")
    }

    // T-56: 미리보기 다크모드 지원 (prefers-color-scheme 미디어 쿼리)
    private func assistantHTML(_ md: String) -> String {
        "<html><head><meta charset=\"utf-8\"><style>body{font-family:-apple-system,sans-serif;padding:16px;line-height:1.7;color:#222}img{max-width:100%}pre{background:#f4f4f4;padding:8px;border-radius:6px}blockquote{border-left:3px solid #ccc;margin:0;padding-left:12px;color:#555}@media (prefers-color-scheme: dark){body{color:#e5e5e5}pre{background:#2a2a2a;color:#e5e5e5;border:1px solid #3a3a3a}blockquote{border-left-color:#555;color:#9a9a9a}code{color:#e5e5e5}a{color:#7fb4ff}}</style></head><body>\(MarkdownRenderer.render(md))</body></html>"
    }

    private func search(forceRefresh: Bool = false) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        cacheHit = false
        // T-71: 새 조회 시 이전 커버/초안 상태 초기화
        coverURL = nil
        registeredPostID = nil
        registeredTitle = ""
        draftError = nil
        do {
            // URL이면 페이지 fetch (실패 시 이름 기반 폴백)
            var urlContent: String?
            if q.lowercased().hasPrefix("http") {
                do {
                    urlContent = try await GeminiService.fetchURLText(q)
                    DebugLogger.info("Assistant", "URL fetch 성공 (\(String(q.prefix(40)))) — \(urlContent?.count ?? 0)자")
                } catch {
                    DebugLogger.warn("Assistant", "URL fetch 실패 → 이름 기반 폴백: \(error.localizedDescription)")
                }
            }
            let compare = compareWith.trimmingCharacters(in: .whitespacesAndNewlines)
            let (text, hit) = try await GeminiService.generateProductGuide(
                query: q,
                compareWith: compare.isEmpty ? nil : compare,
                urlContent: urlContent,
                forceRefresh: forceRefresh
            )
            result = text
            cacheHit = hit
            // T-26: 결과 자동 저장 (같은 쿼리면 갱신) — 리스트에서 재사용 가능
            if let saved = ReferenceStore.save(query: q, compareWith: compare, result: text) {
                savedEntries = ReferenceStore.loadAll()
                selectedID = saved.id
            }
            DebugLogger.info("Assistant", "도우미 생성 완료 (캐시: \(hit ? "hit" : "miss"), 저장됨)")
        } catch {
            let e = error as? APIError
            errorMessage = e?.message ?? error.localizedDescription
            DebugLogger.error("Assistant", "도우미 실패: \(e?.code ?? "unknown")")
        }
        isLoading = false
    }

    // ---------- T-71: AI 커버 이미지 시트 (EditorView imageGenSheet 패턴 재사용) ----------
    private var coverGenSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI 커버 이미지 생성").font(.title3.bold())
                Spacer()
                Text(GeminiService.chainLabel(for: .coverImage)).font(.caption2).foregroundStyle(.secondary)
            }
            Text("글의 커버(대표) 이미지를 만듭니다. [커버로 사용]을 누르면 업로드되어 게시글 초안 등록에 반영됩니다. 업로드된 이미지에서 직접 고를 수도 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $coverImagePromptText)
                .font(.body)
                .frame(minHeight: 70)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.dsSurfaceHover))
            HStack {
                Button("초기화") { coverImagePromptText = coverPrompt() }
                    .buttonStyle(.link)
                    .controlSize(.small)
                Spacer()
                if let data = generatedCoverData, let ns = NSImage(data: data) {
                    Text("\(Int(ns.size.width))×\(Int(ns.size.height))").font(.caption2).foregroundStyle(.secondary)
                }
                Button("다시 생성") {
                    Task { await generateCover(prompt: coverImagePromptText) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(generatingCover || generatedCoverData == nil || coverImagePromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Group {
                if generatingCover {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("이미지 생성 중… (보통 10~30초)").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else if let data = generatedCoverData, let ns = NSImage(data: data) {
                    Image(nsImage: ns)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dsSurfaceHover))
                } else {
                    Rectangle()
                        .fill(Color.dsSurface)
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .overlay(Text("생성 결과가 여기에 표시됩니다").font(.caption).foregroundStyle(.secondary))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            if let err = coverError {
                Text(err).font(.caption).foregroundStyle(Color.dsDanger)
            }
            // T-78: v2.13 — 커버 alt 설명 → 클립보드
            if generatedCoverData != nil {
                Divider()
                HStack(alignment: .top, spacing: 8) {
                    Button(generatingCoverAlt ? "설명 생성 중…" : "alt 설명 생성 → 클립보드") {
                        Task { await generateCoverAlt() }
                    }
                    .controlSize(.small)
                    .disabled(generatingCoverAlt)
                    if !coverAltText.isEmpty {
                        Text(coverAltText).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        Button("지우기") { coverAltText = "" }.controlSize(.small).buttonStyle(.link)
                    }
                }
                if let coverAltError {
                    Text(coverAltError).font(.caption).foregroundStyle(Color.dsDanger)
                }
            }
            HStack {
                Button("업로드 이미지에서 선택") {
                    showCoverGen = false
                    showCoverPicker = true
                }
                .controlSize(.small)
                Spacer()
                Button("취소") { showCoverGen = false }.keyboardShortcut(.cancelAction)
                Button("이 프롬프트로 생성") {
                    Task { await generateCover(prompt: coverImagePromptText) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(generatingCover || coverImagePromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("커버로 사용") {
                    Task { await applyCover() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(generatingCover || generatedCoverData == nil)
            }
        }
        .padding(20)
        .frame(width: 500, height: 520)
    }

    // ---------- T-71: AI 본문 이미지 시트 (EditorView bodyImageGenSheet 패턴 재사용) ----------
    private var bodyGenSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI 본문 이미지 생성").font(.title3.bold())
                Spacer()
                Text(GeminiService.chainLabel(for: .bodyImage)).font(.caption2).foregroundStyle(.secondary)
            }
            Text("본문에 넣을 이미지를 만듭니다. [본문에 삽입]을 누르면 업로드되어 [img:URL]이 결과 끝에 추가됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $bodyImagePromptText)
                .font(.body)
                .frame(minHeight: 70)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.dsSurfaceHover))
            HStack {
                Button("초기화") { bodyImagePromptText = bodyPrompt() }
                    .buttonStyle(.link)
                    .controlSize(.small)
                Spacer()
                if let data = generatedBodyImageData, let ns = NSImage(data: data) {
                    Text("\(Int(ns.size.width))×\(Int(ns.size.height))").font(.caption2).foregroundStyle(.secondary)
                }
                Button("다시 생성") {
                    Task { await generateBodyImage(prompt: bodyImagePromptText) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(generatingBodyImage || generatedBodyImageData == nil || bodyImagePromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Group {
                if generatingBodyImage {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("이미지 생성 중… (보통 10~30초)").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else if let data = generatedBodyImageData, let ns = NSImage(data: data) {
                    Image(nsImage: ns)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dsSurfaceHover))
                } else {
                    Rectangle()
                        .fill(Color.dsSurface)
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .overlay(Text("생성 결과가 여기에 표시됩니다").font(.caption).foregroundStyle(.secondary))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            if let err = bodyImageError {
                Text(err).font(.caption).foregroundStyle(Color.dsDanger)
            }
            // T-78: v2.13 — 본문 이미지 alt 설명 생성 (NVIDIA 비전 AI, [img:URL alt="…"] 연동)
            if generatedBodyImageData != nil {
                Divider()
                HStack(alignment: .top, spacing: 8) {
                    Button(generatingBodyImageAlt ? "설명 생성 중…" : "alt 설명 생성 (비전 AI)") {
                        Task { await generateBodyImageAlt() }
                    }
                    .controlSize(.small)
                    .disabled(generatingBodyImageAlt)
                    if !bodyImageAltText.isEmpty {
                        Text(bodyImageAltText).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                        Button("지우기") { bodyImageAltText = "" }.controlSize(.small).buttonStyle(.link)
                    }
                }
                if let bodyImageAltError {
                    Text(bodyImageAltError).font(.caption).foregroundStyle(Color.dsDanger)
                }
            }
            HStack {
                Button("업로드 이미지에서 선택") {
                    showBodyGen = false
                    showBodyPicker = true
                }
                .controlSize(.small)
                Spacer()
                Button("취소") { showBodyGen = false }.keyboardShortcut(.cancelAction)
                Button("이 프롬프트로 생성") {
                    Task { await generateBodyImage(prompt: bodyImagePromptText) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(generatingBodyImage || bodyImagePromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("본문에 삽입") {
                    Task { await applyBodyImage() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(generatingBodyImage || generatedBodyImageData == nil)
            }
        }
        .padding(20)
        .frame(width: 500, height: 520)
    }

    // T-71: 초안 제목 — 입력 첫 줄 (프로그램 이름)
    private func titleForDraft() -> String {
        let first = query.split(separator: "\n").first.map(String.init) ?? query
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // T-71: 커버 프롬프트 자동 구성 (제목+결과 요약 기반)
    private func coverPrompt() -> String {
        let bodyExcerpt = String(result.replacingOccurrences(of: #"[\[\]]"#, with: " ", options: .regularExpression).prefix(300))
        return """
        다음 글의 커버(대표) 이미지를 만들어 주세요: \(titleForDraft())
        본문 요약: \(bodyExcerpt)
        macOS 앱 큐레이션 블로그 썸네일, 깔끔하고 미니멀한 스타일, 텍스트 없이, 16:9 와이드 비율.
        """
    }

    // T-71: 본문 이미지 프롬프트 자동 구성
    private func bodyPrompt() -> String {
        let bodyExcerpt = String(result.replacingOccurrences(of: #"[\[\]]"#, with: " ", options: .regularExpression).prefix(200))
        return """
        다음 글의 본문에 어울리는 삽화를 만들어 주세요: \(titleForDraft())
        본문 요약: \(bodyExcerpt)
        macOS 앱 큐레이션 블로그 본문 이미지, 깔끔하고 미니멀한 스타일, 텍스트 없이.
        """
    }

    // T-71: AI 커버 이미지 생성 (업로드 없이 Data 유지 — "커버로 사용" 시 업로드)
    private func generateCover(prompt: String) async {
        generatingCover = true
        coverError = nil
        do {
            DebugLogger.info("Assistant", "[FEATURE] 커버 이미지 생성 시작 provider=\(GeminiService.chainLabel(for: .coverImage)) prompt=\(String(prompt.prefix(60)))…")
            let (imageData, provider) = try await GeminiService.generateImage(prompt: prompt, action: .coverImage)
            generatedCoverData = imageData
            DebugLogger.info("Assistant", "[FEATURE] 커버 이미지 생성 완료 provider=\(provider) bytes=\(imageData.count)")
        } catch {
            let e = error as? APIError
            coverError = e?.message ?? error.localizedDescription
            DebugLogger.error("Assistant", "커버 이미지 생성 실패: \(e?.code ?? "unknown")")
        }
        generatingCover = false
    }

    // T-71: 생성된 커버 업로드 → coverURL 지정 → 시트 닫기
    private func applyCover() async {
        guard let data = generatedCoverData else { return }
        do {
            let dir = FileManager.default.temporaryDirectory
            let fileURL = dir.appendingPathComponent("assist-cover-\(UUID().uuidString.prefix(8)).\(GeminiService.imageExtension(for: data))")
            try data.write(to: fileURL)
            let url = try await APIClient.uploadImage(token: token, fileURL: fileURL)
            try? FileManager.default.removeItem(at: fileURL)
            coverURL = url
            generatedCoverData = nil
            showCoverGen = false
            DebugLogger.info("Assistant", "[FEATURE] 커버 이미지 지정 완료 url=\(url)")
        } catch {
            let e = error as? APIError
            coverError = e?.message ?? error.localizedDescription
            DebugLogger.error("Assistant", "커버 업로드 실패: \(e?.code ?? "unknown")")
        }
    }

    // T-71: AI 본문 이미지 생성 (Data 유지 — "본문에 삽입" 시 업로드)
    private func generateBodyImage(prompt: String) async {
        generatingBodyImage = true
        bodyImageError = nil
        do {
            DebugLogger.info("Assistant", "[FEATURE] 본문 이미지 생성 시작 provider=\(GeminiService.chainLabel(for: .bodyImage)) prompt=\(String(prompt.prefix(60)))…")
            let (imageData, provider) = try await GeminiService.generateImage(prompt: prompt, action: .bodyImage)
            generatedBodyImageData = imageData
            DebugLogger.info("Assistant", "[FEATURE] 본문 이미지 생성 완료 provider=\(provider) bytes=\(imageData.count)")
        } catch {
            let e = error as? APIError
            bodyImageError = e?.message ?? error.localizedDescription
            DebugLogger.error("Assistant", "[ERROR] E-MAC-AI-1005 \(bodyImageError ?? "")")
        }
        generatingBodyImage = false
    }

    // T-78: v2.13 — 생성된 이미지 alt 설명 (본문: 텍스트 저장, 커버: 클립보드)
    private func generateBodyImageAlt() async {
        guard let data = generatedBodyImageData else { return }
        generatingBodyImageAlt = true
        bodyImageAltError = nil
        do {
            let alt = try await GeminiService.generateImageDescription(imageData: data)
            bodyImageAltText = alt
            DebugLogger.info("Assistant", "[FEATURE] 본문 이미지 alt 설명 생성 완료")
        } catch {
            let e = error as? APIError
            bodyImageAltError = e?.message ?? error.localizedDescription
            DebugLogger.error("Assistant", "[ERROR] E-MAC-AI-1007 \(bodyImageAltError ?? "")")
        }
        generatingBodyImageAlt = false
    }

    private func generateCoverAlt() async {
        guard let data = generatedCoverData else { return }
        generatingCoverAlt = true
        coverAltError = nil
        do {
            let alt = try await GeminiService.generateImageDescription(imageData: data)
            coverAltText = alt
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(alt, forType: .string)
            DebugLogger.info("Assistant", "[FEATURE] 커버 이미지 alt 설명 생성 완료 (클립보드 복사)")
        } catch {
            let e = error as? APIError
            coverAltError = e?.message ?? error.localizedDescription
            DebugLogger.error("Assistant", "[ERROR] E-MAC-AI-1007 \(coverAltError ?? "")")
        }
        generatingCoverAlt = false
    }

    // T-71: 생성된 본문 이미지 업로드 → [img:URL] 결과 끝에 추가 → 시트 닫기
    private func applyBodyImage() async {
        guard let data = generatedBodyImageData else { return }
        do {
            let dir = FileManager.default.temporaryDirectory
            let fileURL = dir.appendingPathComponent("assist-body-\(UUID().uuidString.prefix(8)).\(GeminiService.imageExtension(for: data))")
            try data.write(to: fileURL)
            let url = try await APIClient.uploadImage(token: token, fileURL: fileURL)
            try? FileManager.default.removeItem(at: fileURL)
            generatedBodyImageData = nil
            showBodyGen = false
            let alt = bodyImageAltText.trimmingCharacters(in: .whitespacesAndNewlines)
            let altClean = alt.replacingOccurrences(of: "\"", with: "")
            result += altClean.isEmpty ? "\n\n[img:\(url)]" : "\n\n[img:\(url) alt=\"\(altClean)\"]"
            bodyImageAltText = ""
            DebugLogger.info("Assistant", "[FEATURE] 본문 이미지 삽입 완료 url=\(url) alt=\(altClean.isEmpty ? "없음" : String(altClean.prefix(40)))")
        } catch {
            let e = error as? APIError
            bodyImageError = e?.message ?? error.localizedDescription
            DebugLogger.error("Assistant", "[ERROR] E-MAC-AI-1005 \(bodyImageError ?? "")")
        }
    }

    // T-71: 게시글 초안(DRAFT) 등록 — ReferenceStore 저장은 search()에서 이미 유지됨
    private func registerDraft() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            draftError = ErrorMessages.message("E-MAC-EDIT-1005")
            DebugLogger.warn("Assistant", "초안 등록 차단: 제목/본문 비어 있음")
            return
        }
        registeringDraft = true
        draftError = nil
        let title = titleForDraft()
        let input = PostInput(
            title: title,
            slug: nil,
            categoryIds: nil,
            tags: nil,
            contentType: "ARTICLE",
            bodyFormat: "MD",
            body: result,
            excerpt: nil,
            status: "DRAFT",
            seoMeta: nil,
            seriesId: nil,
            apps: nil,
            thumbnailUrl: coverURL
        )
        do {
            let saved: Post = try await APIClient.request("api/admin/posts", method: "POST", token: token, body: input)
            registeredPostID = saved.id
            registeredTitle = title
            draftError = nil
            DebugLogger.info("Assistant", "[FEATURE] 게시글 초안 등록 완료 postId=\(saved.id) title=\(title) thumbnail=\(coverURL ?? "없음")")
        } catch {
            let e = error as? APIError
            draftError = e?.message ?? error.localizedDescription
            DebugLogger.error("Assistant", "초안 등록 실패: \(e?.code ?? "unknown")")
        }
        registeringDraft = false
    }

    // T-83: v2.14 — 이미지 프롬프트 생성 시트 (복사 전용)
    private var imagePromptSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("이미지 프롬프트 생성").font(.title3.bold())
                Spacer()
                Text(GeminiService.chainLabel(for: .imagePrompts)).font(.caption2).foregroundStyle(.secondary)
            }
            Text("입력한 내용을 분석해 타 AI 이미지 생성기에 붙여넣을 영어 프롬프트 세트를 만듭니다. 각 항목을 복사해 ChatGPT·Midjourney 등에서 이미지를 생성하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(generatingImagePrompts ? "생성 중…" : "프롬프트 생성") {
                    Task { await generateImagePrompts() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(generatingImagePrompts || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            if generatingImagePrompts {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("내용을 분석해 프롬프트를 만드는 중… (보통 5~15초)").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else if !imagePromptItems.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(imagePromptItems) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(item.label).font(.subheadline.bold())
                                    Text(item.aspectRatio).font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.dsSurfaceHover)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    Spacer()
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(item.prompt, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.link)
                                    .controlSize(.small)
                                    .help("프롬프트 복사")
                                }
                                Text(item.prompt)
                                    .font(.caption)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.dsSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(4)
                }
                .frame(maxWidth: .infinity)
                if let err = imagePromptError {
                    Text(err).font(.caption).foregroundStyle(Color.dsDanger)
                }
                HStack {
                    Button("전체 복사") {
                        let text = imagePromptItems.map { "\($0.label) (\($0.aspectRatio))\n\($0.prompt)" }.joined(separator: "\n\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                    Button("닫기") { showImagePromptGen = false }.keyboardShortcut(.cancelAction)
                }
            } else if let err = imagePromptError {
                Text(err).font(.caption).foregroundStyle(Color.dsDanger)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Rectangle()
                    .fill(Color.dsSurface)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .overlay(Text("'프롬프트 생성'을 누르면 결과가 여기에 표시됩니다").font(.caption).foregroundStyle(.secondary))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .frame(width: 520, height: 560)
    }

    private func generateImagePrompts() async {
        generatingImagePrompts = true
        imagePromptError = nil
        imagePromptItems = []
        defer { generatingImagePrompts = false }
        do {
            let items = try await GeminiService.generateImagePrompts(title: titleForDraft(), body: result)
            imagePromptItems = items
        } catch {
            imagePromptError = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    // T-71: 등록된 초안을 편집기에서 이어서 수정
    private func openInEditor() {
        guard let id = registeredPostID else { return }
        let title = registeredTitle.isEmpty ? "AI 도우미 초안" : registeredTitle
        WindowManager.openEditor(
            key: id,
            title: "글 수정 — \(title)",
            rootView: EditorView(postId: id)
        )
        DebugLogger.info("Assistant", "[FEATURE] 편집기 열림 postId=\(id)")
    }
}

// 미리보기용 WKWebView (MarkdownRenderer 결과 표시)
struct AssistantPreview: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isInspectable = true
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
}