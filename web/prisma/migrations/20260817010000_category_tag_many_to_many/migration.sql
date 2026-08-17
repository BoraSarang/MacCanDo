-- CreateTable
CREATE TABLE "PostCategory" (
    "postId" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,

    CONSTRAINT "PostCategory_pkey" PRIMARY KEY ("postId","categoryId")
);

-- CreateTable
CREATE TABLE "Tag" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Tag_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PostTag" (
    "postId" TEXT NOT NULL,
    "tagId" TEXT NOT NULL,

    CONSTRAINT "PostTag_pkey" PRIMARY KEY ("postId","tagId")
);

-- AlterTable
ALTER TABLE "Post" ADD COLUMN "contentType" TEXT NOT NULL DEFAULT 'ARTICLE';

-- Migrate 단일 카테고리 -> PostCategory (기존 데이터 이전)
INSERT INTO "PostCategory" ("postId", "categoryId")
SELECT "id", "categoryId" FROM "Post" WHERE "categoryId" IS NOT NULL;

-- DropForeignKey
ALTER TABLE "Post" DROP CONSTRAINT IF EXISTS "Post_categoryId_fkey";

-- DropIndex
DROP INDEX IF EXISTS "Post_categoryId_status_idx";

-- AlterTable
ALTER TABLE "Post" DROP COLUMN "categoryId";

-- CreateIndex
CREATE INDEX "PostCategory_categoryId_idx" ON "PostCategory"("categoryId");

-- CreateIndex
CREATE INDEX "PostTag_tagId_idx" ON "PostTag"("tagId");

-- CreateIndex
CREATE INDEX "Post_contentType_status_idx" ON "Post"("contentType", "status");

-- AddForeignKey
ALTER TABLE "PostCategory" ADD CONSTRAINT "PostCategory_postId_fkey" FOREIGN KEY ("postId") REFERENCES "Post"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PostCategory" ADD CONSTRAINT "PostCategory_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "Category"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PostTag" ADD CONSTRAINT "PostTag_postId_fkey" FOREIGN KEY ("postId") REFERENCES "Post"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PostTag" ADD CONSTRAINT "PostTag_tagId_fkey" FOREIGN KEY ("tagId") REFERENCES "Tag"("id") ON DELETE CASCADE ON UPDATE CASCADE;