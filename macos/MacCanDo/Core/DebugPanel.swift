// [FEATURE] DebugPanel — Cmd+Shift+D 토글 플로팅 패널 (T-01 규격 + SmartSeller 19.4 표준 확장)
// 탭: 앱 로그 / 서버 로그
// 앱 로그 선택: 클릭=1줄, Shift+클릭=범위, Cmd+클릭=토글, 드래그=범위
import SwiftUI
import AppKit

private struct RowFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct DebugPanelView: View {
    @ObservedObject var vm: DebugPanelVM
    @ObservedObject var logger = DebugLogger.shared

    @State private var selection = Set<UUID>()
    @State private var lastAnchorID: UUID?
    @State private var dragStartID: UUID?
    @State private var isAutoScroll = true
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var tab: DebugTab = .app

    enum DebugTab: String, CaseIterable, Hashable {
        case app = "앱 로그"
        case server = "서버 로그"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if tab == .app {
                appLogList
            } else {
                serverLogList
            }
        }
        .frame(minWidth: 560, minHeight: 360)
        .background(Color.black.opacity(0.92))
    }

    // MARK: - 헤더

    private var header: some View {
        HStack {
            Picker("", selection: $tab) {
                ForEach(DebugTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .onChange(of: tab) { _ in
                if tab == .server { Task { await vm.refreshServerLogs() } }
            }
            Spacer()
            if tab == .app {
                Text("🐛 [\(logger.logs.count)]")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Button("📌 \(isAutoScroll ? "ON" : "OFF")") { isAutoScroll.toggle() }
                    .buttonStyle(.plain).foregroundColor(.white).help("자동 스크롤 토글")
                Button("선택 복사\(selection.isEmpty ? "" : " (\(selection.count))")") { copySelection() }
                    .buttonStyle(.plain)
                    .foregroundColor(selection.isEmpty ? Color(red: 0.72, green: 0.72, blue: 0.75) : Color.white)
                    .font(selection.isEmpty ? .caption : .caption.bold())
                    .help("선택한 줄만 에이전트 포맷으로 복사")
                Button("전체 복사") { copyAll() }
                    .buttonStyle(.plain).foregroundColor(.white).help("전체 로그를 에이전트 포맷으로 복사")
                Button("클리어") { clear() }
                    .buttonStyle(.plain).foregroundColor(.white)
            } else {
                HStack(spacing: 6) {
                    Picker("", selection: $vm.serverLevel) {
                        Text("전체").tag("")
                        Text("ERROR").tag("ERROR")
                        Text("WARN").tag("WARN")
                        Text("API").tag("API")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 90)
                    .onChange(of: vm.serverLevel) { _ in
                        Task { await vm.refreshServerLogs() }
                    }
                }
                Text("[\(vm.serverLogs.count)]")
                    .font(.caption.bold()).foregroundColor(.white)
                Button("새로고침") { Task { await vm.refreshServerLogs() } }
                    .buttonStyle(.plain).foregroundColor(.white)
                Button("전체 복사") { copyServerLogs() }
                    .buttonStyle(.plain).foregroundColor(.white)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
    }

    // MARK: - 앱 로그 리스트

    private var appLogList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logger.logs) { log in
                        Text(log.formatted)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(textColor(for: log))
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selection.contains(log.id) ? Color.blue.opacity(0.35) : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { handleTap(log.id) }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 3, coordinateSpace: .named("logArea"))
                                    .onChanged { value in
                                        DebugLogger.shared.pauseAutoScroll()
                                        if dragStartID == nil { dragStartID = log.id }
                                        guard let start = dragStartID else { return }
                                        if let current = rowID(at: value.location) {
                                            selectRange(from: start, to: current, anchorTo: current)
                                        }
                                    }
                                    .onEnded { _ in dragStartID = nil }
                            )
                            .background(GeometryReader { geo in
                                Color.clear.preference(
                                    key: RowFrameKey.self,
                                    value: [log.id: geo.frame(in: .named("logArea"))]
                                )
                            })
                            .id(log.id)
                    }
                }
            }
            .coordinateSpace(name: "logArea")
            .onPreferenceChange(RowFrameKey.self) { rowFrames.merge($0) { _, new in new } }
            .onChange(of: logger.logs.count) { _ in
                if isAutoScroll && !logger.isAutoScrollPaused {
                    proxy.scrollTo(logger.logs.last?.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 서버 로그 리스트

    private var serverLogList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if let err = vm.serverError {
                        Text("⚠️ \(err)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(4)
                    }
                    ForEach(vm.serverLogs) { entry in
                        Text(entry.text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(serverColor(entry.level))
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .id(entry.id)
                    }
                }
            }
            .coordinateSpace(name: "serverLogArea")
            .onChange(of: vm.serverLogs.count) { _ in
                if isAutoScroll && !logger.isAutoScrollPaused {
                    proxy.scrollTo(vm.serverLogs.last?.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 선택/복사

    private func handleTap(_ id: UUID) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift), let anchor = lastAnchorID {
            selectRange(from: anchor, to: id, anchorTo: nil)
        } else if flags.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
            lastAnchorID = id
        } else {
            selection = [id]
            lastAnchorID = id
        }
        DebugLogger.shared.pauseAutoScroll()
    }

    private func selectRange(from a: UUID, to b: UUID, anchorTo anchor: UUID?) {
        guard let ia = logger.logs.firstIndex(where: { $0.id == a }),
              let ib = logger.logs.firstIndex(where: { $0.id == b }) else { return }
        let (lo, hi) = ia <= ib ? (ia, ib) : (ib, ia)
        selection = Set(logger.logs[lo...hi].map(\.id))
        if let anchor { lastAnchorID = anchor }
    }

    private func rowID(at point: CGPoint) -> UUID? {
        rowFrames.first { $0.value.contains(point) }?.key
    }

    private func copySelection() {
        guard !selection.isEmpty else { return }
        let texts = logger.logs.filter { selection.contains($0.id) }.map { $0.formatted }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texts, forType: .string)
    }

    private func copyAll() {
        let all = logger.formatForAgent(logger.logs)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(all, forType: .string)
    }

    private func copyServerLogs() {
        let all = vm.serverLogs.map(\.text).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(all, forType: .string)
    }

    private func clear() { logger.clear(); selection.removeAll() }

    // MARK: - 색상

    private func textColor(for log: DebugLogEntry) -> Color {
        if log.message.hasPrefix("API→") { return Color(red: 0.45, green: 0.75, blue: 0.99) }
        if log.message.hasPrefix("API←") { return Color(red: 0.55, green: 0.92, blue: 0.60) }
        switch log.level {
        case .error: return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .warn: return Color(red: 1.0, green: 0.83, blue: 0.26)
        case .debug: return Color(red: 0.62, green: 0.62, blue: 0.66)
        default: return Color.white
        }
    }

    private func serverColor(_ level: String) -> Color {
        switch level {
        case "ERROR": return Color(red: 1.0, green: 0.42, blue: 0.42)
        case "WARN": return Color(red: 1.0, green: 0.83, blue: 0.26)
        case "PERF": return Color(red: 1.0, green: 0.55, blue: 0.35)
        case "CACHE": return Color(red: 0.60, green: 0.85, blue: 1.0)
        default: return Color.white
        }
    }
}

@MainActor
final class DebugPanelVM: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var serverLogs: [APIClient.ServerLogEntry] = []
    @Published var serverLevel = ""
    @Published var serverError: String?
    private var panel: NSPanel?

    static let shared = DebugPanelVM()

    func show() {
        isVisible = true
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
                            styleMask: [.titled, .closable, .resizable, .utilityWindow],
                            backing: .buffered, defer: false)
            p.level = .floating
            p.isReleasedWhenClosed = false
            p.contentView = NSHostingView(rootView: DebugPanelView(vm: self))
            p.center()
            p.orderFrontRegardless()
            panel = p
        } else {
            panel?.orderFrontRegardless()
        }
        DebugLogger.info("DebugPanel", "패널 표시됨")
    }

    func hide() {
        isVisible = false
        panel?.orderOut(nil)
        DebugLogger.info("DebugPanel", "패널 닫힘")
    }

    func toggle() { isVisible ? hide() : show() }

    func refreshServerLogs() async {
        let token = UserDefaults.standard.string(forKey: "apiToken")
        do {
            // ERROR/WARN은 level 필터, API는 category 필터 (서버 getRecentLogs는 정확 일치)
            let isLevelFilter = serverLevel == "ERROR" || serverLevel == "WARN"
            let level = isLevelFilter ? serverLevel : ""
            let category = isLevelFilter ? "" : serverLevel
            let result = try await APIClient.fetchServerLogs(token: token, limit: 300, level: level, category: category)
            serverLogs = result.logs
            serverError = nil
        } catch {
            serverError = error.localizedDescription
        }
    }
}

// Cmd+Shift+D 글로벌 단축키
final class DebugPanelHotkey {
    static func install() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift),
               event.charactersIgnoringModifiers?.lowercased() == "d" {
                Task { @MainActor in DebugPanelVM.shared.toggle() }
                return nil
            }
            return event
        }
    }
}