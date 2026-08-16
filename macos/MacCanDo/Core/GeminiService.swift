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
        let text = try await fetchGeminiText(prompt: prompt)
        guard let jsonData = extractJSON(from: text),
              let suggestion = try? JSONDecoder().decode(SEOSuggestion.self, from: jsonData) else {
            throw APIError(code: "E-MAC-AI-1003", message: "AI 응답을 해석하지 못했습니다. 다시 시도해 주세요.", status: -1)
        }
        return suggestion
    }

    // Gemini 텍스트 응답 (JSON 아님, MD 등)
    private static func callGeminiText(prompt: String) async throws -> String {
        let text = try await fetchGeminiText(prompt: prompt)
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