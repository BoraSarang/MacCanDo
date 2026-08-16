// [FEATURE] 관리자 댓글 상태 변경 API — T-05
// PATCH /api/admin/comments/[id] — 상태 변경 (APPROVED/SPAM/PENDING)
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { setCommentStatus } from "@/lib/downloads";

export const PATCH = withApi(async (req, ctx: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "PATCH", path: "/api/admin/comments" });
  }
  const { id } = await ctx.params;
  const body = (await req.json().catch(() => null)) as { status?: string };
  const status = body?.status;
  if (status !== "APPROVED" && status !== "SPAM" && status !== "PENDING") {
    return apiError("E-WEB-VALID-1001", 400, { method: "PATCH", path: `/api/admin/comments/${id}` });
  }
  return apiOk(await setCommentStatus({ commentId: id, status }));
}, "AdminCommentUpdate");