# MacCanDo — 구현 계획 (PLAN)

> 버전: v0.1.0-draft (2026-08-16) · 플랫폼: web + macos

---

## 1. 로드맵

| 단계 | 작업 | 플랫폼 | 상태 |
|------|------|--------|------|
| T-00 | 표준 인프라 (문서/스크립트/bd/에러코드) | 공통 | 진행중 |
| T-01 | DebugPanel + DebugLogger + API 로깅 골격 | 공통 | 대기 |
| T-02 | Neon 스키마 + Prisma 마이그레이션 | web | 대기 |
| T-03 | web 기반 (목록/카테고리/상세/검색) | web | 대기 |
| T-04 | Google 로그인 + 댓글 + 스팸 방지 | web | 대기 |
| T-05 | 다운로드 게이트 + 통계(/admin) | web | 대기 |
| T-06 | macos 앱 골격 + DebugPanel | macos | 대기 |
| T-07 | macos 에디터 (MD/HTML + 자동저장 + 미리보기) | macos | 대기 |
| T-08 | macos 동기화/배포/백업/복구/AI SEO | macos | 대기 |
| T-09 | 디자인 적용 + E2E + 배포 | 공통 | 대기 |

## 2. 세부 작업 (T-번호)

### T-00 표준 인프라
- [x] docs/ 디렉토리 + PRD/DESIGN/PLAN/TODO/CHANGELOG 생성
- [ ] docs/AI_MODELS.json + error_message_ko.json 생성
- [ ] AGENTS.web.md + AGENTS.macos.md 생성
- [ ] build_and_run.sh 디스패처 (web/macos/all/e2e)
- [ ] scripts/: screenshot.sh, a11y-dump.sh, env-expiry-check.sh
- [ ] bd 설치 확인, .gitignore, README

### T-01 DebugPanel 골격
- [ ] [macos] DebugLogger (Swift, 로그 저장/순환)
- [ ] [macos] DebugPanel NSWindow + Cmd+Shift+D
- [ ] [web] 브라우저 콘솔 로거 + /debug API (개발 모드)
- [ ] API 호출 로깅 규격 (API→ / API←) 적용

### T-02 Neon 스키마
- [ ] Neon 프로젝트 생성 + .env 설정
- [ ] Prisma 스키마 (users/categories/posts/comments/download_links/stats/backups)
- [ ] 마이그레이션 + 시드 데이터

### T-03 web 기반
- [ ] Next.js App Router 프로젝트 생성
- [ ] 레이아웃/홈/카테고리/게시글 목록·상세
- [ ] 검색 (pg_trgm) + 페이지네이션
- [ ] SEO 메타/OG/sitemap

### T-04 로그인/댓글
- [ ] NextAuth Google OAuth 설정
- [ ] 댓글 작성/목록/대댓글 + 스팸 방지 (honeypot + rate limit + 승인 모드)

### T-05 게이트/통계
- [ ] 다운로드 링크 + 권한 게이트
- [ ] 조회수/클릭 집계 + /admin 통계 대시보드

### T-06 macos 골격
- [ ] Xcode 프로젝트 (SwiftUI) + 폴더 구조
- [ ] DebugLogger/DebugPanel 연동
- [ ] API 클라이언트 + 오프라인 큐 (SQLite)

### T-07 macos 에디터
- [ ] MD/HTML 편집기 + 미리보기 (WebKit)
- [ ] 자동 저장 (SQLite) + 임시/배포 상태 관리
- [ ] 스토어 정보 자동 조회 (iTunes Lookup)

### T-08 macos 고급
- [ ] 배포 동기화 (/api/admin/sync/bulk)
- [ ] 백업/복구 (테스트 후 적용)
- [ ] AI SEO (Gemini Free)

### T-09 디자인/배포
- [ ] 로고/아이콘 (design 스킬) + 웹 테마 적용 (ui-ux-pro-max)
- [ ] Playwright E2E + 성능 검증 (PERF/CACHE)
- [ ] Vercel 배포 + 도메인 + R2 연동

## 3. 테스트 계획

| 번호 | 내용 | 플랫폼 |
|------|------|--------|
| TC-01 | 검색/카테고리 필터 동작 | web |
| TC-02 | 댓글 스팸 방지 (honeypot/rate limit) | web |
| TC-03 | 다운로드 게이트 (비로그인/댓글없음/댓글있음/관리자) | web |
| TC-04 | 맥 앱 오프라인 작성 → 온라인 동기화 | macos |
| TC-05 | 백업 → 테스트 복구 → 실제 복구 | macos |
| TC-06 | DebugPanel 로그 표시 + API 로그 | 공통 |
| TC-07 | E2E: 목록→상세→댓글→로그인→다운로드 | web |

## 4. 롤백 계획

- web: git revert + Vercel 이전 배포 재배포
- macos: git revert + SQLite 로컬 백업 복원
- DB: Prisma 마이그레이션 down + Neon 브랜치 복원
- 오프라인 큐 클리어: SQLite delete

## 5. 에러코드 체계 (8.5장)

형식: `E-{PLATFORM}-{CATEGORY}-{NUM4}` — PLATFORM: WEB/MAC, CATEGORY: AUTH/NET/DB/GLIST/BRIDGE/PERF/UI/VALID/STOR/MSG/PERM/CACHE/QUEUE/SYNC