// [FEATURE] macOS 앱 엔트리 — T-06
// T-25: 단일 인스턴스 강제 (AppDelegate) — 중복 실행 시 기존 인스턴스로 포커스
// T-33: unified 툴바 + defaultSize + contentMinSize 리사이즈 (윈도우 복원은 @SceneStorage/autosave)
// T-34: 메뉴 바 정비 — File(⌘N 새 글) / View(DebugPanel ⌘⇧D) / Help
import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // T-61: Cold start 기준 — AppDelegate 생성 시각 (프로세스 시작 직후, didFinishLaunching보다 이름)
    private let delegateStartUptime = ProcessInfo.processInfo.systemUptime

    func applicationDidFinishLaunching(_ notification: Notification) {
        // T-61: [PERF] 콜드 스타트 — delegate 생성 → didFinishLaunching (예산 ≤1.5s)
        let elapsedMs = (ProcessInfo.processInfo.systemUptime - delegateStartUptime) * 1000
        DebugLogger.perf("App", String(format: "Cold start delegate→앱 시작 %.0fms (예산 1500ms)", elapsedMs))
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
                .onAppear {
                    DebugPanelHotkey.install()
                    DebugLogger.info("App", "MacCanDo 시작됨 (v0.1.0)")
                }
        }
        // T-33: unified — 툴바가 타이틀 바와 통합 (Notes/Mail 스타일), contentMinSize — 최소 크기 이하 리사이즈 방지
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1100, height: 720)
        // T-45: 설정 — 별도 Settings scene (⌘,) — 사이드바에서 분리 (macOS 표준)
        Settings {
            SettingsView()
                .environmentObject(authStore)
        }
        .commands {
            // T-34: File — ⌘N 새 글 (표준 단축키)
            CommandGroup(replacing: .newItem) {
                Button("새 글") { newPost() }
                    .keyboardShortcut("n", modifiers: .command)
                // T-67: 이야기 시리즈 마법사 (⌥⌘N — 시리즈 생성)
                Button("새 이야기 시리즈…") { newStoryWizard() }
                    .keyboardShortcut("n", modifiers: [.command, .option])
            }
            // T-34: View — DebugPanel (⌘⇧D)
            CommandGroup(after: .sidebar) {
                Button("DebugPanel 열기") { DebugPanelVM.shared.show() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            // T-34: Help — 웹 도움말
            CommandGroup(after: .help) {
                Button("MacCanDo 웹사이트") {
                    if let url = URL(string: "http://localhost:3000") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    // T-34: ⌘N — 새 글 에디터 창 (ContentView 경유 알림 → 동일 동작 보장)
    private func newPost() {
        NotificationCenter.default.post(name: .newPostRequested, object: nil)
    }

    // T-67: ⌥⌘N — 이야기 시리즈 마법사 시트 (ContentView 경유 알림)
    private func newStoryWizard() {
        NotificationCenter.default.post(name: .newStoryWizardRequested, object: nil)
    }
}
