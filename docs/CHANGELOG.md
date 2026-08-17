# MacCanDo — 변경 이력 (CHANGELOG)

> 형식: [platform] 태그 필수

---

## v2.5.0-T15 (2026-08-17) — [web+macos] 앱 카드 (한 글에 여러 앱)

- DB: PostApp 테이블 (postId/sort/appId/appUrl/homepageUrl/storeInfo Json 스냅샷) + DownloadLink.postAppId — 수동 마이그레이션 20260817_post_app (Neon db execute + migrate resolve)
- API: POST /api/admin/store-fetch — App Store URL/ID → Apple lookup (itunes.apple.com 고정, SSRF 방지, 타임아웃 8s) → 버전/개발자/가격/언어(ISO→한국어)/호환 macOS/업데이트일/별점/아이콘/크기 추출 (E-WEB-STORE-1001/1002 추가)
- 글 저장 API (POST/PUT /api/admin/posts): apps[] 전체 교체 (트랜잭션), 앱별 downloadLinks 포함, admin 단건 조회에 apps 포함
- 웹: lib/markdown.ts [app]~[/app] 블록 → 앱 카드 HTML (렌더러 내장 buildAppCardHTML, 앱 카드 = 아이콘+이름+스펙 행+공개 다운로드+홈페이지/App Store 링크), 글 상세 apps 전달, .app-card CSS (다크 대응)
- macOS: MarkdownRenderer.swift render(md, apps:) + AppCardData/AppStoreInfo 모델, EditorView 툴바 '앱 카드' 시트 (URL→서버 store-fetch→미리보기→홈페이지/다운로드 입력→[app] 삽입), 미리보기/저장/로드 apps 반영, PostInput.apps
- 실적용: iterm2-tmux-oh-my-zsh 글에 iTerm2/tmux/Oh My Zsh 앱 카드 3장 (비로그인 공개 다운로드), 기존 하단 📥 게이트는 유지 (회귀 검증)
- 검증: store-fetch 실호출 OK (Amphetamine), E2E 30/30 (TC-APP-001~004), TSC 통과, macOS 빌드 성공, 스크린샷 docs/screenshots/web/v2.5_appcard_*

## v1.1.0-T09-3 (2026-08-16) — [macos+web] 시리즈 화면 개선 (사용자 요청)

- 시리즈 글 목록 최대 5편 높이 (넘으면 스크롤) → 하단 '시리즈에 없는 글' 영역 확대
- 하단 글 목록 제목 검색 추가 (서버 검색 GET /api/admin/series?q=, 300ms 디바운스, 최근 글부터 정렬)
- 검색 결과 없음/로딩 표시, 선택 → 시리즈 추가 동작 유지
- 검증: q=clean → CleanMyMac X 매칭, 시리즈 2편+3편 정상

## v1.1.0-T09-2 (2026-08-16) — [macos+web] 시리즈 기능 (사용자 요청)

- 시리즈: 제목+설명으로 관리, 글은 일반 게시글 (카테고리/검색 동일 노출, 라벨 없음)
- DB: Series 테이블 + Post.seriesId/seriesOrder (수동 마이그레이션, 글 삭제 시 SetNull)
- macOS 시리즈 관리 화면 (사이드바 '시리즈'): 시리즈 생성/수정/삭제, 글 추가, 마우스 드래그 순서 정렬(=편 번호) → 즉시 서버 저장
- macOS 에디터: 시리즈 드롭다운 (없음/기존/새 시리즈 생성), 저장 시 seriesId 전송
- 웹 /series: 전체 시리즈 (제목+설명+글 리스트, 첫 편 썸네일 대체 표시)
- 웹 /series/[id]: 개별 시리즈 모아보기
- 게시글 하단 시리즈 목록: 1편/2편/3편 + 현재 '보고 있는 글' 강조, 클릭 이동, 초안(DRAFT) 숨김
- 일반 목록(홈/카테고리/검색) 정렬: 시리즈 글은 order 순 나란히, 그룹 위치는 최신 편 발행일 기준 (raw SQL)
- 웹 admin: 시리즈 탭 (생성/수정/삭제/글 추가/↑↓ 순서 변경)
- API: GET/POST /api/admin/series, PATCH/DELETE /[id], POST/PATCH/DELETE /[id]/posts
- 검증: 시리즈 생성→글 3개 추가→순서 [3,1,2] 저장→웹 반영, 2편에서 현재 표시, DRAFT 숨김, 홈 정렬, 검색 정상

