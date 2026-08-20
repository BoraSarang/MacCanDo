# MacCanDo — 작업 추적 (TODO)

> 플랫폼 라벨: web / macos / common
> 상태: todo / 진행중 / 완료

---

## 진행중

| 번호 | 작업 | 플랫폼 | 상태 | 비고 |
|------|------|--------|------|------|
| T-64 | 카테고리 관리 (web admin API + macOS Settings 섹션 — v2.11) | web+macos | ✅ | v2.11 |
| T-65 | 시리즈 홈 배너 순서(featuredOrder) 편집 (SeriesView — v2.11) | macos | ✅ | v2.11 |
| T-66 | AI 설정 관리 (모델 선택 + 키 자동 가져오기 — v2.11) | macos | ✅ | v2.11 |
| T-67 | 이야기 시리즈 마법사 (5단계 위저드 + 진입 3곳 — v2.11) | macos | ✅ | v2.11 |
| T-68 | 본문 이미지 미리보기→등록 흐름 (v2.11) | macos | ✅ | v2.11 |
| T-71 | AI 도우미 개선 — 입력 textbox + 커버/본문 이미지 생성 + 게시글 초안(DRAFT) 등록 (v2.12) | macos | ✅ | v2.12 |
| T-72 | 맥 소식 "글 작성에 사용" → AI 도우미 경유 (v2.12) | macos | ✅ | v2.12 |
| T-73 | 이야기 마법사 개편 — 하드코딩 시드 제거 → 주제 기반 자동 기획/본문/카테고리/이미지 (v2.12) | macos | ✅ 2026-08-20 (StorySeed.all 제거 → GeminiService.StorySeedPlan + generateStorySeriesPlan(.wizard 체인), 1단계 주제 입력+기획 버튼, drafts 빈 시작+가드, canProceed drafts 필수) | v2.13 |
| T-74 | 체인 설정 데이터 모델 (AIProvider/AIModelRef/AIAction/AIChainConfig + UserDefaults JSON) (v2.13) | macos | ✅ 2026-08-20 (AIProvider/AIModelRef/AICapability/AIAction/AIChainConfig + modelCatalog + 기본 체인 + aiChains 저장/로드/커스텀 모델) | v2.13 |
| T-75 | 체인 실행 엔진 + 기존 fetchText/callGeminiText/generateImage 통합 (v2.13) | macos | ✅ 2026-08-20 (runTextChain/runImageChain/generateImageDescription + fetchText(action:)/callGeminiText(action:)/generateImage(prompt:action:), ImageGenProvider/imageModel 제거, 뷰 6곳 chainLabel 교체) | v2.13 |
| T-76 | NVIDIA 공급자 — 텍스트/이미지(flux.1-schnell)/비전(llama-3.2-90b) (v2.13) | macos | ✅ 2026-08-20 (fetchNVIDIAText/callNVIDIAImage(b64_json)/fetchNVision(image_url base64), OpenAI 호환 API) | v2.13 |
| T-77 | 설정 UI — 동작별 모델 체인 편집기 + 키 3종 + 커스텀 모델 (v2.13) | macos | ✅ 2026-08-20 (AI 설정 섹션 개편 — 키 3종, ChainEditorView 팝오버, 커스텀 모델, 기본값 복원, 키체인 NVIDIA_API_KEY 추가) | v2.13 |
| T-78 | 비전 alt — 에디터/도우미 설명 생성 + 웹 [img:URL alt=] 렌더링 (v2.13) | macos+web | ✅ 2026-08-20 (EditorView/AssistantView alt 생성 버튼 + [img:URL alt="…"] 삽입/클립보드, markdown.ts parseParams 쿼터+alt 렌더) | v2.13 |
| T-79 | 검증 + 문서 (v2.13) | common | ✅ 2026-08-20 (xcodebuild BUILD SUCCEEDED, web tsc --noEmit 통과, MD alt 렌더 검증) | v2.13 |
| T-68 | 본문 이미지 미리보기→등록 흐름 (v2.11) | macos | ✅ | v2.11 |
| T-69 | 콘텐츠 등록 (시리즈 "그 이름, 뺏겼다" + 글 3편 + 이미지 + 홈 배너 — v2.11) | web+macos | ✅ | v2.11 (카테고리 stories + 시리즈 + 글 3편 PUBLISHED + 커버 webp 4장 업로드 + 홈 배너 order 1) |
| T-70 | 검증 + 문서 + 커밋 (v2.11) | common | ✅ | v2.11 (tsc/build/E2E 4/4, macos BUILD SUCCEEDED) |
| T-58 | 웹 리디자인 파이프라인 (⌘ 키캡 시그니처·framer-motion spring·타이포 스케일·이모지 제거·감사) | web | ✅ | v2.8 |
| T-44 | 공통 컴포넌트 (ErrorState/EmptyState/StatusBar/배지) + 토큰 실적용 | macos | ✅ | v2.7.0 |
| T-45 | Settings scene 분리 (⌘,) + 사이드바 설정 제거 | macos | ✅ | v2.7.0 |
| T-46 | ContentView — ⌘1~8 hidden Button + ⌥⌘S 토글 + 배지 + 맥 소식 탭 | macos | ✅ | v2.7.0 |
| T-47 | WindowManager 닫은 창 정리 + 창 크기 상수화 | macos | ✅ | v2.7.0 |
| T-48 | 에디터 — 헤더 1줄 + Inspector(⌘⌥I) + 포커스/저장상태/이미지 시트/미리보기/갱신 버그 | macos | ✅ | v2.7.0 |
| T-49 | 게시글 관리 — 표준 행/필터/새로고침/상태바/피드백 | macos | ✅ | v2.7.0 |
| T-50 | 시리즈 — NavigationSplitView 2열 + 글 추가 시트 | macos | ✅ | v2.7.0 |
| T-51 | 댓글 — segmented 필터 유지 + 로컬 반영 | macos | ✅ | v2.7.0 |
| T-52 | 광고 — NavigationStack/재시도/로컬 반영 | macos | ✅ | v2.7.0 |
| T-53 | 통계 — 기간 선택(7/14/30) + 새로고침 | macos | ✅ | v2.7.0 |
| T-54 | 설정 상세 — SecureField/연결 테스트/캐시 초기화 | macos | ✅ | v2.7.0 |
| T-55 | 맥 소식 독립 탭 + AuthStore 단일화 | macos | ✅ | v2.7.0 |
| T-56 | AI 도우미 표준 정리 + 팔레트 TTL/검색 규칙 | macos | ✅ | v2.7.0 |
| T-57 | 전체 빌드/자동 검증/배포/문서/커밋 | macos | ✅ | v2.7.0 |

