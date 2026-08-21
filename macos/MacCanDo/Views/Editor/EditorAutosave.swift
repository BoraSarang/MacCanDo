// [FEATURE] T-88: 에디터 자동저장/드래프트/오프라인 큐 (v2.15)
import Foundation
import Combine
import AppKit

@MainActor
final class EditorAutosave: ObservableObject {
    static let shared = EditorAutosave()
    
    @Published var lastSavedAt: Date?
    @Published var hasUnsavedChanges = false
    @Published var draftKey: String?
    @Published var isSaving = false
    
    private var saveTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval = 2.0  // 2초 디바운스
    private var lastContentHash: Int = 0
    
    private init() {}
    
    // MARK: - Public API
    
    /// 자동저장 시작 (내용 변경 감시)
    func startMonitoring(
        postId: String?,
        title: String,
        content: String,
        onSave: @escaping (String, String, String) async throws -> Void
    ) {
        draftKey = postId ?? DraftStore.newPostKey
        lastContentHash = content.hashValue
        hasUnsavedChanges = false
        
        // 기존 타이머 정리
        saveTimer?.invalidate()
        
        // 2초마다 변경 감지
        saveTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndSave(title: title, content: content, onSave: onSave)
            }
        }
        
        // 앱 종료 시 즉시 저장
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                try? await self?.forceSave(title: title, content: content, onSave: onSave)
            }
        }
    }
    
    func stopMonitoring() {
        saveTimer?.invalidate()
        saveTimer = nil
    }
    
    /// 강제 저장 (즉시)
    func forceSave(
        title: String,
        content: String,
        onSave: @escaping (String, String, String) async throws -> Void
    ) async throws {
        guard hasUnsavedChanges || lastContentHash != content.hashValue else { return }
        isSaving = true
        defer { isSaving = false }
        
        let key = draftKey ?? DraftStore.newPostKey
        try await onSave(key, title, content)
        
        lastContentHash = content.hashValue
        hasUnsavedChanges = false
        lastSavedAt = Date()
        DraftStore.saveDraft(key: key, title: title, content: content)
        
        DebugLogger.info("Autosave", "자동저장 완료 key=\(key)")
    }
    
    // MARK: - Private
    
    private func checkAndSave(
        title: String,
        content: String,
        onSave: @escaping (String, String, String) async throws -> Void
    ) async {
        let currentHash = content.hashValue
        guard currentHash != lastContentHash else { return }
        
        hasUnsavedChanges = true
        
        // 디바운스: 추가 1초 대기 후 저장
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 다시 체크 (그 사이에 또 변경됐을 수 있음)
        guard content.hashValue == currentHash else { return }
        
        do {
            try await forceSave(title: title, content: content) { key, t, c in
                // 실제 저장은 DraftStore로 (로컬 SQLite)
                DraftStore.saveDraft(key: key, title: t, content: c)
            }
        } catch {
            DebugLogger.error("Autosave", "자동저장 실패: \(error)")
        }
    }
    
    /// 드래프트 로드 (앱 시작 시)
    static func loadDraft(key: String) -> (title: String, content: String)? {
        guard let draft = DraftStore.loadDraft(key: key) else { return nil }
        return (draft.title, draft.content)
    }
    
    /// 드래프트 삭제 (발행 완료 시)
    static func clearDraft(key: String) {
        DraftStore.clear(postId: key)
    }
}

// MARK: - DraftRecord 확장 (PostsView에서 사용)

struct DraftRecord: Identifiable {
    let id = UUID()
    let postId: String
    let title: String
    let savedAt: Date
    let body: String
    var wordCount: Int { body.split(separator: " ").count }
}