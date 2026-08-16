// [FEATURE] 동기화 로직 — T-08 (LWW)
// 로컬 초안 → 서버 upsert. 서버 updatedAt이 최신이면 skip.
// slug 없으면 title 기반 자동 생성 (uniqueSlug)
import { db } from "@/lib/db";
import { makeSlug } from "@/lib/posts";

type SyncPost = {
  localPostId?: string | null;
  title: string;
  slug?: string | null;
  body: string;
  bodyFormat?: string;
  status?: string;
  updatedAt?: string;
};

async function uniqueSlug(base: string, excludeId?: string): Promise<string> {
  let slug = base;
  let n = 2;
  for (;;) {
    const existing = await db.post.findUnique({ where: { slug } });
    if (!existing || (excludeId && existing.id === excludeId)) return slug;
    slug = `${base}-${n++}`;
  }
}

export async function syncBulk(posts: SyncPost[]) {
  const stats = { synced: 0, skipped: 0 };
  const results: Array<{ localPostId: string | null; slug: string; id: string; synced: boolean }> = [];

  for (const p of posts) {
    const title = p.title?.trim() ?? "";
    if (!title) {
      stats.skipped++;
      continue;
    }

    // slug 결정: 제공 slug → (기존 글의 slug) → title 자동 생성
    let slug = p.slug?.trim() || "";
    const existingBySlug = slug ? await db.post.findUnique({ where: { slug } }) : null;
    if (!existingBySlug) {
      slug = await uniqueSlug(makeSlug(title, p.slug ?? undefined));
    }

    const existing = existingBySlug ?? (await db.post.findUnique({ where: { slug } }));
    const localTime = p.updatedAt ? new Date(p.updatedAt).getTime() : 0;

    // LWW: 서버가 최신이면 skip
    if (existing && existing.updatedAt.getTime() > localTime) {
      stats.skipped++;
      results.push({ localPostId: p.localPostId ?? null, slug: existing.slug, id: existing.id, synced: false });
      continue;
    }

    const data = {
      title,
      bodyFormat: (p.bodyFormat as "MD" | "HTML") ?? "MD",
      body: p.body ?? "",
      status: (p.status as "DRAFT" | "PUBLISHED") ?? "DRAFT",
      publishedAt: (p.status as "DRAFT" | "PUBLISHED") === "PUBLISHED" && !existing?.publishedAt
        ? new Date()
        : existing?.publishedAt ?? null,
      updatedAt: localTime ? new Date(localTime) : new Date(),
    };

    const saved = await db.post.upsert({
      where: { slug },
      update: data,
      create: { ...data, slug },
    });
    stats.synced++;
    results.push({ localPostId: p.localPostId ?? null, slug: saved.slug, id: saved.id, synced: true });
  }

  return { ...stats, results };
}