## 대기

| 번호 | 작업 | 플랫폼 | 상태 |
|------|------|--------|------|
| T-63 | 소스 리팩토링 (web+macos — P1안전성→P5토큰, PLAN_v2.10_refactor) | web+macos | ✅ 2026-08-18 (P1~P5 완료, bd MacCanDo-27c close) |
| T-62 | Playwright E2E 스모크 + CI 등록 (bd MacCanDo-hx2 ②) | web | ✅ 2026-08-18 (4/4 통과, CI 워크플로 — 시크릿 등록 필요) |
| T-61 | macOS PERF/CACHE 점검 (bd MacCanDo-hx2 ③) — [PERF] 레벨 + Cold start 측정 + API 지연 로그 | macos | ✅ 2026-08-18 (Cold start 346ms) |
| T-60 | 글 상세 페이지 SSG 정적화 (게이트/조회수 클라이언트 전환 — bd MacCanDo-hx2) | web | ✅ 2026-08-18 (TTFB 2957→55ms) |
| T-59 | 일별 통계 기록 누락 수정 (bumpDailyStat 4훅 — bd MacCanDo-c80) | web | ✅ 2026-08-18 |
| T-05b | 디자인 시스템 (토큰 3계층 + 다크모드 + 컴포넌트 적용) | web | ✅ 2026-08-16 |
| T-05c | 앱 아이콘 생성 (.icns + 파비콘) | common | ✅ 2026-08-16 |
| T-06 | macos 앱 골격 + 인증(토큰) + DebugPanel | macos | ✅ 2026-08-16 (골격 완료, 기능 T-07/T-08) |
| T-07 | macos 에디터 (MD/HTML + 자동저장 + 미리보기) | macos | ✅ 2026-08-16 |
| T-08 | macos 승인/통계/업로드/백업/AI SEO | macos | ✅ 2026-08-16 (승인/통계/AI SEO/백업복원/동기화 완료, 이미지 업로드 포함) |
| T-09 | 디자인 적용 + E2E + 배포 | macos | ⏸ 보류 (사용자 결정 — 운영 시점 재개, bd MacCanDo-paf는 완료) |
| T-10 | macos 에디터 MD 전용 2칸 + 확장 MD 문법 (유튜브/이미지/동영상) | macos | ✅ 2026-08-17 |
| T-12 | 웹 사이드바 접힘 + 글 상세 [gallery] 라이트박스 + 카테고리 10개/메뉴 | web | ✅ 2026-08-17 |
| T-13 | macOS 미리보기 [gallery] 그리드 + 사이드바 접힘 | macos | ✅ 2026-08-17 |
| T-14 | 홈 섹션 정리 (최근/최신 분리, 역할별 탐색 10개) + 다크모드 수정 + 정렬 셀렉트 화살표 + 시리즈 이미지 16:9 + 모바일 검색 폼 + 코드 복사 버튼 | web | ✅ 2026-08-17 |
| T-15 | 앱 카드 — 글당 여러 앱 (PostApp + store-fetch + [app] 마커 + macOS 에디터 시트) | web+macos | ✅ 2026-08-17 |
| T-17 | 정적 페이지 6종 — About/Privacy/Disclaimer/Terms/FAQ/Contact (contentType=PAGE + 푸터 + 모바일 하단 바 ⋯) | web+macos | ✅ 2026-08-17 |
| T-18 | iosgods 패턴 — 목록 카드 태그 배지 + 상대시간 + 비로그인 환영 배너 | web | ✅ 2026-08-17 |
| T-19 | 시리즈 커버 AI 생성 (프롬프트 확인/편집 → 생성 → 업로드) | macos | ✅ 2026-08-17 |
| T-20 | [app] 위치 마커 → [app:URL] 자동 변환 (저장 시 1회) | web | ✅ 2026-08-17 |
| T-21 | 커버 이미지 UX — thumbnailUrl + AI 커버 시트 (16:9 생성 → 미리보기 → 적용) | macos | ✅ 2026-08-17 |
| T-22 | 이미지 생성 공급자 선택 (OpenRouter Flux 키 + 무료 폴백) | macos | ✅ 2026-08-17 |
| T-23 | 맥 소식 리포트 (수집/AI 요약/글 작성 시드) + AI 도우미 | macos | ✅ 2026-08-17 |
| T-24 | 로컬 임시 저장 초안 (DraftStore, draft_new 단일 슬롯) | macos | ✅ 2026-08-17 |
| T-25 | 창 중복 방지 (단일 인스턴스 + 키당 창 1개) | macos | ✅ 2026-08-17 |
| T-26 | [center]/[img: align=center] 가운데 정렬 + 앱 카드 homepageUrl 분기 + slug 유지 + 목록 즉시 갱신 | web+macos | ✅ 2026-08-17 |
| T-27 | 한글 맞춤법 검사 (NSSpellChecker + Gemini 개별 적용) | macos | ✅ 2026-08-17 |
| T-28 | 마크다운 2단 중첩 목록 (들여쓰기 2칸 = 1레벨, macOS+웹) | web+macos | ✅ 2026-08-17 |
| T-29 | 앱 카드 "App Store ↗" 오표시 수정 (DB 정리 + 로드 정규화 + 이름 호스트명) | web+macos | ✅ 2026-08-17 |
| T-30 | 커버 이미지 수동 지정 (업로드 목록에서 선택 — 글/시리즈 커버, 1600×900 권장) | macos | ✅ 2026-08-17 |
| T-31 | 일반 웹사이트 앱 카드 og 메타 스크래핑 (og:title/image/description + fallback, "설명" 줄) | web+macos | ✅ 2026-08-17 |
| T-32 | 기존 글 초안 서버 우선 (로컬 초안이 서버 본문을 덮는 버그 수정) | macos | ✅ 2026-08-17 |
| T-33 | 윈도우 아키텍처 (unified 툴바 + defaultSize 1100×720 + @SceneStorage + NSWindow autosave) | macos | ✅ 2026-08-17 |
| T-34 | 메뉴 바 정비 (⌘N 새 글, ⌘⇧D DebugPanel, Help 웹) | macos | ✅ 2026-08-17 |
| T-35 | 사이드바 개선 (220pt + SF Symbols + 컨텍스트 메뉴 + ⌘1~7 + 화면 복원) | macos | ✅ 2026-08-17 |
| T-36 | 색상 토큰 통일 (전 화면 시스템 색 → ds 토큰) | macos | ✅ 2026-08-17 |
| T-37 | 재질 적용 (.bar/.regularMaterial — macOS 26 glassEffect 자동 대응) | macos | ✅ 2026-08-17 |
| T-38 | 타이포 계층 통일 + 이모지 → SF Symbols 전면 교체 | macos | ✅ 2026-08-17 |
| T-39 | hover 상태 (Posts/Stats/Ads/MacNews 행·카드 — dsSurfaceHover) | macos | ✅ 2026-08-17 |
| T-40 | 컨텍스트 메뉴 (글/댓글/시리즈/광고/소식/사이드바) | macos | ✅ 2026-08-17 |
| T-41 | 단축키 (⌘N 새 글, ⌘S 초안 저장, ⌘Return 발행) | macos | ✅ 2026-08-17 |
| T-42 | ⌘K 커맨드 팔레트 (화면 전환 + 글 검색 + 액션, CommandPaletteView) | macos | ✅ 2026-08-17 |
| T-43 | 통계 화면 종료→재시작 시 글 관리로 리셋 버그 (SceneStorage → AppStorage 교체) | macos | ✅ 2026-08-17 |

