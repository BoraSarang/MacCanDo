// [FEATURE] 참고 자료 로컬 저장소 (T-26) — AI 도우미 생성 결과를 SQLite에 저장·리스트 관리
// 매번 AI 호출하지 않고 과거 조회 결과를 재사용 (생성 시 자동 저장, 목록에서 선택/삭제)
import Foundation
import SQLite3

struct ReferenceEntry: Identifiable {
    let id: String
    let query: String
    let compareWith: String
    let result: String
    let createdAt: Date
}

enum ReferenceStore {
    private static var db: OpaquePointer?

    private static var dbPath: String { SQLiteStore.dbPath("references.sqlite") }

    static func open() {
        guard SQLiteStore.open(dbPath, into: &db, context: "Reference") else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS reference_entries (
          id TEXT PRIMARY KEY,
          query TEXT NOT NULL,
          compare_with TEXT NOT NULL DEFAULT '',
          result TEXT NOT NULL,
          created_at REAL NOT NULL,
          UNIQUE(query, compare_with)
        );
        """
        SQLiteStore.exec(db, sql: sql, context: "Reference")
        DebugLogger.info("Reference", "SQLite 초기화 완료 (\(dbPath))")
    }

    // 저장 (같은 쿼리+비교대상이면 갱신) — 최신 결과가 상단
    @discardableResult
    static func save(query: String, compareWith: String, result: String) -> ReferenceEntry? {
        if db == nil { open() }
        guard let db else { return nil }
        let id = UUID().uuidString
        let createdAt = Date().timeIntervalSince1970
        let stmt = """
        INSERT INTO reference_entries (id, query, compare_with, result, created_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(query, compare_with) DO UPDATE SET
          result = excluded.result, created_at = excluded.created_at;
        """
        var sp: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &sp, nil) == SQLITE_OK else {
            sqlite3_finalize(sp)
            return nil
        }
        sqlite3_bind_text(sp, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(sp, 2, query, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(sp, 3, compareWith, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(sp, 4, result, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(sp, 5, createdAt)
        let ok = sqlite3_step(sp) == SQLITE_DONE
        sqlite3_finalize(sp)
        DebugLogger.info("Reference", "저장 완료 (\(query))")
        return ok ? ReferenceEntry(id: id, query: query, compareWith: compareWith, result: result, createdAt: Date(timeIntervalSince1970: createdAt)) : nil
    }

    static func loadAll() -> [ReferenceEntry] {
        if db == nil { open() }
        guard let db else { return [] }
        var entries: [ReferenceEntry] = []
        let stmt = "SELECT id, query, compare_with, result, created_at FROM reference_entries ORDER BY created_at DESC;"
        var sp: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &sp, nil) == SQLITE_OK else {
            sqlite3_finalize(sp)
            return []
        }
        while sqlite3_step(sp) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(sp, 0))
            let query = String(cString: sqlite3_column_text(sp, 1))
            let compare = String(cString: sqlite3_column_text(sp, 2))
            let result = String(cString: sqlite3_column_text(sp, 3))
            let createdAt = sqlite3_column_double(sp, 4)
            entries.append(ReferenceEntry(id: id, query: query, compareWith: compare, result: result, createdAt: Date(timeIntervalSince1970: createdAt)))
        }
        sqlite3_finalize(sp)
        return entries
    }

    static func delete(id: String) {
        if db == nil { open() }
        guard let db else { return }
        let stmt = "DELETE FROM reference_entries WHERE id = ?;"
        var sp: OpaquePointer?
        guard sqlite3_prepare_v2(db, stmt, -1, &sp, nil) == SQLITE_OK else {
            sqlite3_finalize(sp)
            return
        }
        sqlite3_bind_text(sp, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_step(sp)
        sqlite3_finalize(sp)
        DebugLogger.info("Reference", "삭제 완료 (\(id.prefix(8)))")
    }
}
