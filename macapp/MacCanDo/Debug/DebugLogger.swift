// MacCanDo DebugLogger (19.1장 규격)
// 포맷: [HH:mm:ss.SSS] [LEVEL] [FEATURE] 메시지
// 레벨: INFO / WARN / ERROR / PERF / CACHE
// 로그는 순환 버퍼에 저장되어 DebugPanel(Cmd+Shift+D)에서 실시간 표시
// 파일: ~/Library/Logs/MacCanDo/debug.log

import Foundation
import os

enum LogLevel: String {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
    case perf = "PERF"
    case cache = "CACHE"
}

final class DebugLogger {
    static let shared = DebugLogger()

    /// 최근 로그 (DebugPanel 표시용, 최대 2000줄)
    private(set) var buffer: [String] = []
    private let bufferLock = NSLock()
    private let maxBuffer = 2000
    private let logger = Logger(subsystem: "kr.maccando.app", category: "Debug")

    private init() {
        // 로그 파일 준비
        let fm = FileManager.default
        if let dir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/MacCanDo") {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            logFileURL = dir.appendingPathComponent("debug.log")
        }
    }

    private var logFileURL: URL?

    // MARK: - 로그 기록

    func log(_ level: LogLevel, feature: String, _ message: String) {
        let line = String(
            format: "[%@] [%@] [%@] %@",
            timestamp(), level.rawValue, feature, message
        )
        bufferLock.lock()
        buffer.append(line)
        if buffer.count > maxBuffer { buffer.removeFirst(buffer.count - maxBuffer) }
        bufferLock.unlock()

        // 콘솔/OSLog
        switch level {
        case .error: logger.error("\(line, privacy: .public)")
        case .warn: logger.warning("\(line, privacy: .public)")
        default: logger.info("\(line, privacy: .public)")
        }

        // 파일 append
        if let url = logFileURL, let data = (line + "\n").data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    // MARK: - 편의 메서드

    func info(_ feature: String, _ message: String) { log(.info, feature: feature, message) }
    func warn(_ feature: String, _ message: String) { log(.warn, feature: feature, message) }
    func error(_ feature: String, _ message: String) { log(.error, feature: feature, message) }
    func perf(_ feature: String, _ message: String) { log(.perf, feature: feature, message) }
    func cache(_ feature: String, _ message: String) { log(.cache, feature: feature, message) }

    /// API 호출 로깅 (8.6장 GBridge 규격)
    func apiRequest(_ method: String, _ path: String) {
        log(.info, feature: "API", "API→ \(method) \(path)")
    }

    func apiResponse(_ method: String, _ path: String, _ status: Int, _ ms: Int) {
        log(.info, feature: "API", "API← \(status) \(ms)ms (\(method) \(path))")
        if ms > 300 { perf("API", "P95 초과 위험 (\(ms)ms)") }
    }

    // MARK: - 덤프

    /// 전체 로그 (DebugPanel + a11y-dump.sh)
    func dump() -> String { bufferLock.lock(); defer { bufferLock.unlock() }; return buffer.joined(separator: "\n") }

    func clear() { bufferLock.lock(); buffer.removeAll(); bufferLock.unlock() }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}