// [FEATURE] T-84: WritingPipeline 엔진 — 5단계 파이프라인 (v2.15)
import Foundation

@MainActor
final class WritingPipeline {
    static let shared = WritingPipeline()
    
    private init() {}
    
    // MARK: - Public Pipeline Methods
    
    /// 1단계: 주제 → 자료 수집/정규화
    /// - Parameter topic: 사용자 입력 주제/키워드
    /// - Parameter sources: 수집할 소스들 (기본: MacNewsStore 소스들)
    /// - Returns: ResearchBundle (정규화된 수집 데이터)
    func collectAndNormalize(
        topic: String,
        sources: [NewsSource] = MacNewsStore.loadSources().filter { $0.isActive }
    ) async throws -> ResearchBundle {
        DebugLogger.info("Pipeline", "[FEATURE] 1단계 시작: 수집/정규화 topic=\(topic)")
        
        // 소스별 수집 (병렬)
        var allItems: [CollectedItem] = []
        var allApps: [AppCandidate] = []

        await withTaskGroup(of: (String, [CollectedItem], [AppCandidate]).self) { group in
            for source in sources {
                group.addTask {
                    let (items, apps) = await self.collectFromSource(source, topic: topic)
                    return (source.name, items, apps)
                }
            }

            for await (sourceName, items, apps) in group {
                DebugLogger.info("Pipeline", "소스 '\(sourceName)' 수집 완료: \(items.count)개 아이템, \(apps.count)개 앱")
                allItems.append(contentsOf: items)
                allApps.append(contentsOf: apps)
            }
        }

        // T-96: DuckDuckGo 웹 검색 보강 — RSS 결과 부족 시 또는 항상 병행
        do {
            let webResults = try await WebSearchService.search(topic, limit: 8)
            let webItems = webResults.map { r in
                CollectedItem(
                    sourceName: "웹 검색",
                    sourceURL: r.url,
                    title: r.title,
                    summary: r.snippet,
                    evaluation: "",
                    keywords: [],
                    publishedAt: Date()
                )
            }
            DebugLogger.info("Pipeline", "[FEATURE] 웹 검색 수집 완료: \(webItems.count)건")
            allItems.append(contentsOf: webItems)
        } catch {
            DebugLogger.warn("Pipeline", "웹 검색 실패 (RSS 결과로 계속): \(error)")
        }

        // 중복 제거 후 상위 8개 AI 요약/키워드/평가 생성
        let dedupedForSummary = deduplicateByURL(allItems)
        let summarized = await summarizeItems(dedupedForSummary, topic: topic)

        // 키워드 추출 (빈도순)
        let keywords = extractKeywords(from: summarized, topK: 10)

        // 중복 제거 (URL 기준)
        let uniqueItems = deduplicateByURL(summarized)
        let uniqueApps = deduplicateApps(allApps)
        
        let bundle = ResearchBundle(
            topic: topic,
            sources: uniqueItems,
            keywords: keywords,
            relatedApps: uniqueApps
        )
        
        DebugLogger.info("Pipeline", "[FEATURE] 1단계 완료: \(uniqueItems.count)개 아이템, \(keywords.count)개 키워드, \(uniqueApps.count)개 앱")
        return bundle
    }
    
