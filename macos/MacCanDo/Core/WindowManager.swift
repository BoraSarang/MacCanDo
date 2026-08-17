// [FEATURE] 창 중복 방지 매니저 (T-25) — AI 도우미/글 편집 창은 1개만 유지
// 이미 열려 있으면 새로 만들지 않고 앞으로 가져옴 (makeKeyAndOrderFront)
// T-47: 닫은 창 딕셔너리 정리(windowWillClose) + 창 크기 상수화 (메인 1100×720 / 에디터 1000×640 / 도우미 900×600)
import SwiftUI
import AppKit

// T-47: 창 크기 표준 상수 (v2.7.0 — Phase E 창 크기 상수화)
enum WindowSize {
    static let main = NSSize(width: 1100, height: 720)
    static let editor = NSSize(width: 1000, height: 640)
    static let assistant = NSSize(width: 900, height: 600)
}

enum WindowManager {
    static var assistantWindow: NSWindow?

    // AI 도우미 창 — 중복 없이 하나만 (에디터 툴바/사이드바 공용)
    static func showAssistant() {
        if let win = assistantWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            DebugLogger.info("Window", "AI 도우미 창 재사용 (이미 열림)")
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: WindowSize.assistant.width, height: WindowSize.assistant.height),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "AI 도우미"
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: AssistantView())
        win.center()
        win.setFrameAutosaveName("MacCanDo-Assistant") // T-33: 크기/위치 복원
        win.makeKeyAndOrderFront(nil)
        // T-47: 닫으면 참조 제거 — 재열림 시 새 창 생성
        win.delegate = nil
        assistantWindow = win
        DebugLogger.info("Window", "AI 도우미 창 열림")
    }

    // 에디터 창 — 키(postId/draftKey/시드 키)당 1개만 유지
    static var editorWindows: [String: NSWindow] = [:]

    @discardableResult
    static func openEditor(key: String, title: String, rootView: some View, width: CGFloat? = nil, height: CGFloat? = nil) -> NSWindow {
        if let win = editorWindows[key], win.isVisible {
            win.makeKeyAndOrderFront(nil)
            DebugLogger.info("Window", "에디터 창 재사용 (\(key))")
            return win
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width ?? WindowSize.editor.width, height: height ?? WindowSize.editor.height),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = title
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: AnyView(rootView))
        win.center()
        // T-33: 키별 autosave 이름 — 창 크기/위치 복원 (한글/특수문자 sanitize)
        let safeKey = key.map { $0.isLetter || $0.isNumber ? $0 : "_" }
        win.setFrameAutosaveName("MacCanDo-Editor-\(safeKey)")
        win.makeKeyAndOrderFront(nil)
        editorWindows[key] = win
        // T-47: 창이 닫히면 딕셔너리에서 제거 — 같은 키 재열기 시 새 창 (닫힌 창 참조 누수 방지)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { note in
            guard let closed = note.object as? NSWindow else { return }
            if let idx = editorWindows.firstIndex(where: { $0.value === closed }) {
                let closedKey = editorWindows[idx].key
                editorWindows.removeValue(forKey: closedKey)
                DebugLogger.info("Window", "에디터 창 닫힘 — 참조 제거 (\(closedKey))")
            }
        }
        DebugLogger.info("Window", "에디터 창 열림 (\(key))")
        return win
    }
}