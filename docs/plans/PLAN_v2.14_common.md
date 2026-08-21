# PLAN v2.14 common — 이미지 프롬프트 생성 (T-83)

> 문서 우선 (AGENTS.md 1.7) — 코딩 전 계획 확정. v2.13(동작별 AI 체인 설정화) 후속.
> 날짜: 2026-08-21 · 플랫폼: macos (EditorView + AssistantView)

## 개요

게시글 제목+본문을 텍스트 AI 체인으로 분석해, **타 AI 이미지 생성기에 붙여넣기 위한 영어 프롬프트 세트**를 만든다.
출력 형식은 사용자 예시 그대로:

```
커버 이미지 (16:9)
A macOS desktop screenshot showing OpenCode, an AI coding assistant app...

본문 1 — 대화 화면 (4:3)
A macOS app window with dark theme AI chat interface...
```

- 프롬프트는 영어 (타 생성기 호환 목적)
- 커버 1장(16:9) + 본문 이미지 2~5장(내용에 맞는 비율 자동 판단)
- 동작은 **복사 전용** — 각 항목 개별 복사 + 전체 복사(예시 형식 그대로 조립)
- 진입: EditorView 툴바 + AssistantView 액션 바 (둘 다)

## 작업 분해

- [x] 문서: TODO T-83 등록, PLAN_v2.14 작성
- [x] T-83-1: GeminiService — `AIAction.imagePrompts` 케이스 추가 (text capability, 설정 체인 편집기에 자동 노출)
- [x] T-83-2: `ImagePromptItem` 모델 (label:String, aspectRatio:String, prompt:String) + `generateImagePrompts(title:body:)` — `extractJSONArray` 헬퍼 재사용, JSON 배열 파싱
- [x] T-83-3: EditorView — 툴바 "이미지 프롬프트" 버튼(커버/본문 이미지 옆) + 시트: [생성] → 항목별 리스트(라벨+비율 배지+영어 프롬프트+개별 복사) + 전체 복사
- [x] T-83-4: AssistantView — 액션 바 동일 버튼 + 시트 (EditorView 패턴 재사용)
- [x] T-83-5: 검증 (xcodebuild BUILD SUCCEEDED) + 디버그 로그 `[FEATURE] 이미지 프롬프트 생성 완료 N건`

## 프롬프트 설계 (generateImagePrompts)

- 입력: 제목 + 본문 (마크다운/HTML은 텍스트로 추출)
- 지시: 게시글 내용을 시각적으로 표현할 이미지 목록 작성, JSON 배열만 출력
- 항목 형식:
  ```json
  {
    "label": "커버 이미지" 또는 "본문 1 — <화면 설명>",
    "aspectRatio": "16:9" 또는 "4:3" 등,
    "prompt": "영어 이미지 생성 프롬프트 (구체적 시각 묘사, 미니멀/클린 톤, 워터마크 없음)"
  }
  ```
- 첫 항목은 반드시 커버(16:9), 이후 본문 이미지 2~5장
- JSON 외 텍스트 출력 금지

## UI 설계 (macOS SwiftUI, AGENTS.md 12.4/13.1)

- 시트 크기: width 520, height 560
- 상단: 제목 + 체인 라벨(Caption) + [생성] 버튼
- 목록(Scroll): 각 항목
  - HStack: 라벨(bold) + 비율 배지(Caption pill) + Spacer + 복사 버튼(controlSize small)
  - 프롬프트 텍스트: TextEditor(읽기전용, textSelection(.enabled)) 또는 선택 가능 Text
- 하단: [전체 복사] (예시 형식 — "라벨 (비율)\n프롬프트\n\n" 반복) + [닫기]
- 생성 중 ProgressView, 에러는 dsDanger 텍스트

## 에러코드

- 재사용: E-MAC-AI-1003 (응답 해석 실패), E-MAC-SET-1001 (키 없음), E-MAC-AI-1007 (호출 실패)

## 롤백

- 커밋 단위 revert. 신규 AIAction 케이스 추가는 기존 저장 체인 데이터와 하위 호환(디코드 무시 가능).

## 테스트 계획 (TC)

- TC-83-1: 편집기에 제목/본문 입력 → [이미지 프롬프트] → 생성 → 커버+본문 항목 노출, 각 항목 복사 시 클립보드에 영어 프롬프트
- TC-83-2: [전체 복사] → 클립보드에 사용자 예시 형식(라벨(비율)\n프롬프트) 조립
- TC-83-3: AssistantView 액션 바에서 동일 동작
- TC-83-4: 키 미설정 시 E-MAC-SET-1001 안내
