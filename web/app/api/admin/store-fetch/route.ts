// [FEATURE] App Store 메타데이터 자동 추출 — T-15 (앱 카드)
// POST /api/admin/store-fetch — { url } → Apple lookup API → 추출 가능한 메타 반환
// 보안: itunes.apple.com 고정 호스트만 호출 (SSRF 방지), 관리자 세션 필수
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { lookupAppStore, type StoreAppMeta } from "@/lib/store-fetch";

export const POST = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: "/api/admin/store-fetch" });
  }
  const body = (await req.json().catch(() => null)) as { url?: string } | null;
  const url = body?.url?.trim();
  if (!url) {
    return apiError("E-WEB-STORE-1002", 400, { method: "POST", path: "/api/admin/store-fetch" });
  }
  const meta: StoreAppMeta | null = await lookupAppStore(url);
  if (!meta) {
    return apiError("E-WEB-STORE-1001", 400, { method: "POST", path: "/api/admin/store-fetch" });
  }
  return apiOk(meta, { method: "POST", path: "/api/admin/store-fetch" });
}, "StoreFetch");