    /// 2단계: ResearchBundle → PostPlan (기획/구조화)
    func planStructure(bundle: ResearchBundle, mode: PostPlan.PlanMode = .single) async throws -> PostPlan {
        DebugLogger.info("Pipeline", "[FEATURE] 2단계 시작: 기획/구조화 mode=\(mode)")
        
        // 템플릿 선택 (기본: 앱 소개형)
        let template = PromptLibrary.shared.templates(for: .appIntro).first ?? PromptLibrary.defaultBuiltInTemplates()[0]
        
        // 프롬프트 구성
        let systemPrompt = template.systemPrompt
        let userPrompt = """
        주제: \(bundle.topic)
        
        수집된 자료 요약:
        \(bundle.sources.prefix(5).map { "- \($0.title): \($0.summary)" }.joined(separator: "\n"))
        
        핵심 키워드: \(bundle.keywords.joined(separator: ", "))
        
        관련 앱 후보: \(bundle.relatedApps.prefix(3).map { $0.name }.joined(separator: ", "))
        
        위 자료를 바탕으로 \(mode == .single ? "단일 글" : "시리즈(3~5편)") 기획을 JSON으로 출력하세요:
        {
          "title": "글 제목 (흥미롭고 검색 친화적)",
          "slug": "영문-소문자-하이픈",
          "categoryIds": ["카테고리ID배열"],
          "tags": ["태그1", "태그2"],
          "sections": [
            {"heading": "섹션 제목", "keyPoints": ["포인트1", "포인트2"], "imagePromptHint": "이미지 프롬프트 힌트", "order": 1}
          ],
          "coverPrompt": {"label": "커버 이미지", "aspectRatio": "16:9", "prompt": "영어 프롬프트"},
          "appCards": [{"name": "앱명", "appStoreURL": "url", "homepageURL": "url", "storeInfoSnapshot": {...}, "downloadLinks": []}],
          "estimatedWordCount": 2000
        }
        
        JSON 외 텍스트 출력 금지.
        """
        
        let raw = try await GeminiService.fetchText(prompt: userPrompt, action: .wizard)
        guard let data = extractJSON(from: raw),
              let plan = try? JSONDecoder().decode(PostPlan.self, from: data) else {
            throw APIError(code: "E-MAC-PIPE-1001", message: "기획 JSON 파싱 실패", status: -1)
        }
        
        DebugLogger.info("Pipeline", "[FEATURE] 2단계 완료: \(plan.sections.count)개 섹션, 제목=\(plan.title)")
        return plan
    }
    
