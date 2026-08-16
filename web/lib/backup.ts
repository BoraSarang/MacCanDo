// [FEATURE] 백업/복원 로직 — T-08
// LWW: 복원 시 서버 updatedAt이 덤프보다 최신이면 해당 레코드 건너뜀
import { db } from "@/lib/db";

export type BackupPayload = {
  posts: {
    id?: string;
    title: string;
    slug: string;
    bodyFormat?: string;
    body: string;
    excerpt?: string | null;
    thumbnailUrl?: string | null;
    status?: string;
    categorySlug?: string | null;
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
      include: { category: { select: { slug: true, name: true } } },
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
    version: 1,
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
      categorySlug: p.category?.slug ?? null,
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
    const category = p.categorySlug
      ? await db.category.findUnique({ where: { slug: p.categorySlug } })
      : null;
    const data = {
      title: p.title,
      slug: p.slug,
      bodyFormat: (p.bodyFormat as "MD" | "HTML") ?? "MD",
      body: p.body,
      excerpt: p.excerpt ?? null,
      thumbnailUrl: p.thumbnailUrl ?? null,
      status: (p.status as "DRAFT" | "PUBLISHED") ?? "DRAFT",
      categoryId: category?.id ?? null,
      viewCount: p.viewCount ?? 0,
      publishedAt: p.publishedAt ? new Date(p.publishedAt) : null,
      updatedAt: p.updatedAt ? new Date(p.updatedAt) : new Date(),
    };
    const saved = await db.post.upsert({
      where: { slug: p.slug },
      update: data,
      create: { ...data, id: p.id } as never,
    });
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