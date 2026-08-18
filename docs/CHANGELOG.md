## v2.9 (2026-08-18) — [web] 일별 통계 기록 수정 (bd MacCanDo-c80)

- 원인: `GET /api/admin/stats`의 `data.daily`가 항상 `[]` — DailyStat 테이블에 데이터를 기록하는 코드가 전무 (조회수/다운로드/댓글/신규 유저 이벤트에 upsert 누락, 테이블·unique 인덱스는 init 마이그레이션에 존재)
- `lib/stats.ts` 신규: `bumpDailyStat(field)` 헬퍼 — UTC 오늘 0시 전역(postId=null) 레코드 findFirst+create/update (복합 unique where는 postId null 비허용이라 upsert 불가), 실패 시 조용히 무시(logger.warn — 주 흐름 방해 금지) + `isSameUtcDay` 유틸
- 훅 4곳: 조회 `lib/posts.ts`(viewCount 증가 옆, PAGE 제외 로직 동일), 다운로드 `lib/downloads.ts`(clickCount 증가 뒤), 댓글 `lib/comments.ts`(생성 후 — PENDING 포함 활동 추세), 신규 유저 `auth.ts` signIn 콜백(PrismaAdapter 생성 후 email findUnique → createdAt이 오늘이면 newUsers 집계)
- 백필 없음: 과거 조회수를 임의 분산하지 않음 (daily는 이벤트 시점부터 누적, totalViews는 기존 집계 유지)
- 검증 (TC-59-1): dev 서버에서 게시글 조회 API 2회 → `/api/admin/stats` daily `[{date: 2026-08-18, views: 2, clicks: 0, comments: 0, newUsers: 0}]` 확인, 조회수 39→40 증감 정상
- 스키마 변경 없음 (마이그레이션 불필요), 신규 에러코드 없음

## v2.8 (2026-08-18) — [web] 웹 리디자인 파이프라인 (frontend-design → apple-design → emil-design-eng → web-design-guidelines)

