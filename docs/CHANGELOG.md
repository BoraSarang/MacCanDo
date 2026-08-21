## v2.15 (2026-08-21) — [macos+web] 글쓰기 워크스페이스 통합 + 70% 자동화 파이프라인 (T-83~T-95)

### macOS

- **T-83**: 이미지 프롬프트 생성 (본문 분석 → 영어 프롬프트 세트, 커버 16:9 + 본문 2~5장 4:3, 복사 전용)
  - `GeminiService.generateImagePrompts(title, body)` — JSON 배열 파싱, `AIAction.imagePrompts` 체인 경유
  - EditorView/AssistantView 툴바 버튼 + 시트: 개별 복사 + 전체 복사(사용자 예시 형식 그대로 조립)

- **T-84**: WritingPipeline 엔진 — 5단계 파이프라인 (`Core/WritingPipeline.swift`)
  - 1단계 `collectAndNormalize`: 주제 → RSS/소스 수집 → `ResearchBundle`(CollectedItem/AppCandidate/키워드)
  - 2단계 `planStructure`: 번들 → `PostPlan`(섹션/커버프롬프트/앱카드/슬러그/카테고리/태그) JSON 생성
  - 3단계 `generateDraft`: 플랜 → `DraftPackage`(본문MD/이미지프롬프트/앱카드/SEO) 섹션별 생성
  - 4단계 `injectToEditor`: 드래프트 → 에디터 상태 주입 (NotificationCenter 경유)
  - 5단계 `preparePublish`: 발행 전 검증 → `PublishPackage`(SEO/썸네일/alt/앱카드/본문구조)

- **T-85**: PromptLibrary 시스템 (`Core/PromptLibrary.swift` + `Resources/PromptTemplates.json`)
  - 템플릿 CRUD + 내장 5종(앱소개/비교/튜토리얼/뉴스/커스텀) + UserDefaults JSON 저장
  - JSON 내보내기/가져오기 (버전 관리, 내장 템플릿 보호, 중복 스킵/덮어쓰기 옵션)
  - 변수 치환: `{topic}`, `{sections}`, `{tone}`, `{length}`, `{language}`, `{appName}`, `{feature}`, `{style}`

- **T-86**: 정규화 데이터 모델 (`Core/CollectedItem.swift`)
  - `CollectedItem`(원문/요약/평가/키워드/출처), `AppCandidate`(앱스토어/홈페이지/설명/카테고리/가격)
  - `ResearchBundle`, `PostPlan/SectionPlan`, `DraftPackage`, `PublishPackage/ValidationIssue`

- **T-87**: WorkspaceView — NavigationSplitView 3열 (`Views/WorkspaceView.swift`)
  - 사이드바(170pt): 글관리/시리즈/댓글/통계/광고/맥소식/참고자료
  - 메인(가변): EditorCoreView(분할/포커스모드) + ActionBar(6단계 파이프라인)
  - 인스펙터(280pt): Research/Assistant/ImagePrompt/SEO/Publish 5탭
  - ContentView 완전 대체 → 단일 메인 창

- **T-88**: EditorView 전면 재작성 (`Views/EditorView.swift` — 모듈 인라인화)
  - `EditorCoreView`: 분할 드래그(0.25~0.75) + 포커스모드(분할/편집기만/미리보기만)
  - `EditorToolbar`: 포맷/삽입/SEO/도우미/맞춤법/초안저장/발행/이미지프롬프트
  - `EditorAutosave`: 2초 디바운스 + 앱종료시 강제저장 + DraftStore 연동
  - `EditorSEO`: SEO 메타 프리뷰(구글 검색결과 카드) + 수동편집 + AI 자동생성
  - `EditorSheets`: Help/SEO/이미지픽커/커버픽커/앱카드/커버이미지/본문이미지/이미지프롬프트
  - `ActionBar`: 6단계(리서치→기획→초안→이미지→발행준비→발행) 진행바 + 실행/이전/다음/재실행

- **T-89**: 인스펙터 5패널 (`Views/Inspector/*.swift`)
  - `ResearchPanel`: 소스/키워드/앱 탭 + FlowLayout 칩
  - `AssistantPanel`: 도우미 결과 프리뷰 + 복사/에디터적용 + alt 생성
  - `ImagePromptPanel`: 프롬프트 리스트(라벨/비율/복사/편집/생성) + 템플릿 피커 + 편집기
  - `SEOPanel`: 구글 검색결과 프리뷰 카드 + 키워드 태그 + 썸네일 + 수동편집 + AI 생성
  - `PublishChecklist`: 10개 검증항목(SEO/슬러그/카테고리/태그/썸네일/alt/앱카드/본문) + 원클릭 수정

- **T-90**: ActionBar — 6단계 파이프라인 진행 UI (EditorView 내장)

- **T-91**: 이미지 프롬프트 라이브러리 — 템플릿 선택/변수치환/편집/히스토리 (ImagePromptPanel 내장)

- **T-92**: PublishChecklist — 10항목 자동검증 + 상태표시(통과/경고/오류) + 원클릭 수정 액션

- 빌드 이슈 해결:
  - `NotificationCenter.post` 이름 충돌 → 전역 함수 `_postNotification`으로 우회 (`MacCanDoApp.swift`)
  - `CommonUI.swift` 중복 `Notification.Name` 정의 제거
  - `EditorView.swift` 모듈 인라인화로 컴파일러 타임아웃 해결

### Web (T-93, T-94)

- T-93: 마크다운 확장 호환 검증 (`[img:URL alt=]`, `[app:URL]`, `[gallery]`, `[center]` macOS↔웹 100% 일치)
- T-94: Playwright E2E 확장 — `workspace-flow.spec.ts` 7개 테스트 추가 (이미지프롬프트/앱카드/갤러리/중앙정렬/OG메타/이미지프롬프트복사 UX)
- 총 10 passed / 1 skipped (JSON-LD 미구현 skip)

### 검증

- macOS: `xcodebuild -configuration Debug BUILD SUCCEEDED` — 앱 실행 확인 (`/Users/lee/Applications/MacCanDo.app` pid 95086)
- Web: `tsc --noEmit` 통과, Playwright E2E 11개 테스트 통과 (smoke 4 + workspace-flow 7)
- E2E 실행 시간: ~17초

---

## v2.13 (2026-08-20) — [macos+web] 동작별 AI 모델 체인 설정화 + NVIDIA NIM 통합 (T-74~T-79)

### macOS
- T-74: 동작별 AI 모델 체인 설정 데이터 모델 (GeminiService)
...