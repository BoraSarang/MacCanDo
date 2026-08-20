// [FEATURE] Gemini AI SEO — 제목/설명/키워드/슬러그 자동 생성 (T-08)
// REST 직접 호출 (macOS), AI_MODELS.json seo_v0.1 규격
// SQLite LRU 캐시 (동일 입력 = hit, hit>=70% 목표) — 재생성 버튼은 forceRefresh로 우회
import Foundation
import CryptoKit

struct SEOSuggestion: Codable {
    let title: String?
    let slug: String?
    let excerpt: String?
    let keywords: [String]?
    let image: String?

}

// T-27: 한글 맞춤법 검사 — 원문/수정문/이유 (개별 적용 버튼용)
struct SpellingIssue: Codable, Identifiable {
    let original: String
    let fixed: String
    let reason: String

    var id: String { "\(original)|\(fixed)|\(reason)" }
}

enum GeminiService {
    static var hasKey: Bool {
        !(UserDefaults.standard.string(forKey: "geminiKey") ?? "").isEmpty
    }

    // ---------- T-74: 동작별 AI 모델 체인 설정 (v2.13) ----------
    enum AIProvider: String, Codable, CaseIterable, Identifiable {
        case gemini, nvidia, openrouter

        var id: String { rawValue }
        var label: String {
            switch self {
            case .gemini: return "Gemini"
            case .nvidia: return "NVIDIA NIM"
            case .openrouter: return "OpenRouter"
            }
        }
        var hasKey: Bool {
            switch self {
            case .gemini: return GeminiService.hasKey
            case .nvidia: return !(UserDefaults.standard.string(forKey: "nvidiaKey") ?? "").isEmpty
            case .openrouter: return !(UserDefaults.standard.string(forKey: "openrouterKey") ?? "").isEmpty
            }
        }
    }

    struct AIModelRef: Codable, Identifiable, Hashable {
        let provider: AIProvider
        let model: String
        var id: String { "\(provider.rawValue)|\(model)" }
        var label: String { "\(provider.label) · \(model)" }
    }

    enum AICapability: String, Codable { case text, image, vision }

    // AI 동작(기능) — 각각 모델 사용 순서를 설정으로 관리
    enum AIAction: String, CaseIterable, Codable, Identifiable {
        case assistant, seo, spelling, wizard, newsSummary, coverImage, bodyImage, vision

        var id: String { rawValue }
        var label: String {
            switch self {
            case .assistant: return "AI 도우미"
            case .seo: return "AI SEO"
            case .spelling: return "맞춤법 검사"
            case .wizard: return "이야기 마법사"
            case .newsSummary: return "맥 소식 요약"
            case .coverImage: return "커버 이미지"
            case .bodyImage: return "본문 이미지"
            case .vision: return "이미지 설명(alt)"
            }
        }
        var capability: AICapability {
            switch self {
            case .assistant, .seo, .spelling, .wizard, .newsSummary: return .text
            case .coverImage, .bodyImage: return .image
            case .vision: return .vision
            }
        }
    }

    struct AIChainConfig: Codable {
        var chains: [AIAction: [AIModelRef]] = [:]
        var customModels: [AIModelRef] = []
    }

    // 모델 카탈로그 (설정 UI 선택지 — 커스텀 모델로 확장)
    static let modelCatalog: [AIProvider: [String]] = [
        .gemini: ["gemini-3.7-flash", "gemini-3.1-flash", "gemini-2.5-flash",
                  "gemini-3.1-flash-image", "gemini-2.5-flash-image"],
        .nvidia: ["openai/gpt-oss-20b", "nvidia/llama-3.3-nemotron-super-49b-v1.5",
                  "flux.1-schnell", "google/diffusiongemma-26b-a4b-it",
                  "meta/llama-3.2-90b-vision-instruct", "meta/llama-3.2-11b-vision-instruct"],
        .openrouter: ["google/gemma-4-31b-it:free", "openai/gpt-oss-20b:free",
                      "google/gemini-3.1-flash-image", "google/gemini-2.5-flash-image"]
    ]

    // 기본 체인 (마이그레이션 — 기존 하드코딩과 동일 동작 보존)
    private static let defaultTextChain: [AIModelRef] = [
        AIModelRef(provider: .gemini, model: "gemini-3.7-flash"),
        AIModelRef(provider: .nvidia, model: "openai/gpt-oss-20b"),
        AIModelRef(provider: .openrouter, model: "google/gemma-4-31b-it:free"),
        AIModelRef(provider: .openrouter, model: "openai/gpt-oss-20b:free")
    ]
    private static let defaultImageChain: [AIModelRef] = [
        AIModelRef(provider: .gemini, model: "gemini-3.1-flash-image"),
        AIModelRef(provider: .gemini, model: "gemini-2.5-flash-image"),
        AIModelRef(provider: .nvidia, model: "flux.1-schnell")
    ]
    private static let defaultVisionChain: [AIModelRef] = [
        AIModelRef(provider: .nvidia, model: "meta/llama-3.2-90b-vision-instruct")
    ]