## v1.1.0-T09-1 (2026-08-16) — [macos] AI 도우미 (글쓰기 도우미) — 사용자 요청

- 에디터 툴바에 'AI 도우미' 버튼 → 별도 창 (820x600)
- 프로그램 이름 또는 웹사이트 URL 입력 → Gemini가 제품 소개 MD 생성 (소개/한눈에 보기/비교/장점/특이사항/추천 이유)
- URL 입력 시 페이지 fetch(URLSession + Safari UA) → 내용 기반 작성, 실패 시 이름 기반 폴백
- 비교 대상 지정 가능, 비우면 AI가 유사 프로그램 3개 자동 선정
- 결과: 원문(MD) / 미리보기 토글 + 복사 버튼 (참고용 — 에디터에 붙여넣어 수정)
- 캐시: seo_cache 재사용 (guide: prefix, SHA256), 캐시 표시 + 재조회(forceRefresh)
- Gemini 503 재시도 공통화 (callTextWithRetry), E-MAC-AI-1004/E-MAC-VALID-1003 추가
- 검증: 이름 기반 생성 OK, URL fetch+스트립 OK, 빌드 성공

## v1.1.0-T08-5 (2026-08-16) — [macos] AI SEO SQLite LRU 캐시 (T-08 완료 조건)

- seo_cache 테이블 (SQLite, 최대 100건 LRU — 초과 시 오래된 것 삭제, hit 시 saved_at 갱신)
- 캐시 키: SHA256(제목+본문+슬러그+이미지 후보) — 본문 수정 시 자동 miss
- 첫 AI SEO 클릭: 캐시 hit면 Gemini 호출 생략 (즉시 반환) / 재생성·다시 생성 버튼: forceRefresh로 캐시 무시
- hit/miss 카운트 → 설정 화면에 캐시 히트율 표시 (목표 70%, [CACHE] 로그)
- DraftStore 초안에 seoMeta 저장 (v3 컬럼) — 서버 저장 전에도 저장된 SEO 값 유지

## v1.1.0-T08-4 (2026-08-16) — [web][macos] AI SEO 시트 개편 (저장값 표시 + og:image + 메타 미리보기)

- [macos] AI SEO 클릭: seoMeta 저장 시 AI 호출 없이 저장값 즉시 표시 (+ 적용시각) / "재생성" 버튼으로 재생성
- [macos] 시트에 메타 태그 전 요소 표시: 제목/설명/키워드/대표 이미지(og:image) + 실제 meta 태그 미리보기 (HTML 형태)
- [macos] 대표 이미지: 본문 첫 [img:] 자동 추출 → 후보/수동 편집/비우기, Gemini 프롬프트에 이미지 후보 전달
- [macos] SeoMeta.image 필드 + thumbnailUrl 반영, 적용 시 일괄 저장
- [web] generateMetadata og:image = seoMeta.image ?? thumbnailUrl
- 검증: og:image 포함 글 → 웹 og:image 태그 반영 확인, 테스트 글 삭제

## v1.1.0-T08-3 (2026-08-16) — [web][macos] AI SEO 결과 → 웹 meta 태그 자동 구성

- [web] post/[slug] generateMetadata: seoMeta(제목/설명/키워드) 우선 → title/description/keywords/og:title/og:description 자동 구성 (없으면 기본 폴백)
- [web] 대시보드 게시글 표에 SEO 열 추가 (✨ = seoMeta 적용됨, 호버로 제목/설명/키워드/적용시각, 📝 = 설명만 있음)
- [macos] SeoMeta 모델 + 에디터 저장/로드, AI SEO 적용 시 seoMeta 기록(적용시각 포함) 후 저장 시 전송
- [macos] 글 목록에 ✨ 뱃지 + 호버 툴팁 (SEO 값 확인)
- 수정: Gemini 모델 gemini-2.0-flash(폐기) → gemini-3.7-flash (E-MAC-AI-1001 해결)
- 검증: seoMeta 저장 글 → 웹 <title>/meta description/keywords/og 태그 반영 확인, 테스트 글 삭제

## v1.1.0-T08-2 (2026-08-16) — [web][macos] 이미지 목록 DB화 (파일↔DB sync)

