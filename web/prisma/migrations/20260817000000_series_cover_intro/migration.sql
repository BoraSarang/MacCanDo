-- AlterTable (수동 적용: Neon drift 대응)
ALTER TABLE "Series" ADD COLUMN IF NOT EXISTS "imageUrl" TEXT;
ALTER TABLE "Series" ADD COLUMN IF NOT EXISTS "intro" TEXT;
