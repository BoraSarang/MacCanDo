// MacCanDo 시드 데이터 — 초기 카테고리 구조
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@/app/generated/prisma/client";
import { logger } from "@/lib/logger";

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const db = new PrismaClient({ adapter });

async function main() {
  logger.info("SEED", "시드 시작");

  const cats = [
    { slug: "utilities", name: "유틸리티", sort: 1 },
    { slug: "productivity", name: "생산성", sort: 2 },
    { slug: "tips", name: "맥 팁", sort: 3 },
    { slug: "news", name: "맥 소식", sort: 4 },
  ];

  for (const c of cats) {
    const exists = await db.category.findUnique({ where: { slug: c.slug } });
    if (!exists) {
      await db.category.create({ data: c });
      logger.info("SEED", `카테고리 생성: ${c.name}`);
    }
  }

  const user = await db.user.upsert({
    where: { email: "admin@maccando.kr" },
    update: { role: "ADMIN" },
    create: { email: "admin@maccando.kr", name: "관리자", role: "ADMIN" },
  });
  logger.info("SEED", `관리자 사용자: ${user.email}`);

  logger.info("SEED", "시드 완료");
}

main()
  .catch((e) => {
    logger.error("SEED", `실패: ${e.message}`);
    process.exit(1);
  })
  .finally(() => db.$disconnect());