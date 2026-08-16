// [FEATURE] 시리즈 글 관리 API
// POST   /api/admin/series/[id]/posts  — 글 추가 { postIds: [] } (순서 자동: 마지막+1)
// PATCH  /api/admin/series/[id]/posts  — 순서 저장 { postIds: [] } (배열 순서 = 1편, 2편...)
// DELETE /api/admin/series/[id]/posts?postId= — 글 제거 (글 자체는 유지)
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { addPostsToSeries, setSeriesOrder, removePostFromSeries } from "@/lib/series";

const PATH = "/api/admin/series/[id]/posts";

export const POST = withApi(async (req, { params }: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: PATH });
  }
  const { id } = await params;
  const body = (await req.json()) as { postIds?: string[] };
  if (!body.postIds?.length) {
    return apiError("E-WEB-VALID-1002", 400, { method: "POST", path: PATH });
  }
  return apiOk(await addPostsToSeries(id, body.postIds), { method: "POST", path: PATH });
}, "AdminSeriesAddPosts");

export const PATCH = withApi(async (req, { params }: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "PATCH", path: PATH });
  }
  const { id } = await params;
  const body = (await req.json()) as { postIds?: string[] };
  if (!body.postIds?.length) {
    return apiError("E-WEB-VALID-1002", 400, { method: "PATCH", path: PATH });
  }
  return apiOk(await setSeriesOrder(id, body.postIds), { method: "PATCH", path: PATH });
}, "AdminSeriesSetOrder");

export const DELETE = withApi(async (req, { params }: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "DELETE", path: PATH });
  }
  const url = new URL(req.url);
  const postId = url.searchParams.get("postId");
  if (!postId) {
    return apiError("E-WEB-VALID-1002", 400, { method: "DELETE", path: PATH });
  }
  return apiOk(await removePostFromSeries(postId), { method: "DELETE", path: PATH });
}, "AdminSeriesRemovePost");
