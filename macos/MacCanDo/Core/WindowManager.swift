// [FEATURE] 창 중복 방지 매니저 (T-25) — AI 도우미/글 편집 창은 1개만 유지
// 이미 열려 있으면 새로 만들지 않고 앞으로 가져옴 (makeKeyAndOrderFront)
import SwiftUI
import AppKit

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
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "AI 도우미"
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: AssistantView())
        win.center()
        win.makeKeyAndOrderFront(nil)
        assistantWindow = win
        DebugLogger.info("Window", "AI 도우미 창 열림")
    }

    // 에디터 창 — 키(postId/draftKey/시드 키)당 1개만 유지
    static var editorWindows: [String: NSWindow] = [:]

    @discardableResult
    static func openEditor(key: String, title: String, rootView: some View, width: CGFloat = 1100, height: CGFloat = 680) -> NSWindow {
        if let win = editorWindows[key], win.isVisible {
            win.makeKeyAndOrderFront(nil)
            DebugLogger.info("Window", "에디터 창 재사용 (\(key))")
            return win
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = title
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: AnyView(rootView))
        win.center()
        win.makeKeyAndOrderFront(nil)
        editorWindows[key] = win
        DebugLogger.info("Window", "에디터 창 열림 (\(key))")
        return win
    }
}