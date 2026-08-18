// [FEATURE] 웹 공용 헬퍼 — T-63 P4 리팩토링
// User-Agent / HTML→텍스트 스트립 (GeminiService.fetchURLText + MacNewsStore.fetchRaw 공용)
import Foundation

enum WebHelpers {
    // RSS/웹사이트 페치용 Safari UA (GeminiService + MacNewsStore 공용 — 봇 차단 회피)
    static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    // HTML → 텍스트 (script/style 제거 + 엔티티 디코드 + 공백 정규화)
    static func stripHTML(_ html: String) -> String {
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
}
