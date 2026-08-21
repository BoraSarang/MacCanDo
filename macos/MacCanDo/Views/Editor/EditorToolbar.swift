// [FEATURE] T-88: 에디터 툴바 — 포맷/삽입/액션바 (v2.15)
import SwiftUI

struct EditorToolbar: View {
    @Binding var title: String
    @Binding var content: String
    @Binding var slug: String
    @Binding var excerpt: String
    @Binding var thumbnailUrl: String?
    @Binding var status: String
    @Binding var categories: [PostCategory]
    @Binding var selectedCategoryIds: Set<String>
    @Binding var tagsInput: String
    @Binding var contentType: String
    @Binding var seoMeta: SEOSuggestion?
    
    // 시트 상태
    @Binding var showHelp: Bool
    @Binding var showSEO: Bool
    @Binding var showImagePicker: Bool
    @Binding var showYoutubeDialog: Bool
    @Binding var showVideoDialog: Bool
    @Binding var showAppSheet: Bool
    @Binding var showCoverImagePrompt: Bool
    @Binding var showBodyImageGen: Bool
    @Binding var showImagePromptGen: Bool
    @Binding var insertURL: String
    @Binding var insertCaption: String
    
    // T-83: 이미지 프롬프트 생성
    @Binding var imagePromptItems: [GeminiService.ImagePromptItem]
    @Binding var generatingImagePrompts: Bool
    @Binding var imagePromptError: String?
    @Binding var showImagePromptGen: Bool
    
    // 콜백
    let onBold: () -> Void
    let onItalic: () -> Void
    let onStrikethrough: () -> Void
    let onHeading: () -> Void
    let onLink: () -> Void
    let onImageInsert: () -> Void
    let onYoutube: () -> Void
    let onVideo: () -> Void
    let onAppCard: () -> Void
    let onHelp: () -> Void
    let onSEO: () -> Void
    let onOpenAssistant: () -> Void
    let onSpellingCheck: () -> Void
    let onPublish: () -> Void
    let onSaveDraft: () -> Void
    let onGenerateImagePrompts: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            // 포맷 버튼들
            formatButtons
            
            Divider().frame(height: 16)
            
            // 삽입 버튼들
            insertButtons
            
            Divider().frame(height: 16)
            
            // SEO 버튼
            seoButton
            
            // AI 도우미
            assistantButton
            
            Divider().frame(height: 16)
            
            // 맞춤법 검사
            spellingButton
            
            Spacer()
            
            // 액션 버튼들 (우측)
            actionButtons
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.dsSurface)
        .overlay(alignment: .bottom) { Divider() }
    }
    
    // MARK: - Subviews
    
    private var formatButtons: some View {
        HStack(spacing: 2) {
            Button(action: onBold) {
                Image(systemName: "bold").help("굵게 (⌘B)")
            }
            Button(action: onItalic) {
                Image(systemName: "italic").help("기울임 (⌘I)")
            }
            Button(action: onStrikethrough) {
                Image(systemName: "strikethrough").help("취소선")
            }
            Button(action: onHeading) {
                Image(systemName: "textformat.alt").help("제목 (⌘H)")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
    
    private var insertButtons: some View {
        HStack(spacing: 2) {
            Button(action: onLink) {
                Image(systemName: "link").help("링크 (⌘K)")
            }
            Button(action: onImageInsert) {
                Image(systemName: "photo").help("이미지 삽입")
            }
            // T-83: 이미지 프롬프트 생성
            Button(action: onGenerateImagePrompts) {
                Image(systemName: "text.below.photo").help("이미지 프롬프트 생성")
            }
            Button(action: onYoutube) {
                Image(systemName: "play.rectangle").help("유튜브 삽입")
            }
            Button(action: onVideo) {
                Image(systemName: "film").help("동영상 삽입")
            }
            Button(action: onAppCard) {
                Image(systemName: "square.grid.2x2").help("앱 카드 삽입")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
    
    private var seoButton: some View {
        Button(action: onSEO) {
            if seoMeta != nil {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.dsPrimary)
                    Text("SEO ✓")
                        .font(.caption.bold())
                        .foregroundStyle(Color.dsPrimary)
                }
            } else {
                Image(systemName: "sparkles")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help(seoMeta != nil ? "AI SEO — 저장된 메타 적용됨" : "AI SEO — 제목/설명/키워드 생성")
    }
    
    private var assistantButton: some View {
        Button(action: onOpenAssistant) {
            Image(systemName: "wand.and.stars")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help("AI 도우미 — 프로그램/웹사이트 소개 참고 자료 생성")
    }
    
    private var spellingButton: some View {
        Button(action: onSpellingCheck) {
            Image(systemName: "textformat.abc")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help("한글 맞춤법 검사 (Gemini)")
    }
    
    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button(action: onSaveDraft) {
                Label("초안 저장", systemImage: "tray.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .controlSize(.small)
            
            Button(action: onPublish) {
                Label("발행", systemImage: "paperplane")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

// 시트 관련은 별도 뷰로 분리 (EditorSheets.swift)