    /// 3단계: PostPlan → DraftPackage (초안 생성)
    func generateDraft(plan: PostPlan) async throws -> DraftPackage {
        DebugLogger.info("Pipeline", "[FEATURE] 3단계 시작: 초안 생성")
        
        // 섹션별 본문 생성
        var bodyParts: [String] = []
        
        for (idx, section) in plan.sections.enumerated() {
            let sectionPrompt = """
            섹션 \(idx + 1): \(section.heading)
            
            핵심 포인트:
            \(section.keyPoints.map { "- \($0)" }.joined(separator: "\n"))
            
            이미지 힌트: \(section.imagePromptHint ?? "없음")
            
            위 내용을 바탕으로 이 섹션의 본문을 마크다운으로 작성하세요.
            - 소제목(###) 포함
            - 핵심 포인트 모두 다루기
            - 이미지 마커 [img:URL alt="설명"] 적절히 삽입 (URL은 플레이스홀더)
            - 앱 카드 마커 [app:URL] 적절히 삽입
            - 한국어, 친근하고 전문적 톤
            """
            
            let sectionBody = try await GeminiService.fetchText(prompt: sectionPrompt, action: .wizard)
            bodyParts.append(sectionBody.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        let bodyMarkdown = bodyParts.joined(separator: "\n\n---\n\n")
        
        // SEO 메타 생성
        let seoMeta = try await generateSEO(plan: plan, body: bodyMarkdown)
        
        // 앱 카드 입력 변환
        let appCards = plan.appCards.map { candidate in
            PostAppInput(
                appId: nil,
                appUrl: candidate.appStoreURL,
                homepageUrl: candidate.homepageURL,
                storeInfo: candidate.storeInfoSnapshot as? Prisma.InputJsonValue,
                downloadLinks: candidate.downloadLinks.map { PostAppInput.DownloadLink(label: $0.label, url: $0.url, type: $0.type) }
            )
        }
        
        // 이미지 프롬프트 (커버 + 본문)
        var imagePrompts = [plan.coverPrompt]
        // 본문 이미지 프롬프트는 plan에서 생성된 것 사용 (이미 있음)
        
        let draft = DraftPackage(
            title: plan.title,
            bodyMarkdown: bodyMarkdown,
            imagePrompts: imagePrompts,
            appCards: appCards,
            seoMeta: seoMeta,
            plan: plan
        )
        
        DebugLogger.info("Pipeline", "[FEATURE] 3단계 완료: 본문 \(bodyMarkdown.count)자, 이미지 \(imagePrompts.count)개, 앱카드 \(appCards.count)개")
        return draft
    }
    
    /// 4단계: 에디터 주입 (DraftPackage → EditorView 상태 설정)
    func injectToEditor(draft: DraftPackage) async throws {
        DebugLogger.info("Pipeline", "[FEATURE] 4단계: 에디터 주입")
        
        // NotificationCenter를 통해 EditorView에 전달
        // 실제 구현은 EditorView에서 옵저빙
        NotificationCenter.default.post(
            name: .pipelineDraftReady,
            object: nil,
            userInfo: ["draft": draft]
        )
    }
    
    /// 5단계: 발행 준비 검증
    func preparePublish(postId: String) async throws -> PublishPackage {
        DebugLogger.info("Pipeline", "[FEATURE] 5단계: 발행 준비 검증 postId=\(postId)")
        
        // 서버에서 포스트 조회 후 검증
        // 실제 구현 시 API 호출
        var issues: [ValidationIssue] = []
        
        // TODO: 실제 검증 로직 구현
        // - SEO 제목/설명/키워드 길이/키워드 포함
        // - 슬러그 중복/형식
        // - 썸네일 존재/비율/용량
        // - 본문 이미지 alt 전체 존재
        // - 앱 카드 storeInfo/다운로드링크
        // - 본문 길이/구조
        
        return PublishPackage(
            postId: postId,
            seoMeta: SEOSuggestion(),
            thumbnailValidated: false,
            imageAltsValidated: false,
            appCardsValidated: false,
            validationIssues: issues
        )
    }
    
    // MARK: - Private Helpers

    /// T-96: 상위 8개 아이템 AI 일괄 요약 — API 1회 호출로 비용 절감
    /// 실패 시 원본(스니펫만) 유지로 파이프라인 중단 없음
    private func summarizeItems(_ items: [CollectedItem], topic: String) async -> [CollectedItem] {
        let targets = Array(items.prefix(8))
        guard !targets.isEmpty else { return items }

        let list = targets.enumerated().map { idx, item in
            "\(idx + 1). [\(item.sourceName)] \(item.title)\n   URL: \(item.sourceURL)\n   내용: \(item.summary.isEmpty ? "(제목만)" : String(item.summary.prefix(300)))"
        }.joined(separator: "\n")

        let prompt = """
        주제: \(topic)

        수집한 자료 목록:
        \(list)

        각 자료를 한국어로 분석해 JSON 배열로 출력하세요:
        [
          {"index": 1, "summary": "3~5줄 요약", "evaluation": "신뢰도/중요도 한 줄 평가", "keywords": ["키워드", ...]},
          ...
        ]
        JSON 외 텍스트 출력 금지.
        """

        do {
            let raw = try await GeminiService.fetchText(prompt: prompt, action: .wizard)
            guard let data = extractJSON(from: raw),
                  let parsed = try? JSONDecoder().decode([SummaryEntry].self, from: data) else {
                DebugLogger.warn("Pipeline", "요약 JSON 파싱 실패 — 스니펫으로 유지")
                return items
            }
            var result = items
            for entry in parsed where entry.index >= 1 && entry.index <= targets.count {
                let target = targets[entry.index - 1]
                if let pos = result.firstIndex(where: { $0.id == target.id }) {
                    result[pos] = CollectedItem(
                        sourceName: target.sourceName,
                        sourceURL: target.sourceURL,
                        title: target.title,
                        summary: entry.summary,
                        evaluation: entry.evaluation,
                        keywords: entry.keywords,
                        publishedAt: target.publishedAt,
                        rawContent: target.rawContent
                    )
                }
            }
            DebugLogger.info("Pipeline", "[FEATURE] AI 요약 완료: \(parsed.count)/\(targets.count)건")
            return result
        } catch {
            DebugLogger.warn("Pipeline", "AI 요약 실패 — 스니펫으로 유지: \(error)")
            return items
        }
    }

    private struct SummaryEntry: Codable {
        let index: Int
        let summary: String
        let evaluation: String
        let keywords: [String]
    }

    private func collectFromSource(_ source: NewsSource, topic: String) async -> ([CollectedItem], [AppCandidate]) {
        // T-96: RSS fetch → 관련성 필터 → CollectedItem 변환 (AI 요약은 일괄 단계에서)
        do {
            let raws = try await NewsCollector.fetchRaw(source: source, limit: 10)
            let filtered = filterRelevant(raws, topic: topic)
            let items = filtered.map { raw in
                CollectedItem(
                    sourceName: raw.source,
                    sourceURL: raw.url,
                    title: raw.title,
                    summary: "",           // AI 요약은 summarizeItems에서 일괄 처리
                    evaluation: "",
                    keywords: [],
                    publishedAt: Self.parseDate(raw.published) ?? Date()
                )
            }
            return (items, [])
        } catch {
            DebugLogger.warn("Pipeline", "소스 '\(source.name)' 수집 실패: \(error)")
            return ([], [])
        }
    }

    /// 제목/스니펫에 토픽 키워드 포함 여부로 관련성 필터 (토픽이 짧으면 전체 통과)
    private func filterRelevant(_ items: [RawNewsItem], topic: String) -> [RawNewsItem] {
        let tokens = topic.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
        guard !tokens.isEmpty else { return items }

        func isRelevant(_ text: String) -> Bool {
            let lower = text.lowercased()
            return tokens.contains { lower.contains($0) }
        }
        let matched = items.filter { isRelevant($0.title) }
        // 매칭 부족 시 원본 유지 (빈 결과 방지)
        return matched.isEmpty ? items : matched
    }

    /// RSS pubDate 다양한 형식 파싱 (RFC822/ISO8601)
    static func parseDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let rfc822 = DateFormatter()
        rfc822.locale = Locale(identifier: "en_US_POSIX")
        rfc822.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let d = rfc822.date(from: trimmed) { return d }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: trimmed) { return d }
        return nil
    }
    
