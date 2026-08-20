# PLAN v2.11 common — "그 이름, 뺏겼다" 시리즈 + 이야기 마법사 + AI 설정 고도화 (T-64~T-70)

작성: 2026-08-20 · 상태: 구현 전 · 규모: 대형 (web API + macOS UI 신규 개발 + 콘텐츠 3편)

## 개요
- 웹 메인 시리즈 배너에 노출될 재미난 상표권/이름 충돌 스토리 시리즈 **"그 이름, 뺏겼다"** (3편: Gemini / Apple vs 비틀즈 / Threads)를 만들고, 그 생성 절차를 macOS 앱에 **"이야기 시리즈 마법사"** 메뉴로 자동화한다.
- 카테고리 신설(이야기), 시리즈 홈 배너 순서 편집, AI 설정 관리(모델 선택 + 키체인 자동 가져오기), 본문 이미지 미리보기→등록 흐름을 함께 구현한다.

## 결정 사항
- **시리즈명**: "그 이름, 뺏겼다" / **카테고리**: `stories` "이야기" (macOS 앱 관리 UI 신설)
- **글 3편** (각 1,500자+, 앱 Gemini 초안, 출처 섹션 포함): Gemini 동명이인(MacPaw vs Google) / Apple vs 비틀즈 30년 분쟁 / Threads 데이비드 vs 골리앗(Meta vs Threads Software)
- **믹스업**: 시리즈 `featuredOrder` 설정 → 웹 홈 `SeriesBanner` 상단 노출 (기존 정렬 로직 활용, macOS UI만 추가)
- **AI 설정**: Settings "AI" 섹션 — 공급자 키 관리 + **이미지 모델 선택**(gemini-3.1/2.5-flash-image) + **"API 키 자동 가져오기"**(NSTask+security, 키체인 borasarang 계정, 접근 허용 팝업 OK)
- **이야기 마법사**: 메뉴 바(`파일 > 새 이야기 시리즈…`) + SeriesView 버튼 + ⌘K — 5단계 위저드, **단계별 컨펌 후 등록**
- **글 초안**: 앱 내부 Gemini가 생성 (사건 요약/팩트/출처 프롬프트 시드) → 미리보기/수정 → 컨펌
- **본문 이미지**: AI 생성 → 미리보기 → 확인 시 업로드 + 이미지 관리 등록 + `[img:URL]` 삽입

## 아키텍처 (플랫폼별)
- **web**: `POST/PATCH/DELETE /api/admin/categories` 신규 (관리자 전용) — 기존 GET 유지
- **macOS**:
  - `SettingsView` — 카테고리 관리 섹션 + AI 섹션(모델 선택, 키 자동 가져오기)
  - `SeriesView` — 홈 배너 순서(`featuredOrder`) 필드 추가
  - `SeriesWizardView` (신규) — 5단계 시트 위저드
  - `GeminiService` — 선택 이미지 모델 우선 + 폴백 유지, 텍스트 초안 생성 함수 추가
  - `AppMenu`/`CommandPaletteView` — 마법사 진입 등록
- **키체인**: `security find-generic-password -s <서비스명> -a borasarang -w` → AI 키 필드 자동 채움

## 구현 단계
- [x] T-64: 카테고리 관리 (web admin API + macOS Settings 섹션) — web tsc + macos 빌드 통과
- [x] T-65: 시리즈 홈 배너 순서 편집 (SeriesView featuredOrder)
- [x] T-66: AI 설정 관리 (모델 선택 + 키 자동 가져오기, GeminiService 반영)
- [x] T-67: 이야기 시리즈 마법사 (SeriesWizardView 5단계 + 진입 3곳)
- [x] T-68: 본문 이미지 미리보기→등록 흐름
- [x] T-69: 콘텐츠 — 시리즈/카테고리/글 3편 등록 + 이미지 생성 + 홈 배너 배치
- [x] T-70: 검증 + 문서 + 커밋

## 테스트 계획
- TC-64-1: POST/PATCH/DELETE /api/admin/categories 인증+ADMIN 가드, 401/403 확인
- TC-66-1: 키 자동 가져오기 — 키체인에서 GOOGLE_AI_API_KEY/OPENROUTER_API_KEY 채움 확인
- TC-66-2: 이미지 모델 선택 — 선택 모델로 생성 요청 + 폴백 동작
- TC-67-1: 마법사 전체 흐름 — 카테고리→시리즈→글 3편→이미지→홈 배너 등록, 단계별 컨펌
- TC-68-1: 본문 이미지 생성→미리보기→확인→업로드→[img:URL] 삽입
- TC-69-1: 웹 홈 시리즈 배너에 "그 이름, 뺏겼다" 노출 확인
- TC-70-1: web build + tsc + E2E 4건, macos xcodebuild + 빌드/런 검증

## 롤백
- 커밋 단위 분리 (web API → macOS UI → 마법사 → 콘텐츠) — 개별 revert 가능
- 키체인 자동 가져오기는 필드 채움만, 서버 무변경 (취소 시 필드 비우면 됨)
- 콘텐츠 등록은 API DELETE (글/시리즈/카테고리)로 원복

## 에러코드
- error_message_ko.json: E-MAC-CAT-1001(카테고리 생성 실패), E-MAC-WIZ-1001(마법사 등록 실패), E-WEB-CAT-1001(카테고리 저장 실패) 추가