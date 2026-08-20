# PLAN v2.13 common — 동작별 AI 모델 체인 설정화 + NVIDIA NIM 통합 (T-74~T-79)

> 문서 우선 (AGENTS.md 1.7) — 코딩 전 계획 확정. v2.12(AI 도우미 고도화) 후속.
> 날짜: 2026-08-20 · 플랫폼: macos 중심 + web(markdown.ts alt)

## 개요

현재 AI 모델·폴백 체인이 하드코딩되어 있고(모델·순서·온도), 동작별로 폴백 유무도 비일관하다.
**동작(기능)마다 모델 사용 순서를 설정으로 관리**하고, **NVIDIA NIM(build.nvidia.com)**을 새 공급자로 편입한다.

### 확정 사항 (사용자 결정)
1. 텍스트 동작 기본 체인: **Gemini → NVIDIA → OpenRouter** 전부 통일 (지금은 SEO만 폴백)
2. 기존 "이미지 생성 공급자/모델" Picker → **동작별 체인으로 통합** (제거)
3. 비전: 웹 alt 렌더링까지 (`[img:URL alt=…]`)
4. 키: 키체인 `NVIDIA_API_KEY`(borasarang) 존재 · build.nvidia.com 무료(개발용, 모델별 RPM) · OpenAI 호환 API

## 작업 분해

- [x] 문서: TODO T-74~79 등록, PLAN_v2.13 작성
- [x] T-74: 체인 설정 데이터 모델 (GeminiService)
  - `AIProvider`(gemini/nvidia/openrouter) · `AIModelRef`(provider+model) · `AIAction`(assistant·seo·spelling·wizard·newsSummary·coverImage·bodyImage·vision + label/capability) · `AIChainConfig`(동작별 [AIModelRef] 순서)
  - UserDefaults `aiChains` Codable JSON 저장/로드, 기본 체인 시드 (현재 하드코딩과 동일 동작 보존)
  - 커스텀 모델(UserDefaults `aiCustomModels`) — 코드 수정 없이 모델 추가
- [x] T-75: 체인 실행 엔진 + 기존 함수 통합
  - `runTextChain/runImageChain/runVisionChain` — 순서대로 시도, 실패·404·429·키없음 스킵
  - fetchText/callGeminiText/generateImage/callFlux 분기·폴백을 체인 기반으로 통합 (동작 함수 시그니처 유지 → 뷰 무변경)
- [x] T-76: NVIDIA 공급자
  - `fetchNVIDIAText` (integrate.api.nvidia.com/v1/chat/completions)
  - `callNVIDIAImage` (/v1/images/generations, flux.1-schnell, b64_json)
  - `generateVisionDescription` (llama-3.2-90b-vision-instruct, image_url base64)
- [x] T-77: 설정 UI (SettingsView)
  - AI 섹션 개편: 키 3종(Gemini/NVIDIA/OpenRouter) + 동작별 모델 체인 편집기(동작 8종 × 순서 리스트 + 모델 추가 Picker + 커스텀 모델 입력 + 기본값 복원)
  - 기존 이미지 공급자/모델 Picker 제거, 키체인 가져오기에 NVIDIA_API_KEY 추가
- [x] T-78: 비전 alt (macos+web)
  - EditorView/AssistantView 이미지 시트 "설명 생성(alt)" 버튼 → 본문 `[img:URL alt=…]` 삽입, 커버는 클립보드
  - web lib/markdown.ts: `[img:URL alt=…]` 파싱 → `<img alt>` (parseParams 재사용)
- [x] T-79: 검증 + 문서 (xcodebuild/web tsc+build/MD 렌더, TODO/CHANGELOG/세션 로그, 에러코드 재사용)
- [x] T-73 (이어서 완료): 이야기 마법사 주제 기반 개편
  - StorySeed.all 하드코딩 제거 → `GeminiService.StorySeedPlan`(Codable) + `generateStorySeriesPlan(topic:)` (JSON 배열, .wizard 체인)
  - 1단계 주제 입력 + [편 목록 AI 기획] 버튼, drafts 빈 시작(가드 추가), canProceed drafts 필수, draft.seed → draft.plan

## 기본 체인 (마이그레이션 시드)

- 텍스트 5종: `gemini-3.7-flash → nvidia/deepseek-ai/deepseek-v4-flash → openrouter/google/gemma-4-31b-it:free → openrouter/openai/gpt-oss-20b:free`
- 이미지 2종: `gemini/gemini-3.1-flash-image → gemini/gemini-2.5-flash-image → nvidia/flux.1-schnell`
- 비전: `nvidia/meta/llama-3.2-90b-vision-instruct`

## 모델 카탈로그 (설정 UI 선택지)

| Provider | 텍스트 | 이미지 | 비전 |
|----------|--------|--------|------|
| gemini | gemini-3.7-flash, gemini-3.1-flash, gemini-2.5-flash | gemini-3.1-flash-image, gemini-2.5-flash-image | — |
| nvidia | deepseek-ai/deepseek-v4-flash, nvidianemotron-3-ultra-550b-a55b | flux.1-schnell, qwen-image, stable-diffusion-3.5-large | meta/llama-3.2-90b-vision-instruct, meta/llama-3.2-11b-vision-instruct |
| openrouter | google/gemma-4-31b-it:free, openai/gpt-oss-20b:free | google/gemini-3.1-flash-image | — |

> NVIDIA 모델 slug는 구현 시 build.nvidia.com 카탈로그 기준 최신 확인, 불가 시 deepseek-v4-flash/flux.1-schnell/llama-3.2-90b 고정 + 커스텀 모델로 보완

## 에러코드
- E-MAC-SET-1001 (키 없음), E-MAC-AI-1001 (호출 실패), E-MAC-AI-1003 (응답 해석), E-MAC-AI-1007 (HTTP 실패) 재사용

## 롤백
- 커밋 단위 revert (T-74~79 개별), 기본 체인 = 현재 동작 동일 → 회귀 위험 낮음

## 테스트 계획 (TC)
- TC-74-1: 설정 저장 → 재시작 → 체인 유지, 기본값 복원
- TC-75-1: 텍스트 체인 폴백 (Gemini 키 제거 → NVIDIA → OpenRouter 로그 확인)
- TC-76-1: NVIDIA 이미지 생성 (flux.1-schnell) / 비전 alt 생성
- TC-77-1: 동작별 체인 순서 변경이 해당 동작에만 반영
- TC-78-1: `[img:URL alt=…]` 웹 렌더에 alt 속성 노출
- TC-73-1: 마법사 주제 입력 → AI 기획 편 목록 → 본문/카테고리/이미지 → 등록