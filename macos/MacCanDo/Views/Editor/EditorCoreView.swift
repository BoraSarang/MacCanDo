// [FEATURE] T-88: 에디터 코어 — 본문 편집/미리보기 분할 뷰 + 포커스 모드 (v2.15)
import SwiftUI

struct EditorCoreView: View {
    @Binding var title: String
    @Binding var content: String
    @Binding var htmlPreview: String
    @Binding var splitRatio: CGFloat  // 0.3~0.7 (에디터:미리보기 비율)
    @Binding var focusMode: FocusMode
    @FocusState private var isEditorFocused: Bool
    
    enum FocusMode: String, CaseIterable, Identifiable {
        case split = "분할"
        case editor = "편집기만"
        case preview = "미리보기만"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .split: return "rectangle.split.2x1"
            case .editor: return "text.cursor"
            case .preview: return "eye"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 포커스 모드 툴바
            focusModeToolbar
            
            Divider()
            
            // 메인 분할 영역
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // 좌측: 마크다운 에디터
                    editorPane
                        .frame(width: editorWidth(geo.size.width))
                        .clipped()
                    
                    // 분할 드래그 핸들
                    if focusMode == .split {
                        dragHandle
                            .frame(width: 8)
                    }
                    
                    // 우측: HTML 미리보기
                    if focusMode != .editor {
                        previewPane
                            .frame(width: previewWidth(geo.size.width))
                            .clipped()
                    }
                }
            }
        }
    }
    
    // MARK: - Computed
    
    private func editorWidth(_ totalWidth: CGFloat) -> CGFloat {
        switch focusMode {
        case .split: return totalWidth * splitRatio
        case .editor: return totalWidth
        case .preview: return 0
        }
    }
    
    private func previewWidth(_ totalWidth: CGFloat) -> CGFloat {
        switch focusMode {
        case .split: return totalWidth * (1 - splitRatio)
        case .editor: return 0
        case .preview: return totalWidth
        }
    }
    
    // MARK: - Subviews
    
    private var focusModeToolbar: some View {
        HStack(spacing: 8) {
            Picker("보기 모드", selection: $focusMode) {
                ForEach(FocusMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            
            Spacer()
            
            // 분할 비율 표시 (분할 모드일 때만)
            if focusMode == .split {
                Text("\(Int(splitRatio * 100)) : \(Int((1 - splitRatio) * 100))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.dsSurface)
    }
    
    private var editorPane: some View {
        VStack(spacing: 0) {
            // 에디터 헤더
            HStack {
                Label("마크다운", systemImage: "text.cursor")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if isEditorFocused {
                    Image(systemName: "cursorarrow.rays")
                        .font(.caption)
                        .foregroundStyle(Color.dsPrimary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.dsSurface)
            .overlay(alignment: .bottom) { Divider() }
            
            // 마크다운 텍스트 에디터
            EditorTextView(text: $content)
                .focused($isEditorFocused)
                .background(Color.dsBackground)
        }
    }
    
    private var dragHandle: some View {
        Rectangle()
            .fill(Color.dsSurfaceHover)
            .overlay(
                Image(systemName: "line.2.horizontal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = value.translation.width / 800 // 정규화
                        splitRatio = (splitRatio + delta * 0.01).clamped(to: 0.25...0.75)
                    }
            )
            .onHover { inside in
                NSCursor.resizeLeftRight.push()
            }
    }
    
    private var previewPane: some View {
        VStack(spacing: 0) {
            // 미리보기 헤더
            HStack {
                Label("미리보기", systemImage: "eye")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.dsSurface)
            .overlay(alignment: .bottom) { Divider() }
            
            // HTML 미리보기 (WKWebView)
            PreviewWebView(html: htmlPreview)
                .background(Color.dsBackground)
        }
    }
}

// MARK: - Helper Extensions

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

// MARK: - Preview
#Preview {
    EditorCoreView(
        title: .constant("테스트 글"),
        content: .constant("# 안녕하세요\n\n본문 내용입니다."),
        htmlPreview: .constant("<h1>안녕하세요</h1><p>본문 내용입니다.</p>"),
        splitRatio: .constant(0.5),
        focusMode: .constant(.split)
    )
    .frame(width: 1000, height: 600)
}