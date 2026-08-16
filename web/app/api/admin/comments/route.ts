// [FEATURE] 관리자 댓글 승인 API — T-05
// GET /api/admin/comments — 승인 대기 댓글 목록
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { getAdminComments } from "@/lib/downloads";

export const GET = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "GET", path: "/api/admin/comments" });
  }
  const status = new URL(req.url).searchParams.get("status") ?? "";
  return apiOk(await getAdminComments(status || undefined));
}, "AdminComments");