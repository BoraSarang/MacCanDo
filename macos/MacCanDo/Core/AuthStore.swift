// [FEATURE] 인증 스토어 — 관리자 API 토큰 관리 (T-06)
// 웹 /api/auth/token에서 발급한 토큰을 UserDefaults에 저장 (Keychain은 T-08에서)
import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published var token: String? {
        didSet { UserDefaults.standard.set(token, forKey: "apiToken") }
    }

    var isAuthed: Bool { !(token?.isEmpty ?? true) }

    init() {
        token = UserDefaults.standard.string(forKey: "apiToken")
        if token != nil { DebugLogger.info("Auth", "저장된 토큰 로드") }
    }

    func save(_ newToken: String) {
        token = newToken
        DebugLogger.info("Auth", "토큰 저장됨")
    }

    func clear() {
        token = nil
        UserDefaults.standard.removeObject(forKey: "apiToken")
        DebugLogger.info("Auth", "토큰 제거됨")
    }
}