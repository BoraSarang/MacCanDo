# MacCanDo 세션 로그 — 2026-08-16 (T-00 → T-01/T-02)

## 1. 무엇을 (완료 3건)

### T-00: 표준 인프라 — 완료
- 문서 세트 7종: docs/PRD.md, DESIGN.md, PLAN.md, TODO.md, CHANGELOG.md, AI_MODELS.json + error_message_ko.json (에러코드 18개: E-WEB/E-MAC)
- AGENTS.web.md, AGENTS.macos.md 생성
- build_and_run.sh 디스패처 (debug web|macos|all, e2e web, env-check)
- scripts/: screenshot.sh, a11y-dump.sh, env-expiry-check.sh (실행 권한 부여, env-check 통과)
- bd 초기화 완료: 이슈 10개 (T-00~T-09), T-00 close
- README.md, .gitignore 생성

### T-01: DebugPanel + DebugLogger + API 로깅 골격 — 완료
- web: lib/logger.ts (19.1장 규격: [INFO]/[ERROR]/[PERF]/[CACHE], API→/API←), lib/api.ts (withApi 래퍼 + 에러코드 매핑), lib/db.ts (Prisma 7 client extension 쿼리 로깅)
- web: app/api/health/route.ts 검증 — 로깅 5종 동작 확인
- macos: Debug/DebugLogger.swift, Debug/DebugPanel.swift (Cmd+Shift+D, 640x360), API/APIClient.swift 골격 (Xcode 통합은 T-06)
- next build + lint 통과

### T-02: Neon 스키마 + Prisma — 완료
- Neon 연결 성공 (pooler, channel_binding=require)
- Prisma 7 + @prisma/adapter-pg (driver adapter 필수 확인)
- 스키마 7모델: User/Category/Post/Comment/DownloadLink/DownloadEvent/DailyStat/Backup
- migrate dev (20260816031714_init) + 시드 (카테고리 4 + 관리자 admin@maccando.kr)
- .env + .env.example (expires 태그), web/lib/error_message_ko.json 동기화 (prebuild/predev/prestart)

## 2. 플랫폼
- common + web (macos는 골격 소스만)

## 3. 빌드/검증
- next build: 성공 (/, /_not-found, /api/health)
- npm run lint: 오류 0
- /api/health: { ok: true, categoryCount: 4 }
- 로그 확인: API→ / 진입 / PERF Category.count / API← / P95 경고
- 콜드 스타트 940ms (첫 요청) — Warm 시 정상화 예상, 후속 관찰 필요

## 4. 남은 TODO
- T-03 (MacCanDo-0b1): web 기반 — 목록/카테고리/상세/검색 (P1)
- T-04 (MacCanDo-9nn): Google 로그인 + 댓글 + 스팸 방지
- T-05 (MacCanDo-br7): 다운로드 게이트 + 통계
- T-06 (MacCanDo-102): macos Xcode 프로젝트 + DebugPanel 통합
- T-07/T-08/T-09 (등록 완료)

## 5. 다음 에이전트 전달
- Prisma 7 주의: url은 prisma.config.ts, driver adapter 필수, $on 제거 → $extends
- Turbopack: 프로젝트 루트 밖 import 차단 → error_message_ko.json은 prebuild로 web/lib/ 동기화
- Neon URL은 web/.env (gitignore), .env.example이 템플릿
- dev 서버: npm run dev (web/) — 현재 정지 상태

## 6. 문서 업데이트 목록
- 생성: PLAN_v0.1.0_common.md, .env/.env.example
- 수정: TODO.md (T-01/T-02 완료), CHANGELOG.md
- bd: T-00/T-01/T-02 close (3개), 7개 open

## 7. 오프라인 큐 상태
- macos 골격만 작성 (APIClient 오프라인 분기 스텁) — 실제 큐는 T-08

## 8. E2E/k6 결과
- 해당 없음 (web 기반 T-03 이후)
---

# 추후 추가 (T-03 완료 반영 — 2026-08-16 오후)

