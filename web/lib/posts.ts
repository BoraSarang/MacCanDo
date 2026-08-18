// [FEATURE] 게시글 로직 — T-03(공개 목록/상세/검색) + T-07(관리 CRUD)
// 공개: getPosts / getRecentPosts / getCategories / getPostBySlug
// 관리: createPost / updatePost / deletePost (macOS 에디터 → /api/admin/posts)
import { Prisma, PostStatus, PostContentType, BodyFormat } from "@/app/generated/prisma/client";
import { db } from "./db";
import { trackImageUsage } from "./image";
import { logger } from "./logger";
import { lookupAppStore } from "./store-fetch";
import { fetchOgMetadata } from "./og-fetch"; // T-31: 일반 웹사이트 앱 카드 og 메타 채우기
import { bumpDailyStat } from "./stats"; // T-59: 일별 통계

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
  contentType: string;
  categories: { name: string; slug: string }[];
  tags: { name: string; slug: string }[]; // T-18: 목록 카드 태그 배지
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
  contentType?: string;
  tagSlug?: string;
  query?: string;
  page?: number;
  pageSize?: number;
  skip?: number; // T-12~14: 홈 '최신 게시글'(최근의 나머지) 오프셋
  sort?: "latest" | "views"; // T-11 정렬 (최신순/조회수순)
}

