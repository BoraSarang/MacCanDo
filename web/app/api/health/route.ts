// [FEATURE] 헬스체크 — T-01 API 로깅 검증용
import { withApi, apiOk } from "@/lib/api";
import { db } from "@/lib/db";

export const GET = withApi(async () => {
  const categoryCount = await db.category.count();
  return apiOk({
    status: "ok",
    db: "connected",
    categoryCount,
    timestamp: new Date().toISOString(),
  });
}, "Health");