// [FEATURE] T-91: 이미지 프롬프트 패널 — T-83 결과 + 템플릿 라이브러리 연동 (v2.15)
import SwiftUI

struct ImagePromptPanel: View {
    @Binding var imagePromptItems: [GeminiService.ImagePromptItem]
    @Binding var generatingImagePrompts: Bool
    @Binding var imagePromptError: String?
    @Binding var title: String
    @Binding var content: String
    
    @StateObject private var promptLibrary = PromptLibrary.shared
    @State private var selectedTemplate: PromptTemplate?
    @State private var showTemplatePicker = false
    @State private var editingPrompt: GeminiService.ImagePromptItem?
    
    let onGeneratePrompts: () -> Void
    let onCopyPrompt: (String) -> Void
    let onGenerateImage: (GeminiService.ImagePromptItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 + 액션
            HStack {
                Label("이미지 프롬프트", systemImage: "photo.badge.sparkles")
                    .font(.headline)
                Spacer()
                Button(generatingImagePrompts ? "생성 중…" : "프롬프트 생성") {
                    onGeneratePrompts()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(generatingImagePrompts || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button("템플릿") { showTemplatePicker = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            
            if generatingImagePrompts {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("본문을 분석해 프롬프트를 만드는 중… (보통 5~15초)").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else if !imagePromptItems.isEmpty {
                promptList
            } else if let err = imagePromptError {
                Text(err).font(.caption).foregroundStyle(Color.dsDanger)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                EmptyState(
                    icon: "photo.badge.sparkles",
                    title: "프롬프트 없음",
                    subtitle: "'프롬프트 생성'을 누르거나 템플릿에서 시작하세요"
                )
            }
        }
        .padding(12)
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerView(selectedTemplate: $selectedTemplate)
        }
        .sheet(item: $editingPrompt) { item in
            PromptEditorView(item: item, onSave: { updated in
                if let idx = imagePromptItems.firstIndex(where: { $0.id == item.id }) {
                    imagePromptItems[idx] = updated
                }
            })
        }
    }
    
    private var promptList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(imagePromptItems) { item in
                    PromptItemView(
                        item: item,
                        onCopy: { onCopyPrompt(item.prompt) },
                        onEdit: { editingPrompt = item },
                        onGenerate: { onGenerateImage(item) }
                    )
                }
                
                Divider()
                
                HStack {
                    Button("전체 복사") {
                        let text = imagePromptItems.map { "\($0.label) (\($0.aspectRatio))\n\($0.prompt)" }.joined(separator: "\n\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Prompt Item View

private struct PromptItemView: View {
    let item: GeminiService.ImagePromptItem
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.label).font(.subheadline.bold())
                Text(item.aspectRatio).font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.dsSurfaceHover)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
                HStack(spacing: 4) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .help("프롬프트 복사")
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .help("편집")
                    Button(action: onGenerate) {
                        Image(systemName: "photo.badge.plus")
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .help("이 프롬프트로 이미지 생성")
                }
            }
            Text(item.prompt)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.dsSurface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(8)
        .background(Color.dsSurfaceHover.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Template Picker

private struct TemplatePickerView: View {
    @Binding var selectedTemplate: PromptTemplate?
    @StateObject private var library = PromptLibrary.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("템플릿 선택").font(.title3.bold())
            
            List(selection: $selectedTemplate) {
                ForEach(TemplateCategory.allCases) { category in
                    Section(category.rawValue) {
                        ForEach(library.templates(for: category)) { tmpl in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(Color.dsPrimary)
                                VStack(alignment: .leading) {
                                    Text(tmpl.name).font(.subheadline)
                                    if tmpl.isBuiltIn {
                                        Text("내장").font(.caption2).foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                            }
                            .tag(tmpl as PromptTemplate?)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(height: 400)
            
            HStack {
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("선택") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTemplate == nil)
            }
        }
        .padding(20)
        .frame(width: 500, height: 500)
    }
}

// MARK: - Prompt Editor

private struct PromptEditorView: View {
    let item: GeminiService.ImagePromptItem
    let onSave: (GeminiService.ImagePromptItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var label: String
    @State private var aspectRatio: String
    @State private var prompt: String
    
    init(item: GeminiService.ImagePromptItem, onSave: @escaping (GeminiService.ImagePromptItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _label = State(initialValue: item.label)
        _aspectRatio = State(initialValue: item.aspectRatio)
        _prompt = State(initialValue: item.prompt)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("프롬프트 편집").font(.title3.bold())
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("라벨", text: $label)
                    .textFieldStyle(.roundedBorder)
                TextField("비율 (예: 16:9, 4:3)", text: $aspectRatio)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $prompt)
                    .font(.body)
                    .frame(minHeight: 150)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.dsSurfaceHover))
            }
            
            HStack {
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("저장") {
                    var updated = item
                    updated.label = label
                    updated.aspectRatio = aspectRatio
                    updated.prompt = prompt
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 500, height: 450)
    }
}