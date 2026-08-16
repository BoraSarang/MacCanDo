// [FEATURE] MacCanDo macOS 앱 엔트리 — T-06
import SwiftUI

@main
struct MacCanDoApp: App {
    @StateObject private var authStore = AuthStore()

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