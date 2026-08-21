// [FEATURE] T-89: 도우미 패널 — AI 도우미 결과 표시/편집/에디터 적용 (v2.15)
import SwiftUI

struct AssistantPanel: View {
    @Binding var assistantResult: String?
    @Binding var coverAltText: String
    @Binding var bodyImageAltText: String
    @Binding var isLoading: Bool
    
    let onCopyResult: () -> Void
    let onApplyToEditor: () -> Void
    let onGenerateCoverAlt: () -> Void
    let onGenerateBodyAlt: () -> Void
    let onOpenAssistantWindow: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI 도우미", systemImage: "wand.and.stars")
                    .font(.headline)
                Spacer()
                Button("도우미 열기") { onOpenAssistantWindow() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            
            if let result = assistantResult, !result.isEmpty {
                // 결과 프리뷰
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("생성된 참고 자료").font(.subheadline.bold())
                        Spacer()
                        Button(action: onCopyResult) {
                            Label("복사", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                        Button(action: onApplyToEditor) {
                            Label("에디터에 적용", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    ScrollView {
                        Text(result)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(10)
                    .background(Color.dsSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                EmptyState(
                    icon: "wand.and.stars",
                    title: "도우미 결과 없음",
                    subtitle: "AI 도우미 창에서 자료를 생성하면 여기에 표시됩니다"
                )
            }
            
            Divider()
            
            // 이미지 Alt 생성 버튼들
            VStack(spacing: 8) {
                HStack {
                    Text("이미지 설명(alt) 생성").font(.subheadline.bold())
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    Button(coverAltText.isEmpty ? "커버 alt 생성" : "커버 alt 재생성") {
                        // onGenerateCoverAlt 호출은 부모에서 처리
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(true) // 실제 호출은 부모에서
                    
                    Button(bodyImageAltText.isEmpty ? "본문 alt 생성" : "본문 alt 재생성") {
                        // onGenerateBodyAlt 호출은 부모에서 처리
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(true)
                }
                
                if !coverAltText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("커버 Alt:").font(.caption.bold())
                        Text(coverAltText).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    }
                }
                
                if !bodyImageAltText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("본문 Alt:").font(.caption.bold())
                        Text(bodyImageAltText).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    }
                }
            }
        }
        .padding(12)
    }
}