// [FEATURE] 게시글 로직 — T-03(공개 목록/상세/검색) + T-07(관리 CRUD)
// 공개: getPosts / getRecentPosts / getCategories / getPostBySlug
// 관리: createPost / updatePost / deletePost (macOS 에디터 → /api/admin/posts)
import { Prisma } from "@/app/generated/prisma/client";
import { db } from "./db";
import { trackImageUsage } from "./image";
import { logger } from "./logger";
import { PostStatus } from "@/app/generated/prisma/client";

// ---------- 공개 (T-03) ----------

export interface PostListItem {
  id: string;
  slug: string;
  title: string;
  excerpt: string | null;
  thumbnailUrl: string | null;
  publishedAt: Date | null;
  viewCount: number;
  commentCount: number;
  category: { name: string; slug: string } | null;
}

export interface PostListResult {
  items: PostListItem[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export interface PostListParams {
  categorySlug?: string;
  query?: string;
  page?: number;
  pageSize?: number;
}

// 목록 (카테고리 필터 + pg_trgm 기반 검색 + 페이징) — 발행 글만
// 정렬: 시리즈 글은 (시리즈 최신 편 발행일, seriesOrder) 기준으로 나란히, 일반 글은 publishedAt desc
export async function getPosts(params: PostListParams = {}): Promise<PostListResult> {
  const { categorySlug, query, page = 1, pageSize = 12 } = params;
  const where: Prisma.PostWhereInput = {
    status: "PUBLISHED" as PostStatus,
    ...(categorySlug ? { category: { slug: categorySlug } } : {}),
    ...(query
      ? {
          OR: [
            { title: { contains: query, mode: "insensitive" as const } },
            { excerpt: { contains: query, mode: "insensitive" as const } },
            { body: { contains: query, mode: "insensitive" as const } },
          ],
        }
      : {}),
  };
  const total = await db.post.count({ where });

  const conds: Prisma.Sql[] = [Prisma.sql`p."status" = 'PUBLISHED'`];
  if (categorySlug) conds.push(Prisma.sql`c."slug" = ${categorySlug}`);
  if (query) {
    const q = `%${query}%`;
    conds.push(Prisma.sql`(p."title" ILIKE ${q} OR p."excerpt" ILIKE ${q} OR p."body" ILIKE ${q})`);
  }
  const items = await db.$queryRaw<{
    id: string;
    slug: string;
    title: string;
    excerpt: string | null;
    thumbnailUrl: string | null;
    publishedAt: Date | null;
    viewCount: number;
    categoryName: string | null;
    categorySlug: string | null;
    commentCount: number;
  }[]>(Prisma.sql`
    SELECT p.id, p.slug, p.title, p.excerpt, p."thumbnailUrl", p."publishedAt", p."viewCount",
           c."name" AS "categoryName", c."slug" AS "categorySlug",
           (SELECT COUNT(*)::int FROM "Comment" cm WHERE cm."postId" = p.id AND cm.status = 'APPROVED') AS "commentCount"
    FROM "Post" p
    LEFT JOIN "Category" c ON c.id = p."categoryId"
    WHERE ${Prisma.join(conds, " AND ")}
    ORDER BY
      CASE WHEN p."seriesId" IS NULL THEN p."publishedAt"
           ELSE (SELECT MAX(p2."publishedAt") FROM "Post" p2 WHERE p2."seriesId" = p."seriesId" AND p2."status" = 'PUBLISHED') END DESC,
      CASE WHEN p."seriesId" IS NULL THEN NULL ELSE p."seriesOrder" END ASC NULLS LAST
    LIMIT ${pageSize} OFFSET ${(page - 1) * pageSize}
  `);

  const mapped = items.map((p) => ({
    id: p.id,
    slug: p.slug,
    title: p.title,
    excerpt: p.excerpt,
    thumbnailUrl: p.thumbnailUrl,
    publishedAt: p.publishedAt,
    viewCount: p.viewCount,
    commentCount: p.commentCount,
    category: p.categoryName && p.categorySlug ? { name: p.categoryName, slug: p.categorySlug } : null,
  }));

  return { items: mapped, total, page, pageSize, totalPages: Math.max(1, Math.ceil(total / pageSize)) };
}

// 최근 게시글 (홈)
export async function getRecentPosts(count = 6) {
  return getPosts({ page: 1, pageSize: count });
}

// 카테고리 (게시글 수 포함 — 발행 기준)
export async function getCategories() {
  const cats = await db.category.findMany({
    orderBy: { sort: "asc" },
    include: { _count: { select: { posts: { where: { status: "PUBLISHED" } } } } },
  });
  return cats.map((c) => ({ id: c.id, slug: c.slug, name: c.name, postCount: c._count.posts }));
}

// 상세 (조회수 증가 옵션 — generateMetadata에서는 incrementView=false)
export async function getPostBySlug(slug: string, incrementView = true) {
  const post = await db.post.findUnique({
    where: { slug },
    include: {
      category: { select: { name: true, slug: true } },
      downloadLinks: { orderBy: { sort: "asc" } },
      _count: { select: { comments: { where: { status: "APPROVED" } } } },
    },
  });
  if (!post || post.status !== "PUBLISHED") return null;

  if (incrementView) {
    db.post
      .update({ where: { id: post.id }, data: { viewCount: { increment: 1 } } })
      .catch((e) => logger.warn("Post", `조회수 증가 실패: ${e}`));
  }
  return post;
}

// ---------- 관리 (T-07) ----------

export type BodyFormat = "MD" | "HTML";

export interface PostInput {
  title: string;
  slug?: string;
  categoryId?: string | null;
  bodyFormat: BodyFormat;
  body: string;
  excerpt?: string | null;
  thumbnailUrl?: string | null;
  status: PostStatus;
  storeInfo?: Prisma.InputJsonValue | null;
  seoMeta?: Prisma.InputJsonValue | null;
  seriesId?: string | null; // 시리즈 소속 (1편, 2편... 순서는 시리즈 관리에서 결정)
}

// slug 생성: 제목의 영문/숫자만 사용, 비면 post-{timestamp}
export function makeSlug(title: string, fallback?: string): string {
  const base = (fallback ?? title)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60);
  return base || `post-${Date.now().toString(36)}`;
}

// slug 중복 회피: slug, slug-2, slug-3 ...
async function uniqueSlug(base: string, excludeId?: string): Promise<string> {
  let slug = base;
  let n = 2;
  for (;;) {
    const found = await db.post.findUnique({
      where: { slug },
      select: { id: true },
    });
    if (!found || found.id === excludeId) return slug;
    slug = `${base}-${n}`;
    n += 1;
  }
}

export function validatePostInput(input: PostInput): string | null {
  if (!input.title?.trim()) return "E-WEB-VALID-1001";
  if (!input.body?.trim()) return "E-WEB-VALID-1001";
  if (input.bodyFormat !== "MD" && input.bodyFormat !== "HTML") return "E-WEB-VALID-1001";
  if (input.status !== "DRAFT" && input.status !== "PUBLISHED") return "E-WEB-VALID-1001";
  return null;
}

export async function createPost(input: PostInput) {
  const invalid = validatePostInput(input);
  if (invalid) return { ok: false as const, error: invalid };

  const slug = await uniqueSlug(makeSlug(input.title, input.slug));
  try {
    const post = await db.post.create({
      data: {
        title: input.title.trim(),
        slug,
        categoryId: input.categoryId || null,
        bodyFormat: input.bodyFormat,
        body: input.body,
        excerpt: input.excerpt?.trim() || null,
        thumbnailUrl: input.thumbnailUrl || null,
        status: input.status,
        storeInfo: input.storeInfo ?? undefined,
        seoMeta: input.seoMeta ?? undefined,
        seriesId: input.seriesId || null,
        publishedAt: input.status === "PUBLISHED" ? new Date() : null,
      },
    });
    logger.info("Post", `생성 slug=${slug} status=${input.status}`);
    await trackImageUsage(post.id, post.body);
    return { ok: true as const, post };
  } catch (e) {
    logger.error("Post", `생성 실패: ${e}`);
    return { ok: false as const, error: "E-WEB-POST-1001" };
  }
}

export async function updatePost(id: string, input: PostInput) {
  const invalid = validatePostInput(input);
  if (invalid) return { ok: false as const, error: invalid };

  const existing = await db.post.findUnique({ where: { id }, select: { id: true, publishedAt: true } });
  if (!existing) return { ok: false as const, error: "E-WEB-POST-1003" };

  const slug = await uniqueSlug(makeSlug(input.title, input.slug), id);
  try {
    const post = await db.post.update({
      where: { id },
      data: {
        title: input.title.trim(),
        slug,
        categoryId: input.categoryId || null,
        bodyFormat: input.bodyFormat,
        body: input.body,
        excerpt: input.excerpt?.trim() || null,
        thumbnailUrl: input.thumbnailUrl || null,
        status: input.status,
        storeInfo: input.storeInfo ?? undefined,
        seoMeta: input.seoMeta ?? undefined,
        seriesId: input.seriesId || null,
        publishedAt:
          input.status === "PUBLISHED" && !existing.publishedAt
            ? new Date()
            : input.status === "DRAFT"
              ? null
              : undefined,
      },
    });
    logger.info("Post", `수정 id=${id} slug=${slug} status=${input.status}`);
    await trackImageUsage(id, post.body);
    return { ok: true as const, post };
  } catch (e) {
    logger.error("Post", `수정 실패: ${e}`);
    return { ok: false as const, error: "E-WEB-POST-1001" };
  }
}

export async function deletePost(id: string) {
  const existing = await db.post.findUnique({ where: { id }, select: { id: true } });
  if (!existing) return { ok: false as const, error: "E-WEB-POST-1003" };
  try {
    await db.post.delete({ where: { id } });
    logger.info("Post", `삭제 id=${id}`);
    return { ok: true as const };
  } catch (e) {
    logger.error("Post", `삭제 실패: ${e}`);
    return { ok: false as const, error: "E-WEB-POST-1002" };
  }
}