# MacCanDo (맥캔두)

"맥으로 이것도 할 수 있다" — Mac 유틸리티 정보 블로그 시스템

## 구성

| 폴더 | 내용 | 플랫폼 |
|------|------|--------|
| `web/` | 공개 블로그 + API (Next.js 풀스택) | web |
| `macapp/` | 관리자 전용 맥 앱 (SwiftUI) | macos |
| `docs/` | 문서 (PRD/DESIGN/PLAN/TODO/CHANGELOG) | 공통 |
| `scripts/` | 빌드/검증 보조 스크립트 | 공통 |

## 핵심 기능

- Mac 유용한 프로그램 소개 / 팁 / 소식 — 카테고리별
- 게시글 검색 (Postgres pg_trgm) + 댓글 (스팸 방지)
- Google 로그인 + 댓글 작성자에게 다운로드 링크 제공
- 관리자 전용 맥 앱: MD/HTML 에디터, 오프라인 자동저장, 배포 동기화, 백업/복구, AI SEO
- 통계 (관리자 전용)

## 스택

- web: Next.js + TypeScript + Neon(Postgres) + Prisma + NextAuth + Tailwind
- macos: SwiftUI + AppKit + SQLite(GRDB) + WebKit
- AI: Gemini API Free Tier
- 호스팅: Vercel (무료) / 파일: Cloudflare R2 (무료)

## 개발

```bash
./build_and_run.sh debug web      # 웹 개발 서버
./build_and_run.sh debug macos    # 맥 앱 빌드
./build_and_run.sh e2e web        # E2E 테스트
./scripts/env-expiry-check.sh     # 시크릿 만료 체크
```

문서 우선 원칙: 코드 수정 전 docs/PLAN.md + docs/TODO.md 확인 필수.