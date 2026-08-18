// [FEATURE] 에러 메시지 로더 — T-63 P5
// 루트 error_message_ko.json (앱 번들 리소스) → E-MAC-* 코드 → 한국어 사용자 메시지
// 실패 시 코드 문자열 그대로 반환 (web apiError와 동일 폴백 규칙)
import Foundation

enum ErrorMessages {
    private static let cache: [String: String] = {
        guard let url = Bundle.main.url(forResource: "error_message_ko", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }()

    static func message(_ code: String) -> String {
        cache[code] ?? code
    }
}