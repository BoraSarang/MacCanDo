// [FEATURE] 백업/복원 로직 — T-08
// LWW: 복원 시 서버 updatedAt이 덤프보다 최신이면 해당 레코드 건너뜀
import { db } from "@/lib/db";

export type BackupPayload = {
  version?: number;
  posts: {
    id?: string;
    title: string;
    slug: string;
    bodyFormat?: string;
    body: string;
    excerpt?: string | null;
    thumbnailUrl?: string | null;
    status?: string;
    contentType?: string;
    categorySlugs?: string[];
    tags?: string[];
    viewCount?: number;
    publishedAt?: string | null;
    updatedAt?: string;
    createdAt?: string;
  }[];
  categories: {
    id?: string;
    slug: string;
    name: string;
  }[];
  comments: {
    id?: string;
    postSlug?: string;
    postId?: string;
    content: string;
    status?: string;
    createdAt?: string;
  }[];
};

export async function backupAll() {
  const [posts, categories, comments] = await Promise.all([
    db.post.findMany({
      include: {
        categories: { include: { category: { select: { slug: true, name: true } } } },
        tags: { include: { tag: { select: { slug: true, name: true } } } },
      },
      orderBy: { updatedAt: "desc" },
    }),
    db.category.findMany(),
    db.comment.findMany({
      include: { post: { select: { slug: true } } },
      orderBy: { createdAt: "desc" },
    }),
  ]);

  return {
    exportedAt: new Date().toISOString(),
    app: "MacCanDo",
    version: 2,
    categories: categories.map((c) => ({ id: c.id, slug: c.slug, name: c.name })),
    posts: posts.map((p) => ({
      id: p.id,
      title: p.title,
      slug: p.slug,
      bodyFormat: p.bodyFormat,
      body: p.body,
      excerpt: p.excerpt,
      thumbnailUrl: p.thumbnailUrl,
      status: p.status,
      contentType: p.contentType,
      categorySlugs: p.categories.map((pc) => pc.category.slug),
      tags: p.tags.map((pt) => pt.tag.name),
      viewCount: p.viewCount,
      publishedAt: p.publishedAt?.toISOString() ?? null,
      createdAt: p.createdAt.toISOString(),
      updatedAt: p.updatedAt.toISOString(),
    })),
    comments: comments.map((c) => ({
      id: c.id,
      postSlug: c.post?.slug ?? null,
      content: c.content,
      status: c.status,
      createdAt: c.createdAt.toISOString(),
    })),
  };
}

export async function restoreBackup(payload: BackupPayload) {
  const stats = { categories: 0, posts: 0, comments: 0, skipped: 0 };

  // 1) 카테고리 upsert
  for (const c of payload.categories) {
    await db.category.upsert({
      where: { slug: c.slug },
      update: { name: c.name },
      create: { slug: c.slug, name: c.name },
    });
    stats.categories++;
  }

  // 2) 게시글 upsert (LWW — 덤프 updatedAt이 서버보다 최신일 때만)
  const slugToId = new Map<string, string>();
  for (const p of payload.posts) {
    const existing = await db.post.findUnique({ where: { slug: p.slug } });
    const dumpTime = p.updatedAt ? new Date(p.updatedAt).getTime() : 0;
    if (existing && existing.updatedAt.getTime() > dumpTime) {
      stats.skipped++;
      slugToId.set(p.slug, existing.id);
      continue;
    }
    const categoryIds = (p.categorySlugs ?? [])
      .map((slug) => payload.categories.find((c) => c.slug === slug)?.id ?? slug)
      .filter(Boolean);
    const data = {
      title: p.title,
      slug: p.slug,
      bodyFormat: (p.bodyFormat as "MD" | "HTML") ?? "MD",
      body: p.body,
      excerpt: p.excerpt ?? null,
      thumbnailUrl: p.thumbnailUrl ?? null,
      status: (p.status as "DRAFT" | "PUBLISHED") ?? "DRAFT",
      contentType: (p.contentType as "ARTICLE" | "TIP" | "NEWS") ?? "ARTICLE",
      viewCount: p.viewCount ?? 0,
      publishedAt: p.publishedAt ? new Date(p.publishedAt) : null,
      updatedAt: p.updatedAt ? new Date(p.updatedAt) : new Date(),
    };
    const saved = await db.post.upsert({
      where: { slug: p.slug },
      update: data,
      create: { ...data, id: p.id } as never,
    });
    // 카테고리 연결 (다대다 — 덤프 기준으로 재구성)
    if (p.categorySlugs && p.categorySlugs.length > 0) {
      await db.postCategory.deleteMany({ where: { postId: saved.id } });
      for (const slug of p.categorySlugs) {
        const cat = await db.category.findUnique({ where: { slug } });
        if (cat) await db.postCategory.create({ data: { postId: saved.id, categoryId: cat.id } });
      }
    }
    // 태그 연결 (자유 생성)
    if (p.tags && p.tags.length > 0) {
      await db.postTag.deleteMany({ where: { postId: saved.id } });
      for (const name of p.tags) {
        const tagSlug = name.toLowerCase().replace(/[^a-z0-9가-힣]+/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "");
        const tag = await db.tag.upsert({ where: { slug: tagSlug }, update: {}, create: { name, slug: tagSlug } });
        await db.postTag.create({ data: { postId: saved.id, tagId: tag.id } });
      }
    }
    slugToId.set(p.slug, saved.id);
    stats.posts++;
  }

  // 3) 댓글 upsert (게시글 slug → id 매핑)
  for (const c of payload.comments) {
    const postId = c.postSlug ? slugToId.get(c.postSlug) : c.postId;
    if (!postId) {
      stats.skipped++;
      continue;
    }
    await db.comment.upsert({
      where: { id: c.id ?? `backup-${c.postSlug}-${c.content.slice(0, 20)}` },
      update: {
        content: c.content,
        status: (c.status as "PENDING" | "APPROVED" | "SPAM") ?? "PENDING",
      },
      create: {
        id: c.id ?? undefined,
        postId,
        content: c.content,
        status: (c.status as "PENDING" | "APPROVED" | "SPAM") ?? "PENDING",
        createdAt: c.createdAt ? new Date(c.createdAt) : undefined,
      },
    });
    stats.comments++;
  }

  return stats;
}