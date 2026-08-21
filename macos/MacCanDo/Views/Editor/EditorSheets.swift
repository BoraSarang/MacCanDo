// [FEATURE] T-88: 에디터 시트들 — 이미지/앱/유튜브/비디오/도움말/이미지프롬프트 (v2.15)
import SwiftUI

struct EditorSheets: View {
    // 바인딩들
    @Binding var showHelp: Bool
    @Binding var showSEO: Bool
    @Binding var showImagePicker: Bool
    @Binding var showCoverPicker: Bool
    @Binding var showAppSheet: Bool
    @Binding var showCoverImagePrompt: Bool
    @Binding var showBodyImageGen: Bool
    @Binding var showImagePromptGen: Bool
    @Binding var showYoutubeDialog: Bool
    @Binding var showVideoDialog: Bool
    @Binding var insertURL: String
    @Binding var insertCaption: String
    @Binding var title: String
    @Binding var content: String
    
    // T-83: 이미지 프롬프트 생성
    @Binding var imagePromptItems: [GeminiService.ImagePromptItem]
    @Binding var generatingImagePrompts: Bool
    @Binding var imagePromptError: String?
    
    // 시트 콘텐츠 클로저들
    let seoSheet: () -> AnyView
    let imageGenSheet: () -> AnyView
    let bodyImageGenSheet: () -> AnyView
    let appCardSheet: () -> AnyView
    let coverPickerSheet: () -> AnyView
    let imagePickerSheetContent: () -> AnyView
    
    // T-83: 이미지 프롬프트 시트
    private var imagePromptSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("이미지 프롬프트 생성").font(.title3.bold())
                Spacer()
                Text(GeminiService.chainLabel(for: .imagePrompts)).font(.caption2).foregroundStyle(.secondary)
            }
            Text("글의 제목과 본문을 분석해 타 AI 이미지 생성기에 붙여넣을 영어 프롬프트 세트를 만듭니다. 각 항목을 복사해 ChatGPT·Midjourney 등에서 이미지를 생성하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(generatingImagePrompts ? "생성 중…" : "프롬프트 생성") {
                    // 실제 생성 로직은 EditorView에서 처리
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(generatingImagePrompts || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            if generatingImagePrompts {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("본문을 분석해 프롬프트를 만드는 중… (보통 5~15초)").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else if !imagePromptItems.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(imagePromptItems) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(item.label).font(.subheadline.bold())
                                    Text(item.aspectRatio).font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.dsSurfaceHover)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    Spacer()
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(item.prompt, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.link)
                                    .controlSize(.small)
                                    .help("프롬프트 복사")
                                }
                                Text(item.prompt)
                                    .font(.caption)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.dsSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(4)
                }
                .frame(maxWidth: .infinity)
                if let err = imagePromptError {
                    Text(err).font(.caption).foregroundStyle(Color.dsDanger)
                }
                HStack {
                    Button("전체 복사") {
                        let text = imagePromptItems.map { "\($0.label) (\($0.aspectRatio))\n\($0.prompt)" }.joined(separator: "\n\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                    Button("닫기") { }.keyboardShortcut(.cancelAction)
                }
            } else if let err = imagePromptError {
                Text(err).font(.caption).foregroundStyle(Color.dsDanger)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Rectangle()
                    .fill(Color.dsSurface)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .overlay(Text("'프롬프트 생성'을 누르면 결과가 여기에 표시됩니다").font(.caption).foregroundStyle(.secondary))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .frame(width: 520, height: 560)
    }
    
    var body: some View {
        EmptyView()
            .sheet(isPresented: $showHelp) { MarkdownHelpSheet() }
            .sheet(isPresented: $showSEO) { seoSheet() }
            .sheet(isPresented: $showImagePicker) { imagePickerSheetContent() }
            .sheet(isPresented: $showCoverPicker) { coverPickerSheet() }
            .sheet(isPresented: $showAppSheet) { appCardSheet() }
            .sheet(isPresented: $showCoverImagePrompt) { imageGenSheet() }
            .sheet(isPresented: $showBodyImageGen) { bodyImageGenSheet() }
            .sheet(isPresented: $showImagePromptGen) { imagePromptSheet }
            .alert("유튜브 URL 또는 영상 ID 입력", isPresented: Binding(
                get: { !showYoutubeDialog },
                set: { showYoutubeDialog = !$0 }
            )) {
                TextField("https://youtube.com/watch?v=... 또는 11자리 ID", text: $insertURL)
                Button("삽입") { /* EditorView에서 처리 */ }
                Button("취소", role: .cancel) { insertURL = "" }
            }
            .alert("동영상(MP4) URL 입력", isPresented: Binding(
                get: { !showVideoDialog },
                set: { showVideoDialog = !$0 }
            )) {
                TextField("https://.../video.mp4", text: $insertURL)
                Button("삽입") { /* EditorView에서 처리 */ }
                Button("취소", role: .cancel) { insertURL = "" }
            }
    }
}

// MARK: - MarkdownHelpSheet (기존 유지)
struct MarkdownHelpSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("마크다운 사용법").font(.title3.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    helpRow("제목", "`# 제목`, `## 소제목`")
                    helpRow("굵게/기울임/취소선", "`**굵게**`, `*기울임*`, `~~취소선~~`")
                    helpRow("링크", "`[텍스트](URL)`")
                    helpRow("이미지", "`![alt](URL)` 또는 `[img:URL width=600 caption=설명 alt=대체텍스트]`")
                    helpRow("코드", "`인라인` / ```블록```")
                    helpRow("리스트", "`- 항목` / `1. 항목` (들여쓰기 2칸 = 중첩)")
                    helpRow("인용", "`> 인용문`")
                    helpRow("테이블", "`| 헤더 | 헤더 |\n|---|---|\n| 셀 | 셀 |`")
                    helpRow("확장: 유튜브", "`[youtube:영상ID width=560 height=315]`")
                    helpRow("확장: 동영상", "`[video:URL width=640]`")
                    helpRow("확장: 갤러리", "`[gallery] ... [/gallery]`")
                    helpRow("확장: 앱 카드", "`[app]` / `[app:URL]`")
                    helpRow("확장: 중앙정렬", "`[center] ... [/center]`")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack { Spacer(); Button("닫기") { }.keyboardShortcut(.cancelAction) }
        }
        .padding(20)
        .frame(width: 480, height: 500)
    }
    
    private func helpRow(_ title: String, _ syntax: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            Text(syntax).font(.caption.monospaced()).textSelection(.enabled)
        }
    }
}