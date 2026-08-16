// SEO: sitemap + robots (T-03)
import type { MetadataRoute } from "next";
import { getPosts, getCategories } from "@/lib/posts";

const BASE = "https://maccando.kr";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [cats, posts] = await Promise.all([getCategories(), getPosts({ page: 1, pageSize: 50 })]);
  const now = new Date();

  return [
    { url: `${BASE}/`, lastModified: now, changeFrequency: "daily", priority: 1 },
    ...cats.map((c) => ({
      url: `${BASE}/category/${c.slug}`,
      lastModified: now,
      changeFrequency: "weekly" as const,
      priority: 0.8,
    })),
    ...posts.items.map((p) => ({
      url: `${BASE}/post/${p.slug}`,
      lastModified: p.publishedAt ?? now,
      changeFrequency: "weekly" as const,
      priority: 0.6,
    })),
  ];
}