// [FEATURE] SQLite 공용 베이스 — T-63 P4 리팩토링
// DraftStore/ReferenceStore/MacNewsStore의 공통 보일러플레이트(경로/open/exec) 단일화
// C 매크로 SQLITE_TRANSIENT — Swift에서 직접 정의 (파일당 1개 유지 규칙)
import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteStore {
    // Application Support/MacCanDo 하위 DB 파일 경로 (디렉토리 자동 생성)
    static func dbPath(_ file: String) -> String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacCanDo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(file).path
    }

    // 이미 열려 있으면 재사용 — 실패 시 nil 처리
    @discardableResult
    static func open(_ path: String, into db: inout OpaquePointer?, context: String) -> Bool {
        guard db == nil else { return true }
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            DebugLogger.error(context, "SQLite 열기 실패 (\(path))")
            db = nil
            return false
        }
        return true
    }

    // exec + 에러 로그 공통화 (에러 있으면 false, err 포인터 자동 해제)
    // silent: ALTER TABLE "이미 존재" 같은 경고성 실패는 로그 생략
    @discardableResult
    static func exec(_ db: OpaquePointer?, sql: String, context: String, silent: Bool = false) -> Bool {
        var err: UnsafeMutablePointer<CChar>?
        sqlite3_exec(db, sql, nil, nil, &err)
        if let err {
            if !silent {
                DebugLogger.error(context, "SQL 실행 실패: \(String(cString: err))")
            }
            sqlite3_free(err)
            return false
        }
        return true
    }
}
