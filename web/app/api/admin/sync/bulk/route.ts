// [FEATURE] 관리자 동기화 API — T-08
// POST /api/admin/sync/bulk — 로컬 초안(오프라인 큐)을 서버로 upsert
// LWW: 서버 updatedAt이 로컬보다 최신이면 skip
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { syncBulk } from "@/lib/sync";

export const POST = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: "/api/admin/sync/bulk" });
  }
  const body = (await req.json().catch(() => null)) as {
    posts?: Array<{
      localPostId?: string | null;
      title: string;
      slug?: string | null;
      body: string;
      bodyFormat?: string;
      status?: string;
      updatedAt?: string;
    }>;
  };
  if (!body || !Array.isArray(body.posts) || body.posts.length > 100) {
    return apiError("E-WEB-VALID-1002", 400, { method: "POST", path: "/api/admin/sync/bulk" });
  }
  return apiOk(await syncBulk(body.posts));
}, "AdminSyncBulk");