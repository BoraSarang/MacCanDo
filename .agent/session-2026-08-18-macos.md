# 세션 2026-08-18 (macos) — v2.7.0 전면 리뉴얼

## 진행 상황 (00:30~00:55)
- T-44 완료: CommonUI.swift 신규(ErrorState/EmptyState/StatusBar/StatusBadge) + 토큰 실적용(23건 → ds 토큰, .pink/.teal은 차트 시리즈색이라 Phase D)
- T-45 완료: Settings scene(⌘,) 분리, 사이드바 설정 제거, navigateToSettings → showSettingsWindow 표준 셀렉터
- T-46 완료: ContentView ⌘1~8 hidden Button 통일, ⌥⌘S 토글, 사이드바 배지(댓글 대기 60초 타이머+초안 수), 맥 소식 탭(+⌘8)
- T-47 완료: WindowManager 닫은 창 참조 제거(willClose) + WindowSize 상수(1100×720/1000×640/900×600)
- T-48 완료(코드+빌드): 에디터 헤더 4줄→제목 1줄+포맷 바, Inspector(⌘⌥I, 280pt)에 메타/카테고리(FlowLayout)/커버 이동, 제목 자동 포커스, 저장상태 아이콘(SF Symbol, dsSuccess/dsWarning), 이미지 시트 연속 삽입 유지, 미리보기 다크모드(CSS 미디어쿼리)+스크롤 복원(WKWebView scrollY), .postSaved 표준 발행(⌘N/⌘K/시드 갱신 버그 해결), 새 시리즈 취소→nil, 이모지 제거
- FlowLayout.swift 신규 + pbxproj 등록 (중요: PBXBuildFile 정의 누락이 원인 — plutil 검증 필수)

## 검증
- 빌드 BUILD SUCCEEDED ×2, 앱 실행, ⌘N 메뉴 클릭 → 에디터 창 열림(카테고리/시리즈 로드), 창 닫기 → "에디터 창 닫힘 — 참조 제거" 로그 확인
- 접근성(AX) 제한으로 UI 내부 검증 불가 — 로그 기반 검증

## 다음 단계
- Phase C: T-49 PostsView(96px 행/필터/새로고침/상태바/피드백), T-50 SeriesView(NavigationSplitView+시트), T-51 CommentsView, T-52 AdsView
- Phase D: T-53~T-56, Phase E: T-57 배포/문서/커밋

## 진행 상황 (00:55~01:15) — Phase C 완료
- T-49 완료: PostsView — 96px 행(144×80 썸네일)+서브라인(슬러그/카테고리/태그/조회수/수정일), 필터 메뉴(전체/초안/발행 AppStorage)+⌘R, 새 글 ⌘N, 클릭=선택/더블클릭·Return=열기(List selection+onKeyPress), hover 액션 버튼(opacity), 삭제 실패 alert, .postSaved 시 drafts도 갱신, ErrorState/EmptyState/StatusBar 적용
- T-50 완료: SeriesView — HSplitView→NavigationSplitView(사이드바 170pt), 하단 버튼 바 제거→툴바(+⌘N/편집⌘E/삭제⌘⌫), "글 추가"(⌘+) 시트(AddPostsSheet: 검색 디바운스+체크박스+추가) — 검색 시 data 통째 교체 버그 수정(시트 내부 로컬 상태)
- T-51 완료: CommentsView — 필터 AppStorage("comments.filter"), 상태 변경 로컬 반영(재로드 없음=스크롤 유지, 필터 불일치 시 제거), ⌘R, 실패 alert, ErrorState/EmptyState/StatusBar
- T-52 완료: AdsView — NavigationStack+타이틀, 커스텀 카드→List 섹션, 토글 로컬 반영(Post.featuredOrder var 전환, 시리즈는 서버 응답 교체), ⌘R, 실패 alert, 초안 배지 StatusBadge
- 빌드 4회 연속 BUILD SUCCEEDED

## 다음 단계
- Phase D: T-53 StatsView(기간 7/14/30+⌘R, 차트), T-54 Settings 상세(SecureField/연결 테스트/캐시 초기화), T-55 MacNews List 표준화, T-56 AssistantView(⌘C 충돌)+팔레트
- Phase E: T-57 전체 빌드→배포→문서→커밋

## 진행 상황 (01:15~01:40) — Phase D 완료
- T-53 완료: StatsView — 기간 메뉴(7/14/30 AppStorage "stats.days")+⌘R, 차트 기간 연동(suffix 슬라이스+날짜 오름차순 정렬), 카드 dsSurface 표준화, 시리즈 색 .pink/.teal → dsAccent/dsWarning, ErrorState 적용
- T-54 완료: SettingsView — 토큰/키 SecureField(저장값 onAppear 프리필), 연결 테스트(api/categories→성공:카테고리 N개/실패:HTTP status), 캐시 초기화 버튼(DraftStore.clearSEOCache+resetCacheStats 신규), 저장 후 필드 유지
- T-55 완료: MacNewsView — 커스텀 카드(ScrollView+LazyVStack)→List 섹션(리포트=섹션, 날짜 헤더+삭제), 소스 관리 시트로 이동(500×380), EmptyState, toolbar(소스 관리/새로 수집)
- T-56 완료: AssistantView — ⌘C 충돌 제거(복사 버튼 keyboardShortcut 제거), 미리보기 다크모드 CSS(media query), CommandPalette — 검색 규칙 PostsView와 일치(태그/카테고리/설명 추가), 글 목록 60초 TTL 재로드
- 빌드 연속 SUCCEEDED (Phase C~D 합계 8회)

