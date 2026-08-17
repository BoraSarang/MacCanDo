// [FEATURE] 관리자 추천 지정 API — 홈 추천 섹션 (T-11)
// PATCH /api/admin/posts/[id]/featured — body: { order: number | null }
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { db } from "@/lib/db";

export const PATCH = withApi(async (req, ctx: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "PATCH", path: "/api/admin/posts/[id]/featured" });
  }
  const { id } = await ctx.params;
  const body = (await req.json()) as { order?: number | null };
  const order = body.order ?? null;
  await db.post.update({ where: { id }, data: { featuredOrder: order } });
  return apiOk({ id, featuredOrder: order }, { method: "PATCH", path: `/api/admin/posts/${id}/featured` });
}, "AdminPostFeatured");