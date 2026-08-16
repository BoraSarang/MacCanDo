// PrismaClient 싱글턴 (개발 모드 핫리로드 대응)
// API 로깅: 모든 DB 조회는 여기 경유 (logger 규격)
// Prisma 7: 쿼리 로깅은 client extension 사용
// 주의: PrismaAdapter 등은 $extends 이전 base 클라이언트 필요 (findUnique undefined 방지)
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@/app/generated/prisma/client";
import { logger } from "./logger";

const globalForPrisma = globalThis as unknown as {
  prismaBase?: PrismaClient;
  prisma?: ReturnType<typeof createClient>;
};

function createBase() {
  const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
  return new PrismaClient({ adapter });
}

function createClient() {
  const base = globalForPrisma.prismaBase ?? createBase();
  globalForPrisma.prismaBase = base;

  return base.$extends({
    query: {
      $allModels: {
        async $allOperations({ model, operation, args, query }) {
          const start = performance.now();
          const result = await query(args);
          const ms = Math.round(performance.now() - start);
          if (process.env.NODE_ENV === "development") {
            logger.perf("DB", `${model}.${operation} (${ms}ms)`);
            if (ms > 300) logger.warn("DB", `${model}.${operation} 지연 (${ms}ms)`);
          }
          return result;
        },
      },
    },
  });
}

// $extends 전 base 클라이언트 (Auth.js PrismaAdapter 전용)
export const prismaBase = globalForPrisma.prismaBase ?? createBase();

// 로깅 확장 클라이언트 (일반 조회용)
export const db = globalForPrisma.prisma ?? createClient();

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prismaBase = prismaBase;
  globalForPrisma.prisma = db;
}

// 전역 에러 후킹
process.on("unhandledRejection", (reason) => {
  logger.error("DB", `E-WEB-DB-1001 미처리 오류: ${reason instanceof Error ? reason.message : reason}`);
});

export default db;