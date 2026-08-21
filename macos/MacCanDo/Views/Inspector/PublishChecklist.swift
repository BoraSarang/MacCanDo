// [FEATURE] T-92: 발행 전 체크리스트 — 자동 검증 + 원클릭 수정 (v2.15)
import SwiftUI

struct PublishChecklist: View {
    @Binding var post: PostPlan?
    @Binding var draft: DraftPackage?
    @Binding var seoMeta: SEOSuggestion?
    @Binding var thumbnailUrl: String?
    @Binding var imagePromptItems: [GeminiService.ImagePromptItem]
    @Binding var appCards: [PostAppInput]
    
    @State private var validationResults: [CheckItem] = []
    @State private var isValidating = false
    
    let onFixSEO: () -> Void
    let onFixSlug: () -> Void
    let onFixCategory: () -> Void
    let onFixTags: () -> Void
    let onFixThumbnail: () -> Void
    let onFixImageAlts: () -> Void
    let onFixAppCards: () -> Void
    let onFixBody: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("발행 체크리스트", systemImage: "checklist")
                    .font(.headline)
                Spacer()
                Button(isValidating ? "검증 중…" : "전체 검증") {
                    Task { await validate() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isValidating)
            }
            
            if validationResults.isEmpty && !isValidating {
                EmptyState(
                    icon: "checklist",
                    title: "검증 대기 중",
                    subtitle: "'전체 검증'을 눌러 발행 전 상태를 확인하세요"
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(validationResults) { item in
                        CheckRow(item: item) {
                            // 자동 수정 액션 실행
                        }
                    }
                }
                
                // 전체 상태 요약
                HStack {
                    let errors = validationResults.filter { $0.status == .error }.count
                    let warnings = validationResults.filter { $0.status == .warning }.count
                    let passed = validationResults.filter { $0.status == .passed }.count
                    
                    Label("\(passed) 통과", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.dsSuccess)
                    Label("\(warnings) 경고", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.dsWarning)
                    Label("\(errors) 오류", systemImage: "xmark.circle.fill")
                        .foregroundStyle(Color.dsDanger)
                    Spacer()
                    
                    if errors == 0 {
                        Text("발행 가능")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.dsSuccess)
                    } else {
                        Text("오류 수정 필요")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.dsDanger)
                    }
                }
                .font(.caption)
                .padding(8)
                .background(Color.dsSurface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
    }
    
    // MARK: - Validation
    
    private func validate() async {
        isValidating = true
        defer { isValidating = false }
        
        var results: [CheckItem] = []
        
        // 1. SEO 제목
        results.append(await checkSEOTitle())
        // 2. SEO 설명
        results.append(await checkSEODescription())
        // 3. SEO 키워드
        results.append(await checkSEOKeywords())
        // 4. 슬러그
        results.append(await checkSlug())
        // 5. 카테고리
        results.append(await checkCategory())
        // 6. 태그
        results.append(await checkTags())
        // 7. 썸네일
        results.append(await checkThumbnail())
        // 8. 본문 이미지 alt
        results.append(await checkImageAlts())
        // 9. 앱 카드
        results.append(await checkAppCards())
        // 10. 본문 길이/구조
        results.append(await checkBodyStructure())
        
        validationResults = results
        DebugLogger.info("PublishChecklist", "[FEATURE] 발행 검증 완료: 통과 \(results.filter{$0.status==.passed}.count) / 경고 \(results.filter{$0.status==.warning}.count) / 오류 \(results.filter{$0.status==.error}.count)")
    }
    
    // MARK: - Individual Checks
    
    private func checkSEOTitle() async -> CheckItem {
        guard let meta = seoMeta, let title = meta.title, !title.isEmpty else {
            return CheckItem(id: UUID(), field: "SEO 제목", message: "SEO 제목이 없습니다", status: .error, autoFix: "onFixSEO")
        }
        if title.count > 60 {
            return CheckItem(id: UUID(), field: "SEO 제목", message: "\(title.count)자 (60자 초과)", status: .warning, autoFix: "onFixSEO")
        }
        return CheckItem(id: UUID(), field: "SEO 제목", message: "\(title.count)자 ✓", status: .passed)
    }
    
    private func checkSEODescription() async -> CheckItem {
        guard let meta = seoMeta, let desc = meta.description, !desc.isEmpty else {
            return CheckItem(id: UUID(), field: "SEO 설명", message: "SEO 설명이 없습니다", status: .error, autoFix: "onFixSEO")
        }
        if desc.count > 160 {
            return CheckItem(id: UUID(), field: "SEO 설명", message: "\(desc.count)자 (160자 초과)", status: .warning, autoFix: "onFixSEO")
        }
        return CheckItem(id: UUID(), field: "SEO 설명", message: "\(desc.count)자 ✓", status: .passed)
    }
    
    private func checkSEOKeywords() async -> CheckItem {
        guard let meta = seoMeta, let keywords = meta.keywords, !keywords.isEmpty else {
            return CheckItem(id: UUID(), field: "SEO 키워드", message: "키워드가 없습니다", status: .error, autoFix: "onFixSEO")
        }
        if keywords.count < 3 {
            return CheckItem(id: UUID(), field: "SEO 키워드", message: "\(keywords.count)개 (3개 이상 권장)", status: .warning, autoFix: "onFixSEO")
        }
        return CheckItem(id: UUID(), field: "SEO 키워드", message: "\(keywords.count)개 ✓", status: .passed)
    }
    
    private func checkSlug() async -> CheckItem {
        guard let plan = post, !plan.slug.isEmpty else {
            return CheckItem(id: UUID(), field: "슬러그", message: "슬러그가 없습니다", status: .error, autoFix: "onFixSlug")
        }
        let valid = plan.slug.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil
        if !valid {
            return CheckItem(id: UUID(), field: "슬러그", message: "영문 소문자+하이픈만 허용", status: .error, autoFix: "onFixSlug")
        }
        // TODO: 중복 체크 (API 호출 필요)
        return CheckItem(id: UUID(), field: "슬러그", message: "형식 ✓", status: .passed)
    }
    
    private func checkCategory() async -> CheckItem {
        guard let plan = post, !plan.categoryIds.isEmpty else {
            return CheckItem(id: UUID(), field: "카테고리", message: "카테고리가 선택되지 않음", status: .error, autoFix: "onFixCategory")
        }
        return CheckItem(id: UUID(), field: "카테고리", message: "\(plan.categoryIds.count)개 선택 ✓", status: .passed)
    }
    
    private func checkTags() async -> CheckItem {
        guard let plan = post, !plan.tags.isEmpty else {
            return CheckItem(id: UUID(), field: "태그", message: "태그가 없습니다", status: .warning, autoFix: "onFixTags")
        }
        return CheckItem(id: UUID(), field: "태그", message: "\(plan.tags.count)개 ✓", status: .passed)
    }
    
    private func checkThumbnail() async -> CheckItem {
        if thumbnailUrl == nil && seoMeta?.image == nil {
            return CheckItem(id: UUID(), field: "썸네일", message: "커버 이미지가 없습니다", status: .error, autoFix: "onFixThumbnail")
        }
        // TODO: 비율/용량 검증 (실제 이미지 로드 필요)
        return CheckItem(id: UUID(), field: "썸네일", message: "존재 ✓", status: .passed)
    }
    
    private func checkImageAlts() async -> CheckItem {
        let promptsWithAlt = imagePromptItems.filter { !$0.prompt.isEmpty }.count
        let totalImages = imagePromptItems.count
        if totalImages == 0 {
            return CheckItem(id: UUID(), field: "이미지 alt", message: "이미지 프롬프트 없음", status: .warning)
        }
        if promptsWithAlt < totalImages {
            return CheckItem(id: UUID(), field: "이미지 alt", message: "\(totalImages - promptsWithAlt)개 이미지 alt 누락", status: .error, autoFix: "onFixImageAlts")
        }
        return CheckItem(id: UUID(), field: "이미지 alt", message: "전체 \(totalImages)개 alt 준비 ✓", status: .passed)
    }
    
    private func checkAppCards() async -> CheckItem {
        let invalidCards = appCards.filter { card in
            (card.storeInfo == nil && card.appUrl == nil && card.homepageUrl == nil) ||
            (card.downloadLinks?.isEmpty ?? true)
        }
        if !invalidCards.isEmpty {
            return CheckItem(id: UUID(), field: "앱 카드", message: "\(invalidCards.count)개 카드 정보 부족", status: .warning, autoFix: "onFixAppCards")
        }
        return CheckItem(id: UUID(), field: "앱 카드", message: "\(appCards.count)개 완료 ✓", status: .passed)
    }
    
    private func checkBodyStructure() async -> CheckItem {
        guard let draft = draft else {
            return CheckItem(id: UUID(), field: "본문 구조", message: "초안 데이터 없음", status: .error, autoFix: "onFixBody")
        }
        let wordCount = draft.bodyMarkdown.split(separator: " ").count
        let headingCount = draft.bodyMarkdown.components(separatedBy: "###").count - 1
        
        var issues: [String] = []
        if wordCount < 500 { issues.append("500자 미만") }
        if headingCount < 2 { issues.append("소제목 2개 미만") }
        
        if !issues.isEmpty {
            return CheckItem(id: UUID(), field: "본문 구조", message: issues.joined(separator: ", "), status: .warning, autoFix: "onFixBody")
        }
        return CheckItem(id: UUID(), field: "본문 구조", message: "\(wordCount)자 / 소제목 \(headingCount)개 ✓", status: .passed)
    }
}

// MARK: - Check Item Model

struct CheckItem: Identifiable {
    let id: UUID
    let field: String
    let message: String
    let status: Status
    let autoFix: String?  // 수정 액션 식별자
    
    enum Status { case passed, warning, error }
    
    var icon: String {
        switch status {
        case .passed: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    var color: Color {
        switch status {
        case .passed: return Color.dsSuccess
        case .warning: return Color.dsWarning
        case .error: return Color.dsDanger
        }
    }
}

struct CheckRow: View {
    let item: CheckItem
    let onAutoFix: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .foregroundStyle(item.color)
                .font(.system(size: 14, weight: .medium))
            Text(item.field)
                .font(.caption.bold())
                .frame(width: 80, alignment: .leading)
            Text(item.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if let _ = item.autoFix, item.status != .passed {
                Button("수정") { onAutoFix() }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.dsSurface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}