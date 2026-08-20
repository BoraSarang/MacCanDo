# PLAN v2.12 common — AI 도우미 고도화 + 이야기 마법사 개편 (T-71~T-73)

> 문서 우선 (AGENTS.md 1.7) — 코딩 전 계획 확정. v2.11("그 이름, 뺏겼다" 등록) 후속.
> 날짜: 2026-08-20 · 플랫폼: macos 중심 (web 영향 없음)

## 개요

v2.11에서 만들어진 **이야기 시리즈 마법사**가 하드코딩 시드("그 이름, 뺏겼다" 3편)에 묶여 있어 일반화가 안 된 문제를 해소하고,
**AI 도우미 → 글 작성(초안 등록) → 편집기** 흐름을 통합한다.

### 목표

1. **AI 도우미(AssistantView) 고도화**: 프로그램 이름/웹사이트/설명을 textbox로 입력 → 조회 결과에 **커버/본문 이미지를 글 작성 기능처럼 생성**하고 → **게시글 초안(DRAFT)으로 등록** → 편집기에서 이어서 수정. 기존 ReferenceStore 저장 유지.
2. **맥 소식 연동**: MacNewsView "글 작성에 사용"이 에디터 직행 대신 **AI 도우미에서 해당 뉴스 내용으로 조회** 후 초안 진행.
3. **이야기 마법사 개편**: StorySeed 하드코딩 제거 → 주제 입력 → AI가 편 목록 기획 → 본문/카테고리(AI 제안+사용자 수정)/이미지 생성 → 일괄 등록.

## 작업 분해

- [x] 문서: TODO.md T-71~73 등록, PLAN_v2.12 작성
- [ ] T-71: AI 도우미 개선
  - [ ] `query` 입력 TextField → TextEditor (여러 줄, "프로그램 이름 / 웹사이트 URL / 설명")
  - [ ] 조회 결과 액션: 커버 이미지 생성 (자동 프롬프트 + 업로드에서 수동 선택)
  - [ ] 조회 결과 액션: 본문 이미지 생성 (자동 프롬프트 → 미리보기 → [img:URL] 삽입, EditorView 로직 재사용)
  - [ ] "게시글 초안으로 등록" (POST /api/admin/posts status=DRAFT + ReferenceStore 저장 유지) → 등록 후 편집기 열기
- [ ] T-72: 맥 소식 "글 작성에 사용" → AI 도우미 경유 (뉴스 제목/요약/링크 쿼리 시드)
- [ ] T-73: 이야기 마법사 개편 (SeriesWizardView)
  - [ ] StorySeed 하드코딩 제거, 동적 편 기획 (Gemini episode plan)
  - [ ] 본문 생성 + 카테고리 AI 제안/수정 (A+B)
  - [ ] 커버/본문 이미지 프롬프트 자동 생성 + 생성/업로드
- [ ] 검증: xcodebuild + 앱 재실행 + 시나리오 (도우미 조회→이미지→초안 등록→편집기 / 맥 소식 경유 / 마법사 주제 기반 등록)
- [ ] 문서: CHANGELOG(v2.12) + 세션 로그

## GeminiService 신규 함수 (예상)

- `generateImagePrompt(subject:)` — 주제/제목+본문 기반 이미지 생성 프롬프트
- `generateEpisodePlan(title:description:intro:)` — 이야기 마법사 편 목록 (JSON)
- `suggestCategory(title:body:)` — 본문 기반 기존 카테고리 slug 추천
- 재사용: `generateStoryDraft`, `generateImage`, `fetchURLText`, `fetchAdminCategories`, `createCategory`, `uploadImage`

## 에러코드

- E-MAC-WIZ-1001 (기존, 마법사 등록) 재사용, 필요 시 E-MAC-ASSIST-1001 (도우미 초안 등록 실패) 추가

## 롤백

- git revert (T-71~73 개별 커밋 단위), 앱 재빌드로 즉시 복구

## 테스트 계획 (TC)

- TC-71-1: 도우미에 "프로그램 이름" textbox 입력 → 조회 → 커버/본문 이미지 생성 → 초안 등록 → 편집기에서 이어서 수정
- TC-71-2: 조회 결과가 ReferenceStore에 그대로 저장됨
- TC-72-1: 맥 소식 항목 "글 작성에 사용" → AI 도우미 창 열림 + 쿼리 시드 확인
- TC-73-1: 마법사 주제 입력 → 편 목록 생성 → 카테고리 제안 → 등록 → 홈 배너