# 세션 로그 — MacCanDo v2.11 (T-64~T-70 완료)

> 날짜: 2026-08-20 · 플랫폼: macos + web (v2.11)

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
- 없음 (v2.11 완료) — 다음 버전 대기

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
