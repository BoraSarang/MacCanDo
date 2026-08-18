// [FEATURE] 일별 통계 기록 — T-59 (bd MacCanDo-c80)
// GET /api/admin/stats의 data.daily가 항상 []인 문제 수정:
// 조회/다운로드/댓글/신규 유저 이벤트에서 dailyStat 전역 레코드 upsert
// 실패해도 주 흐름을 방해하지 않음 (warn 로그만)
import { db } from "@/lib/db";
import { logger } from "@/lib/logger";

export type DailyStatField = "views" | "clicks" | "comments" | "newUsers";

// UTC 기준 오늘 0시 (DailyStat.date는 @db.Date — UTC 일 경계 일치)
function todayUtc(): Date {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

export async function bumpDailyStat(field: DailyStatField): Promise<void> {
  const date = todayUtc();
  try {
    // 전역(사이트 전체) 일별 레코드 — postId=null (@@unique([date,postId])는
    // null 허용이 아니므로 upsert 대신 findFirst + create/update 사용)
    const existing = await db.dailyStat.findFirst({ where: { date, postId: null } });
    if (existing) {
      await db.dailyStat.update({ where: { id: existing.id }, data: { [field]: { increment: 1 } } });
    } else {
      await db.dailyStat.create({ data: { date, [field]: 1 } });
    }
  } catch (e) {
    logger.warn("Stats", `일별 통계 기록 실패 (${field}): ${e instanceof Error ? e.message : e}`);
  }
}

// UTC 기준 같은 날 여부 (신규 유저 감지 — auth.ts)
export function isSameUtcDay(a: Date, b: Date): boolean {
  return (
    a.getUTCFullYear() === b.getUTCFullYear() &&
    a.getUTCMonth() === b.getUTCMonth() &&
    a.getUTCDate() === b.getUTCDate()
  );
}