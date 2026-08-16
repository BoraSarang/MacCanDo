# AGENTS.web.md — 웹 플랫폼 특화 규칙 (MacCanDo)

> 공통 규칙은 AGENTS.md(공통 가이드 v2.1)를 따르고, 본 파일은 web 전용 규칙만 명시한다.

## 1. 스택 (고정)

- Next.js (App Router) + TypeScript — Vercel 무료 배포
- Neon (외부 Postgres) + Prisma ORM
- NextAuth (Google OAuth)
- 검색: Postgres pg_trgm (외부 검색 서비스 금지)
- 파일: 개발 로컬 → 배포 Cloudflare R2
- AI: Gemini API Free Tier (SEO 메타/태그/요약)
- CSS: Tailwind CSS + 디자인 토큰 (ui-ux-pro-max 확정 값)

## 2. 디렉토리 구조

```
web/
├── app/
│   ├── (public)/          # 공개 블로그 (홈/카테고리/게시글/검색)
│   ├── admin/             # 관리자 전용 (통계/게시글 관리)
│   └── api/               # API Routes (REST)
├── components/
├── lib/                   # db/prisma, auth, logger, rate-limit
├── prisma/                # 스키마 + 마이그레이션
└── public/
```

## 3. 규칙

1. 모든 API 응답: `{ ok, data?, error?: { code: E-WEB-*, message } }` 형태
2. 에러는 반드시 error_message_ko.json 코드 매핑
3. API 로깅: `API→ {METHOD} {path}` / `API← {status} {ms}` (개발 모드 콘솔 + 서버 JSON 로그)
4. 댓글 입력: HTML 이스케이프 필수 (XSS 방지), honeypot 필드 필수
5. Rate Limit: 댓글/다운로드 API 100 req/min (IP 기반)
6. 관리자 API (/api/admin/*)는 세션 role=admin 검증 필수
7. 검색은 pg_trgm (LIKE/ilike 인덱스), 페이지네이션 기본 12개
8. 다운로드 게이트: 로그인 + 해당 게시글 댓글 1개 이상 → 링크 노출
9. SEO: 메타/OG/sitemap/구조화 데이터 자동 생성, AI 요약은 관리자 작성 시에만
10. 이미지 업로드: 개발은 /public/uploads (gitignore), 배포는 R2 (presigned URL)

## 4. 성능 예산

- LCP ≤ 2.5s, 메모리 ≤ 150MB, 60fps
- API P95 ≤ 300ms

## 5. 빌드/검증

```bash
./build_and_run.sh debug web
./build_and_run.sh e2e web      # Playwright
./scripts/a11y-dump.sh web      # 텍스트 검증
```