- 디자인 브리프: "⌘ 커맨드 키" 세계관 시그니처 확립 — 히어로 ⌘ 키캡(.keycap: 표면 그라데이션 + 3px 하단 테두리 + 8px radius) + spring 스태거 진입(Hero.tsx), 헤더 로고 키캡 뱃지
- 모션 토큰 보강: --ds-duration-slow(320ms), --ds-ease-out(Apple cubic-bezier(0.32,0.72,0,1)), --ds-ease-spring 추가, framer-motion 의존성 추가 (web/package.json)
- apple-design 모션: 카드 whileHover y:-3 / whileTap scale(0.985) spring(bounce 0, 0.3s) — PostCard·FeaturedPosts·SeriesBanner·카테고리(CardMotion), FadeIn/FadeInMount 공용 컴포넌트 (Motion.tsx), 버튼 :active scale(0.97) + transition-[transform,...] 분리, reduced-motion 전역 처리
- 타이포: 타입 스케일 클래스(.type-display/-h1/-h2/-caption/-micro) — display 1.05 leading/-0.02em tracking, text-wrap: balance, .tnum(tabular-nums)
- 이모지 제거 (39→0 UI 잔존 0, DB 카테고리 아이콘만 aria-hidden 유지): 테마 토글 ☀️🌙→Sun/MoonIcon SVG, 조회/댓글 👁💬→Eye/CommentIcon, MobileBar 🔍☰⋯→SVG, 코드 복사 📋→"복사"/"✓ 복사됨", 시리즈/다운로드/탭 이모지 제거, AdminDashboard ✨→badge "AI"
- web-design-guidelines 적용: 전역 :focus-visible 링, 검색 placeholder "…" 적용, prefers-reduced-motion 미디어 전역, 이미지 CLS는 비율 고정 컨테이너(aspect-video)로 기존 방어 확인
- Lighthouse 감사 수정 (A11y 92→100): 중첩 `<a>` 제거(PostCard 배지 Link→span — 하이드레이션 실패 근본 원인 해결), WCAG AA 대비 토큰(라이트 primary #0062cc 4.83:1·muted #757580 4.56:1, 다크 primary #409cff 5.9:1·muted #8b8b95 5.4:1, btn-primary 전용 배경 --ds-primary-btn), 터치 타깃(.badge min-h-6+py-1 → 24px) — 최종 A11y 100 / Best Practices 96 / SEO 100 / Agentic 100 (BP 96 잔여 1건은 로컬 시리즈 커버 404 — R2 미적용 인프라 이슈, T-08로 해결 예정)
- 배포: Vercel Production Ready (web-bo-ra-sa-rang.vercel.app, SSO 보호 유지 — 커스텀 도메인 없음)
- 검증: npm run build 성공, dev 서버 DOM/CSS 계산값 검증(키캡 그라데이션·타이포 tracking/leading·focus-visible·reduced-motion 규칙 존재), 카드 hover translateY(-3px)/tap scale/복원 실측, 다크 모드 토큰, 하이드레이션 에러 0(중첩 a 수정 후), 상세 페이지 a11y 스냅샷
- 스크린샷/a11y 덤프: docs/screenshots/web/v2.8_home_light.png, v2.8_post_dark.png, v2.8_home.a11y.json, lighthouse/report.json

## v2.7.5 (2026-08-18) — [macos] Pollinations 무료 이미지 생성 제거 + DebugPanel HIG 적용

- 무료 이미지 생성(Pollinations) 완전 제거: ImageGenProvider case 제거(자동=Gemini), auto 폴백 로직·callPollinations·encodePrompt 삭제, 설정 설명/에디터 폴백 경고 문구 정리 — Gemini(또는 OpenRouter) 전용
- DebugPanel HIG 적용: 검은 배경 하드코딩 → textBackgroundColor(다크/라이트 대응), 이모지(🐛📌⚠️)→SF Symbol(ladybug/pin/exclamationmark.triangle), 하드코딩 RGB → ds토큰(dsBlue/dsSuccess/dsDanger/dsWarning/dsAmber/dsText/dsTextMuted), 폰트 .dsMono/.dsCaption, 헤더 버튼 .bordered+.controlSize(.small) + 선택 복사 disabled 처리
- DebugPanel 표시 검증: frame=(620,558,560,384) 정상, 스크린샷 픽셀 분석으로 패널 렌더 확인 (배경 30,30,30 + 로그 흰 텍스트)
- 배포: ~/Applications/MacCanDo.app (빌드 16)

## v2.7.4-spellfix (2026-08-18) — [macos] 맞춤법 검사 에러 표시 수정

- APIError가 LocalizedError를 채택하지 않아 error.localizedDescription이 "작업을 완료할 수 없습니다.(MacCanDo.APIError 오류 1.)"로만 표시되던 문제 수정 — errorDescription = message로 실제 원인(에러코드/상태) 표시
- 맞춤법 검사 재검증: 본문 입력 → 검사 실행 → 오류 1건 발견("이글은"→"이 글은"), 적용 버튼 정상 (이전 실패는 일시 오류였고 이제 원인 메시지가 표시됨)
- 배포: ~/Applications/MacCanDo.app (빌드 15)

## v2.7.3-editor50 (2026-08-18) — [macos] 에디터/미리보기 50:50 고정

- HSplitView(스플리터 비율 자유) → HStack(spacing: 0) + Divider로 변경 — 에디터/미리보기가 항상 동일한 크기 (각 (창폭-280-1)/2)
- 창 리사이즈 시에도 50:50 유지 검증: 1250→484, 1000→359, 1600→659 (미리보기 폭, GeometryReader 로그)
- Inspector(280pt 고정)는 변경 없음
- 배포: ~/Applications/MacCanDo.app (빌드 14)

## v2.7.2-inspector (2026-08-18) — [macos] Inspector 재배치 (카테고리 최상단 + 커버 이동/상단 크롭)

- Inspector 순서 변경: 카테고리(FlowLayout)를 최상단으로 이동, 커버 이미지 섹션을 글 타입 Form 바로 아래로 이동
  - 기존: [글 타입/시리즈/태그/slug] → [카테고리] → [커버]
  - 변경: [카테고리] → [글 타입/시리즈/태그/slug] → [커버]
- 커버 미리보기 크롭 기준 중앙 → 상단 (frame alignment: .top + clipped) — 세로로 긴 이미지에서 상단이 보이도록
- AX 트리 덤프로 섹션 순서 검증 (카테고리 토큰 4개 → 글 타입 → 커버 버튼들)
- 배포: ~/Applications/MacCanDo.app (빌드 13)

## v2.7.1-T57fix (2026-08-18) — [macos] 시리즈 화면 복구 + 도우미 탭 정리 + 미리보기 리사이즈 + 시트 UX

- T-57 수정 1 (시리즈 동작 안 됨): ContentView(NavigationSplitView) detail 안 중첩 NavigationSplitView가 렌더되지 않는 문제 → NavigationStack + HSplitView 2열로 복구. + isLoading 초기값 false→true (빈 뷰 mount 불가 → .task 미실행이 근본 원인, Posts/Comments와 통일)
- T-57 수정 2 (AI 도우미 UI 불일치): 맥 소식이 사이드바 독립 탭(T-46)으로 승격됐는데 도우미 창에 남아 있던 "참고 자료|맥 소식" segmented 제거 — 참고 자료 전용으로 정리
- T-57 수정 3 (미리보기 리사이즈): WKWebView를 ScrollView로 감싸면 내부 레이아웃이 고정되어 창 리사이즈 미반영 → ScrollView 제거 (WKWebView 자체 스크롤), GeometryReader로 리사이즈 검증 로그 (416×690 등 확인)
- T-57 수정 4 (에디터 시트 UX): 시트 헤더 .headline→.title3.bold() 통일 (SEO/커버/앱카드/마크다운/이미지), 이미지 목록 이모지(💬📄)→SF Symbol, ErrorState/EmptyState 컴포넌트 적용, 파일 선택 버튼 .bordered, URL 필드 Return 제출
- UI 직접 검증: AX 접근성 트리 덤프로 사이드바 7탭·시리즈 5개 목록/상세/툴바 4버튼·글 추가 시트 9개·AI 도우미(참고 자료 3건)·에디터 헤더/포맷 바/Inspector/미리보기/시트 5종(이미지·SEO·커버·앱카드·마크다운) 확인
- 배포: Release 빌드 → ~/Applications/MacCanDo.app (빌드 12, v1.0.0)

## v2.7.0-T44~T57 (2026-08-18) — [macos] 전면 HIG 표준화: 공통 컴포넌트·에디터·목록·설정

- T-44: 공통 컴포넌트 신규 (ErrorState/EmptyState/StatusBar/StatusBadge) + 디자인 토큰 실적용 (6개 뷰 시스템 색 → ds*)
- T-45: Settings scene 분리 (⌘,) — 사이드바 설정 제거, "설정 열기" 표준 셀렉터 통일
- T-46: ContentView — ⌘1~8 hidden Button 통일, ⌥⌘S 사이드바 토글, 댓글 대기(60초 타이머)/초안 배지, 맥 소식 독립 탭(+⌘8)
- T-47: WindowManager — 닫은 창 참조 정리(willClose) + 창 크기 상수 (1100×720/1000×640/900×600)
- T-48: 에디터 — 헤더 4줄→제목 1줄+포맷 바, Inspector(⌘⌥I, 280pt)로 메타/카테고리(FlowLayout)/커버 이동, 제목 자동 포커스, 저장 상태 SF Symbol, 이미지 시트 연속 삽입, 미리보기 다크모드+스크롤 복원, .postSaved 표준 발행(시드/⌘N/⌘K 갱신 버그 해결), 새 시리즈 취소 nil, 이모지 제거
- T-49: 글 관리 — 96px 표준 행(144×80 썸네일), 필터 메뉴(전체/초안/발행 유지)+⌘R, 클릭=선택·더블클릭/Return=열기, hover 액션, 삭제 실패 alert, 상태 바
- T-50: 시리즈 — HSplitView→NavigationSplitView 2열(170pt), 하단 버튼 바→툴바(+⌘N/편집⌘E/삭제⌘⌫), "글 추가"(⌘+) 시트(검색+체크박스) — 검색 시 목록 통째 교체 버그 수정
- T-51: 댓글 — 필터 AppStorage 유지, 상태 변경 로컬 반영(스크롤 유지), ⌘R, 실패 alert
- T-52: 광고 — NavigationStack+타이틀, 커스텀 카드→List 섹션, 토글 로컬 반영(재로드 없음), ⌘R
- T-53: 통계 — 기간 선택(7/14/30 유지)+⌘R, 차트 기간 연동, 카드 dsSurface 표준화, 시리즈 색 ds 토큰 통일
- T-54: 설정 — SecureField(토큰/키, 저장값 프리필), 연결 테스트(api/categories), AI SEO 캐시 초기화, 저장 후 필드 유지
- T-55: 맥 소식 — 커스텀 카드→List 섹션(리포트=섹션), 소스 관리 시트, EmptyState
- T-56: AI 도우미 — ⌘C 충돌 제거(시스템 복사 복원), 미리보기 다크모드, 팔레트 글 검색 규칙 PostsView와 일치(태그/카테고리/설명) + 60초 TTL
- 배포: Release 빌드 → ~/Applications/MacCanDo.app (빌드 11, v1.0.0)
- 알려진 이슈: 서버 /api/admin/stats daily 빈 배열 (MacCanDo-c80) — 일별 차트 데이터 없음

# MacCanDo — 변경 이력 (CHANGELOG)

> 형식: [platform] 태그 필수

---

## v2.6.0-T32~T42 (2026-08-17) — [macos] 디자인 개편: 윈도우/사이드바/⌘K 팔레트/토큰 통일

- T-32: 기존 글 초안 서버 우선 (로컬 빈 초안이 서버 본문을 덮는 버그 수정 — 기존 글은 초안 정리, 새 글만 body 필수 복구)
- T-33: 윈도우 아키텍처 — unified 툴바 + defaultSize 1100×720 + contentMinSize + @SceneStorage("sidebar.selection") + NSWindow autosave (도우미/에디터 창 크기·위치 복원)
- T-34: 메뉴 바 정비 — File(새 글 ⌘N), View(DebugPanel ⌘⇧D), Help(MacCanDo 웹사이트)
- T-35: 사이드바 — 220pt(ideal/max 300) + 행 컨텍스트 메뉴 + ⌘1~7 화면 전환 + 마지막 화면 복원
- T-36: 색상 토큰 통일 — 전 화면 시스템 색 → dsPrimary/dsAccent/dsSuccess/dsWarning/dsDanger/dsSurfaceHover
- T-37: 재질 — EditorView 헤더 .bar, ⌘K 팔레트 .regularMaterial (macOS 26 glassEffect는 semantic API로 자동 대응)
- T-38: 이모지 → SF Symbols — 조회수 eye, books.vertical, star.fill, checkmark/xmark.circle.fill, megaphone 등 전면 교체
- T-39: hover — 글 목록 행/통계 카드/광고 행/맥 소식 항목 (dsSurfaceHover + onHover)
- T-40: 컨텍스트 메뉴 — 글(에디터/웹/삭제), 댓글(승인/스팸/복구), 시리즈(편집/삭제), 광고(지정/해제), 맥 소식(원문/글 작성), 사이드바(새 글/열기)
- T-41: 단축키 — ⌘S 초안 저장, ⌘Return 발행 (에디터)
- T-42: ⌘K 커맨드 팔레트 (CommandPaletteView) — 화면 6개 + 액션 3개 + 글 22개 검색 → 에디터 열기, 화살표/Return/Esc
- 배포: Release 빌드 → ~/Applications/MacCanDo.app (빌드 9, v1.0.0)

## v2.5.0-T19~T31 (2026-08-17) — [macos+web] 시리즈 커버·초안·맞춤법·중첩 목록·앱 카드 개선

- T-19: 시리즈 커버 AI 생성 (제목·설명 기반 프롬프트 확인/편집 → 생성 → 업로드 → URL 자동 입력)
- T-20: [app] 위치 마커 → [app:URL] 자동 변환 (저장 시 1회, migrateAppMarkers)
- T-21: 커버 이미지 UX 전환 — thumbnailUrl 기반 (AI 커버 시트: 프롬프트 → 16:9 생성 → 미리보기 → "커버 이미지로 사용")
- T-22: 이미지 생성 공급자 선택 (OpenRouter Flux 키 설정, 무료 티어 폴백)
- T-23: 맥 소식 리포트 (수집/AI 요약/글 작성 시드) + 사이드바 AI 도우미(참고 자료)
- T-24: 로컬 임시 저장 초안 (DraftStore, draft_new 단일 슬롯 — 새 글 중복 초안 방지, 시드 경로는 초안 로드 안 함)
- T-25: 창 중복 방지 — 단일 인스턴스(AppDelegate) + 키(postId/draftKey)당 창 1개 + AI 도우미 별도 창
- T-26: [center] / [img: align=center] 가운데 정렬 (macOS+웹 렌더러) + 앱 카드 homepageUrl 분기(App Store URL만 appUrl) + slug 미지정 시 기존 유지 + 저장 성공 시 글 관리 목록 즉시 갱신 + AI 도우미 결과 자동 저장
- T-27: 한글 맞춤법 검사 (NSSpellChecker 물결 밑줄 + Gemini 검사 — 코드블록/URL/[app:]/[img:] 보호, 개별 적용 버튼)
- T-28: 마크다운 2단 중첩 목록 (들여쓰기 2칸 = 1레벨, 최대 4단 — macOS+웹 렌더러 동일 규격)
- T-29: 앱 카드 "App Store ↗" 오표시 수정 (DB PostApp 정리 + macOS 로드 정규화 + isStore 판별 + 이름 호스트명 표시)
- T-30: 커버 이미지 수동 지정 — 업로드 목록에서 선택 (ImagePickerSheet cover 모드, 글 커버 + 시리즈 커버, 권장 1600×900)
- T-31: 일반 웹사이트 앱 카드 og 메타 스크래핑 (og:title/image/description/site_name + <title>/favicon fallback + 상대경로 절대화, 저장 시 1회 — 기존 URL-만 카드도 재저장 시 채움, "설명" 줄 표시)
- 검증: macOS BUILD SUCCEEDED, 웹 TSC 통과, og 스크래핑 3사이트(iterm2/tmux/ohmyz) 실전 검증, 웹 페이지 렌더 확인

## v2.5.0-T18 (2026-08-17) — [web] iosgods 패턴: 목록 카드 태그 배지 + 상대시간 + 환영 배너

- lib/format.ts 신규: fmtRelativeTime (방금 전/N분 전/N시간 전/N일 전, 7일 초과 시 절대 날짜) + fmtFullDate (호버 툴팁)
- getPosts SQL에 태그 string_agg 추가 → PostListItem.tags, PostCard에 태그 배지 2개 (#태그, 카테고리 옆) + 날짜를 상대시간으로 (호버 시 전체 날짜)
- WelcomeBanner.tsx 신규 (글 상세 상단, 비로그인만): "안녕하세요! 👋 — 댓글을 남기면 다운로드 링크 공개" + 로그인 버튼 (useEffect로 표시, 정적 PAGE 글 제외, [FEATURE] 로그)
- 배너 버튼은 댓글 영역의 "Google 로그인"과 중복돼 strict mode flaky → "로그인하고 시작하기"로 분리
- 참고: 댓글 수(💬) 표시는 T-14에 이미 구현돼 있어 추가 작업 없음
- 검증: E2E 39/39 (TC-T18-001~003 신규), TSC 통과, 스크린샷 docs/screenshots/web/v2.5_t18_*

## v2.5.0-T17 (2026-08-17) — [web+macos] 정적 페이지 6종 + 모바일 하단 바

- DB: PostContentType enum에 PAGE 추가 (수동 마이그레이션 20260817_add_page_content_type, Neon db execute + migrate resolve)
- 웹: 목록 쿼리 일괄 PAGE 제외 (홈/카테고리/검색/추천/관련글/이전·다음/sitemap 목록), 글 상세 — PAGE면 카테고리/조회수/썸네일/댓글/시리즈/관련글 숨김 + 조회수 미집계 (본문·앱 카드 기능은 그대로)
- 푸터: About · Privacy Policy · Disclaimer · Terms of Service · FAQ · Contact Us 링크 6개 (데스크톱 가로/모바일 세로)
- 모바일 하단 고정 바 (appstorrent 패턴, <768px): 🔍 검색 / ☰ 메뉴 / ⋯ 드롭업(6개 링크 + 닫기) — MobileBar.tsx 신규
- macOS: 에디터 글 타입 드롭다운에 '페이지' 옵션 추가 (contentType=PAGE로 저장)
- 시드: 6개 페이지 초안 한국어 등록 (about/privacy-policy/disclaimer/terms/faq/contact, lib/seed_pages.ts 재실행 안전)
- 검증: E2E 35/35 (TC-PAGE-001~004 신규), TSC 통과, macOS BUILD SUCCEEDED, 스크린샷 docs/screenshots/web/v2.5_page_*

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
