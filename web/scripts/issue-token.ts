// 관리자 API 토큰 발급 (T-07 검증용) — 사용법: npx tsx --env-file=.env scripts/issue-token.ts
import { issueApiToken } from "@/lib/auth-token";
import { db } from "@/lib/db";

async function main() {
  const user = await db.user.findUnique({ where: { email: "leeborasarang@gmail.com" } });
  if (!user || user.role !== "ADMIN") { console.error("관리자 없음"); process.exit(1); }
  const token = await issueApiToken({ userId: user.id, role: user.role });
  console.log(token);
}
main();