## 다음 단계
- Phase E (T-57): 최종 빌드 → 앱 재실행 로그 검증 → ~/Applications 배포(build_and_run.sh install macos) → CHANGELOG/TODO/DESIGN → 커밋

## 진행 상황 (01:40~02:00) — Phase E 완료
- 최종 빌드 BUILD SUCCEEDED, 앱 재실행 로그 검증 (Posts/Series/Comments/Stats/Ads/MacNews 탭별 onAppear+API 로드 확인, 1100×720 창 확인)
- 서버 daily 빈 배열 발견 → bd MacCanDo-c80 생성 (P2)
- 배포 완료: build_and_run.sh install macos → ~/Applications/MacCanDo.app (v1.0.0, 빌드 11), Release 앱 로그 정상
- CHANGELOG v2.7.0 항목 작성, TODO T-57 ✅
- 남은 것: git 커밋 (사용자 확인 후)

## 커밋 대기
- 커밋 예정 파일: Views 8개(Posts/Series/Comments/Ads/Stats/Settings/MacNews/Assistant/CommandPalette/ContentView/EditorView/SeriesView), Core(CommonUI/FlowLayout 신규, DraftStore, PostModels), MacCanDoApp/WindowManager, docs(CHANGELOG/TODO/PLAN), pbxproj

## 진행 상황 (04:10~04:45) — 사용자 보고 4건 수정 + UI 직접 검증
- 1) 시리즈 동작 안 됨 → 근본 원인 2개: ① ContentView detail 안 중첩 NavigationSplitView 렌더 불가 ② isLoading=false 초기값 → 빈 뷰 mount 안 됨 → .task 미실행. NavigationStack+HSplitView 복구 + isLoading=true → 복구 확인
- 2) AI 도우미 참고자료/맥 소식 탭 불일치 → 맥 소식은 사이드바 독립 탭이므로 도우미 창 segmented 제거 (참고 자료만)
- 3) 미리보기 리사이즈 안 됨 → WKWebView를 ScrollView로 감싼 것이 원인 → ScrollView 제거, GeometryReader 리사이즈 로그로 검증 (482×840, 416×690 등)
- 4) 에디터 시트 UI/UX → 헤더 title3.bold 통일, 이모지→SF Symbol, ErrorState/EmptyState, 파일 선택 bordered
- UI 직접 검증: Swift AX 트리 덤프/클릭/타이핑 스크립트(/tmp/ax*.swift) — 사이드바 7탭, 시리즈(목록 5+상세+툴바+글추가 시트), AI 도우미(참고자료 3건, segmented 없음), 에디터(제목 입력→AI 생성 활성화 확인, 시트 5종 열림 확인)
- 배포: 빌드 12 (~/Applications)
- 남은 것: 커밋


## 진행 상황 (08:2x) — Inspector 재배치 (v2.7.2)
- 카테고리 최상단 + 커버를 글 타입 Form 아래로 이동, 커버 미리보기 상단 크롭 (alignment .top)
- AX 검증: [카테고리 4토큰] → [글 타입/시리즈/태그/slug] → [커버] 순서 확인
- 배포 빌드 13, 커밋 후 push 필요
- (참고) 사용자 로그에 맞춤법 검사 API 오류(APIError 1) — 별도 이슈로 남겨둠


## 진행 상황 (08:30) — 에디터/미리보기 50:50 (v2.7.3)
- HSplitView → HStack+Divider (에디터/미리보기 동일 사이즈, 리사이즈 시에도 유지)
- 검증: 1250→484 / 1000→359 / 1600→659 (= (창폭-281)/2 정확 일치)
- 배포 빌드 14, 커밋 필요


## 진행 상황 (08:35) — 맞춤법 검사 에러 수정 (v2.7.4)
- 원인: APIError가 LocalizedError 미채택 → localizedDescription이 "MacCanDo.APIError 오류 1."로만 표시 (실제 원인 숨김)
- 수정: errorDescription = message 반환
- 검증: 본문 42자 검사 → 오류 1건 발견 + 적용 버튼 정상, 툴바 배지 "맞춤법 1"
- 배포 빌드 15, 커밋 필요


## 진행 상황 (09:05~09:25) — Pollinations 제거 + DebugPanel HIG (v2.7.5)
- Pollinations(무료 이미지) 완전 제거: case/폴백/callPollinations/encodePrompt/설정문구/폴백 경고 삭제 (Gemini 전용)
- DebugPanel HIG 적용: textBackgroundColor, SF Symbols(ladybug/pin/triangle), ds토큰 색상, .dsMono/.dsCaption, bordered 버튼
- 검증: frame 로그 + 스크린샷 픽셀 분석으로 패널 렌더 확인 (이미지 미지원 모델 — 픽셀 검사로 대체)
- 참고: NSPanel(utilityWindow)은 System Events/AX 트리에서 windows로 안 잡힘 — 좌표/픽셀 검증 필요
- 배포 빌드 16, 커밋 필요