// 목록 (카테고리 필터 + pg_trgm 기반 검색 + 페이징) — 발행 글만 (PAGE 타입 제외, T-17)
// 정렬: 시리즈 글은 (시리즈 최신 편 발행일, seriesOrder) 기준으로 나란히, 일반 글은 publishedAt desc
export async function getPosts(params: PostListParams = {}): Promise<PostListResult> {
  const { categorySlug, contentType, tagSlug, query, page = 1, pageSize = 12, skip = 0, sort = "latest" } = params;
  const notPage = { not: "PAGE" as PostContentType };
  const where: Prisma.PostWhereInput = {
    status: "PUBLISHED" as PostStatus,
    ...(contentType ? { contentType: contentType as PostContentType } : { contentType: notPage }),
    ...(categorySlug ? { categories: { some: { category: { slug: categorySlug } } } } : {}),
    ...(tagSlug ? { tags: { some: { tag: { slug: tagSlug } } } } : {}),
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
  if (categorySlug) {
    conds.push(
      Prisma.sql`EXISTS (SELECT 1 FROM "PostCategory" pcx JOIN "Category" cx ON cx.id = pcx."categoryId" WHERE pcx."postId" = p.id AND cx."slug" = ${categorySlug})`
    );
  }
  if (contentType) {
    conds.push(Prisma.sql`p."contentType" = ${contentType}::"PostContentType"`);
  } else {
    conds.push(Prisma.sql`p."contentType" != 'PAGE'`);
  }
  if (tagSlug) {
    conds.push(
      Prisma.sql`EXISTS (SELECT 1 FROM "PostTag" ptx JOIN "Tag" tx ON tx.id = ptx."tagId" WHERE ptx."postId" = p.id AND tx."slug" = ${tagSlug})`
    );
  }
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
    contentType: string;
    categoryNames: string | null;
    categorySlugs: string | null;
    tagNames: string | null;
    tagSlugs: string | null;
    commentCount: number;
  }[]>(Prisma.sql`
    SELECT p.id, p.slug, p.title, p.excerpt, p."thumbnailUrl", p."publishedAt", p."viewCount", p."contentType"::text,
           (SELECT string_agg(c2."name", ', ' ORDER BY c2."sort", c2."name") FROM "PostCategory" pc2 JOIN "Category" c2 ON c2.id = pc2."categoryId" WHERE pc2."postId" = p.id) AS "categoryNames",
           (SELECT string_agg(c3."slug", ',' ORDER BY c3."sort", c3."name") FROM "PostCategory" pc3 JOIN "Category" c3 ON c3.id = pc3."categoryId" WHERE pc3."postId" = p.id) AS "categorySlugs",
           (SELECT string_agg(t2."name", ', ' ORDER BY t2."name") FROM "PostTag" pt2 JOIN "Tag" t2 ON t2.id = pt2."tagId" WHERE pt2."postId" = p.id) AS "tagNames",
           (SELECT string_agg(t3."slug", ',' ORDER BY t3."name") FROM "PostTag" pt3 JOIN "Tag" t3 ON t3.id = pt3."tagId" WHERE pt3."postId" = p.id) AS "tagSlugs",
           (SELECT COUNT(*)::int FROM "Comment" cm WHERE cm."postId" = p.id AND cm.status = 'APPROVED') AS "commentCount"
    FROM "Post" p
    WHERE ${Prisma.join(conds, " AND ")}
    ORDER BY
      ${sort === "views"
        ? Prisma.sql`p."viewCount" DESC, p."publishedAt" DESC`
        : Prisma.sql`CASE WHEN p."seriesId" IS NULL THEN p."publishedAt"
             ELSE (SELECT MAX(p2."publishedAt") FROM "Post" p2 WHERE p2."seriesId" = p."seriesId" AND p2."status" = 'PUBLISHED') END DESC,
        CASE WHEN p."seriesId" IS NULL THEN NULL ELSE p."seriesOrder" END ASC NULLS LAST`}
    LIMIT ${pageSize} OFFSET ${skip + (page - 1) * pageSize}
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
    contentType: p.contentType,
    categories: p.categoryNames && p.categorySlugs
      ? p.categoryNames.split(", ").map((name, i) => ({ name, slug: (p.categorySlugs?.split(",")[i] ?? "").trim() }))
      : [],
    tags: p.tagNames && p.tagSlugs
      ? p.tagNames.split(", ").map((name, i) => ({ name, slug: (p.tagSlugs?.split(",")[i] ?? "").trim() }))
      : [],
  }));

  return { items: mapped, total, page, pageSize, totalPages: Math.max(1, Math.ceil(total / pageSize)) };
}

// 최근 게시글 (홈)
// 홈 최근 게시글 — count개. offset 지정 시 그 이후의 글 (홈 '최신 게시글' = 최근의 나머지)
export async function getRecentPosts(count = 6, offset = 0) {
  return getPosts({ page: 1, pageSize: count, skip: offset });
}

// 홈 추천 게시글 — 관리자 지정(featuredOrder) 우선, 모자라면 조회수 top으로 채움 (T-11)
export async function getFeaturedPosts(count = 3) {
  const pick = {
    id: true,
    slug: true,
    title: true,
    excerpt: true,
    thumbnailUrl: true,
    publishedAt: true,
    viewCount: true,
    contentType: true,
    categories: { include: { category: { select: { name: true, slug: true } } } },
  } as const;
  const featured = await db.post.findMany({
    where: { status: "PUBLISHED", contentType: { not: "PAGE" }, featuredOrder: { not: null } },
    orderBy: [{ featuredOrder: "asc" }, { publishedAt: "desc" }],
    take: count,
    select: pick,
  });
  if (featured.length >= count) return featured;
  const extra = await db.post.findMany({
    where: {
      status: "PUBLISHED",
      contentType: { not: "PAGE" },
      featuredOrder: null,
      ...(featured.length ? { id: { notIn: featured.map((f) => f.id) } } : {}),
    },
    orderBy: [{ viewCount: "desc" }, { publishedAt: "desc" }],
    take: count - featured.length,
    select: pick,
  });
  return [...featured, ...extra];
}

// 관련 게시글 — 같은 태그 공유 우선, 모자라면 같은 카테고리로 폴백 (T-11)
export async function getRelatedPosts(postId: string, tagIds: string[], categoryIds: string[], count = 3) {
  const pick = {
    id: true,
    slug: true,
    title: true,
    excerpt: true,
    thumbnailUrl: true,
    publishedAt: true,
    viewCount: true,
    contentType: true,
    categories: { include: { category: { select: { name: true, slug: true } } } },
  } as const;
  const notSelf = { id: { not: postId } } as const;
  const byTag = await db.post.findMany({
    where: {
      status: "PUBLISHED",
      contentType: { not: "PAGE" },
      ...notSelf,
      ...(tagIds.length ? { tags: { some: { tagId: { in: tagIds } } } } : { id: "__none__" }),
    },
    orderBy: { publishedAt: "desc" },
    take: count,
    select: pick,
  });
  if (byTag.length >= count) return byTag;
  const byCat = await db.post.findMany({
    where: {
      status: "PUBLISHED",
      contentType: { not: "PAGE" },
      ...notSelf,
      ...(byTag.length ? { id: { notIn: byTag.map((p) => p.id) } } : {}),
      ...(categoryIds.length ? { categories: { some: { categoryId: { in: categoryIds } } } } : { id: "__none__" }),
    },
    orderBy: { publishedAt: "desc" },
    take: count - byTag.length,
    select: pick,
  });
  return [...byTag, ...byCat];
}

// 이전글/다음글 — 발행일 기준 1편씩. 시리즈 글은 제외 (하단 시리즈 목록이 이전/다음 역할) (T-11)
// 동일 발행일 글이 많으면 id 사전순으로 폴백 (데모 데이터처럼 bulk 발행 시에도 동작)
export async function getPrevNextPosts(slug: string) {
  const post = await db.post.findUnique({
    where: { slug },
    select: { id: true, seriesId: true, publishedAt: true },
  });
  if (!post || post.seriesId || !post.publishedAt) return null;
  const [prev, next] = await Promise.all([
    db.post.findFirst({
      where: {
        status: "PUBLISHED",
        contentType: { not: "PAGE" },
        seriesId: null,
        OR: [
          { publishedAt: { lt: post.publishedAt } },
          { publishedAt: post.publishedAt, id: { lt: post.id } },
        ],
      },
      orderBy: [{ publishedAt: "desc" }, { id: "desc" }],
      select: { slug: true, title: true },
    }),
    db.post.findFirst({
      where: {
        status: "PUBLISHED",
        contentType: { not: "PAGE" },
        seriesId: null,
        OR: [
          { publishedAt: { gt: post.publishedAt } },
          { publishedAt: post.publishedAt, id: { gt: post.id } },
        ],
      },
      orderBy: [{ publishedAt: "asc" }, { id: "asc" }],
      select: { slug: true, title: true },
    }),
  ]);
  return { prev, next };
}

// 카테고리 (게시글 수 포함 — 발행 기준)
export async function getCategories() {
  const cats = await db.category.findMany({
    orderBy: { sort: "asc" },
    include: { _count: { select: { posts: { where: { post: { status: "PUBLISHED" } } } } } },
  });
  return cats.map((c) => ({
    id: c.id,
    slug: c.slug,
    name: c.name,
    description: c.description,
    icon: c.icon, // T-12: 사이드바/카드용 이모지
    postCount: c._count.posts,
  }));
}

// 태그 목록 (글 수 포함 — 발행 기준)
export async function getTags() {
  const tags = await db.tag.findMany({
    orderBy: { name: "asc" },
    include: { _count: { select: { posts: { where: { post: { status: "PUBLISHED" } } } } } },
  });
  return tags.map((t) => ({ id: t.id, slug: t.slug, name: t.name, postCount: t._count.posts }));
}

// generateMetadata 전용 경량 조회 (T-63 P3: 무거운 include 쿼리 2회 → select 축소)
export async function getPostMetaBySlug(slug: string) {
  const post = await db.post.findUnique({
    where: { slug },
    select: { title: true, excerpt: true, thumbnailUrl: true, seoMeta: true, contentType: true, status: true },
  });
  if (!post || post.status !== "PUBLISHED") return null;
  return post;
}

// 상세 (조회수 증가 옵션 — generateMetadata에서는 incrementView=false)
export async function getPostBySlug(slug: string, incrementView = true) {
  const post = await db.post.findUnique({
    where: { slug },
    include: {
      categories: { include: { category: { select: { name: true, slug: true } } } },
      tags: { include: { tag: { select: { name: true, slug: true } } } },
      downloadLinks: { orderBy: { sort: "asc" } },
      apps: { orderBy: { sort: "asc" }, include: { downloadLinks: { orderBy: { sort: "asc" } } } }, // T-15
      _count: { select: { comments: { where: { status: "APPROVED" } } } },
    },
  });
  if (!post || post.status !== "PUBLISHED") return null;

  // T-17: 정적 페이지(PAGE)는 조회수 미집계
  if (incrementView && post.contentType !== "PAGE") {
    incrementPostView(post.slug).catch(() => {});
  }
  return post;
}

// T-60: 조회수 기록 (SSG 페이지에서 클라이언트 → POST /api/posts/[slug]/view)
export async function incrementPostView(slug: string): Promise<void> {
  const target = await db.post.findFirst({ where: { slug, status: "PUBLISHED" }, select: { id: true, contentType: true } });
  if (!target || target.contentType === "PAGE") return; // T-17: 정적 페이지 미집계
  await db.post.update({ where: { id: target.id }, data: { viewCount: { increment: 1 } } });
  bumpDailyStat("views"); // T-59: 일별 통계
}

// ---------- 관리 (T-07) ----------

// T-15: 앱 카드 입력 (macOS 에디터 → 글 저장 시 함께 전송)
export interface PostAppInput {
  appId?: string | null;
  appUrl?: string | null;
  homepageUrl?: string | null;
  storeInfo?: Prisma.InputJsonValue | null; // 추출 스냅샷 (store-fetch 결과)
  downloadLinks?: { label: string; url: string; type?: "OFFICIAL" | "FREE" | "TORRENT" }[]; // 앱별 공개 다운로드
}

export interface PostInput {
  title: string;
  slug?: string;
  categoryIds?: string[];
  tags?: string[];
  contentType?: "ARTICLE" | "TIP" | "NEWS" | "PAGE"; // T-17: PAGE = 정적 페이지
  bodyFormat: BodyFormat;
  body: string;
  excerpt?: string | null;
  thumbnailUrl?: string | null;
  status: PostStatus;
  storeInfo?: Prisma.InputJsonValue | null;
  seoMeta?: Prisma.InputJsonValue | null;
  seriesId?: string | null; // 시리즈 소속 (1편, 2편... 순서는 시리즈 관리에서 결정)
  featuredOrder?: number | null; // 홈 추천 순서 (T-11)
  apps?: PostAppInput[]; // T-15: 앱 카드 목록 (미전달 시 유지, [] 전달 시 전체 삭제)
}

// T-20: 기존 [app] 위치 마커 → [app:URL] 자동 변환 (저장 시 1회)
// 시트 삽입 패턴 "[app]␣␣[/app]" 블록을 apps 배열 순서대로 URL 마커로 치환
function migrateAppMarkers(body: string, apps: PostAppInput[]): string {
  let idx = 0;
  return body.replace(/\[app\]\s*\[\/app\]/g, () => {
    const a = apps[idx++];
    const url = a?.appUrl ?? a?.homepageUrl;
    return url ? `[app:${url}]` : "[app]\n\n[/app]";
  });
}

// T-20: 본문 [app:URL] 마커에서 URL 추출 → 앱 데이터에 없는 URL이면 store-fetch로 자동 보강
// 렌더링 시점이 아닌 저장 시점 1회만 조회 (웹 페이지 열람 시 외부 요청 없음)
function extractAppMarkerUrls(body: string): string[] {
  const urls: string[] = [];
  for (const m of body.matchAll(/\[app:([^\]]+)\]/g)) {
    const u = m[1].trim();
    if (u.startsWith("http")) urls.push(u);
  }
  return urls;
}

async function enrichAppsFromMarkers(body: string, apps: PostAppInput[]): Promise<PostAppInput[]> {
  const urls = extractAppMarkerUrls(body);
  if (urls.length === 0) return apps;
  const out = [...apps];
  for (const url of urls) {
    const existing = out.find((a) => a.appUrl === url || a.homepageUrl === url);
    if (existing) {
      // T-31: 기존 카드가 URL만 있고(storeInfo 없음) App Store가 아니면 og 메타로 채우기
      if (!existing.storeInfo && !url.startsWith("https://apps.apple.com/")) {
        const og = await fetchOgMetadata(url);
        if (og) {
          existing.homepageUrl = url;
          existing.storeInfo = {
            appName: og.title,
            artworkUrl100: og.image,
            sellerName: og.siteName,
            description: og.description,
            sellerUrl: og.url,
          } as unknown as Prisma.InputJsonValue;
          logger.info("Post", `[app:URL] 기존 카드 og 메타 채움 (${url}) → ${og.title}`);
        }
      }
      continue;
    }
    const meta = await lookupAppStore(url);
    if (meta) {
      out.push({
        appUrl: url,
        storeInfo: meta as unknown as Prisma.InputJsonValue,
        downloadLinks: [],
      });
    } else {
      // 조회 실패 → URL만 있는 카드 (렌더 시 호스트명 표시)
      // T-26: App Store URL이 아니면 appUrl(→"App Store ↗")가 아니라 homepageUrl로 저장
      const isStore = url.startsWith("https://apps.apple.com/");
      if (!isStore) {
        // T-31: 일반 웹사이트 — og 메타 스크래핑으로 이름/이미지/설명 채우기 (실패 시 URL만)
        const og = await fetchOgMetadata(url);
        if (og) {
          out.push({
            homepageUrl: url,
            storeInfo: {
              appName: og.title,
              artworkUrl100: og.image,
              sellerName: og.siteName,
              description: og.description,
              sellerUrl: og.url,
            } as unknown as Prisma.InputJsonValue,
            downloadLinks: [],
          });
          logger.info("Post", `[app:URL] og 메타 채움 (${url}) → ${og.title}${og.image ? " +이미지" : ""}`);
          continue;
        }
      }
      out.push(
        isStore
          ? { appUrl: url, storeInfo: null, downloadLinks: [] }
          : { homepageUrl: url, storeInfo: null, downloadLinks: [] }
      );
    }
  }
  if (out.length > apps.length) {
    logger.info("Post", `[app:URL] 마커 앱 자동 보강 +${out.length - apps.length}개 (body 마커 ${urls.length}개)`);
  }
  return out;
}

// 앱 카드 전체 교체 (기존 앱 + 앱별 다운로드 삭제 후 재생성)
async function resolveApps(postId: string, apps: PostAppInput[] | undefined) {
  if (apps === undefined) return;
  await db.$transaction(async (tx) => {
    await tx.downloadLink.deleteMany({ where: { postId, postAppId: { not: null } } });
    await tx.postApp.deleteMany({ where: { postId } });
    for (let i = 0; i < apps.length; i++) {
      const a = apps[i];
      const created = await tx.postApp.create({
        data: {
          postId,
          sort: i,
          appId: a.appId || null,
          appUrl: a.appUrl || null,
          homepageUrl: a.homepageUrl || null,
          storeInfo: a.storeInfo ?? undefined,
        },
      });
      for (let j = 0; j < (a.downloadLinks?.length ?? 0); j++) {
        const dl = a.downloadLinks![j];
        if (!dl.url) continue; // URL 없는 다운로드 링크는 저장 생략 (T-21, macOS AppCardLink.url 없던 구버전 호환)
        await tx.downloadLink.create({
          data: {
            postId,
            postAppId: created.id,
            label: dl.label,
            url: dl.url,
            type: dl.type ?? "FREE",
            sort: j,
          },
        });
      }
    }
  });
  logger.info("Post", `앱 카드 ${apps.length}개 저장 (post=${postId})`);
}

// 카테고리 참조(id 또는 slug) → id 배열 (다대다)
async function resolveCategoryIds(refs: string[] | undefined): Promise<{ create: { categoryId: string }[] }> {
  const creates = [];
  for (const ref of refs ?? []) {
    const cat =
      (await db.category.findUnique({ where: { id: ref } })) ??
      (await db.category.findUnique({ where: { slug: ref } }));
    if (cat) creates.push({ categoryId: cat.id });
  }
  return { create: creates };
}

// 태그 이름 배열 → upsert + id 배열 (자유 생성 허용)
async function resolveTagIds(names: string[] | undefined): Promise<{ create: { tag: { connect: { id: string } } }[] }> {
  const creates = [];
  for (const raw of names ?? []) {
    const name = raw.trim().replace(/^#+/, "");
    if (!name) continue;
    const slug = makeTagSlug(name);
    const tag = await db.tag.upsert({
      where: { slug },
      update: {},
      create: { name, slug },
    });
    creates.push({ tag: { connect: { id: tag.id } } });
  }
  return { create: creates };
}

function makeTagSlug(name: string): string {
  const base = name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9가-힣-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 40);
  return base || `tag-${Date.now().toString(36)}`;
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
  if (input.contentType && !["ARTICLE", "TIP", "NEWS", "PAGE"].includes(input.contentType)) return "E-WEB-VALID-1001";
  return null;
}

export async function createPost(input: PostInput) {
  const invalid = validatePostInput(input);
  if (invalid) return { ok: false as const, error: invalid };

  const slug = await uniqueSlug(makeSlug(input.title, input.slug));
  try {
    const body = migrateAppMarkers(input.body, input.apps ?? []);
    const post = await db.post.create({
      data: {
        title: input.title.trim(),
        slug,
        contentType: input.contentType ?? "ARTICLE",
        bodyFormat: input.bodyFormat,
        body,
        excerpt: input.excerpt?.trim() || null,
        thumbnailUrl: input.thumbnailUrl || null,
        status: input.status,
        storeInfo: input.storeInfo ?? undefined,
        seoMeta: input.seoMeta ?? undefined,
        seriesId: input.seriesId || null,
        featuredOrder: input.featuredOrder ?? undefined,
        publishedAt: input.status === "PUBLISHED" ? new Date() : null,
        categories: await resolveCategoryIds(input.categoryIds),
        tags: await resolveTagIds(input.tags),
      },
    });
    logger.info("Post", `생성 slug=${slug} status=${input.status} categories=${input.categoryIds?.length ?? 0} tags=${input.tags?.length ?? 0}`);
    await trackImageUsage(post.id, post.body);
    const apps = input.apps === undefined ? undefined : await enrichAppsFromMarkers(post.body, input.apps);
    await resolveApps(post.id, apps);
    return { ok: true as const, post };
  } catch (e) {
    logger.error("Post", `생성 실패: ${e}`);
    return { ok: false as const, error: "E-WEB-POST-1001" };
  }
}

export async function updatePost(id: string, input: PostInput) {
  const invalid = validatePostInput(input);
  if (invalid) return { ok: false as const, error: invalid };

  const existing = await db.post.findUnique({ where: { id }, select: { id: true, slug: true, publishedAt: true } });
  if (!existing) return { ok: false as const, error: "E-WEB-POST-1003" };

  // T-26: slug 미지정(빈 값)이면 기존 slug 유지 — 제목 기반 재생성으로 URL이 바뀌는 문제 수정
  const slug = input.slug?.trim()
    ? await uniqueSlug(makeSlug(input.title, input.slug), id)
    : existing.slug;
  try {
    const body = migrateAppMarkers(input.body, input.apps ?? []);
    const post = await db.post.update({
      where: { id },
      data: {
        title: input.title.trim(),
        slug,
        ...(input.contentType !== undefined ? { contentType: input.contentType } : {}),
        bodyFormat: input.bodyFormat,
        body,
        excerpt: input.excerpt?.trim() || null,
        thumbnailUrl: input.thumbnailUrl || null,
        status: input.status,
        storeInfo: input.storeInfo ?? undefined,
        seoMeta: input.seoMeta ?? undefined,
        ...(input.seriesId !== undefined ? { seriesId: input.seriesId } : {}), // 미전달 시 기존 유지
        ...(input.featuredOrder !== undefined ? { featuredOrder: input.featuredOrder } : {}), // T-11
        publishedAt:
          input.status === "PUBLISHED" && !existing.publishedAt
            ? new Date()
            : input.status === "DRAFT"
              ? null
              : undefined,
        ...(input.categoryIds !== undefined
          ? { categories: { deleteMany: {}, ...(await resolveCategoryIds(input.categoryIds)) } }
          : {}),
        ...(input.tags !== undefined ? { tags: { deleteMany: {}, ...(await resolveTagIds(input.tags)) } } : {}),
      },
    });
    logger.info("Post", `수정 id=${id} slug=${slug} status=${input.status}`);
    await trackImageUsage(id, post.body);
    const apps = input.apps === undefined ? undefined : await enrichAppsFromMarkers(post.body, input.apps);
    await resolveApps(id, apps);
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