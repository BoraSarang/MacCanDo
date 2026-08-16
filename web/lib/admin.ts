// [FEATURE] 관리자 판정 — T-05/T-06
// 세션 쿠키 OR Bearer API 토큰 둘 다 허용 — role === ADMIN만 통과
import { auth } from "@/auth";
import { db } from "./db";
import { logger } from "./logger";
import { verifyApiToken, extractBearerToken } from "./auth-token";

export async function getAdminUser(req?: Request) {
  // 1) Bearer API 토큰 (macOS 앱)
  if (req) {
    const bearer = extractBearerToken(req);
    if (bearer) {
      const payload = await verifyApiToken(bearer);
      if (payload && payload.role === "ADMIN") {
        const user = await db.user.findUnique({ where: { id: payload.sub } });
        if (user && user.role === "ADMIN") return user;
      }
      logger.warn("Admin", "Bearer 토큰 검증 실패 — 접근 차단");
      return null;
    }
  }

  // 2) 세션 쿠키 (웹 브라우저)
  const session = await auth();
  if (!session?.user?.id) return null;
  const user = await db.user.findUnique({ where: { id: session.user.id } });
  if (!user || user.role !== "ADMIN") {
    logger.warn("Admin", `비관리자 접근 차단 (user=${session.user.id})`);
    return null;
  }
  return user;
}