- [web] Image 모델 신설 (url/name/size/mimeType/caption/postId/createdAt) + 마이그레이션 (Neon shadow DB 제한 → 수동 SQL + migrate deploy)
- [web] GET /api/admin/uploads: 파일 스캔 ↔ DB sync (새 파일 upsert, 고아 정리) → DB 목록 (캡션·사용처 포함)
- [web] POST: 업로드 + DB 기록 + 캡션, DELETE: 파일+DB 동시 삭제, PATCH: 캡션 수정
- [web] 사용처 추적: 글 생성/수정 시 본문 [img:/uploads/] 참조 → Image.postId 갱신, 글 삭제 시 SetNull
- [web] lib/image.ts (UPLOAD_ROOT/트래버설 방지), E-WEB-VALID-1002 메시지 일반화
- [macos] 이미지 시트: 캡션·사용처 표시, 연필로 캡션 수정, 삽입 시 DB 캡션 자동 적용
- 검증: sync 백필(2개) / 업로드+캡션 / PATCH / DELETE(파일+DB) / 사용처 생성→표시→삭제 해제

## v1.1.0-T08 (2026-08-16) — [macos][web] 승인/통계/AI SEO/백업/동기화

- [macos] 댓글 승인 화면 (대기/전체/승인/스팸 필터, 승인/스팸/복구 버튼) — GET/PATCH /api/admin/comments
- [macos] 통계 화면 (요약 카드 6종 + Swift Charts 일별 추이) — GET /api/admin/stats (totalViews)
- [macos] AI SEO: 에디터 sparkles 버튼 → Gemini 2.0 Flash로 제목/슬러그/설명/키워드 생성 후 적용
- [macos] 설정: Gemini API 키 입력 (UserDefaults), 백업 다운로드/복원 (JSON, NSSavePanel/NSOpenPanel), 로컬 초안→서버 동기화
- [macos] 초안 DB v2: slug 컬럼 추가 (ALTER TABLE 마이그레이션) — 동기화 slug 매핑
- [web] GET /api/admin/backup + POST (복원, LWW) — lib/backup.ts
- [web] POST /api/admin/sync/bulk (LWW upsert, slug 자동생성) — lib/sync.ts
- [web] GET /api/admin/comments?status= 필터 추가 (getAdminComments)
- [web] E-WEB-VALID-1002 추가
- 성능: 백업/복원 P95 경고 (dev Neon 지연), Swift Charts 네이티브

## v0.1.0-draft (2026-08-16)

- [common] 프로젝트 초기화: 문서 세트 생성 (PRD/DESIGN/PLAN/TODO)
- [common] 디자인 방향 확정: ⌘+체크마크 모티브, 시스템 블루→퍼플 그라디언트
- [common] 스택 결정: Next.js 풀스택 + SwiftUI + Neon + Gemini Free
- [common] T-00: 표준 인프라 완료 (build_and_run.sh, scripts 3종, bd 이슈 10개, AGENTS.web/macos.md)
- [web] T-01: DebugLogger 규격 + withApi 래퍼 + Prisma 확장 쿼리 로깅 (API→/API←/PERF/CACHE)
- [web] T-02: Neon 연결 + Prisma 7 스키마 7모델 + 마이그레이션(init) + 시드(카테고리4/관리자)
- [macos] T-01: DebugLogger/DebugPanel/APIClient 골격 소스 (Xcode 프로젝트는 T-06)
- [web] /api/health 검증: DB 연결 + API 로깅 5종 확인 (콜드 스타트 940ms — Warm 정상화 예상)
- [web] T-03: web 기반 완료 — 홈/카테고리/상세/검색 페이지 + 게시글/카테고리 API
- [web] T-03: pg_trgm 확장 + GIN 인덱스 마이그레이션 (검색 성능)
- [web] T-03: MD 렌더링 (react-markdown + remark-gfm), SEO (sitemap/robots/OG), 다운로드 게이트 섹션 (T-04/05 연동 대기)
- [web] T-03: 샘플 게시글 2개 시드 (검증용) + eslint react-hooks/purity 대응 (PERF 측정을 lib 계층으로)
- [web] T-04: NextAuth v5 (Auth.js) + Google 로그인 + PrismaAdapter (User에 emailVerified/image 추가)
- [web] T-04: 댓글 API/UI — 로그인 필수, honeypot + IP rate limit(10분 5개) + 승인 모드(PENDING)
- [web] T-04: 다운로드 게이트 1단계 — 로그인 + 승인 댓글 1개 이상 시 링크 공개 (클릭 추적은 T-05)
- [web] T-04: 마이그레이션 정리 — comment_ip(ipAddress) + user_auth_fields, pg_trgm 인덱스 복구
- [web] T-04: 검증 — 비로그인 POST 401(E-WEB-AUTH-1001), GET 200, 게이트 잠김 표시 (OAuth 자격 증명 필요)
- [web] T-04: Google OAuth 실제 로그인 성공 (client_id undefined 문제 수정 — Auth.js v5는 env 자동 인식 안 함, providers에 명시 전달)
- [web] T-04: AdapterError 수정 — 스키마에 Account/Session/VerificationToken 추가 + PrismaAdapter에 base 클라이언트 사용
- [web] T-04: 댓글 개선 — 본인 PENDING 보기(배지) + 수정/삭제(본인+승인 전만, 대댓글 포함), PUT/DELETE API
- [web] T-04: Neon shadow DB 불안정 → migration.sql 직접 작성 + migrate deploy 방식 전환

