-- PostApp 테이블 (T-15: 앱 카드)
CREATE TABLE "PostApp" (
    "id" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "sort" INTEGER NOT NULL DEFAULT 0,
    "appId" TEXT,
    "appUrl" TEXT,
    "homepageUrl" TEXT,
    "storeInfo" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "PostApp_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "PostApp_postId_idx" ON "PostApp"("postId");
ALTER TABLE "PostApp" ADD CONSTRAINT "PostApp_postId_fkey" FOREIGN KEY ("postId") REFERENCES "Post"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- DownloadLink.postAppId (T-15)
ALTER TABLE "DownloadLink" ADD COLUMN "postAppId" TEXT;
CREATE INDEX "DownloadLink_postAppId_idx" ON "DownloadLink"("postAppId");
ALTER TABLE "DownloadLink" ADD CONSTRAINT "DownloadLink_postAppId_fkey" FOREIGN KEY ("postAppId") REFERENCES "PostApp"("id") ON DELETE CASCADE ON UPDATE CASCADE;
