// [FEATURE] 관리자 백업/복원 API — T-08
// GET /api/admin/backup — 게시글+카테고리+댓글 전체 JSON 덤프
// POST /api/admin/backup — JSON 덤프 복원 (id 기준 upsert, LWW: 서버 updatedAt이 최신이면 건너뜀)
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { backupAll, restoreBackup } from "@/lib/backup";
import type { BackupPayload } from "@/lib/backup";

export const GET = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "GET", path: "/api/admin/backup" });
  }
  return apiOk(await backupAll());
}, "AdminBackup");

export const POST = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: "/api/admin/backup" });
  }
  const body = (await req.json().catch(() => null)) as Partial<BackupPayload> | null;
  if (!body || !Array.isArray(body.posts) || !Array.isArray(body.categories) || !Array.isArray(body.comments)) {
    return apiError("E-WEB-VALID-1001", 400, { method: "POST", path: "/api/admin/backup" });
  }
  return apiOk(await restoreBackup(body as BackupPayload));
}, "AdminRestore");