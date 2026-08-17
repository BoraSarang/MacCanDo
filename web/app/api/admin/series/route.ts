// [FEATURE] 시리즈 관리 API — 사용자 요청 (시리즈 묶기 + 순서)
// GET  /api/admin/series          — 시리즈 목록 (+글, DRAFT 포함) + 시리즈 없는 글
// POST /api/admin/series          — 시리즈 생성 { title, description }
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import {
  getAdminSeriesList,
  getPostsWithoutSeries,
  createSeries,
} from "@/lib/series";

export const GET = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "GET", path: "/api/admin/series" });
  }
  const q = new URL(req.url).searchParams.get("q") ?? undefined;
  const [series, loosePosts] = await Promise.all([getAdminSeriesList(), getPostsWithoutSeries(q)]);
  return apiOk({ series, loosePosts }, { method: "GET", path: "/api/admin/series" });
}, "AdminSeriesList");

export const POST = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: "/api/admin/series" });
  }
  const body = (await req.json()) as { title?: string; description?: string; imageUrl?: string; intro?: string };
  if (!body.title?.trim()) {
    return apiError("E-WEB-VALID-1002", 400, { method: "POST", path: "/api/admin/series" });
  }
  const series = await createSeries(body.title, body.description ?? null, body.imageUrl ?? null, body.intro ?? null);
  return apiOk(series, { method: "POST", path: "/api/admin/series" });
}, "AdminSeriesCreate");
