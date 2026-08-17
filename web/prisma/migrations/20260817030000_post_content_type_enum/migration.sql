-- CreateEnum
CREATE TYPE "PostContentType" AS ENUM ('ARTICLE', 'TIP', 'NEWS');

-- AlterTable
ALTER TABLE "Post" ALTER COLUMN "contentType" DROP DEFAULT;
ALTER TABLE "Post" ALTER COLUMN "contentType" TYPE "PostContentType" USING "contentType"::"PostContentType";
ALTER TABLE "Post" ALTER COLUMN "contentType" SET DEFAULT 'ARTICLE';