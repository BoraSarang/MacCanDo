// [FEATURE] T-96: WebSearchService — DuckDuckGo 웹 검색 (v2.16)
// API 키 불필요, html.duckduckgo.com HTML 파싱
import Foundation

struct SearchResult: Identifiable, Equatable {
    var id: String { url }
    let title: String
    let url: String
    let snippet: String
}

enum WebSearchService {

    /// DuckDuckGo 웹 검색 — 결과 최대 limit개
    static func search(_ query: String, limit: Int = 8) async throws -> [SearchResult] {
        DebugLogger.info("WebSearch", "[FEATURE] 검색 시작: \(query)")

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            throw APIError(code: "E-MAC-NET-1002", message: "검색 주소 생성 실패", status: -1)
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue(WebHelpers.safariUserAgent, forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-NET-1002", message: "웹 검색 실패 (HTTP \(code))", status: code)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw APIError(code: "E-MAC-NET-1002", message: "검색 응답 디코딩 실패", status: -1)
        }

        // 봇 탐지(challenge) 페이지 감지 — 일시 차단이므로 폴백 유도
        if html.contains("anomaly-modal") || html.contains("challenge") {
            DebugLogger.warn("WebSearch", "DDG 봇 탐지 차단 — 잠시 후 재시도 필요")
            throw APIError(code: "E-MAC-NET-1002", message: "웹 검색 일시 차단 (나중에 다시 시도)", status: 403)
        }

        let results = parseDDGResults(html: html).prefix(limit).map { $0 }
        DebugLogger.info("WebSearch", "[FEATURE] 검색 완료: \(results.count)건")
        return results
    }

    // MARK: - DDG HTML 파싱

    /// result__a(제목/링크) + result__snippet(요약, a 또는 div) 정규식 추출
    static func parseDDGResults(html: String) -> [SearchResult] {
        var results: [SearchResult] = []

        // DDG 링크는 //duckduckgo.com/l/?uddg=<인코딩된URL> 형태로 리다이렉트될 수 있음
        let linkPattern = #"<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"s"
        // 스니펫은 a 또는 div 태그로 오기도 함
        let snippetPattern = #"<(?:a|div)[^>]*class="result__snippet"[^>]*>(.*?)</(?:a|div)>"s"

        let links = matches(of: linkPattern, in: html)
        let snippets = matches(of: snippetPattern, in: html)

        for (idx, m) in links.enumerated() {
            let rawHref = String(html[m.1])
            let title = WebHelpers.stripHTML(String(html[m.2])).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let realURL = extractRealURL(from: rawHref), !title.isEmpty else { continue }
            let snippet = idx < snippets.count
                ? WebHelpers.stripHTML(String(html[snippets[idx].1])).trimmingCharacters(in: .whitespacesAndNewlines)
                : ""

            results.append(SearchResult(title: title, url: realURL, snippet: snippet))
        }
        return results
    }

    /// uddg= 파라미터에서 실제 URL 복원 (직접 링크면 그대로 반환)
    private static func extractRealURL(from href: String) -> String? {
        if let range = href.range(of: "uddg=") {
            let tail = String(href[range.upperBound...])
            if let amp = tail.firstIndex(of: "&") {
                let enc = String(tail[..<amp])
                return enc.removingPercentEncoding
            }
            return tail.removingPercentEncoding
        }
        // 직접 링크 (http/https 시작)
        if href.hasPrefix("http") { return href }
        return nil
    }

    private static func matches(of pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let full = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: full)
    }
}
