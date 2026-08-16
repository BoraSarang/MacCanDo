-- pg_trgm 확장 (전문검색/유사도 검색용 — docs/DESIGN.md 2.1)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 게시글 검색 인덱스: 제목/요약 대상 (pg_trgm GIN)
CREATE INDEX IF NOT EXISTS "Post_title_trgm_idx" ON "Post" USING GIN (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "Post_excerpt_trgm_idx" ON "Post" USING GIN (COALESCE(excerpt, '') gin_trgm_ops);