-- 시리즈 기능: Series 테이블 + Post.seriesId/seriesOrder
CREATE TABLE "Series" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Series_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "Post" ADD COLUMN "seriesId" TEXT;
ALTER TABLE "Post" ADD COLUMN "seriesOrder" INTEGER;

CREATE INDEX "Post_seriesId_seriesOrder_idx" ON "Post"("seriesId", "seriesOrder");

ALTER TABLE "Post" ADD CONSTRAINT "Post_seriesId_fkey" FOREIGN KEY ("seriesId") REFERENCES "Series"("id") ON DELETE SET NULL ON UPDATE CASCADE;
