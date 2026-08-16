// [FEATURE] DebugLogger — macOS용 로거 (T-01 표준 규격)
// 포맷: [HH:mm:ss.SSS] [LEVEL] [MODULE] message
// 디버그 패널용 메모리 버퍼(최대 2000) + 파일 로그 + os_log 동시 기록
import Foundation
import os

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

struct DebugLogEntry: Identifiable {
    let id: UUID
    let timestamp: String
    let level: LogLevel
    let category: String
    let message: String
    var formatted: String { "[\(timestamp)] [\(level.rawValue)] [\(category)] \(message)" }
}

final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    @Published private(set) var logs: [DebugLogEntry] = []
    private let osLogger = Logger(subsystem: "kr.maccando.app", category: "MacCanDo")
    private let dateFmt: DateFormatter
    private let fileURL: URL
    private let maxBuffer = 2000
    private var autoScrollPausedUntil = Date.distantPast

    var isAutoScrollPaused: Bool { Date() < autoScrollPausedUntil }

    private init() {
        dateFmt = DateFormatter()
        dateFmt.dateFormat = "HH:mm:ss.SSS"
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        fileURL = dir.appendingPathComponent("MacCanDo/logs.txt")
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    func log(_ level: LogLevel, _ module: String, _ message: String) {
        let entry = DebugLogEntry(id: UUID(), timestamp: dateFmt.string(from: Date()), level: level, category: module, message: message)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            logs.append(entry)
            if logs.count > maxBuffer {
                logs.removeFirst(logs.count - maxBuffer)
            }
        }
        let line = entry.formatted
        osLogger.log(level: level == .error ? .error : .info, "\(line, privacy: .public)")
        appendToFile(line)
    }

    static func debug(_ module: String, _ msg: String) { shared.log(.debug, module, msg) }
    static func info(_ module: String, _ msg: String) { shared.log(.info, module, msg) }
    static func warn(_ module: String, _ msg: String) { shared.log(.warn, module, msg) }
    static func error(_ module: String, _ msg: String) { shared.log(.error, module, msg) }

    // 디버그 패널: 사용자가 스크롤 조작 시 2초간 자동 스크롤 중지
    func pauseAutoScroll() { autoScrollPausedUntil = Date().addingTimeInterval(2) }

    // 에이전트 전달용 전체 복사 포맷
    func formatForAgent(_ entries: [DebugLogEntry]) -> String {
        entries.map(\.formatted).joined(separator: "\n")
    }

    func clear() {
        logs.removeAll()
        DebugLogger.info("DebugPanel", "로그 클리어")
    }

    private func appendToFile(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let fh = try? FileHandle(forWritingTo: fileURL) {
                defer { try? fh.close() }
                try? fh.seekToEnd()
                try? fh.write(contentsOf: data)
            }
        } else {
            try? data.write(to: fileURL)
        }
    }

    func dumpLogs() -> String {
        return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }
}