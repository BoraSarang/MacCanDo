// [FEATURE] App Store lookup — T-20 확장 (미리보기 [app:URL] 자동 보강)
// Apple lookup API: https://itunes.apple.com/lookup?id={appId}
// 웹 web/lib/store-fetch.ts와 동일 로직 — 에디터 미리보기에서 [app:URL] 마커의
// 앱 정보를 가져와 정식 앱 카드로 렌더 (저장 전 미리보기 시점에 동작)
import Foundation

struct StoreAppMeta {
    var appId: String
    var appName: String
    var version: String
    var sellerName: String
    var price: String
    var isFree: Bool
    var languages: [String]
    var minimumOsVersion: String?
    var currentVersionReleaseDate: String?
    var rating: Double?
    var ratingCount: Int?
    var artworkUrl100: String?
    var fileSizeBytes: Int?
    var sellerUrl: String?
}

// ISO 639-1 (대문자) → 한국어명 (웹과 동일 매핑)
private let langKo: [String: String] = [
    "EN": "영어", "KO": "한국어", "JA": "일본어",
    "ZH-HANS": "중국어(간체)", "ZH-HANT": "중국어(번체)", "ZH": "중국어",
    "DE": "독일어", "FR": "프랑스어", "ES": "스페인어",
    "IT": "이탈리아어", "PT": "포르투갈어", "RU": "러시아어",
    "NL": "네덜란드어", "SV": "스웨덴어", "PL": "폴란드어",
    "TR": "터키어", "VI": "베트남어", "ID": "인도네시아어",
    "AR": "아랍어", "TH": "태국어", "CS": "체코어",
    "UK": "우크라이나어", "DA": "덴마크어", "FI": "핀란드어",
    "NO": "노르웨이어", "HE": "히브리어", "HU": "헝가리어",
    "RO": "루마니아어", "EL": "그리스어", "HI": "힌디어",
    "MS": "말레이어",
]

private func langToKo(_ code: String) -> String {
    langKo[code.uppercased()] ?? code
}

enum AppStoreLookup {
    // App Store URL에서 앱 ID 추출: /id{digits} 또는 순수 숫자
    static func parseAppId(_ url: String) -> String? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let m = trimmed.range(of: #"/id(\d{6,12})\b"#, options: .regularExpression) {
            let idPart = trimmed[m]
            if let digits = idPart.range(of: #"\d{6,12}"#, options: .regularExpression) {
                return String(idPart[digits])
            }
        }
        if trimmed.range(of: #"^\d{6,12}$"#, options: .regularExpression) != nil {
            return trimmed
        }
        return nil
    }

    // https://itunes.apple.com/lookup?id={appId} → 앱 메타 (실패/비맥앱이면 nil)
    static func lookup(url: String) async throws -> StoreAppMeta? {
        guard let appId = parseAppId(url),
              let api = URL(string: "https://itunes.apple.com/lookup?id=\(appId)") else {
            return nil
        }
        var req = URLRequest(url: api)
        req.timeoutInterval = 8
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let r = results.first else {
            DebugLogger.warn("StoreLookup", "App Store 조회 실패 (id=\(appId))")
            return nil
        }
        let kind = r["kind"] as? String
        // mac-software = 순수 macOS, software = macOS/iOS 겸용(Catalyst) — 둘 다 허용
        guard kind == "mac-software" || kind == "software" else {
            DebugLogger.warn("StoreLookup", "App Store 조회 실패 (kind=\(kind ?? "?"), id=\(appId))")
            return nil
        }
        let languages = (r["languages"] as? [String])?.map { langToKo($0) } ?? []
        let price: Double = r["price"] as? Double ?? 1
        let meta = StoreAppMeta(
            appId: appId,
            appName: r["trackName"] as? String ?? "",
            version: r["version"] as? String ?? "",
            sellerName: r["sellerName"] as? String ?? "",
            price: r["formattedPrice"] as? String ?? (price == 0 ? "무료" : ""),
            isFree: price == 0,
            languages: languages,
            minimumOsVersion: r["minimumOsVersion"] as? String,
            currentVersionReleaseDate: r["currentVersionReleaseDate"] as? String,
            rating: r["averageUserRating"] as? Double,
            ratingCount: r["userRatingCount"] as? Int,
            artworkUrl100: r["artworkUrl100"] as? String,
            fileSizeBytes: r["fileSizeBytes"] as? Int,
            sellerUrl: r["sellerUrl"] as? String
        )
        DebugLogger.info("StoreLookup", "App Store 조회 성공: \(meta.appName) (id=\(appId))")
        return meta
    }
}
