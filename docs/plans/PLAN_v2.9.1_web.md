# PLAN v2.9.1 web — 글 상세 페이지 SSG 정적화 (T-60, bd MacCanDo-hx2)

작성: 2026-08-18 · 상태: 구현 전 · 규모: 중형 (설계 변경 — 사용자 승인: "정적화 (SSG)")

## 개요
- `/post/[slug]`가 ƒ(Dynamic) — auth() 쿠키 의존 게이트 + 조회수 증가(DB write)가 페이지 렌더링에 포함 → TTFB 2.7s (로컬 프로덕션 실측)
- 해결: 페이지 SSG화 (읽기만) — 게이트 판정/조회수 기록을 클라이언트로 이동. **최종 다운로드는 `/post/[slug]/download/[dlId]` 서버가 재검증** (checkDownloadGate + auth) → 보안 강도 동일

## 결정 사항
- page.tsx: `getPostBySlug(slug, false)` + auth()/getUserApprovedCommentCount/gateUnlocked 계산 제거
- 신규 클라이언트 컴포넌트:
  1. `PostViewCounter` — 마운트 1회 POST /api/posts/[slug]/view (ref 가드, StrictMode 안전), PAGE 스킵
  2. `GateCheck` — session fetch + GET /api/posts/[slug]/mine → 잠금/공개 UI (기존 다운로드 섹션 마크업 이동), `?gate=blocked` 배너 유지
- 신규 API:
  1. `POST /api/posts/[slug]/view` — `incrementPostView(slug)` 호출
  2. `GET /api/posts/[slug]/mine` — auth() 세션 + getUserApprovedCommentCount (게이트 판정용)
- lib/posts.ts: `incrementPostView(slug)` 추출 (PAGE 제외 + bumpDailyStat) — getPostBySlug 내부 증가 블록 대체 (DRY)
- 댓글(CommentsSection)은 이미 "use client" — SSG 후에도 실시간 fetch 유지, 영향 없음
- JS 미실행(봇) 시 다운로드 링크가 HTML에 노출되나, 실제 다운로드는 서버 게이트 차단 (보안 동일, UX는 클라이언트 숨김 동일)

## 구현 단계
- [ ] T-60 lib/posts.ts incrementPostView 추출 + view/mine API 2개
- [ ] T-60 PostViewCounter / GateCheck 클라이언트 컴포넌트
- [ ] T-60 page.tsx 정적화 수정
- [ ] T-60 빌드(○ 확인) + TTFB 재측정 + 게이트 동작 검증 (미로그인 잠금/다운로드 차단)
- [ ] T-60 문서(CHANGELOG/TODO/세션) + bd

## 테스트 계획
- TC-60-1: 빌드 출력 `/post/[slug]` ○(Static) 확인
- TC-60-2: TTFB < 300ms (프로덕션 로컬)
- TC-60-3: 미로그인 시 다운로드 섹션 "로그인 후 댓글" 문구 (기존 동작), 로그인+댓글 1개 시 링크 표시 — 브라우저 검증
- TC-60-4: /download/[dlId] 서버 게이트 차단 (미로그인 → /post/[slug]?gate=blocked 리다이렉트) — 기존 동작 회귀 없음
- TC-60-5: 조회수 증가 — 페이지 로드 → viewCount +1 + daily views +1

## 롤백
- git revert (서버 게이트 로직은 그대로 남아 있어 페이지 재변경만으로 복구)

## 에러코드
- 신규 없음 (withApi 표준)