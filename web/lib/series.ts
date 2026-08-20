// [FEATURE] 시리즈 로직 — 사용자 요청 (시리즈 묶기 + 모아보기 + 순서)
// 공개: getSeriesOverview / getSeriesById (웹 페이지용)
// 관리: createSeries / updateSeries / deleteSeries / addPostsToSeries / setSeriesOrder / removePostFromSeries
import { db } from "./db";
import { PostStatus } from "@/app/generated/prisma/client";

// ---------- 공개 ----------

export interface SeriesPost {
  id: string;
  title: string;
  slug: string;
  excerpt: string | null;
  thumbnailUrl: string | null;
  publishedAt: Date | null;
  seriesOrder: number;
}

export interface SeriesOverview {
  id: string;
  title: string;
  description: string | null;
  imageUrl: string | null;
  intro: string | null;
  featuredOrder: number | null; // 홈 배너 순서 (T-11)
  posts: SeriesPost[];
}

// 전체 시리즈 (발행 글만, 순서대로) — /series
export async function getSeriesOverview(): Promise<SeriesOverview[]> {
  const series = await db.series.findMany({
    orderBy: { createdAt: "desc" },
    include: {
      posts: {
        where: { status: "PUBLISHED" as PostStatus, seriesOrder: { not: null } },
        orderBy: { seriesOrder: "asc" },
        select: {
          id: true,
          title: true,
          slug: true,
          excerpt: true,
          thumbnailUrl: true,
          publishedAt: true,
          seriesOrder: true,
        },
      },
    },
  });
  return series
    .filter((s) => s.posts.length > 0)
    .map((s) => ({
      id: s.id,
      title: s.title,
      description: s.description,
      imageUrl: s.imageUrl,
      intro: s.intro,
      featuredOrder: s.featuredOrder,
      posts: s.posts.map((p) => ({ ...p, seriesOrder: p.seriesOrder as number })),
    }));
}

// 홈 시리즈 배너 — 관리자 지정(featuredOrder) 우선, 나머지 최신순으로 채움 (T-11)
export async function getSeriesBanner(count = 4): Promise<SeriesOverview[]> {
  const all = await getSeriesOverview();
  return all
    .sort((a, b) => (a.featuredOrder ?? 999) - (b.featuredOrder ?? 999))
    .slice(0, count);
}

// 개별 시리즈 (발행 글만) — /series/[id]
export async function getSeriesById(id: string): Promise<SeriesOverview | null> {
  const series = await db.series.findUnique({
    where: { id },
    include: {
      posts: {
        where: { status: "PUBLISHED" as PostStatus, seriesOrder: { not: null } },
        orderBy: { seriesOrder: "asc" },
        select: {
          id: true,
          title: true,
          slug: true,
          excerpt: true,
          thumbnailUrl: true,
          publishedAt: true,
          seriesOrder: true,
        },
      },
    },
  });
  if (!series) return null;
  return {
    id: series.id,
    title: series.title,
    description: series.description,
    imageUrl: series.imageUrl,
    intro: series.intro,
    featuredOrder: series.featuredOrder,
    posts: series.posts.map((p) => ({ ...p, seriesOrder: p.seriesOrder as number })),
  };
}

// 게시글 상세의 시리즈 컨텍스트 (하단 목록용) — 발행 글만
export async function getSeriesForPost(seriesId: string) {
  const series = await db.series.findUnique({
    where: { id: seriesId },
    include: {
      posts: {
        where: { status: "PUBLISHED" as PostStatus, seriesOrder: { not: null } },
        orderBy: { seriesOrder: "asc" },
        select: {
          id: true,
          title: true,
          slug: true,
          seriesOrder: true,
        },
      },
    },
  });
  if (!series) return null;
  return {
    id: series.id,
    title: series.title,
    posts: series.posts.map((p) => ({ ...p, seriesOrder: p.seriesOrder as number })),
  };
}

// ---------- 관리 (macOS 앱 + 웹 admin) ----------

export interface AdminSeriesItem {
  id: string;
  title: string;
  description: string | null;
  imageUrl: string | null;
  intro: string | null;
  featuredOrder: number | null; // 홈 배너 순서 (T-11)
  createdAt: Date;
  posts: {
    id: string;
    title: string;
    slug: string;
    status: PostStatus;
    seriesOrder: number;
    publishedAt: Date | null;
  }[];
}

// 관리자용 전체 목록 (DRAFT 포함)
export async function getAdminSeriesList(): Promise<AdminSeriesItem[]> {
  const series = await db.series.findMany({
    orderBy: { createdAt: "desc" },
    include: {
      posts: {
        where: { seriesOrder: { not: null } },
        orderBy: { seriesOrder: "asc" },
        select: {
          id: true,
          title: true,
          slug: true,
          status: true,
          seriesOrder: true,
          publishedAt: true,
        },
      },
    },
  });
  return series.map((s) => ({
    id: s.id,
    title: s.title,
    description: s.description,
    imageUrl: s.imageUrl,
    intro: s.intro,
    featuredOrder: s.featuredOrder,
    createdAt: s.createdAt,
    posts: s.posts.map((p) => ({ ...p, seriesOrder: p.seriesOrder as number })),
  }));
}

