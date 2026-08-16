// [FEATURE] 관리자 통계 API — T-05
// GET /api/admin/stats — 사이트 요약 + 일별 통계
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { getAdminSummary } from "@/lib/downloads";

export const GET = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "GET", path: "/api/admin/stats" });
  }
  return apiOk(await getAdminSummary());
}, "AdminStats");