// [FEATURE] macOS 앱 엔트리 — T-06
// T-25: 단일 인스턴스 강제 (AppDelegate) — 중복 실행 시 기존 인스턴스로 포커스
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 이미 실행 중인 인스턴스가 있으면 앞으로 가져오고 새 프로세스 종료
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if let existing = running.first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            DebugLogger.warn("App", "중복 실행 감지 — 기존 인스턴스로 전환 후 종료")
            existing.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        DebugLogger.info("App", "단일 인스턴스 확인 완료")
    }

    // 모든 창이 닫혀도 앱 유지 (Dock 클릭 시 재활성화)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 창이 모두 닫힌 상태에서 Dock 클릭 → 메인 창 복원
            NSApp.windows.first { $0.title == "MacCanDo" }?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

@main
struct MacCanDoApp: App {
    @StateObject private var authStore = AuthStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authStore)
                .frame(minWidth: 960, minHeight: 600)
                .onAppear {
                    DebugPanelHotkey.install()
                    DebugLogger.info("App", "MacCanDo 시작됨 (v0.1.0)")
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("DebugPanel 열기") { DebugPanelVM.shared.show() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}