## T-03: web 기반 (목록/카테고리/상세/검색) — 완료
- 페이지: 홈(히어로+카테고리+최신 6), /category/[slug], /post/[slug](MD 렌더링+다운로드 게이트 섹션), /search
- API: /api/categories, /api/posts(검색·페이징·카테고리 필터), /api/posts/[slug](조회수 증가)
- 마이그레이션: pg_trgm 확장 + GIN 인덱스 (20260816032736_pg_trgm)
- SEO: sitemap.xml(7 URL), robots.txt, OG 메타, generateMetadata
- 검증: curl로 홈/상세/카테고리/검색/robots/sitemap 확인 + API 로깅 동작
- 샘플 게시글 2개: seed-dev-posts.ts (cleanmymac, homebrew — 유틸리티 카테고리)
- lint: react-hooks/purity 규칙 → performance.now() 렌더 측정 제거, lib 계층으로 이관 (db.ts $extends PERF 유지)
- bd: MacCanDo-0b1 close (T-03) — 4 close / 6 open
- 다음: T-04 (Google 로그인+댓글+스팸 방지) — AUTH_SECRET/GOOGLE_CLIENT_ID/SECRET 필요

# 추후 추가 (T-04 완료 반영 — 2026-08-16 오후)

## T-04: Google 로그인 + 댓글 + 스팸 방지 — 완료 (OAuth 자격 증명 대기)
- NextAuth v5 (5.0.0-beta.32) + Google provider + PrismaAdapter
- User 스키마: emailVerified, image 추가 (user_auth_fields 마이그레이션)
- Comment: ipAddress 추가 (comment_ip 마이그레이션)
- 댓글: POST(로그인 필수, honeypot, IP rate limit 10분5개, PENDING 승인 모드) + GET(승인 댓글 트리)
- 다운로드 게이트 1단계: 로그인+승인 댓글 1개 이상 → 링크 공개
- 검증: GET 200, 비로그인 POST 401(E-WEB-AUTH-1001), 게이트 잠김 표시, lint+build 통과
- 마이그레이션 복구 이력: 20260816032736 중복 삭제, comment_ip에서 DROP INDEX 오염 제거, trgm 인덱스 재생성
- 남은 것: 사용자 Google OAuth 자격 증명 (GOOGLE_CLIENT_ID/SECRET) → .env 채우면 로그인 테스트 가능
- bd: MacCanDo-9nn close — 5 close / 5 open
- 다음: T-05 (다운로드 게이트 클릭 추적 + /admin 통계) — T-04와 자연 연결

# 추후 추가 (T-04 사용자 검증 완료 — 2026-08-16 오후)

## T-04 최종 완료 (사용자 실테스트 통과)
- Google OAuth 로그인 성공 (계정: leeborasarang@gmail.com)
- 댓글 등록 → PENDING → 본인에게 "승인 대기 중" 배지 표시 확인
- 댓글 수정/삭제 (본인+PENDING) 구현, 사용자 확인 완료
- 추가 수정 사항:
  1. Auth.js v5: GOOGLE_CLIENT_ID env 자동 인식 안 함 → providers: [Google({ clientId, clientSecret })] 명시
  2. PrismaAdapter: $extends 전 base 클라이언트(prismaBase) 전달해야 함 (lib/db.ts export 추가)
  3. 스키마: Account/Session/VerificationToken 모델 필수 (auth_models 마이그레이션)
  4. Neon: migrate dev shadow DB 불안정(P1017/DROP INDEX 오류) → migration.sql 직접 작성 + migrate deploy 사용
- bd: T-04 close 유지. 5 close / 5 open
- 다음: T-05 (다운로드 게이트 클릭 추적 + /admin 통계) 또는 사용자 지시 대기

# T-05b/T-05c/T-06 (2026-08-16 오후)

