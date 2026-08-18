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

    var json: String {
        var parts: [String] = []
        if let title { parts.append("title: \(title)") }
        if let slug { parts.append("slug: \(slug)") }
        if let excerpt { parts.append("excerpt: \(excerpt)") }
        if let keywords { parts.append("keywords: \(keywords.joined(separator: ", "))") }
        if let image { parts.append("image: \(image)") }
        return parts.joined(separator: "\n")
    }
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
        let suggestion = try await callWithRetry(prompt: prompt)

        // 캐시 저장
        let key = cacheKey(title: title, body: body, slug: slug, images: imageCandidates)
        if let data = try? JSONEncoder().encode(suggestion),
           let json = String(data: data, encoding: .utf8) {
            DraftStore.saveSEOCache(key: key, suggestionJSON: json)
            DebugLogger.info("Gemini", "[CACHE] SEO hit=false 저장 (캐시 \(DraftStore.seoCacheCount())건)")
        }
        return suggestion
    }

    // 입력 → SHA256 캐시 키
    private static func cacheKey(title: String, body: String, slug: String?, images: [String]) -> String {
        let raw = "\(title)|\(slug ?? "")|\(body)|\(images.joined(separator: ","))"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
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

    private static func callWithRetry(prompt: String) async throws -> SEOSuggestion {
        var lastError: APIError?
        for attempt in 0..<3 {
            if attempt > 0 {
                DebugLogger.warn("Gemini", "503 재시도 (\(attempt + 1)/3)")
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            do {
                return try await callGemini(prompt: prompt)
            } catch let e as APIError {
                lastError = e
                if e.status != 503 { throw e }  // 503(일시 과부하)만 재시도
            }
        }
        throw lastError ?? APIError(code: "E-MAC-AI-1001", message: "Gemini 일시 오류 (503). 잠시 후 다시 시도해 주세요.", status: 503)
    }

    private static func callGemini(prompt: String) async throws -> SEOSuggestion {
        let text = try await fetchText(prompt: prompt)
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
        let raw = try await callTextWithRetry(prompt: prompt)
        guard let data = extractJSONArray(from: raw) else {
            throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        return (try? JSONDecoder().decode([SpellingIssue].self, from: data)) ?? []
    }

    // ---------- AI 이미지 생성 (시리즈 커버/썸네일, T-19) ----------

    // 이미지 생성 공급자 설정 (UserDefaults "imageGenProvider")
    // auto: Gemini(최신) / gemini: Gemini만 / openrouter: Flux (OpenRouter 키, 품질 우수)
    enum ImageGenProvider: String, CaseIterable, Identifiable {
        case auto = "auto"
        case gemini = "gemini"
        case openrouter = "openrouter"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .auto: return "자동 (Gemini)"
            case .gemini: return "Gemini (유료/무료 쿼터)"
            case .openrouter: return "OpenRouter 이미지 (키 필요)"
            }
        }
    }

    static var imageGenProvider: ImageGenProvider {
        ImageGenProvider(rawValue: UserDefaults.standard.string(forKey: "imageGenProvider") ?? "") ?? .auto
    }

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

    static let imageModels: [String] = ["gemini-3.1-flash-image", "gemini-2.5-flash-image"]

    // 프롬프트 → 16:9 이미지 생성 (base64 inlineData 디코드)
    // 공급자 체인: 설정값에 따라 Gemini(3.1 → 2.5 폴백) 또는 Flux(OpenRouter)
    // 반환: (이미지 Data, 사용 공급자 "gemini"|"flux")
    static func generateImage(prompt: String) async throws -> (data: Data, provider: String) {
        let mode = imageGenProvider
        if mode == .openrouter {
            return try await callFlux(prompt: prompt)
        }
        do {
            for model in imageModels {
                do {
                    let data = try await callImageGen(model: model, prompt: prompt)
                    DebugLogger.info("Gemini", "[FEATURE] AI 이미지 생성 완료 model=\(model) bytes=\(data.count)")
                    return (data, "gemini")
                } catch let e as APIError where e.status == 404 {
                    DebugLogger.warn("Gemini", "이미지 모델 없음 (\(model)) — 폴백 시도")
                    continue
                }
            }
            throw APIError(code: "E-MAC-AI-1005", message: "이미지 생성 모델을 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.", status: 404)
        } catch {
            throw error // 폴백 없음 — Gemini 실패는 그대로 전파
        }
    }

    // OpenRouter 이미지 생성 — Gemini 이미지 모델 (2026 기준 Flux는 OpenRouter에서 제거됨)
    // OpenAI 호환 /chat/completions + response_format image → images 배열 (data URI)
    private static func callFlux(prompt: String) async throws -> (data: Data, provider: String) {
        guard let key = UserDefaults.standard.string(forKey: "openrouterKey"), !key.isEmpty else {
            throw APIError(code: "E-MAC-SET-1001", message: "OpenRouter API 키가 설정되지 않았습니다. 설정 → 이미지 생성에서 입력하세요.", status: -1)
        }
        let models = ["google/gemini-3.1-flash-image", "google/gemini-2.5-flash-image"]
        var lastError: Error?
        for model in models {
            do {
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
                        DebugLogger.info("Gemini", "[FEATURE] AI 이미지 생성 완료 provider=Flux model=\(model) bytes=\(imageData.count)")
                        return (imageData, "flux")
                    }
                }
                throw APIError(code: "E-MAC-AI-1006", message: "AI 이미지 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
            } catch {
                lastError = error
                if let e = error as? APIError, e.status != 404 && e.status != 400 && e.status != -1 {
                    throw error // 모델 부재가 아닌 실패는 즉시 전파
                }
                DebugLogger.warn("Gemini", "Flux 모델 실패 (\(model)) — 폴백 시도")
            }
        }
        if let lastError { throw lastError }
        throw APIError(code: "E-MAC-AI-1005", message: "이미지 생성 실패", status: -1)
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

    // AI 텍스트 응답 (JSON 아님, MD 등) — Gemini → OpenRouter(무료) 체인
    private static func callGeminiText(prompt: String) async throws -> String {
        let text = try await fetchText(prompt: prompt)
        guard !text.isEmpty else {
            throw APIError(code: "E-MAC-AI-1003", message: "AI 응답이 비어 있습니다. 다시 시도해 주세요.", status: -1)
        }
        return text
    }

    // 공통 fetch (Gemini 호출 → 텍스트 추출)
    private static func fetchGeminiText(prompt: String) async throws -> String {
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
        req.timeoutInterval = 60
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

    // ---------- AI 텍스트 체인: Gemini → OpenRouter(무료 모델) 폴백 (T-23) ----------
    // Gemini 키 없음/쿼터(429)/오류 시 OpenRouter 무료 모델로 자동 전환
    // 폴백 모델: gemma-4-31b-it:free → gpt-oss-20b:free (크레딧 불필요)

    private static let openRouterTextModels = ["google/gemma-4-31b-it:free", "openai/gpt-oss-20b:free"]

    private static func fetchText(prompt: String) async throws -> String {
        var lastError: APIError?
        if hasKey {
            do {
                return try await fetchGeminiText(prompt: prompt)
            } catch let e as APIError {
                lastError = e
                DebugLogger.warn("Gemini", "Gemini 텍스트 실패 (\(e.code)) — OpenRouter(무료) 폴백")
            } catch {
                lastError = APIError(code: "E-MAC-AI-1001", message: error.localizedDescription, status: -1)
                DebugLogger.warn("Gemini", "Gemini 텍스트 실패 — OpenRouter(무료) 폴백")
            }
        } else {
            DebugLogger.warn("Gemini", "Gemini 키 없음 — OpenRouter(무료) 사용")
        }
        do {
            return try await fetchOpenRouterText(prompt: prompt)
        } catch {
            if let e = lastError { throw e }
            throw error
        }
    }

    // OpenRouter 무료 모델 호출 — OpenAI 호환 /chat/completions
    private static func fetchOpenRouterText(prompt: String) async throws -> String {
        guard let key = UserDefaults.standard.string(forKey: "openrouterKey"), !key.isEmpty else {
            throw APIError(code: "E-MAC-SET-1001", message: "AI API 키가 설정되지 않았습니다. 설정에서 입력하세요.", status: -1)
        }
        var lastError: APIError?
        for model in openRouterTextModels {
            do {
                guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
                    throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
                }
                let payload: [String: Any] = [
                    "model": model,
                    "messages": [["role": "user", "content": prompt]]
                ]
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = 60
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
                    DebugLogger.info("Gemini", "OpenRouter 텍스트 성공 model=\(model)")
                    return text
                }
                if let parts = message?["content"] as? [[String: Any]] {
                    for p in parts where p["type"] as? String == "text" {
                        if let t = p["text"] as? String, !t.isEmpty {
                            DebugLogger.info("Gemini", "OpenRouter 텍스트 성공 model=\(model)")
                            return t
                        }
                    }
                }
                throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
            } catch let e as APIError {
                lastError = e
                DebugLogger.warn("Gemini", "OpenRouter 모델 실패 (\(model)) — 폴백 시도")
            }
        }
        throw lastError ?? APIError(code: "E-MAC-AI-1007", message: "AI 호출에 실패했습니다. 잠시 후 다시 시도해 주세요.", status: -1)
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
        let text = try await callTextWithRetry(prompt: prompt)
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
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-AI-1004", message: "웹사이트를 불러오지 못했습니다 (HTTP \(code)).", status: code)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw APIError(code: "E-MAC-AI-1004", message: "웹사이트 내용을 읽을 수 없습니다.", status: -1)
        }
        return stripHTML(html)
    }

    private static func stripHTML(_ html: String) -> String {
        var t = html
        t = t.replacingOccurrences(of: #"<script[^>]*>.*?</script>"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"<style[^>]*>.*?</style>"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"&nbsp;"#, with: " ")
        t = t.replacingOccurrences(of: #"&amp;"#, with: "&")
        t = t.replacingOccurrences(of: #"&lt;"#, with: "<")
        t = t.replacingOccurrences(of: #"&gt;"#, with: ">")
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func guideCacheKey(query: String, compareWith: String?, urlContent: String?) -> String {
        let raw = "guide:\(query)|\(compareWith ?? "")|\(urlContent?.prefix(1500) ?? "")"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return "g" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func callTextWithRetry(prompt: String) async throws -> String {
        var lastError: APIError?
        for attempt in 0..<3 {
            if attempt > 0 {
                DebugLogger.warn("Gemini", "503 재시도 (\(attempt + 1)/3)")
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            do {
                return try await callGeminiText(prompt: prompt)
            } catch let e as APIError {
                lastError = e
                if e.status != 503 { throw e }  // 503(일시 과부하)만 재시도
            }
        }
        throw lastError ?? APIError(code: "E-MAC-AI-1001", message: "Gemini 일시 오류 (503). 잠시 후 다시 시도해 주세요.", status: 503)
    }

    // ---------- 맥 소식 일괄 요약 (T-23) ----------
    // RSS 원시 항목 → JSON 배열 [{"title","summary","rating"}] — 요약 2줄 + 소재 추천도
    // 대량 수집 대비 25건씩 청크 분할 호출 (모델 출력 한도 안전)
    static func summarizeNews(_ items: [RawNewsItem]) async throws -> [NewsItem] {
        guard !items.isEmpty else { return [] }
        var all: [NewsItem] = []
        let chunkSize = 25
        var index = 0
        while index < items.count {
            let chunk = Array(items[index..<min(index + chunkSize, items.count)])
            let part = try await summarizeChunk(chunk)
            all.append(contentsOf: part)
            index += chunkSize
            if index < items.count {
                DebugLogger.info("Gemini", "소식 요약 청크 진행 \(index)/\(items.count)건")
            }
        }
        DebugLogger.info("Gemini", "소식 요약 완료 \(items.count)건 → \(all.count)건")
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
        let text = try await callGeminiText(prompt: prompt)
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

    // ```json ... ``` 또는 순수 JSON 배열 추출
    private static func extractJSONArray(from text: String) -> Data? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "")
            t = t.replacingOccurrences(of: "```", with: "")
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = t.firstIndex(of: "["), let end = t.lastIndex(of: "]") else { return nil }
        return String(t[start...end]).data(using: .utf8)
    }

    // ```json ... ``` 또는 순수 JSON 추출
    private static func extractJSON(from text: String) -> Data? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "```json", with: "")
            t = t.replacingOccurrences(of: "```", with: "")
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = t.firstIndex(of: "{"), let end = t.lastIndex(of: "}") else { return nil }
        return String(t[start...end]).data(using: .utf8)
    }
}