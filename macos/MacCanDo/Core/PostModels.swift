// [FEATURE] 게시글 모델 — 웹 API 응답/요청 규격 (T-07)
import Foundation

struct PostCategory: Decodable, Identifiable {
    let id: String
    let slug: String
    let name: String
}

struct PostCategoryRef: Decodable, Identifiable {
    var id: String { slug }
    let name: String
    let slug: String
}

struct PostTagRef: Decodable, Identifiable {
    var id: String { slug }
    let name: String
    let slug: String
}

struct Post: Decodable, Identifiable {
    let id: String
    let title: String
    let slug: String
    let bodyFormat: String
    let body: String
    let excerpt: String?
    let thumbnailUrl: String?
    let status: String
    let viewCount: Int
    let publishedAt: String?
    let updatedAt: String
    let categories: [PostCategoryRef]?
    let tags: [PostTagRef]?
    let contentType: String?
    let seoMeta: SeoMeta?
    let seriesId: String?
    let seriesOrder: Int?
    let featuredOrder: Int? // 홈 추천 순서 (T-11, null=미지정)
    let apps: [AppCardData]? // T-15: 앱 카드 (에디터 로드/저장)

    var isPublished: Bool { status == "PUBLISHED" }
}

// AI SEO 메타 (웹 페이지 meta 태그 자동 구성에 사용)
struct SeoMeta: Codable, Equatable {
    var title: String?
    var description: String?
    var tags: [String]?
    var image: String?
    var appliedAt: String?

    init(title: String?, description: String?, tags: [String]?, image: String?, appliedAt: String?) {
        self.title = title
        self.description = description
        self.tags = tags
        self.image = image
        self.appliedAt = appliedAt
    }
}

// 생성/수정 요청 body
struct PostInput: Encodable {
    var title: String
    var slug: String?
    var categoryIds: [String]?
    var tags: [String]?
    var contentType: String?
    var bodyFormat: String
    var body: String
    var excerpt: String?
    var status: String
    var seoMeta: SeoMeta?
    var seriesId: String?
    var apps: [AppCardData]? // T-15: 앱 카드

    init(title: String, slug: String?, categoryIds: [String]?, tags: [String]?, contentType: String?, bodyFormat: String, body: String, excerpt: String?, status: String, seoMeta: SeoMeta? = nil, seriesId: String? = nil, apps: [AppCardData]? = nil) {
        self.title = title
        self.slug = slug
        self.categoryIds = categoryIds
        self.tags = tags
        self.contentType = contentType
        self.bodyFormat = bodyFormat
        self.body = body
        self.excerpt = excerpt
        self.status = status
        self.seoMeta = seoMeta
        self.seriesId = seriesId
        self.apps = apps
    }

    init(post: Post) {
        title = post.title
        slug = post.slug
        categoryIds = post.categories?.map { $0.slug }
        tags = post.tags?.map { $0.name }
        contentType = post.contentType
        bodyFormat = post.bodyFormat
        body = post.body
        excerpt = post.excerpt
        status = post.status
        seoMeta = post.seoMeta
        seriesId = post.seriesId
        apps = post.apps
    }

    init(draft: DraftRecord) {
        title = draft.title
        slug = nil
        categoryIds = nil
        tags = nil
        contentType = nil
        bodyFormat = draft.bodyFormat
        body = draft.body
        excerpt = nil
        status = draft.status
        seoMeta = nil
        seriesId = nil
    }
}

// ---------- 시리즈 (관리자) — /api/admin/series (사용자 요청) ----------

struct SeriesPost: Decodable, Identifiable {
    let id: String
    let title: String
    let slug: String
    let status: String
    let seriesOrder: Int
    let publishedAt: String?

    var isPublished: Bool { status == "PUBLISHED" }
}

struct SeriesItem: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let imageUrl: String?
    let intro: String?
    let createdAt: String?
    let featuredOrder: Int? // 홈 배너 순서 (T-11, null=미지정)
    let posts: [SeriesPost]
}

struct AdminSeriesData: Decodable {
    let series: [SeriesItem]
    let loosePosts: [LoosePostItem]
}

struct LoosePostItem: Decodable, Identifiable {
    let id: String
    let title: String
    let slug: String
    let status: String
    let updatedAt: String?

    var isPublished: Bool { status == "PUBLISHED" }
}

struct SeriesCreateBody: Encodable {
    let title: String
    let description: String?
    let imageUrl: String?
    let intro: String?
}

struct SeriesUpdateBody: Encodable {
    var title: String?
    var description: String?
    var imageUrl: String?
    var intro: String?
}

// 배너/추천 순서 지정 — nil이어도 키 필수 전송 (null = 해제)
struct FeaturedOrderBody: Encodable {
    let featuredOrder: Int?
}

struct PostIdsBody: Encodable {
    let postIds: [String]
}

// ---------- 댓글 (관리자) — GET /api/admin/comments (T-08) ----------

struct AdminCommentUser: Decodable {
    let id: String
    let name: String?
    let email: String?
    let image: String?
}

struct AdminCommentPost: Decodable {
    let id: String
    let slug: String
    let title: String
}

struct AdminComment: Decodable, Identifiable {
    let id: String
    let content: String
    let status: String
    let createdAt: String
    let user: AdminCommentUser
    let post: AdminCommentPost
}

// ---------- 통계 (관리자) — GET /api/admin/stats (T-08) ----------

struct AdminStats: Decodable {
    let postCount: Int
    let commentCount: Int
    let pendingCommentCount: Int
    let clickCount: Int
    let userCount: Int
    let totalViews: Int
    let daily: [DailyStat]
}

struct DailyStat: Decodable, Identifiable {
    let date: String
    let views: Int
    let clicks: Int
    let comments: Int
    let newUsers: Int
    var id: String { date }
}