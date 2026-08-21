// [FEATURE] T-86: ResearchBundle/CollectedItem 정규화 모델 (v2.15)
// 수집된 소스 데이터를 파이프라인에서 사용할 통합 모델로 정규화
import Foundation

// 수집된 단일 아이템 (RSS/웹 검색/기존 리포트 등 모든 소스 공통)
struct CollectedItem: Codable, Identifiable, Hashable {
    let id: UUID
    let sourceName: String           // 소스 이름 (예: "9to5Mac", "MacRumors")
    let sourceURL: String            // 원문 URL
    let title: String                // 기사/게시글 제목
    let summary: String              // AI 요약 (한국어, 3~5줄)
    let evaluation: String           // 신뢰도/중요도 평가 (예: "공식 발표 기반, 높은 신뢰도")
    let keywords: [String]           // 추출된 핵심 키워드 (3~5개)
    let publishedAt: Date            // 발행 일시
    let rawContent: String?          // 원문 전체 (선택, 용량 고려)
    
    init(
        id: UUID = UUID(),
        sourceName: String,
        sourceURL: String,
        title: String,
        summary: String,
        evaluation: String,
        keywords: [String],
        publishedAt: Date,
        rawContent: String? = nil
    ) {
        self.id = id
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.title = title
        self.summary = summary
        self.evaluation = evaluation
        self.keywords = keywords
        self.publishedAt = publishedAt
        self.rawContent = rawContent
    }
}

// 앱 후보 (App Store 검색 결과 또는 웹에서 발견된 앱)
struct AppCandidate: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String                 // 앱 이름
    let bundleId: String?            // 번들 ID (App Store일 때)
    let appStoreURL: String?         // App Store URL
    let homepageURL: String?         // 공식 홈페이지 URL
    let description: String          // 앱 설명 (한국어)
    let category: String             // 카테고리 (예: "생산성", "개발 도구")
    let price: String                // 가격 (예: "무료", "₩5,900", "구독")
    let iconURL: String?             // 아이콘 URL
    let version: String?             // 현재 버전
    let rating: Double?              // 평점
    let ratingCount: Int?            // 리뷰 수
    
    init(
        id: UUID = UUID(),
        name: String,
        bundleId: String? = nil,
        appStoreURL: String? = nil,
        homepageURL: String? = nil,
        description: String,
        category: String,
        price: String,
        iconURL: String? = nil,
        version: String? = nil,
        rating: Double? = nil,
        ratingCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.appStoreURL = appStoreURL
        self.homepageURL = homepageURL
        self.description = description
        self.category = category
        self.price = price
        self.iconURL = iconURL
        self.version = version
        self.rating = rating
        self.ratingCount = ratingCount
    }
}

// 연구 번들 (1단계 출력 → 2단계 입력)
struct ResearchBundle: Codable {
    let topic: String                    // 사용자 입력 주제/키워드
    let sources: [CollectedItem]         // 수집된 아이템들 (최신순 정렬)
    let keywords: [String]               // 통합 키워드 (빈도순 상위 10개)
    let relatedApps: [AppCandidate]      // 관련 앱 후보들
    let collectedAt: Date                // 수집 완료 시각
    
    init(
        topic: String,
        sources: [CollectedItem],
        keywords: [String],
        relatedApps: [AppCandidate],
        collectedAt: Date = Date()
    ) {
        self.topic = topic
        self.sources = sources.sorted { $0.publishedAt > $1.publishedAt }
        self.keywords = keywords
        self.relatedApps = relatedApps
        self.collectedAt = collectedAt
    }
}

// 섹션 기획 (2단계 출력 일부)
struct SectionPlan: Codable, Identifiable, Hashable {
    let id: UUID
    let heading: String                  // 섹션 제목 (예: "핵심 기능", "설치 방법")
    let keyPoints: [String]              // 다룰 핵심 포인트들
    let imagePromptHint: String?         // 본문 이미지 프롬프트 힌트
    let order: Int                       // 섹션 순서
    
    init(
        id: UUID = UUID(),
        heading: String,
        keyPoints: [String],
        imagePromptHint: String? = nil,
        order: Int
    ) {
        self.id = id
        self.heading = heading
        self.keyPoints = keyPoints
        self.imagePromptHint = imagePromptHint
        self.order = order
    }
}

// 포스트 기획 전체 (2단계 출력)
struct PostPlan: Codable {
    enum PlanMode: String, Codable { case single, series }
    