## v0.0.0 (2026-08-16)

- [common] 빈 저장소 초기화 (git init)- [web] T-05: 다운로드 게이트 — /post/[slug]/download/[dlId] (로그인+승인 댓글≥1, 실패 시 ?gate=blocked), DownloadEvent 기록(IP sha256 해시) + clickCount 증가
- [web] T-05: /admin 대시보드 — 요약(게시글/조회/댓글/대기/클릭/사용자) + 최근 14일 + 게시글별 통계 + 댓글 승인/스팸 처리 (role=ADMIN 전용, /api/admin/*)
- [web] T-05: Header 관리자 링크 (로그인+ADMIN일 때만, 세션 role 확장 — @auth/core/jwt augmentation)
- [web] T-05: 버그 수정 — /api/admin/comments GET 라우트 누락(404) → comments/route.ts 분리
- [web] T-05b: 디자인 시스템 — 토큰 3계층(Primitive/Semantic/Component) globals.css, 블루 #007AFF→퍼플 #AF52DE 그라디언트, 4px 그리드, 시스템 폰트
- [web] T-05b: 다크모드 — ThemeProvider(시스템 감지+토글) + FOUC 방지 스크립트 + 헤더 토글 버튼, semantic 토큰 기반 전환
- [web] T-05b: 컴포넌트 토큰 적용 — btn/card/badge/input/table, 전 컴포넌트 하드코딩 색상 제거 (Header/Footer/PostCard/Pagination/CommentsSection/AdminDashboard/페이지)
- [web] T-05b: 검증 — 라이트(#007AFF)/다크(#0A84FF) computed style + a11y 스냅샷
- [common] T-05c: 앱 아이콘 — assets/logo/MacCanDo_icon.svg (⌘+체크마크, 블루→퍼플 그라디언트, 유리질감), .icns 생성, favicon(icon.png/apple-icon.png)
- [web] T-06: /api/auth/token 발급 (관리자 세션, JWT 30일, jose) + lib/auth-token.ts + getAdminUser Bearer 토큰 지원 (세션 OR 토큰)
- [macos] T-06: xcodegen 프로젝트 (macOS 14+, MacCanDo.xcodeproj) + AppIcon(.icns→1024 PNG)
- [macos] T-06: DesignTokens (블루/퍼플 브랜드, 라이트/다크, 4px 그리드, Radius, Font) — 웹 토큰과 동일 규격
- [macos] T-06: DebugLogger + DebugPanel (Cmd+Shift+D 플로팅 패널) + 실행 로그 확인
- [macos] T-06: NavigationSplitView 4섹션 (글 관리/댓글 승인/통계/설정) + APIClient(Bearer) + AuthStore(토큰 저장) + 빌드 성공

## v1.0.0-T07 (2026-08-16) — [macos][web] 글 관리 에디터 + 관리 CRUD API
- web: POST/PUT/DELETE/GET /api/admin/posts(/[id]) — DRAFT/PUBLISHED 관리, slug 자동 생성/중복 회피 (lib/posts.ts)
- web: error_message_ko.json E-WEB-POST-1001~1004 추가
- macos: PostModels + DraftStore(SQLite 자동저장 3초 디바운스) + MarkdownRenderer + EditorView(NSTextView/WKWebView 미리보기/발행) + PostsView 개편
- macos: APIClient 쿼리스트링 URL 버그 수정 (URL(string:relativeTo:))
- 검증: CRUD curl 통과 (DRAFT 미노출 → 발행 노출 → 삭제), 앱↔API 연동 200 (게시글 2개 로드)
- 에러코드: E-WEB-POST-1001/1002/1003/1004, E-MAC-DB-1001, E-MAC-VALID-1001/1002
