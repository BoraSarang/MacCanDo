// SEO: sitemap + robots (T-03)
import type { MetadataRoute } from "next";
import { getPosts, getCategories, getTags } from "@/lib/posts";

const BASE = "https://maccando.kr";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [cats, posts, tags] = await Promise.all([
    getCategories(),
    getPosts({ page: 1, pageSize: 50 }),
    getTags(),
  ]);
  const now = new Date();

  return [
    { url: `${BASE}/`, lastModified: now, changeFrequency: "daily", priority: 1 },
    { url: `${BASE}/apps`, lastModified: now, changeFrequency: "daily", priority: 0.9 },
    { url: `${BASE}/tips`, lastModified: now, changeFrequency: "daily", priority: 0.8 },
    { url: `${BASE}/news`, lastModified: now, changeFrequency: "daily", priority: 0.8 },
    ...cats.map((c) => ({
      url: `${BASE}/category/${c.slug}`,
      lastModified: now,
      changeFrequency: "weekly" as const,
      priority: 0.8,
    })),
    ...tags.map((t) => ({
      url: `${BASE}/tag/${t.slug}`,
      lastModified: now,
      changeFrequency: "weekly" as const,
      priority: 0.4,
    })),
    ...posts.items.map((p) => ({
      url: `${BASE}/post/${p.slug}`,
      lastModified: p.publishedAt ?? now,
      changeFrequency: "weekly" as const,
      priority: 0.6,
    })),
  ];
}