    private static let chainsKey = "aiChains"

    static func defaultChain(for action: AIAction) -> [AIModelRef] {
        switch action.capability {
        case .text: return defaultTextChain
        case .image: return defaultImageChain
        case .vision: return defaultVisionChain
        }
    }

    // 설정된 체인 (없으면 기본)
    static func chain(for action: AIAction) -> [AIModelRef] {
        if let c = loadChains().chains[action], !c.isEmpty { return c }
        return defaultChain(for: action)
    }

    static func loadChains() -> AIChainConfig {
        guard let data = UserDefaults.standard.data(forKey: chainsKey),
              let config = try? JSONDecoder().decode(AIChainConfig.self, from: data) else {
            return AIChainConfig()
        }
        return config
    }

    static func saveChains(_ config: AIChainConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: chainsKey)
        }
    }

    static func setChain(_ chain: [AIModelRef], for action: AIAction) {
        var config = loadChains()
        config.chains[action] = chain
        saveChains(config)
    }

    static func resetChains() {
        UserDefaults.standard.removeObject(forKey: chainsKey)
    }

    // 카탈로그 + 커스텀 모델 → capability별 선택지
    static func catalogModels(for capability: AICapability) -> [AIModelRef] {
        var models: [AIModelRef] = []
        for (provider, ids) in modelCatalog {
            for id in ids where modelCapability(provider: provider, model: id) == capability {
                models.append(AIModelRef(provider: provider, model: id))
            }
        }
        models.append(contentsOf: loadChains().customModels.filter { modelCapability(provider: $0.provider, model: $0.model) == capability })
        return models
    }

    private static func modelCapability(provider: AIProvider, model: String) -> AICapability {
        if model.contains("-image") || model.contains("flux") || model.contains("qwen-image") || model.contains("stable-diffusion") { return .image }
        if model.contains("vision") { return .vision }
        return .text
    }

    static func addCustomModel(provider: AIProvider, model: String) {
        let clean = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var config = loadChains()
        let ref = AIModelRef(provider: provider, model: clean)
        if !config.customModels.contains(ref) {
            config.customModels.append(ref)
            saveChains(config)
        }
    }

    static func removeCustomModel(_ ref: AIModelRef) {
        var config = loadChains()
        config.customModels.removeAll { $0 == ref }
        saveChains(config)
    }

    // 체인 요약 (설정 UI/이미지 시트 헤더 표시)
    static func chainLabel(for action: AIAction) -> String {
        chain(for: action).map { $0.provider.label }.joined(separator: " → ")
    }

    // ---------- T-75: 체인 실행 엔진 (v2.13) ----------
    // 각 모델 순서대로 시도 — 실패/404/429/키 없음은 다음으로 폴백
    static func runTextChain(_ chain: [AIModelRef], prompt: String) async throws -> String {
        guard !chain.isEmpty else {
            throw APIError(code: "E-MAC-AI-1007", message: "AI 체인이 비어 있습니다. 설정에서 모델을 추가해 주세요.", status: -1)
        }
        var lastError: APIError?
        for ref in chain {
            guard ref.provider.hasKey else {
                DebugLogger.debug("Gemini", "체인 스킵 (키 없음) \(ref.label)")
                continue
            }
            do {
                let text: String
                switch ref.provider {
                case .gemini: text = try await fetchGeminiText(prompt: prompt, model: ref.model)
                case .nvidia: text = try await fetchNVIDIAText(prompt: prompt, model: ref.model)
                case .openrouter: text = try await fetchOpenRouterText(prompt: prompt, model: ref.model)
                }
                DebugLogger.info("Gemini", "텍스트 생성 완료 provider=\(ref.provider.rawValue) model=\(ref.model)")
                return text
            } catch {
                lastError = (error as? APIError) ?? APIError(code: "E-MAC-NET-1001", message: "네트워크 오류: \(error.localizedDescription)", status: (error as? URLError)?.errorCode ?? -1)
                DebugLogger.warn("Gemini", "체인 폴백 (\(ref.label)): \(error.localizedDescription)")
            }
        }
        throw lastError ?? APIError(code: "E-MAC-AI-1007", message: "AI 호출에 실패했습니다. 잠시 후 다시 시도해 주세요.", status: -1)
    }

    static func runImageChain(_ chain: [AIModelRef], prompt: String) async throws -> (data: Data, provider: String) {
        guard !chain.isEmpty else {
            throw APIError(code: "E-MAC-AI-1005", message: "이미지 AI 체인이 비어 있습니다. 설정에서 모델을 추가해 주세요.", status: -1)
        }
        var lastError: APIError?
        for ref in chain {
            guard ref.provider.hasKey else {
                DebugLogger.debug("Gemini", "이미지 체인 스킵 (키 없음) \(ref.label)")
                continue
            }
            do {
                let data: Data
                switch ref.provider {
                case .gemini: data = try await callImageGen(model: ref.model, prompt: prompt)
                case .nvidia: data = try await callNVIDIAImage(model: ref.model, prompt: prompt)
                case .openrouter: data = try await callFlux(model: ref.model, prompt: prompt)
                }
                DebugLogger.info("Gemini", "[FEATURE] 이미지 생성 완료 provider=\(ref.provider.rawValue) model=\(ref.model) bytes=\(data.count)")
                return (data, ref.provider.rawValue)
            } catch {
                lastError = (error as? APIError) ?? APIError(code: "E-MAC-NET-1001", message: "네트워크 오류: \(error.localizedDescription)", status: (error as? URLError)?.errorCode ?? -1)
                DebugLogger.warn("Gemini", "이미지 체인 폴백 (\(ref.label)): \(error.localizedDescription)")
            }
        }
        throw lastError ?? APIError(code: "E-MAC-AI-1005", message: "이미지 생성에 실패했습니다.", status: -1)
    }

    // 비전: 이미지 → 한국어 alt 설명 (체인은 .vision)
    static func generateImageDescription(imageData: Data) async throws -> String {
        let prompt = "이 이미지를 한국어로 1~2문장으로 설명해 주세요. 접근성 alt 텍스트로 적합하게, 감정적인 수식 없이 사실적으로."
        var lastError: APIError?
        for ref in chain(for: .vision) {
            guard ref.provider.hasKey else { continue }
            switch ref.provider {
            case .nvidia:
                do {
                    let text = try await fetchNVision(model: ref.model, imageData: imageData, prompt: prompt)
                    DebugLogger.info("Gemini", "[FEATURE] 이미지 설명 생성 완료 provider=\(ref.provider.rawValue) model=\(ref.model)")
                    return text
                } catch {
                    lastError = (error as? APIError) ?? APIError(code: "E-MAC-NET-1001", message: "네트워크 오류: \(error.localizedDescription)", status: (error as? URLError)?.errorCode ?? -1)
                    DebugLogger.warn("Gemini", "비전 폴백 (\(ref.label)): \(error.localizedDescription)")
                }
            default:
                continue // 비전은 NVIDIA만 지원
            }
        }
        throw lastError ?? APIError(code: "E-MAC-AI-1007", message: "이미지 분석에 실패했습니다.", status: -1)
    }

    // ---------- T-76: NVIDIA NIM (build.nvidia.com, OpenAI 호환) ----------
    private static func nvidiaKey() -> String {
        UserDefaults.standard.string(forKey: "nvidiaKey") ?? ""
    }

    private static func fetchNVIDIAText(prompt: String, model: String) async throws -> String {
        let key = nvidiaKey()
        guard !key.isEmpty else {
            throw APIError(code: "E-MAC-SET-1001", message: "NVIDIA API 키가 설정되지 않았습니다. 설정에서 입력하세요.", status: -1)
        }
        guard let url = URL(string: "https://integrate.api.nvidia.com/v1/chat/completions") else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        let payload: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-AI-1007", message: "NVIDIA 호출 실패 (HTTP \(code))", status: code)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (json?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
        if let text = message?["content"] as? String, !text.isEmpty {
            return text
        }
        if let parts = message?["content"] as? [[String: Any]] {
            for p in parts where p["type"] as? String == "text" {
                if let t = p["text"] as? String, !t.isEmpty { return t }
            }
        }
        throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
    }

    // NVIDIA 이미지 생성 — OpenAI 호환 /v1/images/generations (b64_json)
    private static func callNVIDIAImage(model: String, prompt: String) async throws -> Data {
        let key = nvidiaKey()
        guard !key.isEmpty else {
            throw APIError(code: "E-MAC-SET-1001", message: "NVIDIA API 키가 설정되지 않았습니다. 설정에서 입력하세요.", status: -1)
        }
        guard let url = URL(string: "https://ai.api.nvidia.com/v1/images/generations") else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "response_format": "b64_json"
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-AI-1005", message: "NVIDIA 이미지 생성 실패 (HTTP \(code))", status: code)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = (json?["data"] as? [[String: Any]]) ?? []
        if let b64 = items.first?["b64_json"] as? String, let imageData = Data(base64Encoded: b64) {
            return imageData
        }
        throw APIError(code: "E-MAC-AI-1006", message: "AI 이미지 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
    }

    // NVIDIA 비전 — image_url(base64 data URI) + 텍스트
    private static func fetchNVision(model: String, imageData: Data, prompt: String) async throws -> String {
        let key = nvidiaKey()
        guard !key.isEmpty else {
            throw APIError(code: "E-MAC-SET-1001", message: "NVIDIA API 키가 설정되지 않았습니다. 설정에서 입력하세요.", status: -1)
        }
        guard let url = URL(string: "https://integrate.api.nvidia.com/v1/chat/completions") else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        let mime = imageExtension(for: imageData) == "jpg" ? "image/jpeg" : "image/\(imageExtension(for: imageData))"
        let dataURI = "data:\(mime);base64,\(imageData.base64EncodedString())"
        let payload: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": dataURI]]
            ]]]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-AI-1007", message: "이미지 분석 실패 (HTTP \(code))", status: code)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (json?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
        if let text = message?["content"] as? String, !text.isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
    }

    struct GeminiRequest: Encodable {
        struct Content: Encodable {
            struct Part: Encodable { let text: String }
            let parts: [Part]
        }
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    struct GenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
    }

    struct GeminiResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    static let model = "gemini-3.7-flash"

    // 제목/본문 → SEO 제안 생성 (503 일시 오류 시 최대 3회 재시도 + SQLite LRU 캐시)
    // forceRefresh: 재생성 버튼 — 캐시 무시하고 새로 생성
    static func generateSEO(title: String, body: String, slug: String?, imageCandidates: [String], forceRefresh: Bool = false) async throws -> SEOSuggestion {
        let prompt = """
        다음 블로그 글의 SEO 최적화 제안을 JSON으로만 출력하세요 (마크다운 코드블록 없이).
        {"title": "검색에 유리한 제목 (30자 이내, 기존 제목과 다르면)", "slug": "영문 slug (kebab-case, max 60자)", "excerpt": "본문 요약 (130자 이내)", "keywords": ["키워드3-5개"], "image": "대표 이미지 URL (아래 후보 중 1개 선택, 없으면 제외)"}
        현재 slug: \(slug ?? "없음")
        현재 제목: \(title)
        대표 이미지 후보: \(imageCandidates.isEmpty ? "없음" : imageCandidates.joined(separator: ", "))
        본문:
        \(String(body.prefix(3000)))
        """

        // 캐시 조회 (forceRefresh면 스킵)
        if !forceRefresh {
            let key = cacheKey(title: title, body: body, slug: slug, images: imageCandidates)
            if let cached = DraftStore.loadSEOCache(key: key),
               let data = cached.data(using: .utf8),
               let suggestion = try? JSONDecoder().decode(SEOSuggestion.self, from: data) {
                recordCacheHit()
                DebugLogger.info("Gemini", "[CACHE] SEO hit=true key=\(key.prefix(10))...")
                return suggestion
            }
        }

        recordCacheMiss()
        let suggestion = try await withRetry { try await callGemini(prompt: prompt) }

        // 캐시 저장
        let key = cacheKey(title: title, body: body, slug: slug, images: imageCandidates)
        if let data = try? JSONEncoder().encode(suggestion),
           let json = String(data: data, encoding: .utf8) {
            DraftStore.saveSEOCache(key: key, suggestionJSON: json)
            DebugLogger.info("Gemini", "[CACHE] SEO hit=false 저장 (캐시 \(DraftStore.seoCacheCount())건)")
        }
        return suggestion
    }

    // 입력 → SHA256 캐시 키 (prefix: 용도 구분 — T-63 P4)
    private static func sha256(_ raw: String, prefix: String = "") -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        return prefix + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func cacheKey(title: String, body: String, slug: String?, images: [String]) -> String {
        sha256("\(title)|\(slug ?? "")|\(body)|\(images.joined(separator: ","))")
    }

    private static func recordCacheHit() {
        let hits = (UserDefaults.standard.integer(forKey: "seoCacheHits")) + 1
        UserDefaults.standard.set(hits, forKey: "seoCacheHits")
    }

    private static func recordCacheMiss() {
        let misses = UserDefaults.standard.integer(forKey: "seoCacheMisses") + 1
        UserDefaults.standard.set(misses, forKey: "seoCacheMisses")
    }

    static var cacheStats: (hits: Int, misses: Int) {
        (UserDefaults.standard.integer(forKey: "seoCacheHits"), UserDefaults.standard.integer(forKey: "seoCacheMisses"))
    }

    // 503(일시 과부하)만 3회 재시도 — callGemini/callGeminiText 공용 (T-63 P4)
    private static func withRetry<T>(_ op: () async throws -> T) async throws -> T {
        var lastError: APIError?
        for attempt in 0..<3 {
            if attempt > 0 {
                DebugLogger.warn("Gemini", "503 재시도 (\(attempt + 1)/3)")
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            do {
                return try await op()
            } catch let e as APIError {
                lastError = e
                if e.status != 503 { throw e }  // 503만 재시도
            }
        }
        throw lastError ?? APIError(code: "E-MAC-AI-1001", message: "Gemini 일시 오류 (503). 잠시 후 다시 시도해 주세요.", status: 503)
    }

    private static func callGemini(prompt: String) async throws -> SEOSuggestion {
        let text = try await fetchText(prompt: prompt, action: .seo)
        guard let jsonData = extractJSON(from: text),
              let suggestion = try? JSONDecoder().decode(SEOSuggestion.self, from: jsonData) else {
            throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        return suggestion
    }

    // ---------- 한글 맞춤법 검사 (T-27) ----------
    // 본문 → 오류 목록 JSON 반환. 마크다운/코드블록/URL/커스텀 태그는 수정 대상 제외.
    static func checkKoreanSpelling(text: String) async throws -> [SpellingIssue] {
        guard hasKey else {
            throw APIError(code: "E-MAC-AI-1007", message: "Gemini API 키가 설정되지 않았습니다. 설정에서 입력해 주세요.", status: -1)
        }
        let prompt = """
        아래 마크다운 문서의 한국어 맞춤법·띄어쓰기·문법 오류만 검사하세요.
        JSON 배열만 출력하세요 (마크다운 코드블록 없이). 각 항목 형식: {"original": "오류가 포함된 원문 조각", "fixed": "수정된 조각", "reason": "짧은 이유 (예: 띄어쓰기 오류)"}
        규칙:
        - original은 문서에 그대로 존재하는 최소 단위 조각(단어 또는 짧은 문장)이어야 합니다.
        - 마크다운 문법(**, #, [텍스트](URL), ![이미지]), 코드 블록(```) 안 텍스트, URL, 이메일, [app:...]/[img:...]/[youtube:...]/[video:...]/[center] 등 커스텀 태그 내부는 절대 수정하지 마세요.
        - 원문과 동일한 내용이 여러 번 나오면 한 항목만 반환하세요.
        - 오류가 없으면 빈 배열 [] 만 반환하세요.
        문서:
        \(text)
        """
        let raw = try await withRetry { try await callGeminiText(prompt: prompt, action: .spelling) }
        guard let data = extractJSONArray(from: raw) else {
            throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        return (try? JSONDecoder().decode([SpellingIssue].self, from: data)) ?? []
    }

    // ---------- AI 이미지 생성 (시리즈 커버/썸네일, T-19) ----------
    // 공급자/모델 선택은 동작별 체인 설정으로 통합 (T-74, .coverImage/.bodyImage)

    struct ImageGenResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    struct InlineData: Decodable {
                        let mimeType: String
                        let data: String
                    }
                    let inlineData: InlineData?
                    let thought: Bool?
                }
                let parts: [Part]
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    // 프롬프트 → 이미지 생성 — 동작별 체인 경유 (T-75)
    // 반환: (이미지 Data, 사용 공급자 "gemini"|"nvidia"|"openrouter")
    static func generateImage(prompt: String, action: AIAction) async throws -> (data: Data, provider: String) {
        try await runImageChain(chain(for: action), prompt: prompt)
    }

    // OpenRouter 이미지 생성 — Gemini 이미지 모델 (2026 기준 Flux는 OpenRouter에서 제거됨)
    // OpenAI 호환 /chat/completions + response_format image → images 배열 (data URI)
    private static func callFlux(model: String, prompt: String) async throws -> Data {
        guard let key = UserDefaults.standard.string(forKey: "openrouterKey"), !key.isEmpty else {
            throw APIError(code: "E-MAC-SET-1001", message: "OpenRouter API 키가 설정되지 않았습니다. 설정 → AI 설정에서 입력하세요.", status: -1)
        }
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        let payload: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "response_format": ["type": "image"],
            "aspect_ratio": "16:9"
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-AI-1005", message: "이미지 생성 실패 (HTTP \(code)). 잠시 후 다시 시도해 주세요.", status: code)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let images = (json?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any] ?? [:]
        if let uri = (images["images"] as? [String])?.first ?? imageDataURI(in: images["content"]) {
            if let imageData = decodeDataURI(uri) {
                return imageData
            }
        }
        throw APIError(code: "E-MAC-AI-1006", message: "AI 이미지 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
    }

    // content 배열에서 image_url 타입 data URI 추출 (모델별 응답 형식 대응)
    private static func imageDataURI(in content: Any?) -> String? {
        guard let parts = content as? [[String: Any]] else { return nil }
        for part in parts {
            if let imageUrl = part["image_url"] as? String { return imageUrl }
            if let dict = part["image_url"] as? [String: Any], let u = dict["url"] as? String { return u }
        }
        return nil
    }

    // "data:image/jpeg;base64,XXXX" → Data
    private static func decodeDataURI(_ uri: String) -> Data? {
        guard let comma = uri.range(of: ",") else { return nil }
        return Data(base64Encoded: String(uri[comma.upperBound...]))
    }

    private static func callImageGen(model: String, prompt: String) async throws -> Data {
        guard let key = UserDefaults.standard.string(forKey: "geminiKey"), !key.isEmpty else {
            throw APIError(code: "E-MAC-SET-1001", message: "Gemini API 키가 설정되지 않았습니다. 설정에서 입력하세요.", status: -1)
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }

        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseModalities": ["IMAGE"],
                "imageConfig": ["aspectRatio": "16:9", "imageSize": "1K"]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-AI-1005", message: "이미지 생성 실패 (HTTP \(code))", status: code)
        }

        let response = try JSONDecoder().decode(ImageGenResponse.self, from: data)
        guard let parts = response.candidates?.first?.content?.parts else {
            throw APIError(code: "E-MAC-AI-1006", message: "AI 이미지 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        // thought=true (중간 산출물) 스킵 — 마지막 inlineData 사용
        guard let imagePart = parts.filter({ $0.thought != true }).last(where: { $0.inlineData != nil }),
              let b64 = imagePart.inlineData?.data,
              let imageData = Data(base64Encoded: b64) else {
            throw APIError(code: "E-MAC-AI-1006", message: "AI 이미지 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        return imageData
    }

    // 생성 이미지 바이트 → 확장자 판별 (JPEG/PNG/WebP/GIF) — 업로드 mimeType 대응
    static func imageExtension(for data: Data) -> String {
        if data.count > 3, data[0] == 0xFF, data[1] == 0xD8, data[2] == 0xFF { return "jpg" }
        if data.count > 4, data[0] == 0x89, data[1] == 0x50, data[2] == 0x4E, data[3] == 0x47 { return "png" }
        if data.count > 12, data[0] == 0x52, data[1] == 0x49, data[2] == 0x46, data[3] == 0x46,
           data[8] == 0x57, data[9] == 0x45, data[10] == 0x42, data[11] == 0x50 { return "webp" }
        if data.count > 3, data[0] == 0x47, data[1] == 0x49, data[2] == 0x46, data[3] == 0x38 { return "gif" }
        return "png"
    }

    // AI 텍스트 응답 (JSON 아님, MD 등) — 동작별 체인 경유 (T-75)
    private static func callGeminiText(prompt: String, action: AIAction) async throws -> String {
        let text = try await fetchText(prompt: prompt, action: action)
        guard !text.isEmpty else {
            throw APIError(code: "E-MAC-AI-1003", message: "AI 응답이 비어 있습니다. 다시 시도해 주세요.", status: -1)
        }
        return text
    }

    // v2.11 T-67: 이야기 시리즈 글 초안 생성 (사건 요약/팩트/출처 시드 → 1,500자+ 스토리텔링)
    static func generateStoryDraft(title: String, summary: String) async throws -> String {
        let prompt = """
        다음 주제로 MacCanDo 블로그의 이야기 시리즈 글 초안을 한국어로 작성해 주세요.

        글 제목: \(title)

        사건 요약/팩트 (아래 사실을 반드시 모두 자연스럽게 녹여내세요):
        \(summary)

        작성 규칙:
        - 본문 1,500자 이상의 길고 자세한 스토리텔링 (사건의 흐름, 배경, 인용, 여운까지)
        - 딱딱한 기사체가 아닌, 블로그 독자가 술술 읽는 자연스러운 한국어 문체
        - 마크다운 형식: ## 소제목으로 단락을 나누고, 필요하면 - 목록 사용
        - 마지막에 반드시 '## 출처' 소제목을 만들고 검증된 출처를 '1. 제목 — URL' 형태로 링크 나열
        - 확실하지 않은 수치는 '추정'으로 표기하고, 사실은 추측과 명확히 구분
        - 글 제목은 출력하지 말고 본문 내용만 출력
        """
        return try await callGeminiText(prompt: prompt, action: .wizard)
    }

    // ---------- T-73: 이야기 시리즈 편 목록 AI 기획 (v2.13) ----------
    struct StorySeedPlan: Codable, Identifiable {
        var id = UUID()
        let title: String
        let slug: String
        let summary: String
        let coverPrompt: String
        let bodyPrompts: [String]

        enum CodingKeys: String, CodingKey { case title, slug, summary, coverPrompt, bodyPrompts }
    }

    // 주제 → 시리즈 편 목록(3~5편) 기획 — 동작 체인 .wizard 경유
    static func generateStorySeriesPlan(topic: String) async throws -> [StorySeedPlan] {
        let prompt = """
        다음 주제로 블로그 '이야기' 시리즈의 편 목록을 3~5편 기획해 주세요. JSON 배열만 출력하세요 (마크다운 코드블록·설명 없이).

        시리즈 주제: \(topic)

        각 편 형식 (키 이름 그대로, 값은 한국어):
        {
          "title": "편 제목 (흥미로운 제목)",
          "slug": "영문-소문자-하이픈-슬러그",
          "summary": "이 편에서 다룰 사실/사건 요약 — 검증 가능한 팩트 위주(기업·제품·연도·수치), 창작 내용은 '추정' 명시. 4~6줄.",
          "coverPrompt": "16:9 커버 이미지 생성 프롬프트 (구체적인 시각 묘사, 미니멀/일러스트 톤)",
          "bodyPrompts": ["본문 이미지 1 프롬프트", "본문 이미지 2 프롬프트"]
        }

        요구사항:
        - 전체가 하나의 큰 이야기 흐름(서사)이 되도록 편 순서를 구성
        - 실제 존재하는 사건/기업/제품이면 정확한 이름·연도·수치로 팩트 기반
        - summary에 출처(신문/보도명 — URL 생략)를 붙이면 좋음
        - JSON 외 어떤 텍스트도 출력 금지
        """
        let raw = try await fetchText(prompt: prompt, action: .wizard)
        guard let data = extractJSONArray(from: raw) else {
            throw APIError(code: "E-MAC-AI-1003", message: "편 목록을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        guard let plans = try? JSONDecoder().decode([StorySeedPlan].self, from: data), !plans.isEmpty else {
            throw APIError(code: "E-MAC-AI-1003", message: "편 목록을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        DebugLogger.info("Gemini", "[FEATURE] 시리즈 편 목록 기획 완료 count=\(plans.count) topic=\(String(topic.prefix(40)))")
        return plans
    }

    // 공통 fetch (Gemini 호출 → 텍스트 추출)
    private static func fetchGeminiText(prompt: String, model: String) async throws -> String {
        let payload = GeminiRequest(
            contents: [.init(parts: [.init(text: prompt)])],
            generationConfig: .init(temperature: 0.3, maxOutputTokens: 4096)
        )

        guard let key = UserDefaults.standard.string(forKey: "geminiKey"), !key.isEmpty else {
            throw APIError(code: "E-MAC-SET-1001", message: "Gemini API 키가 설정되지 않았습니다. 설정에서 입력하세요.", status: -1)
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if code == 400 {
                throw APIError(code: "E-MAC-AI-1002", message: "Gemini 요청 오류 (400) — 키 또는 모델을 확인하세요.", status: code)
            }
            throw APIError(code: "E-MAC-AI-1001", message: "Gemini 호출 실패 (HTTP \(code))", status: code)
        }

        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = response.candidates?.first?.content?.parts.first?.text else {
            throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        return text
    }

    // ---------- AI 텍스트 호출 — 동작별 체인 (T-75) ----------
    // 각 동작 함수는 fetchText(prompt:action:)을 통해 설정된 모델 체인을 순서대로 시도
    private static func fetchText(prompt: String, action: AIAction) async throws -> String {
        try await runTextChain(chain(for: action), prompt: prompt)
    }

    // OpenRouter 호출 — OpenAI 호환 /chat/completions
    private static func fetchOpenRouterText(prompt: String, model: String) async throws -> String {
        guard let key = UserDefaults.standard.string(forKey: "openrouterKey"), !key.isEmpty else {
            throw APIError(code: "E-MAC-SET-1001", message: "OpenRouter API 키가 설정되지 않았습니다. 설정에서 입력하세요.", status: -1)
        }
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        let payload: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-AI-1007", message: "AI 호출 실패 (HTTP \(code))", status: code)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (json?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
        if let text = message?["content"] as? String, !text.isEmpty {
            return text
        }
        if let parts = message?["content"] as? [[String: Any]] {
            for p in parts where p["type"] as? String == "text" {
                if let t = p["text"] as? String, !t.isEmpty {
                    return t
                }
            }
        }
        throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
    }

    // ---------- AI 도우미 (글쓰기 도우미) ----------

    // 프로그램 이름/웹사이트 → 제품 소개 MD 생성 (캐시 지원) — 반환: (본문, 캐시 히트 여부)
    // urlContent: fetch된 페이지 텍스트 (있으면 그 내용 기반, 없으면 AI 지식)
    static func generateProductGuide(query: String, compareWith: String?, urlContent: String?, forceRefresh: Bool = false) async throws -> (String, Bool) {
        let compareTarget = compareWith?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = """
        다음 요청의 프로그램/웹사이트에 대한 블로그 게시글용 제품 소개를 한국어 마크다운으로 작성하세요.
        형식 (섹션 제목은 ##):
        # {프로그램명} 소개
        ## 한눈에 보기 — 용도/가격/플랫폼 요약 (가능하면 목록 4~6줄)
        ## 소개 — 2~3문단
        ## 비슷한 프로그램과 비교 — \(compareTarget?.isEmpty == false ? compareTarget! : "유사 프로그램 3개를 자동 선정")과의 차이점 위주 목록
        ## 장점 — 5~8개 목록
        ## 특이사항 — 참신한 기능/주의점
        ## 추천 이유 — 어떤 사용자에게 추천하는지

        요청: \(query)
        \(urlContent.map { "참고 자료 (이 웹사이트 내용 기반으로 작성):\n\(String($0.prefix(12000)))" } ?? "참고 자료 없음 — AI 지식 기반으로 작성")
        """

        // 캐시 조회 (forceRefresh면 스킵)
        let key = guideCacheKey(query: query, compareWith: compareTarget, urlContent: urlContent)
        if !forceRefresh,
           let cached = DraftStore.loadSEOCache(key: key) {
            recordCacheHit()
            DebugLogger.info("Gemini", "[CACHE] Guide hit=true key=\(key.prefix(12))...")
            return (cached, true)
        }
        recordCacheMiss()
        let text = try await withRetry { try await callGeminiText(prompt: prompt, action: .assistant) }
        DraftStore.saveSEOCache(key: key, suggestionJSON: text)
        DebugLogger.info("Gemini", "[CACHE] Guide hit=false 저장 (캐시 \(DraftStore.seoCacheCount())건)")
        return (text, false)
    }

    // URL → 텍스트 추출 (웹사이트 내용 기반 작성용)
    static func fetchURLText(_ urlString: String) async throws -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme == "http" || url.scheme == "https" else {
            throw APIError(code: "E-MAC-VALID-1003", message: "올바른 URL 형식이 아닙니다 (http/https 포함).", status: -1)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue(WebHelpers.safariUserAgent, forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-AI-1004", message: "웹사이트를 불러오지 못했습니다 (HTTP \(code)).", status: code)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw APIError(code: "E-MAC-AI-1004", message: "웹사이트 내용을 읽을 수 없습니다.", status: -1)
        }
        return WebHelpers.stripHTML(html)
    }

    private static func guideCacheKey(query: String, compareWith: String?, urlContent: String?) -> String {
        sha256("guide:\(query)|\(compareWith ?? "")|\(urlContent?.prefix(1500) ?? "")", prefix: "g")
    }


    // ---------- 맥 소식 일괄 요약 (T-23) ----------
    // RSS 원시 항목 → JSON 배열 [{"title","summary","rating"}] — 요약 2줄 + 소재 추천도
    // 대량 수집 대비 25건씩 청크 분할 호출 (모델 출력 한도 안전)
    static func summarizeNews(_ items: [RawNewsItem]) async throws -> [NewsItem] {
        guard !items.isEmpty else { return [] }
        var all: [NewsItem] = []
        var failedChunks = 0
        let chunkSize = 25
        var index = 0
        while index < items.count {
            let chunk = Array(items[index..<min(index + chunkSize, items.count)])
            do {
                let part = try await summarizeChunk(chunk)
                all.append(contentsOf: part)
            } catch {
                failedChunks += 1
                DebugLogger.warn("Gemini", "소식 요약 청크 \(index / chunkSize + 1) 실패, 건너뜀: \(error.localizedDescription)")
            }
            index += chunkSize
            if index < items.count {
                DebugLogger.info("Gemini", "소식 요약 청크 진행 \(index)/\(items.count)건")
            }
        }
        DebugLogger.info("Gemini", "소식 요약 완료 \(items.count)건 → \(all.count)건 (실패 청크 \(failedChunks)개)")
        return all
    }

    private static func summarizeChunk(_ items: [RawNewsItem]) async throws -> [NewsItem] {
        let list = items.enumerated()
            .map { "\($0.offset + 1). [\($0.element.source)] \($0.element.title) — \($0.element.url)" }
            .joined(separator: "\n")
        let prompt = """
        아래는 최근 맥/애플 관련 소식 목록입니다. 각 항목을 한국어 3줄 이내로 요약하고, 블로그 글 소재로 올릴 만한지 평가해 주세요.
        JSON 배열로만 출력하세요 (마크다운 코드블록 없이):
        [{"title": "원문 제목 그대로", "summary": "한국어 요약 3줄", "rating": "추천 또는 보통", "reason": "추천이라면 블로그 소재로 왜 좋은지 한 줄, 보통이면 비우거나 생략"}]
        rating 규칙: "추천" = 독자에게 유용하거나 흥미로운 소재, "보통" = 그 외.
        항목 수와 동일한 개수로 출력하세요. title은 반드시 원문 제목과 정확히 동일하게.

        목록:
        \(list)
        """
        let text = try await callGeminiText(prompt: prompt, action: .newsSummary)
        guard let data = extractJSONArray(from: text) else {
            throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        struct SummaryEntry: Codable {
            let title: String
            let summary: String
            let rating: String?
            let reason: String?
        }
        let entries = (try? JSONDecoder().decode([SummaryEntry].self, from: data)) ?? []
        // title 정확 매칭 우선 → 매칭 안 되면 남은 원문 순서대로 연결
        var result: [NewsItem] = []
        var used = Set<Int>()
        for e in entries {
            if let idx = items.indices.first(where: { items[$0].title == e.title && !used.contains($0) }) {
                let raw = items[idx]
                result.append(NewsItem(title: raw.title, url: raw.url, source: raw.source, published: raw.published, summary: e.summary, rating: e.rating == "추천" ? "추천" : "보통"))
                used.insert(idx)
            } else if let idx = items.indices.first(where: { !used.contains($0) }) {
                let raw = items[idx]
                result.append(NewsItem(title: raw.title, url: raw.url, source: raw.source, published: raw.published, summary: e.summary, rating: e.rating == "추천" ? "추천" : "보통"))
                used.insert(idx)
            }
        }
        return result
    }

    // ```json ... ``` 또는 순수 JSON 추출 (객체/배열 공용 — T-63 P4)
    private static func extractJSON(from text: String, open: Character, close: Character) -> Data? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "")
            t = t.replacingOccurrences(of: "```", with: "")
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = t.firstIndex(of: open), let end = t.lastIndex(of: close) else { return nil }
        return String(t[start...end]).data(using: .utf8)
    }

    private static func extractJSON(from text: String) -> Data? { extractJSON(from: text, open: "{", close: "}") }
    private static func extractJSONArray(from text: String) -> Data? { extractJSON(from: text, open: "[", close: "]") }
}