    let mode: PlanMode
    let title: String
    let slug: String
    let categoryIds: [String]
    let tags: [String]
    let sections: [SectionPlan]
    let coverPrompt: ImagePromptItem     // 커버 이미지 프롬프트
    let appCards: [AppCardCandidate]
    let estimatedWordCount: Int          // 예상 총 글자 수
    
    init(
        mode: PlanMode = .single,
        title: String,
        slug: String,
        categoryIds: [String],
        tags: [String],
        sections: [SectionPlan],
        coverPrompt: ImagePromptItem,
        appCards: [AppCandidate] = [],
        estimatedWordCount: Int = 0
    ) {
        self.mode = mode
        self.title = title
        self.slug = slug
        self.categoryIds = categoryIds
        self.tags = tags
        self.sections = sections.sorted { $0.order < $1.order }
        self.coverPrompt = coverPrompt
        self.appCards = appCards.map { AppCardCandidate(from: $0) }
        self.estimatedWordCount = estimatedWordCount
    }
}

// 앱 카드 후보 (PostPlan에서 사용)
struct AppCardCandidate: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let appStoreURL: String?
    let homepageURL: String?
    let storeInfoSnapshot: [String: String]?  // storeInfo 스냅샷 (제목/이미지/개발자 등)
    let downloadLinks: [DownloadLinkCandidate]
    
    init(from app: AppCandidate) {
        self.id = app.id
        self.name = app.name
        self.appStoreURL = app.appStoreURL
        self.homepageURL = app.homepageURL
        self.storeInfoSnapshot = [
            "appName": app.name,
            "artworkUrl100": app.iconURL ?? "",
            "sellerName": "",  // 별도 조회 시 채움
            "version": app.version ?? "",
            "price": app.price,
            "description": app.description
        ]
        self.downloadLinks = []
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        appStoreURL: String? = nil,
        homepageURL: String? = nil,
        storeInfoSnapshot: [String: String]? = nil,
        downloadLinks: [DownloadLinkCandidate] = []
    ) {
        self.id = id
        self.name = name
        self.appStoreURL = appStoreURL
        self.homepageURL = homepageURL
        self.storeInfoSnapshot = storeInfoSnapshot
        self.downloadLinks = downloadLinks
    }
}

struct DownloadLinkCandidate: Codable, Hashable {
    let label: String
    let url: String
    let type: String  // "OFFICIAL" | "FREE" | "TORRENT"
}

// 드래프트 패키지 (3단계 출력 → 에디터 주입)
struct DraftPackage: Codable {
    let title: String
    let bodyMarkdown: String             // 완성된 마크다운 본문
    let imagePrompts: [ImagePromptItem]  // 커버 + 본문 이미지 프롬프트들
    let appCards: [PostAppInput]         // 앱 카드 입력 데이터
    let seoMeta: SEOSuggestion           // SEO 메타 제안
    let plan: PostPlan                   // 원본 기획 (참조용)
    
    init(
        title: String,
        bodyMarkdown: String,
        imagePrompts: [ImagePromptItem],
        appCards: [PostAppInput],
        seoMeta: SEOSuggestion,
        plan: PostPlan
    ) {
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.imagePrompts = imagePrompts
        self.appCards = appCards
        self.seoMeta = seoMeta
        self.plan = plan
    }
}

// 발행 준비 패키지 (5단계 출력)
struct PublishPackage: Codable {
    let postId: String
    let seoMeta: SEOSuggestion
    let thumbnailValidated: Bool
    let imageAltsValidated: Bool
    let appCardsValidated: Bool
    let validationIssues: [ValidationIssue]
    
    var isReady: Bool {
        validationIssues.filter { $0.severity == .error }.isEmpty
    }
}

struct ValidationIssue: Codable, Identifiable {
    let id: UUID
    let field: String
    let message: String
    let severity: Severity
    let autoFixAction: String?  // 자동 수정 액션 식별자
    
    enum Severity: String, Codable { case error, warning, info }
    
    init(
        id: UUID = UUID(),
        field: String,
        message: String,
        severity: Severity,
        autoFixAction: String? = nil
    ) {
        self.id = id
        self.field = field
        self.message = message
        self.severity = severity
        self.autoFixAction = autoFixAction
    }
}

// PostAppInput은 posts.ts와 호환되는 구조 (web/lib/posts.ts 참고)
// 여기서 재정의하지 않고 GeminiService에서 import 해서 사용

// SEOSuggestion은 GeminiService에 정의됨 (import 해서 사용)