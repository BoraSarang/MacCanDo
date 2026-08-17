-- PostContentType enum에 PAGE 추가 (T-17 정적 페이지)
ALTER TYPE "PostContentType" ADD VALUE IF NOT EXISTS 'PAGE';
