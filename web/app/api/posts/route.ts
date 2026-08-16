// [FEATURE] 게시글 목록/검색 API — T-03
// GET /api/posts?category=유틸리티&q=검색어&page=1&pageSize=12
import { withApi, apiOk } from "@/lib/api";
import { getPosts } from "@/lib/posts";

export const GET = withApi(async (req) => {
  const url = new URL(req.url);
  const params = {
    categorySlug: url.searchParams.get("category") ?? undefined,
    query: url.searchParams.get("q") ?? undefined,
    page: url.searchParams.get("page") ? Number(url.searchParams.get("page")) : 1,
    pageSize: url.searchParams.get("pageSize")
      ? Number(url.searchParams.get("pageSize"))
      : undefined,
  };
  const data = await getPosts(params);
  return apiOk(data);
}, "Posts");