# PLAN v2.9 web — 일별 통계 기록 누락 수정 (bd MacCanDo-c80)

작성: 2026-08-18 · 상태: 구현 전 · 규모: 소규모 버그 픽스 (PLAN 3분 초안)

## 개요
- `GET /api/admin/stats` 응답 `data.daily`가 항상 `[]` — DailyStat 테이블에 데이터를 기록하는 코드가 전무
- 원인: 조회수/다운로드/댓글/신규 유저 이벤트에서 `dailyStat.upsert` 호출 누락 (테이블·unique 인덱스는 init 마이그레이션에 이미 존재)

## 결정 사항
- 스키마 변경 없음 (`@@unique([date, postId])` 이미 존재 — upsert 가능)
- `web/lib/stats.ts` 신규 헬퍼 `bumpDailyStat(field)` — 전역 날짜(postId=null) 레코드 upsert, 실패 시 조용히 무시(주 흐름 방해 금지, logger.warn)
- 훅 4곳:
  1. 조회: `lib/posts.ts:303` viewCount 증가 옆 → `views`
  2. 다운로드: `lib/downloads.ts` clickCount 증가 옆 → `clicks`
  3. 댓글: `lib/comments.ts` comment.create 뒤 → `comments` (PENDING 포함 — 활동 추세)
  4. 신규 유저: `auth.ts` signIn 콜백 — email로 findUnique, `createdAt`이 오늘(UTC)이면 `newUsers` (PrismaAdapter가 먼저 user 생성)
- 백필 없음: 과거 조회수를 임의 분산하지 않음 (추측 금지). daily는 이벤트 시점부터 누적, totalViews는 기존 집계 유지

## 구현 단계
- [ ] T-59 lib/stats.ts 헬퍼 생성
- [ ] T-59 posts.ts / downloads.ts / comments.ts / auth.ts 훅 4곳 추가
- [ ] T-59 빌드 + dev 검증: 조회 1회 → /api/admin/stats daily에 오늘 views=1
- [ ] T-59 문서(CHANGELOG v2.9, TODO, 세션) + bd close

## 테스트 계획
- TC-59-1: dev 서버에서 게시글 조회 API 호출 → daily[0].views >= 1
- TC-59-2: dailyStat upsert 실패 시 조회 API가 500 나지 않는지 (try-catch) — 코드 리뷰로 확인

## 롤백
- 커밋 revert (코드 추가만 — DB 영향 없음)

## 에러코드
- 신규 에러코드 없음 (실패 시 기존 E-WEB-DB-1001 로깅)