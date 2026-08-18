// [FEATURE] 로컬 초안 저장소 — SQLite 자동저장 (T-07)
// 편집 중인 게시글을 Application Support/MacCanDo/drafts.sqlite에 저장
// 앱 종료/오프라인에도 초안 유지 → 재실행 시 복구
import Foundation
import SQLite3

struct DraftRecord {
    var postId: String?   // nil = 새 글
    var title: String
    var bodyFormat: String
    var body: String
    var status: String
    var slug: String?
    var seoMeta: SeoMeta?
    var savedAt: Date
}

enum DraftStore {
    private static var db: OpaquePointer?

    // T-26: 새 글 초안은 단일 슬롯 — 자동저장할 때마다 항상 같은 행 갱신 (초안 = 하나의 글)
    static let newPostKey = "draft_new"

    private static var dbPath: String { SQLiteStore.dbPath("drafts.sqlite") }

    static func open() {
        guard SQLiteStore.open(dbPath, into: &db, context: "Draft") else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS drafts (
          post_id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          body_format TEXT NOT NULL DEFAULT 'MD',
          body TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL DEFAULT 'DRAFT',
          slug TEXT,
          saved_at REAL NOT NULL
        );
        """
        SQLiteStore.exec(db, sql: sql, context: "Draft")
        // v1→v2 마이그레이션: slug 컬럼 추가 (T-08) — 이미 존재하면 무시
        SQLiteStore.exec(db, sql: "ALTER TABLE drafts ADD COLUMN slug TEXT;", context: "Draft", silent: true)
        // v2→v3 마이그레이션: seo_meta 컬럼 추가 (T-08 보강)
        SQLiteStore.exec(db, sql: "ALTER TABLE drafts ADD COLUMN seo_meta TEXT;", context: "Draft", silent: true)
        // v3→v4 마이그레이션 (T-26): "__new__" + 기존 "draft_<uuid>" 초안들 → 단일 "draft_new" 슬롯으로 병합
        // (가장 최근 초안 1건만 draft_new로 승격, 나머지 삭제 — 이후 새 키 생성 없음이라 1회로 충분)
        if sqlite3_exec(db, "SELECT COUNT(*) FROM drafts WHERE post_id = '__new__' OR (post_id LIKE 'draft_%' AND post_id != 'draft_new');", nil, nil, nil) == SQLITE_OK {
            let mergeSQL = """
            INSERT INTO drafts (post_id, title, body_format, body, status, slug, seo_meta, saved_at)
            SELECT 'draft_new', title, body_format, body, status, slug, seo_meta, saved_at
            FROM drafts
            WHERE post_id = '__new__' OR (post_id LIKE 'draft_%' AND post_id != 'draft_new')
            ORDER BY saved_at DESC LIMIT 1
            ON CONFLICT(post_id) DO UPDATE SET
              title=excluded.title, body_format=excluded.body_format, body=excluded.body,
              status=excluded.status, slug=excluded.slug, seo_meta=excluded.seo_meta, saved_at=excluded.saved_at;
            DELETE FROM drafts WHERE post_id = '__new__' OR (post_id LIKE 'draft_%' AND post_id != 'draft_new');
            """
            if !SQLiteStore.exec(db, sql: mergeSQL, context: "Draft") {
                DebugLogger.error("Draft", "draft_new 병합 실패")
            }
        }
        // AI SEO 캐시 테이블 (LRU — 최대 100건, T-08)
        let cacheSQL = """
        CREATE TABLE IF NOT EXISTS seo_cache (
          cache_key TEXT PRIMARY KEY,
          suggestion TEXT NOT NULL,
          saved_at REAL NOT NULL
        );
        """
        SQLiteStore.exec(db, sql: cacheSQL, context: "Draft")
        DebugLogger.info("Draft", "SQLite 초기화 완료 (\(dbPath))")
    }

    // 자동저장 (3초 디바운스 호출)
    static func save(postId: String?, title: String, bodyFormat: String, body: String, status: String, slug: String? = nil, seoMeta: SeoMeta? = nil) {
        open()
        guard let db else { return }
        let key = postId ?? "__new__"
        let stmt = "INSERT INTO drafts (post_id, title, body_format, body, status, slug, seo_meta, saved_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(post_id) DO UPDATE SET title=excluded.title, body_format=excluded.body_format, body=excluded.body, status=excluded.status, slug=excluded.slug, seo_meta=excluded.seo_meta, saved_at=excluded.saved_at;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else {
            DebugLogger.error("Draft", "prepare 실패")
            return
        }
        sqlite3_bind_text(p, 1, key, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(p, 2, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(p, 3, bodyFormat, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(p, 4, body, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(p, 5, status, -1, SQLITE_TRANSIENT)
        if let slug {
            sqlite3_bind_text(p, 6, slug, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(p, 6)
        }
        if let seoMeta, let data = try? JSONEncoder().encode(seoMeta) {
            sqlite3_bind_text(p, 7, String(data: data, encoding: .utf8) ?? "", -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(p, 7)
        }
        sqlite3_bind_double(p, 8, Date().timeIntervalSince1970)
        if sqlite3_step(p) == SQLITE_DONE {
            DebugLogger.debug("Draft", "자동저장 완료 (\(key))")
        } else {
            DebugLogger.error("Draft", "자동저장 실패 (\(key))")
        }
        sqlite3_finalize(p)
    }

    static func load(postId: String?) -> DraftRecord? {
        open()
        guard let db else { return nil }
        let key = postId ?? "__new__"
        // T-26: loadDrafts와 동일하게 post_id 포함 8컬럼 SELECT — 컬럼 인덱스 불일치로
        // 초안이 [MD]/[DRAFT]로 오독·재저장되던 버그 수정 (2026-08-17)
        let stmt = "SELECT post_id, title, body_format, body, status, slug, seo_meta, saved_at FROM drafts WHERE post_id = ?;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(p, 1, key, -1, SQLITE_TRANSIENT)
        defer { sqlite3_finalize(p) }
        guard sqlite3_step(p) == SQLITE_ROW else { return nil }
        return draftRecord(from: p, key: key)
    }

    // T-24: 로컬 초안 전체 목록 (새 글 초안: "__new__" 레거시 + "draft_*") — 글 관리 화면 표시용
    static func loadDrafts() -> [DraftRecord] {
        open()
        guard let db else { return [] }
        var result: [DraftRecord] = []
        let stmt = "SELECT post_id, title, body_format, body, status, slug, seo_meta, saved_at FROM drafts WHERE post_id = '__new__' OR post_id LIKE 'draft_%' ORDER BY saved_at DESC;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(p) }
        while sqlite3_step(p) == SQLITE_ROW {
            let key = String(cString: sqlite3_column_text(p, 0))
            var record = draftRecord(from: p, key: key)
            record.title = record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "제목 없음" : record.title
            result.append(record)
        }
        return result
    }

    // T-26: NULL 안전 — title/body/status도 NULL이면 기본값 (크래시 방지, 2026-08-17 크래시 리포트)
    private static func draftRecord(from p: OpaquePointer?, key: String) -> DraftRecord {
        func col(_ i: Int32) -> String? {
            guard sqlite3_column_type(p, i) != SQLITE_NULL,
                  let t = sqlite3_column_text(p, i) else { return nil }
            return String(cString: t)
        }
        let title = col(1) ?? ""
        let format = col(2) ?? "MD"
        let body = col(3) ?? ""
        let status = col(4) ?? "DRAFT"
        let slug = col(5)
        let seoMeta = decodeSeoMeta(p, 6)
        let savedAt = Date(timeIntervalSince1970: sqlite3_column_double(p, 7))
        if col(1) == nil || col(2) == nil || col(3) == nil || col(4) == nil {
            DebugLogger.warn("Draft", "초안 NULL 컬럼 발견 (key=\(key)) — 기본값 처리")
        }
        return DraftRecord(postId: key, title: title, bodyFormat: format, body: body, status: status, slug: slug, seoMeta: seoMeta, savedAt: savedAt)
    }

    static func clear(postId: String?) {
        open()
        guard let db else { return }
        let key = postId ?? "__new__"
        let stmt = "DELETE FROM drafts WHERE post_id = ?;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(p, 1, key, -1, SQLITE_TRANSIENT)
        sqlite3_step(p)
        sqlite3_finalize(p)
        DebugLogger.debug("Draft", "초안 삭제 (\(key))")
    }

    // 전체 초안 목록 (동기화용, T-08)
    static func all() -> [DraftRecord] {
        open()
        guard let db else { return [] }
        let stmt = "SELECT post_id, title, body_format, body, status, slug, seo_meta, saved_at FROM drafts;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(p) }
        var records: [DraftRecord] = []
        while sqlite3_step(p) == SQLITE_ROW {
            let postId = String(cString: sqlite3_column_text(p, 0))
            let title = String(cString: sqlite3_column_text(p, 1))
            let format = String(cString: sqlite3_column_text(p, 2))
            let body = String(cString: sqlite3_column_text(p, 3))
            let status = String(cString: sqlite3_column_text(p, 4))
            let slug = sqlite3_column_type(p, 5) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(p, 5))
            let seoMeta = decodeSeoMeta(p, 6)
            let savedAt = Date(timeIntervalSince1970: sqlite3_column_double(p, 7))
            records.append(DraftRecord(
                postId: postId == "__new__" ? nil : postId,
                title: title, bodyFormat: format, body: body, status: status, slug: slug, seoMeta: seoMeta, savedAt: savedAt
            ))
        }
        return records
    }

    // seo_meta TEXT (JSON) → SeoMeta?
    private static func decodeSeoMeta(_ p: OpaquePointer?, _ col: Int32) -> SeoMeta? {
        guard sqlite3_column_type(p, col) != SQLITE_NULL,
              let raw = sqlite3_column_text(p, col) else { return nil }
        let json = String(cString: raw)
        return try? JSONDecoder().decode(SeoMeta.self, from: Data(json.utf8))
    }

    // ---------- AI SEO 캐시 (LRU) ----------

    static func saveSEOCache(key: String, suggestionJSON: String) {
        open()
        guard let db else { return }
        let stmt = "INSERT INTO seo_cache (cache_key, suggestion, saved_at) VALUES (?, ?, ?) ON CONFLICT(cache_key) DO UPDATE SET suggestion=excluded.suggestion, saved_at=excluded.saved_at;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(p, 1, key, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(p, 2, suggestionJSON, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(p, 3, Date().timeIntervalSince1970)
        sqlite3_step(p)
        sqlite3_finalize(p)
        pruneSEOCache()
    }

    static func loadSEOCache(key: String) -> String? {
        open()
        guard let db else { return nil }
        let stmt = "SELECT suggestion, saved_at FROM seo_cache WHERE cache_key = ?;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(p, 1, key, -1, SQLITE_TRANSIENT)
        defer { sqlite3_finalize(p) }
        guard sqlite3_step(p) == SQLITE_ROW else { return nil }
        // hit 시 saved_at 갱신 (LRU)
        let json = String(cString: sqlite3_column_text(p, 0))
        _ = p
        let touch = "UPDATE seo_cache SET saved_at = ? WHERE cache_key = ?;"
        var tp: OpaquePointer?
        if sqlite3_prepare_v2(db, touch, -1, &tp, nil) == SQLITE_OK {
            sqlite3_bind_double(tp, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text(tp, 2, key, -1, SQLITE_TRANSIENT)
            sqlite3_step(tp)
            sqlite3_finalize(tp)
        }
        return json
    }

    // 최대 100건 유지 — 초과 시 가장 오래된 것부터 삭제
    private static func pruneSEOCache(limit: Int = 100) {
        open()
        guard let db else { return }
        let stmt = """
        DELETE FROM seo_cache WHERE cache_key IN (
          SELECT cache_key FROM seo_cache ORDER BY saved_at DESC LIMIT -1 OFFSET ?
        );
        """
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return }
        sqlite3_bind_int(p, 1, Int32(limit))
        sqlite3_step(p)
        sqlite3_finalize(p)
    }

    static func seoCacheCount() -> Int {
        open()
        guard let db else { return 0 }
        let stmt = "SELECT COUNT(*) FROM seo_cache;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(p) }
        guard sqlite3_step(p) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(p, 0))
    }

    // T-54: AI SEO 캐시 전체 초기화 (설정의 '캐시 초기화' 버튼)
    static func clearSEOCache() {
        open()
        guard let db else { return }
        let stmt = "DELETE FROM seo_cache;"
        var p: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &p, nil) == SQLITE_OK else { return }
        sqlite3_step(p)
        sqlite3_finalize(p)
    }

    // T-54: 캐시 히트/미스 통계 리셋
    static func resetCacheStats() {
        UserDefaults.standard.set(0, forKey: "seoCacheHits")
        UserDefaults.standard.set(0, forKey: "seoCacheMisses")
    }
}