    private func extractKeywords(from items: [CollectedItem], topK: Int) -> [String] {
        var freq: [String: Int] = [:]
        for item in items {
            for kw in item.keywords {
                freq[kw, default: 0] += 1
            }
        }
        return freq.sorted { $0.value > $1.value }.prefix(topK).map { $0.key }
    }
    
    private func deduplicateByURL(_ items: [CollectedItem]) -> [CollectedItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.sourceURL).inserted }
    }
    
    private func deduplicateApps(_ apps: [AppCandidate]) -> [AppCandidate] {
        var seen = Set<String>()
        return apps.filter {
            let key = $0.bundleId ?? $0.appStoreURL ?? $0.homepageURL ?? $0.name
            return seen.insert(key).inserted
        }
    }
    
    private func extractJSON(from raw: String) -> Data? {
        // ```json ... ``` 래퍼 제거
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") { s = String(s.dropFirst(7)) }
        if s.hasPrefix("```") { s = String(s.dropFirst(3)) }
        if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)
    }
    
    private func generateSEO(plan: PostPlan, body: String) async throws -> SEOSuggestion {
        let prompt = """
        글 제목: \(plan.title)
        본문 요약: \(String(body.prefix(2000)))
        
        SEO 메타를 JSON으로 생성:
        {"title": "SEO 제목 (60자 내외)", "description": "설명 (160자 내외)", "keywords": ["키워드1","키워드2","키워드3"], "image": "커버이미지URL플레이스홀더"}
        """
        let raw = try await GeminiService.fetchText(prompt: prompt, action: .seo)
        guard let data = extractJSON(from: raw),
              let seo = try? JSONDecoder().decode(SEOSuggestion.self, from: data) else {
            return SEOSuggestion()
        }
        return seo
    }
}

// Notification 이름 확장
extension Notification.Name {
    static let pipelineDraftReady = Notification.Name("pipelineDraftReady")
    static let pipelineStepCompleted = Notification.Name("pipelineStepCompleted")
    static let newPostRequested = Notification.Name("newPostRequested")
    static let newStoryWizardRequested = Notification.Name("newStoryWizardRequested")
}

// Prisma.InputJsonValue 타입 별칭 (web/lib/posts.ts와 호환)
typealias PrismaInputJsonValue = [String: Any]

extension PostAppInput {
    struct DownloadLink: Codable {
        let label: String
        let url: String
        let type: String
    }
}

// PostPlan.PlanMode 확장
extension PostPlan.PlanMode {
    var displayName: String {
        switch self {
        case .single: return "단일 글"
        case .series: return "시리즈"
        }
    }
}