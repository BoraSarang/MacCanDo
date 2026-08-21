// [FEATURE] T-88: 에디터 SEO 패널 — 메타 프리뷰/편집/자동생성 (v2.15)
import SwiftUI

struct EditorSEO: View {
    @Binding var seoMeta: SEOSuggestion?
    @Binding var title: String
    @Binding var content: String
    @Binding var slug: String
    @Binding var thumbnailUrl: String?
    
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showMetaEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Label("SEO 메타", systemImage: "magnifyingglass")
                    .font(.headline)
                Spacer()
                Button(isGenerating ? "생성 중…" : "AI 자동 생성") {
                    Task { await generateSEO() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isGenerating || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button("수동 편집") { showMetaEditor.toggle() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            
            if let meta = seoMeta {
                // 프리뷰 카드
                seoPreviewCard(meta)
            } else {
                EmptyState(
                    icon: "magnifyingglass",
                    title: "SEO 메타 없음",
                    subtitle: "제목/본문 입력 후 'AI 자동 생성'을 누르거나 수동으로 입력하세요"
                )
            }
            
            if showMetaEditor {
                Divider()
                metaEditor
            }
            
            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(Color.dsDanger)
            }
        }
        .padding(16)
        .background(Color.dsSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Subviews
    
    private func seoPreviewCard(_ meta: SEOSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 구글 검색 결과 프리뷰
            VStack(alignment: .leading, spacing: 6) {
                Text(meta.title ?? "제목 없음")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .help("검색 결과 제목 (최대 60자 권장)")
                
                Text("macando.app › \(slug)")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                
                Text(meta.description ?? "설명이 없습니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .help("검색 결과 설명 (최대 160자 권장)")
            }
            .padding(12)
            .background(Color.dsSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.dsSurfaceHover, lineWidth: 1)
            )
            
            // 키워드 태그
            if let keywords = meta.keywords, !keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(keywords, id: \.self) { kw in
                            Text(kw)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.dsPrimary.opacity(0.1))
                                .foregroundStyle(Color.dsPrimary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // 썸네일 프리뷰
            if let thumb = thumbnailUrl ?? meta.image {
                HStack {
                    AsyncImage(url: URL(string: thumb)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        default:
                            ProgressView()
                        }
                    }
                    .frame(width: 80, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading) {
                        Text("썸네일 (OG 이미지)").font(.caption.bold())
                        Text("1200×630 권장").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var metaEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("수동 편집").font(.subheadline.bold())
            
            VStack(alignment: .leading, spacing: 6) {
                Text("SEO 제목 (60자 이내)").font(.caption.bold()).foregroundStyle(.secondary)
                TextField("검색 결과에 표시될 제목", text: Binding(
                    get: { seoMeta?.title ?? "" },
                    set: { seoMeta?.title = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                
                Text("SEO 설명 (160자 이내)").font(.caption.bold()).foregroundStyle(.secondary)
                TextField("검색 결과에 표시될 설명", text: Binding(
                    get: { seoMeta?.description ?? "" },
                    set: { seoMeta?.description = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                
                Text("키워드 (쉼표로 구분)").font(.caption.bold()).foregroundStyle(.secondary)
                TextField("키워드1, 키워드2, 키워드3", text: Binding(
                    get: { seoMeta?.keywords?.joined(separator: ", ") ?? "" },
                    set: { newValue in
                        seoMeta?.keywords = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Spacer()
                Button("완료") { showMetaEditor = false }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateSEO() async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        
        do {
            let prompt = """
            글 제목: \(title)
            본문 요약: \(String(content.prefix(3000)))
            
            SEO 메타를 JSON으로 생성:
            {"title": "SEO 제목 (60자 내외, 핵심 키워드 포함)", "description": "설명 (160자 내외, 클릭 유도)", "keywords": ["키워드1","키워드2","키워드3"], "image": "커버이미지URL플레이스홀더"}
            
            - 제목: 60자 이내, 핵심 키워드 앞쪽에 배치
            - 설명: 160자 이내, 클릭 유도 문구 포함
            - 키워드: 3~5개, 핵심 토픽 중심
            """
            let raw = try await GeminiService.fetchText(prompt: prompt, action: .seo)
            guard let data = extractJSON(from: raw),
                  let meta = try? JSONDecoder().decode(SEOSuggestion.self, from: data) else {
                throw APIError(code: "E-MAC-SEO-1001", message: "SEO 메타 파싱 실패", status: -1)
            }
            
            seoMeta = meta
            DebugLogger.info("EditorSEO", "[FEATURE] SEO 메타 자동 생성 완료")
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            DebugLogger.error("EditorSEO", "SEO 생성 실패: \(error)")
        }
    }
    
    private func extractJSON(from raw: String) -> Data? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") { s = String(s.dropFirst(7)) }
        if s.hasPrefix("```") { s = String(s.dropFirst(3)) }
        if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)
    }
}

// MARK: - Preview
#Preview {
    EditorSEO(
        seoMeta: .constant(SEOSuggestion(
            title: "맥으로 이것도 할 수 있다 - OpenCode Desktop 완전 정복",
            description: "AI 코딩 어시스턴트 OpenCode Desktop의 설치부터 실전 활용까지 완벽 가이드",
            keywords: ["OpenCode", "AI 코딩", "맥 개발 도구"],
            image: "https://example.com/og-image.png"
        )),
        title: .constant("OpenCode Desktop 완전 정복"),
        content: .constant("본문 내용..."),
        slug: .constant("opencode-desktop-guide"),
        thumbnailUrl: .constant("https://example.com/thumb.png")
    )
    .frame(width: 300)
    .padding()
}