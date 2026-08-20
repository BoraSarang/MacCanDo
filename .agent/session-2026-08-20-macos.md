# 세션 로그 — MacCanDo v2.11~v2.13 (T-64~T-79)

> 날짜: 2026-08-20 · 플랫폼: macos + web

## v2.13 작업 (T-74~T-79 완료)

### 1. 무엇을
- T-74 ✅ 동작별 AI 모델 체인 설정 데이터 모델 (GeminiService — AIProvider/AIModelRef/AICapability/AIAction/AIChainConfig, modelCatalog, 기본 체인 시드, UserDefaults `aiChains` JSON 저장/로드/커스텀 모델, chainLabel(for:))
- T-75 ✅ 체인 실행 엔진 — runTextChain/runImageChain/generateImageDescription(비전), fetchText(prompt:action:)/callGeminiText(prompt:action:)/generateImage(prompt:action:)로 동작 함수 통합, ImageGenProvider/imageModel/imageModels/imageModelOptions 제거, 뷰 6곳 헤더·로그 chainLabel 교체
- T-76 ✅ NVIDIA NIM — fetchNVIDIAText(chat/completions), callNVIDIAImage(/v1/images/generations b64_json), fetchNVision(image_url base64) — build.nvidia.com 무료, OpenAI 호환
- T-77 ✅ 설정 UI — AI 설정 섹션 개편(키 3종 Gemini/OpenRouter/NVIDIA), ChainEditorView 팝오버(순서/추가/삭제/기본값), 커스텀 모델, 전체 기본값 복원, importKeysFromKeychain에 NVIDIA_API_KEY 추가
- T-78 ✅ 비전 alt — EditorView/AssistantView 이미지 시트 "alt 설명 생성" 버튼(본문 `[img:URL alt="…"]` 삽입, 커버는 클립보드), web markdown.ts parseParams 쿼터 지원 + `<img alt>` 렌더
- T-79 ✅ 검증+문서 — TODO/PLAN/CHANGELOG/error_message_ko.json(E-MAC-SET-1001 추가)/세션 로그
- T-73 ✅ (이어서) 이야기 마법사 개편 — StorySeed.all 하드코딩 제거 → GeminiService.StorySeedPlan + generateStorySeriesPlan(topic:) (JSON 배열, .wizard 체인), 1단계 주제 입력+[편 목록 AI 기획], drafts 빈 시작/가드, canProceed drafts 필수, draft.seed→draft.plan

### 3. 빌드/검증
- macOS xcodebuild Debug **BUILD SUCCEEDED**
- web `npx tsc --noEmit` 통과 + MD 렌더 스니펫: `[img:https://example.com/a.png alt="맥북 화면과 커피잔" width=600]` → `<img src="…" width="600" alt="…" loading="lazy"/>`

### 5. 다음 에이전트 전달 (v2.13 추가)
- T-73(이야기 마법사 개편 — StorySeed 하드코딩 → 주제 기반 자동 기획)은 다음 단계. 체인 엔진(runTextChain) 재사용 가능
- NVIDIA 이미지 호스트: `https://ai.api.nvidia.com/v1/images/generations` — build.nvidia.com 카탈로그 slug가 다르면 커스텀 모델로 보완 (PLAN 각주 참조)
- 기본 체인 = 기존 하드코딩과 동일하므로 회귀 없음. 체인 설정은 UserDefaults `aiChains` — 삭제 시 기본값 복원

### 6. 문서
- docs/TODO.md (T-74~79 ✅), docs/plans/PLAN_v2.13_common.md (체크 완료), docs/CHANGELOG.md (v2.13), error_message_ko.json (E-MAC-SET-1001), 세션 로그

---

## v2.12 오후 작업 (T-71~T-72 완료, T-73 대기)

### 1. 무엇을
- T-71 ✅ AI 도우미(AssistantView) 개선: 입력 textbox(TextEditor)화, 조회 결과 액션 바(커버/본문 이미지 AI 생성+수동 선택, 게시글 초안 DRAFT 등록 → 편집기에서 열기), EditorView imageGenSheet/bodyImageGenSheet 패턴 재사용, ReferenceStore 저장 유지
- T-72 ✅ 맥 소식 "글 작성에 사용" → AI 도우미 경유 (WindowManager.showAssistant(seedQuery:), MacNewsView.openAssistant — 제목+원문+소스+평가+요약 시드 자동 조회)
- T-73 ⏳ 이야기 마법사 개편 (StorySeed 하드코딩 제거 → 주제 기반 자동 기획) — 사용자 승인 대기
- 버그 수정: 시리즈 PATCH 빈 posts 문제(서버+macOS 가드), 취지 소개 TextEditor 첫 렌더링 버그(TextField axis:vertical 전환), update() intro 보존, 마법사 @State 시드 기본값 제거, /apps에서 stories 제외(excludeCategorySlug)

### 3. 빌드/검증
- xcodebuild Debug **BUILD SUCCEEDED** (경고 2건 SeriesWizardView 기존)
- 앱 재실행(pid 60906, DerivedData/MacCanDo) — 토큰 로드·맥 소식 리포트 로드 확인
- GUI 시나리오(맥 소식→글 작성에 사용→도우미 시드 조회→초안 등록→편집기)는 사용자 직접 확인 필요

### 6. 문서
- docs/TODO.md (T-71~73 등록, T-71/72 ✅), docs/plans/PLAN_v2.12_common.md, docs/CHANGELOG.md (v2.12)

