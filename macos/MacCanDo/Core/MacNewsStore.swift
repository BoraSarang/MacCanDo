// [FEATURE] 맥 소식 리포트 (T-23) — RSS 소스 수집 + AI 요약 + 로컬 저장
// 1회 수집 = 1개 리포트 (reports 테이블), 소스 관리는 sources 테이블 (로컬 SQLite)
// 수집 흐름: RSS fetch → XML 파싱 → 중복 링크 제외 → Gemini 체인 일괄 요약 → 리포트 저장
import Foundation
import SQLite3


// RSS 항목 (요약 전)
struct RawNewsItem {
    let title: String
    let url: String
    let source: String
    let published: String
}

// 요약된 소식 항목
struct NewsItem: Codable, Identifiable {
    var id: String { url }
    let title: String
    let url: String
    let source: String
    let published: String
    let summary: String
    let rating: String   // "추천" | "보통"
}

// 1회 수집 결과 리포트
struct NewsReport: Codable, Identifiable {
    let id: String       // UUID
    let createdAt: Date
    let items: [NewsItem]
}

// 소스 (설정에서 추가/삭제)
struct NewsSource: Codable, Identifiable {
    var id: String       // UUID
    var name: String
    var url: String
    var isActive: Bool
}

enum MacNewsStore {
    private static var db: OpaquePointer?

    // 기본 소스 — 최초 실행 시 시드 (사용자가 추가/삭제 가능)
    // v2: 2026-08 검증된 RSS/Atom 피드만 (404/비RSS 제외: MacUpdate, Setapp, Intego, MacPaw)
    static let defaultSources: [(name: String, url: String)] = [
        // 종합 Mac/Apple 뉴스
        ("MacRumors", "https://feeds.macrumors.com/MacRumors-All"),
        ("9to5Mac", "https://9to5mac.com/feed/"),
        ("iMore", "https://www.imore.com/feeds.xml"),
        ("The Verge", "https://www.theverge.com/rss/index.xml"),
        ("AppleInsider", "https://appleinsider.com/rss/news/"),
        ("Macworld", "https://www.macworld.com/feed"),
        ("MacDailyNews", "https://macdailynews.com/feed/"),
        ("Apple Newsroom", "https://www.apple.com/newsroom/rss-feed.rss"),
        // 신규 앱/소프트웨어
        ("Mac App Store 신규", "https://itunes.apple.com/kr/rss/newapplications/limit=50/genre=12007/xml"),
        ("Product Hunt", "https://www.producthunt.com/feed?category=macos"),
        ("The Sweet Setup", "https://thesweetsetup.com/feed/"),
        ("Nektony", "https://nektony.com/feed"),
        // 기술/심층 분석
        ("TidBITS", "https://tidbits.com/feed/"),
        ("Ars Technica Apple", "https://arstechnica.com/apple/feed/"),
        ("Eclectic Light", "https://eclecticlight.co/feed/"),
        ("MacTech", "https://www.mactech.com/feed"),
        // 기타
        ("MacSparky", "https://www.macsparky.com/feed"),
        ("Mac Observer", "https://www.macobserver.com/feed/"),
        ("MacPrices", "https://www.macprices.net/feed"),
        ("맥쓰는사람들", "https://macnews.tistory.com/feed")
    ]

    private static var dbPath: String { SQLiteStore.dbPath("news.sqlite") }

