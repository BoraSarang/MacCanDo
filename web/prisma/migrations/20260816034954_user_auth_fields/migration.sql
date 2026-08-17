/*
  Warnings:

  - You are about to drop the column `avatar` on the `User` table. All the data in the column will be lost.

*/
-- DropIndex
DROP INDEX IF EXISTS "Post_title_trgm_idx";

-- AlterTable
ALTER TABLE "User" DROP COLUMN "avatar",
ADD COLUMN     "emailVerified" TIMESTAMP(3),
ADD COLUMN     "image" TEXT;
