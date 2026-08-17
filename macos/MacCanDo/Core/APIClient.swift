// [FEATURE] API 클라이언트 — macOS 앱 → 웹 API (T-06)
// Bearer 토큰 인증 (관리자 API 토큰), 응답 규격 { ok, data | error }
import Foundation

struct APIError: Error {
    let code: String
    let message: String
    let status: Int
}

struct APIResponse<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: APIFailure?
}

struct APIFailure: Decodable {
    let code: String
    let message: String
}

struct APIEmptyData: Decodable {}

enum APIClient {
    static var baseURL = URL(string: "http://localhost:3000")!

    static func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        token: String? = nil,
        body: Encodable? = nil
    ) async throws -> T {
        // 쿼리스트링 포함 경로 대응 (URL(string:relativeTo:) 우선)
        let url: URL
        if let u = URL(string: path, relativeTo: baseURL) {
            url = u
        } else {
            url = baseURL.appendingPathComponent(path)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }

        DebugLogger.debug("API", "→ \(method) \(path)")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError(code: "E-MAC-NET-1001", message: "네트워크 응답 오류", status: -1)
        }

        let decoded = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        if !decoded.ok {
            let e = decoded.error ?? APIFailure(code: "E-MAC-NET-1001", message: "알 수 없는 오류")
            DebugLogger.error("API", "← \(http.statusCode) \(path) \(e.code)")
            throw APIError(code: e.code, message: e.message, status: http.statusCode)
        }
        guard let data = decoded.data else {
            throw APIError(code: "E-MAC-NET-1001", message: "데이터 없음", status: http.statusCode)
        }
        DebugLogger.debug("API", "← \(http.statusCode) \(path)")
        return data
    }

    // ---------- 이미지 업로드 (multipart/form-data → POST /api/admin/uploads) ----------

    static func uploadImage(token: String?, fileURL: URL) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "api/admin/uploads", relativeTo: baseURL) else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let mime = mimeType(for: fileURL.pathExtension)
        var body = Data()
        let head = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\nContent-Type: \(mime)\r\n\r\n"
        body.append(head.data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        DebugLogger.debug("API", "→ POST api/admin/uploads (\(fileData.count) bytes)")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError(code: "E-MAC-NET-1001", message: "업로드 실패", status: (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        struct UploadResponse: Decodable {
            struct Data: Decodable { let url: String }
            let ok: Bool
            let data: Data?
            let error: APIFailure?
        }
        let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
        guard decoded.ok, let url = decoded.data?.url else {
            let e = decoded.error ?? APIFailure(code: "E-MAC-NET-1001", message: "업로드 실패")
            throw APIError(code: e.code, message: e.message, status: http.statusCode)
        }
        DebugLogger.debug("API", "← 200 api/admin/uploads")
        return url
    }

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }

    // ---------- 홈페이지 주소 (설정에서 변경, "웹에서 보기"에 사용) ----------
    static var webURL: URL {
        if let s = UserDefaults.standard.string(forKey: "webURL"),
           !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return u
        }
        return URL(string: "http://localhost:3000")!
    }

    // 업로드된 이미지 목록 (최신순, DB 기반 — 캡션/사용처 포함)
    struct UploadItem: Decodable, Identifiable {
        let url: String
        let name: String
        let size: Int
        let date: String
        let caption: String?
        let postTitle: String?
        var id: String { url }

        var sizeLabel: String {
            if size >= 1024 * 1024 { return String(format: "%.1f MB", Double(size) / 1024 / 1024) }
            return String(format: "%.0f KB", Double(size) / 1024)
        }
    }

    static func fetchUploads(token: String?) async throws -> [UploadItem] {
        guard let url = URL(string: "api/admin/uploads", relativeTo: baseURL) else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-NET-1001", message: "이미지 목록 조회 실패 (HTTP \(code))", status: code)
        }
        struct Response: Decodable {
            struct Data: Decodable { let images: [UploadItem] }
            let ok: Bool
            let data: Data?
            let error: APIFailure?
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard decoded.ok, let images = decoded.data?.images else {
            let e = decoded.error ?? APIFailure(code: "E-MAC-NET-1001", message: "이미지 목록 조회 실패")
            throw APIError(code: e.code, message: e.message, status: http.statusCode)
        }
        return images
    }

    static func deleteUpload(token: String?, name: String) async throws {
        guard let url = URL(string: "api/admin/uploads?name=\(name)", relativeTo: baseURL) else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.timeoutInterval = 30
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-NET-1001", message: "이미지 삭제 실패 (HTTP \(code))", status: code)
        }
    }

    // 캡션 수정
    static func updateUploadCaption(token: String?, name: String, caption: String) async throws {
        struct Body: Encodable { let caption: String }
        guard let url = URL(string: "api/admin/uploads?name=\(name)", relativeTo: baseURL) else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(Body(caption: caption))
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-NET-1001", message: "캡션 수정 실패 (HTTP \(code))", status: code)
        }
    }

    // ---------- 동기화 (T-08) ----------

    struct SyncPost: Encodable {
        let localPostId: String?
        let title: String
        let slug: String?
        let body: String
        let bodyFormat: String
        let status: String
        let updatedAt: String
    }

    struct SyncResult: Decodable {
        let synced: Int
        let skipped: Int
        struct Item: Decodable {
            let localPostId: String?
            let slug: String
            let id: String
            let synced: Bool
        }
        let results: [Item]
    }

    static func syncBulk(token: String?, posts: [SyncPost]) async throws -> SyncResult {
        struct Body: Encodable { let posts: [SyncPost] }
        guard let url = URL(string: "api/admin/sync/bulk", relativeTo: baseURL) else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(Body(posts: posts))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-NET-1001", message: "동기화 실패 (HTTP \(code))", status: code)
        }
        return try JSONDecoder().decode(SyncResult.self, from: data)
    }

    // ---------- 백업/복원 (T-08) ----------

    struct BackupData: Codable {
        let exportedAt: String
        let app: String
        let version: Int
        let categories: [BackupCategory]
        let posts: [BackupPost]
        let comments: [BackupComment]

        struct BackupCategory: Codable {
            let id: String?
            let slug: String
            let name: String
        }
        struct BackupPost: Codable {
            let id: String?
            let title: String
            let slug: String
            let bodyFormat: String?
            let body: String
            let excerpt: String?
            let thumbnailUrl: String?
            let status: String?
            let categorySlug: String?
            let viewCount: Int?
            let publishedAt: String?
            let createdAt: String?
            let updatedAt: String?
        }
        struct BackupComment: Codable {
            let id: String?
            let postSlug: String?
            let content: String
            let status: String?
            let createdAt: String?
        }
    }

    struct RestoreResult: Decodable {
        let categories: Int
        let posts: Int
        let comments: Int
        let skipped: Int
    }

    static func fetchBackup(token: String?) async throws -> BackupData {
        guard let url = URL(string: "api/admin/backup", relativeTo: baseURL) else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 60
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-NET-1001", message: "백업 다운로드 실패 (HTTP \(code))", status: code)
        }
        return try JSONDecoder().decode(BackupData.self, from: data)
    }

    static func restoreBackup(token: String?, data: BackupData) async throws -> RestoreResult {
        guard let url = URL(string: "api/admin/backup", relativeTo: baseURL) else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(data)
        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-NET-1001", message: "복원 실패 (HTTP \(code))", status: code)
        }
        return try JSONDecoder().decode(RestoreResult.self, from: respData)
    }

    // ---------- 시리즈 (관리자) — /api/admin/series (사용자 요청) ----------

    // 목록 (+시리즈 없는 글, q=제목 검색 — 최근 글부터) — GET /api/admin/series
    static func fetchSeries(token: String?, q: String? = nil) async throws -> AdminSeriesData {
        var path = "api/admin/series"
        if let q, !q.isEmpty {
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            path += "?q=\(encoded)"
        }
        return try await request(path, token: token)
    }

    // 생성 — POST /api/admin/series
    static func createSeries(token: String?, title: String, description: String?, imageUrl: String? = nil, intro: String? = nil) async throws -> SeriesItem {
        try await request(
            "api/admin/series",
            method: "POST",
            token: token,
            body: SeriesCreateBody(title: title, description: description, imageUrl: imageUrl, intro: intro)
        )
    }

    // 이름/설명/커버/취지 변경 — PATCH /api/admin/series/[id]
    static func updateSeries(token: String?, id: String, title: String?, description: String?, imageUrl: String? = nil, intro: String? = nil) async throws -> SeriesItem {
        try await request(
            "api/admin/series/\(id)",
            method: "PATCH",
            token: token,
            body: SeriesUpdateBody(title: title, description: description, imageUrl: imageUrl, intro: intro)
        )
    }

    // 삭제 (글은 유지) — DELETE /api/admin/series/[id]
    static func deleteSeries(token: String?, id: String) async throws {
        let _: APIEmptyData = try await request("api/admin/series/\(id)", method: "DELETE", token: token)
    }

    // 홈 배너 지정/해제 — PATCH /api/admin/series/[id] (featuredOrder만 전송)
    static func setSeriesFeatured(token: String?, id: String, order: Int?) async throws -> SeriesItem {
        try await request(
            "api/admin/series/\(id)",
            method: "PATCH",
            token: token,
            body: FeaturedOrderBody(featuredOrder: order)
        )
    }

    // 홈 추천 지정/해제 — PATCH /api/admin/posts/[id]/featured
    struct FeaturedBody: Encodable {
        let order: Int?
    }
    static func setPostFeatured(token: String?, id: String, order: Int?) async throws {
        let _: APIEmptyData = try await request(
            "api/admin/posts/\(id)/featured",
            method: "PATCH",
            token: token,
            body: FeaturedBody(order: order)
        )
    }

    // 글 추가 — POST /api/admin/series/[id]/posts
    static func addPostsToSeries(token: String?, seriesId: String, postIds: [String]) async throws {
        let _: APIEmptyData = try await request(
            "api/admin/series/\(seriesId)/posts",
            method: "POST",
            token: token,
            body: PostIdsBody(postIds: postIds)
        )
    }

    // 순서 저장 (배열 순서 = 1편, 2편...) — PATCH /api/admin/series/[id]/posts
    static func setSeriesOrder(token: String?, seriesId: String, postIds: [String]) async throws {
        let _: APIEmptyData = try await request(
            "api/admin/series/\(seriesId)/posts",
            method: "PATCH",
            token: token,
            body: PostIdsBody(postIds: postIds)
        )
    }

    // 글 제거 (글 자체는 유지) — DELETE /api/admin/series/[id]/posts?postId=
    static func removePostFromSeries(token: String?, seriesId: String, postId: String) async throws {
        let _: APIEmptyData = try await request(
            "api/admin/series/\(seriesId)/posts?postId=\(postId)",
            method: "DELETE",
            token: token
        )
    }

    // ---------- 디버그 패널: 서버 로그 조회 (자체 로그 미발생 — 폴링 잡음 방지) ----------

    struct ServerLogEntry: Codable, Identifiable {
        let time: String
        let level: String
        let platform: String
        let category: String
        let message: String
        let meta: String?
        let text: String
        var id: String { text }
    }

    struct ServerLogs: Codable {
        let total: Int
        let logs: [ServerLogEntry]
    }

    static func fetchServerLogs(token: String?, limit: Int = 300, level: String = "", category: String = "") async throws -> ServerLogs {
        var path = "api/debug/logs?limit=\(limit)"
        if !level.isEmpty { path += "&level=\(level)" }
        if !category.isEmpty { path += "&category=\(category)" }
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError(code: "E-MAC-NET-1001", message: "잘못된 URL", status: -1)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-NET-1001", message: "서버 로그 조회 실패 (HTTP \(code))", status: code)
        }
        return try JSONDecoder().decode(ServerLogs.self, from: data)
    }
}