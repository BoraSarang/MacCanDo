# 세션 로그 — MacCanDo v2.11~v2.13 (T-64~T-82)

> 날짜: 2026-08-20 · 플랫폼: macos + web

## v2.13 작업 (T-73~T-82 완료)

### 1. 무엇을
- T-74 ✅ 동작별 AI 모델 체인 설정 데이터 모델 (GeminiService — AIProvider/AIModelRef/AICapability/AIAction/AIChainConfig, modelCatalog, 기본 체인 시드, UserDefaults `aiChains` JSON 저장/로드/커스텀 모델, chainLabel(for:))
- T-75 ✅ 체인 실행 엔진 — runTextChain/runImageChain/generateImageDescription(비전), fetchText(prompt:action:)/callGeminiText(prompt:action:)/generateImage(prompt:action:), ImageGenProvider/imageModel 제거, 뷰 6곳 chainLabel 교체
- T-76 ✅ NVIDIA NIM — fetchNVIDIAText(chat/completions), callNVIDIAImage(/v1/images/generations b64_json), fetchNVision(image_url base64) — build.nvidia.com 무료, OpenAI 호환
- T-77 ✅ 설정 UI — AI 설정 섹션 개편(키 3종), ChainEditorView 팝오버(순서/추가/삭제/기본값), 커스텀 모델, 전체 기본값 복원, importKeysFromKeychain에 NVIDIA_API_KEY 추가
- T-78 ✅ 비전 alt — EditorView/AssistantView "alt 설명 생성" 버튼(본문 `[img:URL alt="…"]` 삽입, 커버는 클립보드), web markdown.ts 쿼터+alt 렌더
- T-79 ✅ 검증+문서 — TODO/PLAN/CHANGELOG/error_message_ko.json(E-MAC-SET-1001)/세션 로그
- T-73 ✅ 이야기 마법사 개편 — StorySeed.all 하드코딩 제거 → generateStorySeriesPlan(topic:), 1단계 주제→편 목록 기획, drafts 빈 시작+가드
- T-80 ✅ AI 실패 로그 상세화 — 체인 폴백 3곳 status/message, MacNewsView "unknown" 제거, RSS 소스별 실패 원인 로그
- T-81 ✅ 설정 3분류 개편 **최종: NavigationSplitView → HStack 고정(사이드바 180pt+Divider+섹션 제목)**, Settings scene toolbar 제거 — macOS 26 설정 자동 토글 문제 해결, 사용자 승인. 추가: ChainEditorView 폭 520/삭제 버튼/라벨 줄바꿈, 카테고리 2줄+아이콘 힌트, 공급자 URL Link, NVIDIA 키 onAppear 채움, AI 도우미 행 전체 클릭
- T-82 ✅ AI 폴백 정비 — 소식 요약 전멸(6/6 청크 실패 0건) 수정
  - NVIDIA 실측: `deepseek-ai/deepseek-v4-flash-0731` **529 과부하+100초(타임아웃 유발)** → 기본 체인/카탈로그 **`openai/gpt-oss-20b`(0.46초)** 교체, nemotron-3-ultra 제거, `llama-3.3-nemotron-super-49b-v1.5`(1.48초) 추가
  - runTextChain/runImageChain/비전 catch `APIError`만 → 전체 Error — URLError(타임아웃 -1001/네트워크 유실 -1005)를 APIError(E-MAC-NET-1001)로 래핑해 **다음 공급자로 폴백**
  - 타임아웃 60→120초 4곳 (NVIDIA 텍스트/비전, Gemini, OpenRouter)
  - summarizeNews 실패 청크 건너뛰기(부분 결과 반환)
  - aiChains 초기화(기본 체인 복원) + NVIDIA 키 키체인/UserDefaults 갱신 (70자 동일 확인)

### 3. 빌드/검증
- macOS xcodebuild Debug **BUILD SUCCEEDED** (T-82 최종)
- NVIDIA 모델 실측: `openai/gpt-oss-20b` 200/0.46초, `nemotron-super-49b-v1.5` 200/1.48초, `gemma-3-4b-it`/`12b-it`/`nemotron-nano` 404
- 배포/실행: `/Users/lee/Applications/MacCanDo.app` pid 18845 (T-82)
- web `npx tsc --noEmit` 통과 + MD alt 렌더 확인 (T-79)

### 4. 남은 TODO (T-번호)
- 미커밋 정리: T-80~T-82 + v2.13 오후 수정분 (docs 4종 + 코드 5종 — 사용자 커밋 요청 대기)
- GUI 시나리오 검증 대기: 맥 소식 요약 재실행 → gpt-oss-20b 폴백 확인, AI 도우미 초안 등록→편집기

### 5. 다음 에이전트 전달 로그
- 기본 텍스트 체인: Gemini gemini-3.7-flash → **NVIDIA openai/gpt-oss-20b** → OpenRouter gemma-4-31b-it:free → gpt-oss-20b:free
- 배포 규칙: **무조건 /Users/lee/Applications/MacCanDo.app** (DerivedData 직접 실행 금지)
- 빌드: `cd macos && xcodebuild -project MacCanDo.xcodeproj -scheme MacCanDo -configuration Debug build`
- Gemini 503 반복 시 폴백이 끝까지 진행됨(T-82). 그래도 0건이면 로그에서 provider별 실패 원인 확인
- 업로드 주의: `curl -F "file=@x.webp"`는 MIME 미감지 → `;type=image/webp` 명시
- 본문 이미지 마커에 `[img:URL]` 자체를 텍스트로 넣지 말 것(깨진 렌더)

### 6. 문서 업데이트 목록
- docs/TODO.md (T-73~T-82 ✅), docs/plans/PLAN_v2.13_common.md (카탈로그 실측 갱신), docs/CHANGELOG.md (v2.13 T-81/T-82 상세), error_message_ko.json (E-MAC-SET-1001), .agent/session (본 파일)

### 7. 오프라인 큐 상태
해당 없음 (macos+web 프로젝트)

### 8. E2E/k6 결과
- web: Playwright E2E 4/4 (홈/글 상세/검색/카테고리), build/tsc 통과
- k6: 해당 없음 (server 없음)
- macOS: xcodebuild BUILD SUCCEEDED, /Users/lee/Applications 배포·실행 확인