// 시리즈 없는 글 (추가용) — 제목 검색 지원, 최근 글부터
export async function getPostsWithoutSeries(q?: string) {
  return db.post.findMany({
    where: { seriesId: null, ...(q?.trim() ? { title: { contains: q.trim(), mode: "insensitive" } } : {}) },
    orderBy: { updatedAt: "desc" },
    select: { id: true, title: true, slug: true, status: true, updatedAt: true },
  });
}

export async function createSeries(title: string, description?: string | null, imageUrl?: string | null, intro?: string | null) {
  const series = await db.series.create({
    data: {
      title: title.trim(),
      description: description?.trim() || null,
      imageUrl: imageUrl?.trim() || null,
      intro: intro?.trim() || null,
    },
  });
  return { ...series, posts: [] as { id: string; title: string; slug: string; status: PostStatus; seriesOrder: number; publishedAt: Date | null }[] };
}

export async function updateSeries(id: string, title?: string, description?: string | null, imageUrl?: string | null, intro?: string | null, featuredOrder?: number | null) {
  const data: { title?: string; description?: string | null; imageUrl?: string | null; intro?: string | null; featuredOrder?: number | null } = {};
  if (title !== undefined) data.title = title.trim();
  if (description !== undefined) data.description = description?.trim() || null;
  if (imageUrl !== undefined) data.imageUrl = imageUrl?.trim() || null;
  if (intro !== undefined) data.intro = intro?.trim() || null;
  if (featuredOrder !== undefined) data.featuredOrder = featuredOrder;
  // PATCH 후에도 posts를 실제로 포함해 반환 (빈 배열 반환 시 macOS 앱 로컬 시리즈의 글 목록이 초기화됨)
  const series = await db.series.update({
    where: { id },
    data,
    include: {
      posts: {
        where: { seriesOrder: { not: null } },
        orderBy: { seriesOrder: "asc" },
        select: {
          id: true,
          title: true,
          slug: true,
          status: true,
          seriesOrder: true,
          publishedAt: true,
        },
      },
    },
  });
  return { ...series, posts: series.posts.map((p) => ({ ...p, seriesOrder: p.seriesOrder as number })) };
}

// 삭제 시 글은 유지 (seriesId만 SetNull)
export async function deleteSeries(id: string) {
  await db.$transaction([
    db.post.updateMany({ where: { seriesId: id }, data: { seriesId: null, seriesOrder: null } }),
    db.series.delete({ where: { id } }),
  ]);
}

// 글 추가 — 시리즈의 마지막 순서 다음 번호 배정
export async function addPostsToSeries(seriesId: string, postIds: string[]) {
  const series = await db.series.findUnique({
    where: { id: seriesId },
    include: { posts: { select: { seriesOrder: true } } },
  });
  if (!series) throw new Error("E-WEB-DB-1001");
  let order = Math.max(0, ...series.posts.map((p) => p.seriesOrder ?? 0));
  for (const postId of postIds) {
    order += 1;
    await db.post.update({ where: { id: postId }, data: { seriesId, seriesOrder: order } });
  }
  return getAdminSeriesList();
}

// 순서 저장 — 배열 순서 = 1편, 2편, 3편...
export async function setSeriesOrder(seriesId: string, postIds: string[]) {
  await db.$transaction(
    postIds.map((postId, idx) =>
      db.post.update({ where: { id: postId }, data: { seriesId, seriesOrder: idx + 1 } })
    )
  );
  return getAdminSeriesList();
}

// 시리즈에서 글 제거 (글 자체는 유지) — 남은 글들은 1편부터 재번호
export async function removePostFromSeries(postId: string) {
  const post = await db.post.findUnique({ where: { id: postId }, select: { seriesId: true } });
  if (!post?.seriesId) {
    return db.post.update({ where: { id: postId }, data: { seriesId: null, seriesOrder: null } });
  }
  const seriesId = post.seriesId;
  await db.post.update({ where: { id: postId }, data: { seriesId: null, seriesOrder: null } });
  // 남은 글들 1부터 재정렬 (2편, 3편...이 남지 않도록)
  const remaining = await db.post.findMany({
    where: { seriesId, seriesOrder: { not: null } },
    orderBy: { seriesOrder: "asc" },
    select: { id: true },
  });
  await db.$transaction(
    remaining.map((p, idx) => db.post.update({ where: { id: p.id }, data: { seriesOrder: idx + 1 } }))
  );
}
