// [FEATURE] 관리자 API 토큰 발급 라우트 — T-06
// POST /api/auth/token — 관리자 로그인 세션에서 토큰 발급 (macOS 앱용)
import { withApi, apiOk, apiError } from "@/lib/api";
import { auth } from "@/auth";
import { db } from "@/lib/db";
import { issueApiToken } from "@/lib/auth-token";

export const POST = withApi(async () => {
  const session = await auth();
  if (!session?.user?.id) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: "/api/auth/token" });
  }

  const user = await db.user.findUnique({ where: { id: session.user.id } });
  if (!user || user.role !== "ADMIN") {
    return apiError("E-WEB-AUTH-1001", 403, { method: "POST", path: "/api/auth/token" });
  }

  const token = await issueApiToken({ userId: user.id, role: user.role });
  return apiOk({ token, expiresInDays: 30, note: "macOS 앱 설정에 저장 후 Authorization: Bearer <token>으로 사용" });
}, "AuthToken");