// MacCanDo API 클라이언트 (8.6장 GBridge 규격)
// 모든 호출: DebugLogger에 API→ / API← 로깅 (DebugPanel 실시간 표시)
// 오프라인: 실패 시 OfflineQueue에 적재 (T-08에서 연동)

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case network(Error)
    case server(status: Int, code: String, message: String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "E-MAC-BRIDGE-1001"
        case .network: return "E-MAC-NET-1001"
        case let .server(_, code, message): return "\(code) \(message)"
        case .decoding: return "E-MAC-BRIDGE-1001"
        }
    }
}

struct APIResponse<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: APIErrorBody?
}

struct APIErrorBody: Decodable {
    let code: String
    let message: String
}

final class APIClient {
    static let shared = APIClient()
    private let session: URLSession
    private var baseURL: URL

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
        // 개발: 로컬 서버, 배포: 프로덕션 URL (Info.plist/설정에서 주입)
        baseURL = URL(string: ProcessInfo.processInfo.environment["MACCANDO_API_URL"] ?? "http://localhost:3000")!
    }

    // MARK: - 공통 요청

    func request<T: Decodable>(
        _ method: String,
        _ path: String,
        body: Data? = nil,
        as type: T.Type
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            DebugLogger.shared.error("API", "E-MAC-BRIDGE-1001 잘못된 URL: \(path)")
            throw APIError.invalidURL
        }

        DebugLogger.shared.apiRequest(method, path)
        let start = Date()

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = body }

        do {
            let (data, response) = try await session.data(for: req)
            let ms = Int(Date().timeIntervalSince(start) * 1000)

            guard let http = response as? HTTPURLResponse else {
                DebugLogger.shared.error("API", "E-MAC-NET-1001 응답 없음: \(path)")
                throw APIError.network(URLError(.badServerResponse))
            }

            if (200...299).contains(http.statusCode) {
                DebugLogger.shared.apiResponse(method, path, http.statusCode, ms)
                let decoded = try JSONDecoder().decode(APIResponse<T>.self, from: data)
                if let d = decoded.data { return d }
                throw APIError.decoding(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "data 없음")))
            } else {
                DebugLogger.shared.apiResponse(method, path, http.statusCode, ms)
                let err = try? JSONDecoder().decode(APIResponse<EmptyData>.self, from: data)
                let code = err?.error?.code ?? "E-MAC-BRIDGE-1001"
                let message = err?.error?.message ?? "HTTP \(http.statusCode)"
                DebugLogger.shared.error("API", "\(code) \(message)")
                throw APIError.server(status: http.statusCode, code: code, message: message)
            }
        } catch let e as APIError {
            throw e
        } catch {
            DebugLogger.shared.warn("API", "E-MAC-NET-1001 오프라인 가능성: \(path) — 큐 적재 예정(T-08)")
            throw APIError.network(error)
        }
    }
}

struct EmptyData: Decodable {}