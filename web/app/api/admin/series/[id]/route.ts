// [FEATURE] 시리즈 개별 관리 API
// PATCH /api/admin/series/[id]          — 이름/설명 변경
// DELETE /api/admin/series/[id]         — 삭제 (글은 유지, seriesId만 해제)
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { updateSeries, deleteSeries } from "@/lib/series";

export const PATCH = withApi(async (req, { params }: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "PATCH", path: "/api/admin/series/[id]" });
  }
  const { id } = await params;
  const body = (await req.json()) as { title?: string; description?: string; imageUrl?: string; intro?: string };
  if (body.title !== undefined && !body.title.trim()) {
    return apiError("E-WEB-VALID-1002", 400, { method: "PATCH", path: "/api/admin/series/[id]" });
  }
  return apiOk(
    await updateSeries(id, body.title, body.description ?? null, body.imageUrl ?? null, body.intro ?? null),
    { method: "PATCH", path: `/api/admin/series/${id}` }
  );
}, "AdminSeriesUpdate");

export const DELETE = withApi(async (req, { params }: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "DELETE", path: "/api/admin/series/[id]" });
  }
  const { id } = await params;
  await deleteSeries(id);
  return apiOk({ id }, { method: "DELETE", path: `/api/admin/series/${id}` });
}, "AdminSeriesDelete");