## T-05b 디자인 시스템 (완료)
- 토큰 3계층: Primitive(블루#007AFF/퍼플#AF52DE/그레이/4px/라디우스/섀도우) → Semantic(다크 전환 포함) → Component(btn/card/badge/input/table)
- ThemeProvider + FOUC 방지 스크립트 + 헤더 토글 버튼, 전 컴포넌트 하드코딩 색상 제거
- 검증: 라이트(#007AFF)/다크(#0A84FF) computed style + 스크린샷 2장 + a11y 덤프
- 주의: Tailwind v4는 커스텀 클래스 @apply 불가 → .btn-primary 등에 클래스 풀어쓰기. react-hooks/set-state-in-effect → requestAnimationFrame으로 해결

## T-05c 앱 아이콘 (완료)
- assets/logo/MacCanDo_icon.svg (⌘+체크마크+그라디언트+유리질감) → 1024 PNG → .icns + web icon.png/apple-icon.png

## T-06 (완료 — 골격 + 인증)
- 웹: POST /api/auth/token (관리자만, jose JWT 30일) + lib/auth-token.ts + getAdminUser(req) Bearer 지원, 401 검증
- macos/: xcodegen (macOS 14+, kr.maccando.app) + DesignTokens + DebugLogger/DebugPanel(Cmd+Shift+D) + APIClient(Bearer) + AuthStore + NavigationSplitView 4섹션
- 빌드 성공 + 앱 실행 확인 (logs.txt: 앱 시작/글 관리 화면 표시)
- 다음: T-07 에디터 (게시글 CRUD API + MD/HTML 에디터 + 자동저장 + 배포 플래그)
- 사용자 테스트 필요: 웹 로그인 후 POST /api/auth/token → 토큰을 맥 앱 설정에 붙여넣기

## 14:30~14:45 macOS 앱 이름/아이콘 문제 해결 (T-06 후속)

**문제**: Finder/Dock에 앱 이름이 영문 표시, 아이콘 미표시

**원인 (3중):
1. `project.yml`의 `info:` 들여쓰기 오류 → xcodegen이 Info.plist 생성 못 함 (수동 파일 계속 사용, properties 반영 안 됨)
2. CFBundleDisplayName("MacCanDo Manager") ≠ 디스크 번들 이름("MacCanDo") → Finder 로컬라이즈 규칙(이름 일치 필요) 실패
3. LSHasLocalizedDisplayName 누락 (Apple DTS 공식: Finder/Dock 로컬라이즈 표시에 필수)

**수정:
- xcassets(AppIcon) → AppIcon.icns 직접 방식 (actool이 산출물 안 만드는 문제 우회)
- project.yml: info 들여쓰기 수정, CFBundleDisplayName="MacCanDo" (디스크 이름 일치), LSHasLocalizedDisplayName: true, CFBundleDevelopmentRegion: ko
- en.lproj 제거 (존재 시 ko.lproj보다 우선 선택되는 문제), ko.lproj만 유지 ("맥캔두 관리자")
- CFBundleShortVersionString/CFBundleVersion을 $(MARKETING_VERSION)/$(CURRENT_PROJECT_VERSION) placeholder로 → 빌드 번호 자동 증가 반영

**build_and_run.sh:
- `install macos` 모드 추가: Release 빌드 → ~/Applications/MacCanDo.app 배포 → LSHasLocalizedDisplayName 주입 → 실행
- 빌드 번호 자동 증가: macos/.build-version 카운터 (빌드마다 +1, CFBundleVersion 반영)
- debug macos도 동일 카운터 사용
- .gitignore에 .build-version 추가

**검증**: Finder 표시 이름 "맥캔두 관리자" 확인, CFBundleVersion=8 (자동 증가 동작), 버전 1.0.0

**다음**: T-07 (글 관리 CRUD API + MD/HTML 에디터 + 미리보기 + 자동저장 + 로컬 SQLite 초안 + 배포 플래그)

## 14:45~14:55 T-07 글 관리 에디터 완료

**web (T-07a/b)**:
- lib/posts.ts: 기존 lib/posts.ts 실수로 덮어쓰기 → 사용처(git 없음, 전부 untracked)에서 시그니처 복원 + 관리 CRUD 병합 (getPosts/getRecentPosts/getCategories/getPostBySlug + createPost/updatePost/deletePost/makeSlug/uniqueSlug)
- 주의: git 커밋이 bd init 하나뿐 — 작업 파일 전부 untracked 상태. 파일 덮어쓰기 위험 큼. 커밋 필요성 사용자에게 안내 예정
- POST /api/admin/posts, [id]/route.ts (GET/PUT/DELETE), GET ?all=1 관리자 목록
- Prisma InputJsonValue 타입 (storeInfo/seoMeta), totalPages 필드 (Pagination 사용)

**macos (T-07c~e)**:
- PostModels.swift, DraftStore.swift (SQLite3 C API — SQLITE_TRANSIENT 직접 정의), MarkdownRenderer.swift, EditorView.swift (NSTextView 래퍼 + WKWebView 미리보기 + 3초 디바운스 자동저장 + 초안/발행 버튼), PostsView 개편 (목록/새 글/삭제)
- 트러블: @State var body → View.body 충돌 (content로), 정규식 치환 과오 수정, let _: Post 타입 추론 실패 → let saved: Post
- APIClient: appendingPathComponent가 쿼리 인코딩 → URL(string:relativeTo:)로 수정

**검증**:
- 웹 빌드 + macOS 빌드 성공
- 토큰 발급: npx tsx --env-file=.env scripts/issue-token.ts (첫 시도 시 issueApiToken(userId, role) 잘못 호출 → sub 누락 → 401. 객체 형태 issueApiToken({userId, role}) 수정)
- curl CRUD: DRAFT 생성 → 공개 미노출 → 발행 → 노출 → 삭제 전부 통과
- 앱 실행: GET api/admin/posts?all=1 200 (게시글 2개 로드) — 앱↔API 연동 확인

**남음**: 사용자 UI 확인 (에디터/미리보기/자동저장), git 커밋 권고, T-08 (승인/통계/업로드/백업/AI SEO)

## 15:00~15:25 T-10 에디터 MD 전용 2칸 + 확장 MD 문법

**결정 (사용자)**: MD/HTML 모드 전환 제거 → MD 전용, 2칸 (좌 MD / 우 실시간 미리보기), 유튜브/이미지/동영상 삽입 + 사이즈/자동재생/시작시간 + MD 사용법

**구현**:
- MarkdownRenderer.swift: youtube/video/img 확장 문법 + HTML 인라인 화이트리스트(span style/font color) — 플레이스홀더 보호 후 escape
- HTMLToMarkdown.swift: 기존 HTML 글 → MD 변환 (figure/iframe/video/img/a/강조/제목/목록/인용/코드블록)
- EditorView.swift: 2칸 HSplitView, 툴바(B/I/S/H/링크/이미지/유튜브/동영상/사용법), 커서 위치 삽입(activeTextView), 유튜브 URL→ID 추출, 미리보기 300ms 디바운스, MD 사용법 시트, HTML 글 자동 변환, 저장 MD 고정
- web/lib/markdown.ts: 동일 규격 렌더러 (ReactMarkdown 대체), /post/[slug] 교체
- 검증: 웹 빌드 ✅ / macOS 빌드 ✅ / 웹 렌더러 출력 검증 ✅ (유튜브 iframe 파라미터/이미지/비디오/span/font)

**확장 문법**:
[youtube:ID] [youtube:ID width=800 height=450 autoplay=1 start=90]
[img:URL width=600 caption=캡션] / ![alt](url) / [video:URL width=640 autoplay=0]
<span style="color:red"> / <font color="red" size="4">

**이슈**: span/font가 escape에 막힘 → 플레이스홀더 방식 수정 (macOS+웹 동일)
**남음**: 사용자 UI 확인 (2칸/삽입/사용법 시트), 기존 HTML 글 변환 확인, T-10 close + 문서(CHANGELOG)
