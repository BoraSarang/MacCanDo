-- AlterTable
ALTER TABLE "Post" ADD COLUMN "featuredOrder" INTEGER;

-- AlterTable
ALTER TABLE "Series" ADD COLUMN "featuredOrder" INTEGER;

-- CreateIndex
CREATE INDEX "Post_featuredOrder_idx" ON "Post"("featuredOrder");