## 완료

| 번호 | 작업 | 플랫폼 | 상태 |
|------|------|--------|------|
| T-00 | 표준 인프라 (문서/스크립트/bd/에러코드) | common | ✅ 2026-08-16 |
| T-01 | DebugPanel + DebugLogger + API 로깅 골격 | common | ✅ 2026-08-16 |
| T-02 | Neon 스키마 + Prisma 마이그레이션 | web | ✅ 2026-08-16 |
| T-03 | web 기반 (목록/카테고리/상세/검색) | web | ✅ 2026-08-16 |
| T-04 | Google 로그인 + 댓글 + 스팸 방지 | web | ✅ 2026-08-16 (OAuth 자격 증명 대기) |
| T-05 | 다운로드 게이트 + 통계(/admin) + 댓글 승인 | web | ✅ 2026-08-16 |
| T-64 | 카테고리 관리 (web admin API + macOS Settings 섹션 — v2.11) | web+macos | ✅ 2026-08-20 |
| T-65 | 시리즈 홈 배너 순서(featuredOrder) 편집 (SeriesView — v2.11) | macos | ✅ 2026-08-20 |
| T-66 | AI 설정 관리 (모델 선택 + 키 자동 가져오기 — v2.11) | macos | ✅ 2026-08-20 |
| T-67 | 이야기 시리즈 마법사 (5단계 위저드 + 진입 3곳 — v2.11) | macos | ✅ 2026-08-20 |
| T-68 | 본문 이미지 미리보기→등록 흐름 (v2.11) | macos | ✅ 2026-08-20 |
