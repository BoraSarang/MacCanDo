// MacCanDo DebugPanel (19장 표준 — macOS)
// 열기: Cmd+Shift+D → NSWindow(.floating) 640x360
// 표시: DebugLogger 실시간 로그 / API 호출 기록 / 오프라인 큐 상태 / 성능·캐시
// NOTE: T-06 (macos 앱 골격)에서 Xcode 프로젝트 통합 시 완성

import SwiftUI

/// DebugPanel 내용 (로그 탭)
struct DebugLogView: View {
    @State private var logs: [String] = []
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            Text(logs.joined(separator: "\n"))
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .background(Color.black.opacity(0.9))
        .foregroundColor(.green)
        .onReceive(timer) { _ in
            logs = DebugLogger.shared.dump().split(separator: "\n").suffix(200).map(String.init)
        }
    }
}

/// DebugPanel 컨테이너 (Cmd+Shift+D로 토글)
struct DebugPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MacCanDo Debug").font(.headline)
                Spacer()
                Button("로그 지우기") { DebugLogger.shared.clear() }
            }
            .padding(8)

            TabView {
                DebugLogView().tabItem { Label("로그", systemImage: "text.alignleft") }
                APILogView().tabItem { Label("API", systemImage: "network") }
                QueueStatusView().tabItem { Label("큐", systemImage: "arrow.triangle.2.circlepath") }
            }
        }
        .frame(width: 640, height: 360)
    }
}

/// API 로그 탭 — DebugLogger의 API 항목 필터
struct APILogView: View {
    @State private var apiLogs: [String] = []
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            Text(apiLogs.joined(separator: "\n"))
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .onReceive(timer) { _ in
            apiLogs = DebugLogger.shared.dump()
                .split(separator: "\n")
                .filter { $0.contains("[API]") }
                .suffix(100)
                .map(String.init)
        }
    }
}

/// 오프라인 큐 상태 탭 (T-08 완성 — 현재 스텁)
struct QueueStatusView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오프라인 큐 상태").font(.headline)
            Text("대기 중 작업: 0 (동기화 미구현 — T-08)")
            Text("마지막 동기화: -")
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DebugPanel()
}