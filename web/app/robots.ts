// SEO: robots.txt (T-03)
import type { MetadataRoute } from "next";

const BASE = "https://maccando.kr";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/" },
    sitemap: `${BASE}/sitemap.xml`,
  };
}