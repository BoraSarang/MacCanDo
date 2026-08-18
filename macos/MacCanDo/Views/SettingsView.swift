// [FEATURE] 설정 — API 토큰 입력/저장/제거 (T-06)
// 토큰은 웹 /api/auth/token에서 발급 (관리자 로그인 후)
// T-54: v2.7.0 — SecureField(토큰/키) + 연결 테스트(api/categories) + 캐시 초기화 + 저장 후 필드 유지
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var inputToken = ""
    @State private var message = ""
    @State private var testingConnection = false
    @State private var testMessage: String?
    @State private var testIsError = false

    var body: some View {
        Form {
            Section("서버") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API 서버: \(APIClient.baseURL.absoluteString)")
                        .font(.dsMono)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("홈페이지 주소 (웹에서 보기)", text: $inputWebURL)
                            .font(.dsMono)
                            .textFieldStyle(.roundedBorder)
                        Button("저장") {
                            let url = inputWebURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard let u = URL(string: url), u.scheme != nil else {
                                webMessage = ErrorMessages.message("E-MAC-SET-1002")
                                return
                            }
                            UserDefaults.standard.set(url, forKey: "webURL")
                            inputWebURL = ""
                            webMessage = "저장되었습니다."
                            DebugLogger.info("Settings", "홈페이지 주소 저장 (\(url))")
                        }
                    }
                    if !webMessage.isEmpty {
                        Text(webMessage).font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                    }
                    Text("에디터의 '웹에서 보기' 버튼이 이 주소로 발행된 글을 엽니다. (기본: http://localhost:3000)")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("관리자 API 토큰") {
                if authStore.isAuthed {
                    Label("연결됨 (토큰 저장됨)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.dsSuccess)
                    // T-54: 연결 테스트 — api/categories 호출로 토큰 유효성 확인
                    HStack(spacing: 8) {
                        Button("연결 테스트") { testConnection() }
                            .disabled(testingConnection)
                        if testingConnection {
                            ProgressView().controlSize(.small)
                        }
                        Button("토큰 제거", role: .destructive) {
                            authStore.clear()
                            message = "토큰이 제거되었습니다."
                            DebugLogger.info("Settings", "토큰 제거됨")
                        }
                    }
                    if let testMessage {
                        Label(testMessage, systemImage: testIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.dsCaption)
                            .foregroundStyle(testIsError ? Color.dsDanger : Color.dsSuccess)
                    }
                } else {
                    SecureField("토큰 붙여넣기", text: $inputToken)
                        .font(.dsMono)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("저장") {
                            let t = inputToken.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else {
                                message = "토큰을 입력해 주세요."
                                return
                            }
                            authStore.save(t)
                            // T-54: 저장 후 필드 유지 (재입력 불편 제거)
                            message = "토큰이 저장되었습니다."
                            DebugLogger.info("Settings", "토큰 저장됨")
                        }
                        .keyboardShortcut(.defaultAction)
                        Button("토큰 발급 안내") {
                            if let url = URL(string: "\(APIClient.baseURL.absoluteString)/api/auth/token") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.small)
                    }
                }
                if !message.isEmpty {
                    Text(message).font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                }
                Text("① 웹에서 관리자 로그인 후 토큰 발급 버튼 → ② 응답의 token 값을 복사 → ③ 여기에 붙여넣기")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
            }

            Section("AI SEO (Gemini)") {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Gemini API 키", text: $inputGeminiKey)
                        .font(.dsMono)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.none)
                    HStack {
                        Button("저장") {
                            let k = inputGeminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !k.isEmpty else {
                                geminiMessage = "Gemini API 키를 입력해 주세요."
                                return
                            }
                            UserDefaults.standard.set(k, forKey: "geminiKey")
                            // T-54: 저장 후 필드 유지
                            geminiMessage = "키가 저장되었습니다."
                            DebugLogger.info("Settings", "Gemini 키 저장됨")
                        }
                        .keyboardShortcut(.defaultAction)
                        if GeminiService.hasKey {
                            Label("저장됨", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.dsSuccess)
                        }
                    }
                    if !geminiMessage.isEmpty {
                        Text(geminiMessage).font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                    }
                    Text("에디터의 'AI SEO' 버튼이 제목·설명·키워드·슬러그를 자동 생성합니다. 키는 https://aistudio.google.com/apikey 에서 발급 (무료).")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                    // T-19: 이미지 생성 공급자 선택
                    Divider()
                    Picker("이미지 생성 공급자", selection: Binding(
                        get: { GeminiService.imageGenProvider },
                        set: { newValue in
                            UserDefaults.standard.set(newValue.rawValue, forKey: "imageGenProvider")
                            imageGenMessage = "이미지 생성 공급자: \(newValue.label)"
                            DebugLogger.info("Settings", "이미지 생성 공급자 변경: \(newValue.rawValue)")
                        }
                    )) {
                        ForEach(GeminiService.ImageGenProvider.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    if !imageGenMessage.isEmpty {
                        Text(imageGenMessage).font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                    }
                    Text("시리즈 커버/글 썸네일의 AI 이미지 생성 공급자입니다. '자동'이면 Gemini를 사용합니다.")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                    // T-22: OpenRouter (Flux) 키 — 이미지 생성 공급자 선택과 연결
                    if GeminiService.imageGenProvider == .openrouter {
                        Divider()
                        TextField("OpenRouter API 키 (이미지 생성)", text: $inputOpenRouterKey)
                            .font(.dsMono)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("저장") {
                                let k = inputOpenRouterKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !k.isEmpty else {
                                    openRouterMessage = "OpenRouter API 키를 입력해 주세요."
                                    return
                                }
                                UserDefaults.standard.set(k, forKey: "openrouterKey")
                                // T-54: 저장 후 필드 유지
                                openRouterMessage = "키가 저장되었습니다."
                                DebugLogger.info("Settings", "OpenRouter 키 저장됨")
                            }
                            .keyboardShortcut(.defaultAction)
                            if !(UserDefaults.standard.string(forKey: "openrouterKey") ?? "").isEmpty {
                                Label("저장됨", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.dsSuccess)
                            }
                        }
                        if !openRouterMessage.isEmpty {
                            Text(openRouterMessage).font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                        }
                        Text("OpenRouter 이미지 생성(Gemini 3.1 Image)에 사용합니다. 키는 https://openrouter.ai/keys 에서 발급 후 크레딧 충전 필요 (402 시 충전 안내).")
                            .font(.dsCaption)
                            .foregroundStyle(.secondary)
                    }
                    let stats = GeminiService.cacheStats
                    let total = stats.hits + stats.misses
                    if total > 0 {
                        HStack(spacing: 6) {
                            Label("캐시 히트율", systemImage: "arrow.trianglehead.2.clockwise")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(Double(stats.hits) / Double(total) * 100))% (\(stats.hits)/\(total)회, 목표 70%)")
                                .font(.caption.monospaced())
                                .foregroundStyle(stats.hits * 10 >= total * 7 ? Color.dsSuccess : Color.dsWarning) // T-36
                        }
                    }
                    // T-54: AI SEO 캐시 초기화
                    HStack(spacing: 10) {
                        Button("캐시 초기화") {
                            DraftStore.clearSEOCache()
                            DraftStore.resetCacheStats()
                            cacheMessage = "AI SEO 캐시 \(DraftStore.seoCacheCount())건을 비웠습니다."
                            DebugLogger.info("Settings", "[FEATURE] AI SEO 캐시 초기화 완료")
                        }
                        .controlSize(.small)
                        if !cacheMessage.isEmpty {
                            Text(cacheMessage)
                                .font(.dsCaption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                    }
                    Text("SEO 자동 생성 결과를 저장한 캐시입니다. 캐시를 비우면 다음 요청에서 새로 생성합니다 (AI 비용 발생).")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("백업 / 복원") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button("백업 다운로드") { downloadBackup() }
                            .disabled(!authStore.isAuthed || backupBusy)
                        Button("복원…") { pickRestoreFile() }
                            .disabled(!authStore.isAuthed || backupBusy)
                        if backupBusy {
                            ProgressView().controlSize(.small)
                        }
                    }
                    if !backupMessage.isEmpty {
                        Text(backupMessage).font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                    }
                    Text("백업: 게시글·카테고리·댓글 전체를 JSON으로 저장합니다. 복원: 저장한 JSON을 다시 올립니다 (서버보다 최신 데이터만 반영, LWW).")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("동기화") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button("로컬 초안 → 서버 동기화") { syncDrafts() }
                            .disabled(!authStore.isAuthed || backupBusy)
                        if backupBusy {
                            ProgressView().controlSize(.small)
                        }
                    }
                    if !syncMessage.isEmpty {
                        Text(syncMessage).font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                    }
                    Text("앱이 오프라인일 때 로컬에 저장된 초안을 서버로 올립니다 (자동저장이 실패한 글, LWW — 서버가 최신이면 건너뜀).")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            DebugLogger.info("Settings", "설정 화면 표시됨")
            // T-54: 저장된 값 미리 채우기 (재입력 불편 제거)
            if let token = authStore.token, !token.isEmpty {
                inputToken = token
            }
            if let key = UserDefaults.standard.string(forKey: "geminiKey"), !key.isEmpty {
                inputGeminiKey = key
            }
            if let key = UserDefaults.standard.string(forKey: "openrouterKey"), !key.isEmpty {
                inputOpenRouterKey = key
            }
        }
    }

    @State private var inputGeminiKey = ""
    @State private var geminiMessage = ""
    @State private var inputOpenRouterKey = "" // T-22: Flux (OpenRouter) 키
    @State private var openRouterMessage = ""
    @State private var imageGenMessage = ""
    @State private var inputWebURL = ""
    @State private var webMessage = ""
    @State private var backupBusy = false
    @State private var backupMessage = ""
    @State private var syncMessage = ""
    @State private var cacheMessage = ""

    // T-54: 연결 테스트 — api/categories 호출로 토큰 유효성 + 서버 응답 확인
    private func testConnection() {
        testingConnection = true
        testMessage = nil
        Task {
            do {
                let cats: [PostCategory] = try await APIClient.request("api/categories", token: authStore.token)
                testMessage = "연결 성공 — 서버 응답 정상 (카테고리 \(cats.count)개)"
                testIsError = false
                DebugLogger.info("Settings", "[FEATURE] 연결 테스트 성공 (카테고리 \(cats.count)개)")
            } catch {
                let e = error as? APIError
                testMessage = "연결 실패: \(e?.message ?? error.localizedDescription) (HTTP \(e?.status ?? -1))"
                testIsError = true
                DebugLogger.error("Settings", "연결 테스트 실패: \(e?.code ?? "unknown") status=\(e?.status ?? -1)")
            }
            testingConnection = false
        }
    }

    private func syncDrafts() {
        let drafts = DraftStore.all()
        guard !drafts.isEmpty else {
            syncMessage = "동기화할 로컬 초안이 없습니다."
            return
        }
        backupBusy = true
        syncMessage = ""
        Task {
            do {
                let posts = drafts.map { d in
                    let iso = ISO8601DateFormatter()
                    return APIClient.SyncPost(
                        localPostId: d.postId,
                        title: d.title,
                        slug: d.slug,
                        body: d.body,
                        bodyFormat: d.bodyFormat,
                        status: d.status,
                        updatedAt: iso.string(from: d.savedAt)
                    )
                }
                let result = try await APIClient.syncBulk(token: authStore.token, posts: posts)
                for item in result.results {
                    DraftStore.clear(postId: item.localPostId)
                }
                syncMessage = "동기화 완료: \(result.synced)건 반영, \(result.skipped)건 건너뜀 (로컬 초안 정리됨)"
                DebugLogger.info("Settings", "동기화 완료 (synced \(result.synced), skipped \(result.skipped))")
            } catch {
                let e = error as? APIError
                syncMessage = "동기화 실패: \(e?.message ?? error.localizedDescription)"
                DebugLogger.error("Settings", "동기화 실패: \(e?.code ?? "unknown")")
            }
            backupBusy = false
        }
    }

    private func downloadBackup() {
        backupBusy = true
        backupMessage = ""
        Task {
            do {
                let backup = try await APIClient.fetchBackup(token: authStore.token)
                let panel = NSSavePanel()
                panel.nameFieldStringValue = "maccando-backup-\(Int(Date().timeIntervalSince1970)).json"
                panel.allowedContentTypes = [.json]
                if panel.runModal() == .OK, let url = panel.url {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    try encoder.encode(backup).write(to: url)
                    backupMessage = "백업 저장 완료: \(url.lastPathComponent) (게시글 \(backup.posts.count), 댓글 \(backup.comments.count))"
                    DebugLogger.info("Settings", "백업 저장 완료 (\(url.lastPathComponent))")
                } else {
                    backupMessage = "저장이 취소되었습니다."
                }
            } catch {
                let e = error as? APIError
                backupMessage = "백업 실패: \(e?.message ?? error.localizedDescription)"
                DebugLogger.error("Settings", "백업 실패: \(e?.code ?? "unknown")")
            }
            backupBusy = false
        }
    }

    private func pickRestoreFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "복원할 백업 JSON 선택"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            backupBusy = true
            backupMessage = ""
            Task {
                do {
                    let data = try Data(contentsOf: url)
                    let backup = try JSONDecoder().decode(APIClient.BackupData.self, from: data)
                    let result = try await APIClient.restoreBackup(token: authStore.token, data: backup)
                    backupMessage = "복원 완료: 카테고리 \(result.categories) / 게시글 \(result.posts) / 댓글 \(result.comments) (최신 데이터 \(result.skipped)건 건너뜀)"
                    DebugLogger.info("Settings", "복원 완료 (posts \(result.posts))")
                } catch {
                    let e = error as? APIError
                    backupMessage = "복원 실패: \(e?.message ?? error.localizedDescription)"
                    DebugLogger.error("Settings", "복원 실패: \(e?.code ?? "unknown")")
                }
                backupBusy = false
            }
        }
    }
}