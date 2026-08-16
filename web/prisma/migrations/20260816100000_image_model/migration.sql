-- 이미지 목록 DB화 (T-08): 업로드 메타데이터 + 캡션 + 사용처
CREATE TABLE "Image" (
    "id" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "mimeType" TEXT NOT NULL,
    "caption" TEXT,
    "postId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Image_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "Image_url_key" ON "Image"("url");
CREATE INDEX "Image_createdAt_idx" ON "Image"("createdAt");

ALTER TABLE "Image" ADD CONSTRAINT "Image_postId_fkey" FOREIGN KEY ("postId") REFERENCES "Post"("id") ON DELETE SET NULL ON UPDATE CASCADE;