### 5. 다음 에이전트 전달 (v2.12 추가)
- AssistantView: 관리자 토큰은 UserDefaults "apiToken" 직접 읽음 (environmentObject 없음), EditorView(postId:)로 초안 이어서 수정
- ImagePickerSheet(mode: .cover/.insert)는 EditorView에 정의 — AssistantView에서 재사용
- 미커밋 상태: v2.12 작업 + v2.11 오전 수정분(웹 lib/posts.ts·series.ts, macOS SeriesView/PostModels/SeriesWizardView 등) 모두 작업 트리에 있음

---

## v2.11 오전 작업 (T-64~T-70 완료)

## 1. 무엇을 (T-번호)
- T-64 ✅ 카테고리 관리 (web API + macOS Settings)
- T-65 ✅ 시리즈 홈 배너 순서 편집 (SeriesView) — `toggleBanner`에서 `data?.series[idx] = updated` 옵셔널 체이닝 subscript 오류 → `newSeries` 복사 재구성으로 수정
- T-66 ✅ AI 설정 관리 — `SettingsView.importKeysFromKeychain()` + `keychainValue(service:)` (NSTask+security, 계정 borasarang)
- T-67 ✅ 이야기 시리즈 마법사 — `SeriesWizardView.swift` (5단계 + StorySeed 3편 + `GeminiService.generateStoryDraft`) + 진입 3곳 + `newStoryWizardRequested` 알림
- T-68 ✅ 에디터 AI 본문 이미지 — `bodyImageGenSheet` (생성→미리보기→"본문에 삽입" 시 업로드+[img:URL])
- T-69 ✅ 콘텐츠 등록 — 시리즈 "그 이름, 뺏겼다" + 카테고리 stories + 글 3편 PUBLISHED + 커버 webp 4장 + 홈 배너

## 2. 플랫폼
macos (구현) + web (API/콘텐츠 등록)

## 3. 빌드/검증 결과
- macOS: `xcodebuild -project MacCanDo.xcodeproj -scheme MacCanDo` **성공** (XcodeGen 재생성 후)
- 웹 서버: `web`에서 `npm run dev` (localhost:3000, pid 21233)
- 콘텐츠 등록 완료:
  - 카테고리 stories (cmt0urm0u0000eemrnzhrmgao), 시리즈 "그 이름, 뺏겼다" (cmt0urm7l0001eemr1ar18loz)
  - 글: gemini-macpaw-google (cmt0urn6k0003eemrf7pkxnxm) / apple-vs-beatles-30years (cmt0urolg0004eemrb077bwp7) / threads-name-war-david-goliath (cmt0urpxq0005eemrpb683pjv)
  - 시리즈 순서 PATCH (postIds 3편) + 홈 배너 featuredOrder=1
- TC-69-1 ✅: 웹 홈 배너 최상단 "그 이름, 뺏겼다"(3개의 글, 커버) + 최근 게시글 3편 + 커버 노출 — a11y 덤프로 확인
- 초안 다듬기: korean-humanizer 적용 (줄표/이중해시 ## ## 출처 수정, 과도한 볼드 제거) — draft-1 ~/2 ~/3
- 이미지: Gemini 이미지 쿼터 429 + OpenRouter 잔액 부족 → 사용자가 수동 생성해 /Users/lee/Downloads에 webp 4장(g1/g2/g3/series) → 업로드(type=image/webp 명시 필요, curl 기본 MIME 미감지) + 커버 연결

## 4. 남은 TODO (T-번호)
- v2.12: T-73 이야기 마법사 개편 (주제 기반 자동 기획) — 다음 작업
- GUI 시나리오 검증 대기: AI 도우미(초안 등록→편집기), 맥 소식→도우미 경유
- 미커밋 정리: v2.11 오후 수정분 + v2.12 전체 (사용자 커밋 요청 대기)

## 5. 다음 에이전트 전달 로그
- 에러코드: E-MAC-WIZ-1001 (마법사 등록 실패), E-MAC-AI-1005 (본문 이미지 생성) — error_message_ko.json 존재
- 업로드 주의: `curl -F "file=@x.webp"`는 webp MIME을 못 잡음 → `;type=image/webp` 명시 필요
- 시리즈 순서 설정은 **PATCH** `/api/admin/series/[id]/posts` { postIds } (PUT 아님)
- 홈 배너: 시리즈 PATCH `featuredOrder`, 글 추천은 `posts/[id]/featured` 별개
- 본문 이미지 마커: 웹은 `[img:URL]` 지원 (markdown.ts). 자리 표시 텍스트에 `[img:URL]`이 남으면 깨진 이미지 렌더링 → 마커 텍스트에는 img: 구문 넣지 말 것
- 웹 dev 서버 pid 36065 (재기동됨)

## 6. 문서 업데이트 목록
- docs/TODO.md (T-64~T-70 ✅)
- docs/plans/PLAN_v2.11_common.md (전체 체크)
- docs/CHANGELOG.md (v2.11 — T-64~T-70)

## 7. 오프라인 큐 상태
해당 없음 (macos+web 프로젝트, 오프라인 큐 미사용)

## 8. E2E/k6 결과
- web: Playwright E2E 4/4 통과 (홈/글 상세/검색/카테고리)
- k6: 해당 없음 (server 없음)
- web build: `npm run build` 성공, `tsc --noEmit` 통과
- macOS: `xcodebuild -configuration Debug` BUILD SUCCEEDED