    static func open() {
        guard SQLiteStore.open(dbPath, into: &db, context: "News") else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS news_sources (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE IF NOT EXISTS news_reports (
          id TEXT PRIMARY KEY,
          created_at REAL NOT NULL,
          items_json TEXT NOT NULL
        );
        """
        SQLiteStore.exec(db, sql: sql, context: "News")
        seedDefaultSourcesIfNeeded()
        DebugLogger.info("News", "SQLite 초기화 완료 (\(dbPath))")
    }

    private static func seedDefaultSourcesIfNeeded() {
        guard let db else { return }
        // v1: 소스 테이블이 비어 있으면 전부 시드
        var count: Int64 = 0
        let countSQL = "SELECT COUNT(*) FROM news_sources;"
        var p: OpaquePointer?
        if sqlite3_prepare_v2(db, countSQL, -1, &p, nil) == SQLITE_OK, sqlite3_step(p) == SQLITE_ROW {
            count = sqlite3_column_int64(p, 0)
        }
        sqlite3_finalize(p)
        if count == 0 {
            for (name, url) in defaultSources {
                insertSource(name: name, url: url)
            }
            UserDefaults.standard.set(true, forKey: "newsDefaultSourcesV2Seeded")
            DebugLogger.info("News", "기본 소스 \(defaultSources.count)개 시드됨")
            return
        }
        // v2 마이그레이션: 기존 DB에 없는 새 기본 소스만 1회 추가
        // (사용자가 삭제한 소스는 재추가하지 않도록 플래그로 1회만 실행)
        if !UserDefaults.standard.bool(forKey: "newsDefaultSourcesV2Seeded") {
            let existing = loadSources().map(\.name)
            var added = 0
            for (name, url) in defaultSources where !existing.contains(name) {
                insertSource(name: name, url: url)
                added += 1
            }
            UserDefaults.standard.set(true, forKey: "newsDefaultSourcesV2Seeded")
            DebugLogger.info("News", "v2 소스 마이그레이션: \(added)개 추가")
        }
    }

    private static func insertSource(name: String, url: String) {
        guard let db else { return }
        let id = UUID().uuidString
        let stmt = "INSERT INTO news_sources (id, name, url, is_active) VALUES (?, ?, ?, 1);"
        var sp: OpaquePointer?
        if sqlite3_prepare_v2(db, stmt, -1, &sp, nil) == SQLITE_OK {
            sqlite3_bind_text(sp, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(sp, 2, name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(sp, 3, url, -1, SQLITE_TRANSIENT)
            sqlite3_step(sp)
        }
        sqlite3_finalize(sp)
    }

    // ---------- 소스 CRUD ----------

    static func loadSources() -> [NewsSource] {
        open()
        guard let db else { return [] }
        var result: [NewsSource] = []
        let stmt = "SELECT id, name, url, is_active FROM news_sources ORDER BY name;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(p) }
        while sqlite3_step(p) == SQLITE_ROW {
            result.append(NewsSource(
                id: String(cString: sqlite3_column_text(p, 0)),
                name: String(cString: sqlite3_column_text(p, 1)),
                url: String(cString: sqlite3_column_text(p, 2)),
                isActive: sqlite3_column_int64(p, 3) != 0
            ))
        }
        return result
    }

    static func addSource(name: String, url: String) {
        open()
        guard let db else { return }
        let id = UUID().uuidString
        let stmt = "INSERT INTO news_sources (id, name, url, is_active) VALUES (?, ?, ?, 1);"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(p, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(p, 2, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(p, 3, url, -1, SQLITE_TRANSIENT)
        sqlite3_step(p)
        sqlite3_finalize(p)
        DebugLogger.info("News", "소스 추가: \(name)")
    }

    static func deleteSource(id: String) {
        open()
        guard let db else { return }
        let stmt = "DELETE FROM news_sources WHERE id = ?;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(p, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_step(p)
        sqlite3_finalize(p)
    }

    // ---------- 리포트 CRUD ----------

    static func saveReport(_ report: NewsReport) {
        open()
        guard let db else { return }
        guard let data = try? JSONEncoder().encode(report) else { return }
        let stmt = "INSERT INTO news_reports (id, created_at, items_json) VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET created_at=excluded.created_at, items_json=excluded.items_json;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(p, 1, report.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(p, 2, report.createdAt.timeIntervalSince1970)
        sqlite3_bind_text(p, 3, String(data: data, encoding: .utf8) ?? "", -1, SQLITE_TRANSIENT)
        sqlite3_step(p)
        sqlite3_finalize(p)
        DebugLogger.info("News", "리포트 저장 (\(report.items.count)건)")
    }

    // 최신순 리포트 목록
    static func loadReports() -> [NewsReport] {
        open()
        guard let db else { return [] }
        var result: [NewsReport] = []
        let stmt = "SELECT id, created_at, items_json FROM news_reports ORDER BY created_at DESC;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(p) }
        while sqlite3_step(p) == SQLITE_ROW {
            let json = String(cString: sqlite3_column_text(p, 2))
            if let data = json.data(using: .utf8),
               let report = try? JSONDecoder().decode(NewsReport.self, from: data) {
                result.append(report)
            }
        }
        return result
    }

    static func deleteReport(id: String) {
        open()
        guard let db else { return }
        let stmt = "DELETE FROM news_reports WHERE id = ?;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(p, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_step(p)
        sqlite3_finalize(p)
    }

    // 저장된 리포트의 전체 링크 (중복 수집 방지)
    static func collectedURLs() -> Set<String> {
        var urls = Set<String>()
        for report in loadReports() {
            for item in report.items {
                urls.insert(item.url)
            }
        }
        return urls
    }
}

// ---------- RSS XML 파서 ----------
private final class RSSParserDelegate: NSObject, XMLParserDelegate {
    var items: [RawNewsItem] = []
    private var inItem = false
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentElement = ""
    private var sourceName = ""
    private var collectedText = ""

    init(sourceName: String) {
        self.sourceName = sourceName
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "item" || elementName == "entry" {
            inItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
            return
        }
        if inItem {
            currentElement = elementName
            collectedText = ""
            if elementName == "link", let href = attributeDict["href"] {
                currentLink = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inItem { collectedText += string }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if inItem, let s = String(data: CDATABlock, encoding: .utf8) {
            collectedText += s
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard inItem else { return }
        let text = collectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "title": currentTitle = text
        case "link": if currentLink.isEmpty { currentLink = text }
        case "pubDate", "published", "updated", "dc:date": currentPubDate = text
        default: break
        }
        if elementName == "item" || elementName == "entry" {
            let cleanTitle = WebHelpers.stripHTML(currentTitle)
            if !cleanTitle.isEmpty, !currentLink.isEmpty {
                items.append(RawNewsItem(title: cleanTitle, url: currentLink, source: sourceName, published: currentPubDate))
            }
            inItem = false
        }
    }

}

// ---------- 수집 파이프라인 ----------
enum NewsCollector {
    // 소스 RSS fetch → 원시 항목 (소스당 최신 limit개)
    static func fetchRaw(source: NewsSource, limit: Int = 8) async throws -> [RawNewsItem] {
        guard let url = URL(string: source.url.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw APIError(code: "E-MAC-NEWS-1001", message: "잘못된 소스 주소: \(source.name)", status: -1)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue(WebHelpers.safariUserAgent, forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(code: "E-MAC-NEWS-1001", message: "RSS 수집 실패 (\(source.name), HTTP \(code))", status: code)
        }
        let delegate = RSSParserDelegate(sourceName: source.name)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return Array(delegate.items.prefix(limit))
    }

    // 전체 수집 실행: 소스별 병렬 fetch → 중복 제외 → AI 일괄 요약 → 리포트
    // 실패한 소스는 건너뛰고 나머지로 계속 (마지막에 실패 목록 반환)
    static func collect(progress: @escaping (String) -> Void) async throws -> (report: NewsReport, failed: [String]) {
        let sources = MacNewsStore.loadSources().filter(\.isActive)
        let existing = MacNewsStore.collectedURLs()
        // 병렬 fetch — 소스별 TaskGroup (RSS 20개 순차 대기 방지)
        var rawBySource: [String: [RawNewsItem]] = [:]
        var failed: [String] = []
        await withTaskGroup(of: (String, [RawNewsItem]?, String?).self) { group in
            for source in sources {
                group.addTask {
                    do {
                        let items = try await fetchRaw(source: source)
                        return (source.name, items, nil)
                    } catch {
                        DebugLogger.warn("News", "\(source.name) 수집 실패: \(error)")
                        return (source.name, nil, source.name)
                    }
                }
            }
            for await (name, items, failure) in group {
                if let failure {
                    failed.append(failure)
                    DebugLogger.warn("News", "\(name) 수집 실패")
                } else if let items {
                    rawBySource[name] = items
                }
            }
        }
        // 중복 제외
        var raw: [RawNewsItem] = []
        var addedBySource: [String: Int] = [:]
        for (name, items) in rawBySource {
            var added = 0
            for item in items where !existing.contains(item.url) {
                raw.append(item)
                added += 1
            }
            addedBySource[name] = added
        }
        let addedTotal = raw.count
        let progressSummary = rawBySource.keys.sorted().map { "\($0)+\(addedBySource[$0] ?? 0)" }.joined(separator: ", ")
        progress("수집 완료 \(addedTotal)건 (중복 제외) — \(progressSummary)")
        guard !raw.isEmpty else {
            let empty = NewsReport(id: UUID().uuidString, createdAt: Date(), items: [])
            return (empty, failed)
        }
        progress("AI 요약 중 (\(raw.count)건)…")
        let summarized = try await GeminiService.summarizeNews(raw)
        let report = NewsReport(id: UUID().uuidString, createdAt: Date(), items: summarized)
        MacNewsStore.saveReport(report)
        return (report, failed)
    }
}
