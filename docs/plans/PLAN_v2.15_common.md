# PLAN v2.15 common — 글쓰기 워크스페이스 통합 + 70% 자동화 파이프라인 (T-84~T-95)

> 문서 우선 (AGENTS.md 1.7) — 코딩 전 계획 확정. v2.14(이미지 프롬프트 생성) 후속.
> 날짜: 2026-08-21 · 플랫폼: macos (메인) + web(렌더링 동기화)

## 개요

현재 에디터/도우미/마법사/맥소식이 별도 창/탭으로 분산되어 **컨텍스트 전환 비용이 크고 자동화 플로우가 단절**되어 있다.
이를 **단일 '글쓰기 워크스페이스' 창(3열 NavigationSplitView)** 으로 통합하고,
**자료 수집 → 기획 → 초안 생성 → 이미지 프롬프트 → 발행 준비 → 발행/동기화** 6단계 파이프라인을 원클릭으로 연결해 **70% 자동화**를 달성한다.

### 확정 사항 (사용자 결정)
1. **진입점**: 기존 `ContentView` 완전 대체 → `WorkspaceView` 단일 메인 창
2. **에디터 분할**: 드래그 가변(1:1~3:1) + 포커스 모드(에디터/미리보기 단독 토글)
3. **프롬프트 템플릿**: `Resources/PromptTemplates.json` 외부화 + 설정에서 내보내기/가져오기
4. **자동 수집**: RSS만 유지(안정적), 웹 검색 확장은 **T-96 별도 이슈**로 분리
5. **테스트**: 신규 코드 **TDD 필수** (`test-driven-development` 스킬 적용)

## 작업 분해

- [x] 문서: TODO T-84~95 등록, PLAN_v2.15 작성
- [ ] T-84: WritingPipeline 엔진 — 5단계 파이프라인 (`ResearchBundle → PostPlan → DraftPackage → PublishPackage`)
- [ ] T-85: PromptLibrary 시스템 — 템플릿 CRUD + 내장 5종 + JSON 파일 저장/내보내기/가져오기
- [ ] T-86: ResearchBundle/CollectedItem 정규화 모델
- [ ] T-87: WorkspaceView — NavigationSplitView 3열 (사이드바/에디터/인스펙터) + ContentView 대체
- [ ] T-88: EditorView 모듈 분리 (5파일: Core/Toolbar/Sheets/Autosave/SEO)
- [ ] T-89: 인스펙터 패널 4종 (Research/Assistant/ImagePrompt/SEO) + PublishChecklist
- [ ] T-90: ActionBar — 6단계 원클릭 액션 바 (리서치→기획→초안→이미지→발행준비→발행)
- [ ] T-91: 이미지 프롬프트 라이브러리 연동 (T-83 + 템플릿 선택/편집/히스토리)
- [ ] T-92: 발행 전 체크리스트 (SEO/슬러그/카테고리/태그/썸네일/alt/앱카드 자동 검증)
- [ ] T-93: 웹 렌더링 파이프라인 동기화 검증 (`[img:URL alt=]`, `[app:URL]`, `[gallery]`, `[center]`)
- [ ] T-94: E2E 시나리오 확장 (워크스페이스 전체 플로우 Playwright 테스트)
- [ ] T-95: 문서/커밋 정리 + 빌드 검증

## 상세 설계

### T-84: WritingPipeline 엔진 (`Core/WritingPipeline.swift`)

```swift
enum WritingPipeline {
    // 1단계: 수집 → 정규화
    static func collectAndNormalize(topic: String, sources: [NewsSource]) async throws -> ResearchBundle
    
    // 2단계: 기획 → 구조화 (시리즈/단일 분기)
    static func planStructure(bundle: ResearchBundle, mode: PlanMode) async throws -> PostPlan
    
    // 3단계: 초안 생성 (섹션별 + 이미지 프롬프트 + 앱 카드)
    static func generateDraft(plan: PostPlan) async throws -> DraftPackage
    
    // 4단계: 에디터 주입 (자동 저장 + 미리보기 동기화)
    static func injectToEditor(draft: DraftPackage) async throws
    
    // 5단계: 발행 준비 (SEO + 메타 + 썸네일 검증)
    static func preparePublish(postId: String) async throws -> PublishPackage
}

enum PlanMode { case single, series(estimatedCount: Int) }

struct ResearchBundle {
    let topic: String
    let sources: [CollectedItem]
    let keywords: [String]
    let relatedApps: [AppCandidate]
}

struct CollectedItem {
    let sourceName: String
    let sourceURL: String
    let title: String
    let summary: String          // AI 요약 (한국어)
    let evaluation: String       // 신뢰도/중요도 평가
    let keywords: [String]
    let publishedAt: Date
}

struct PostPlan {
    let mode: PlanMode
    let title: String
    let slug: String
    let categoryIds: [String]
    let tags: [String]
    let sections: [SectionPlan]
    let coverPrompt: ImagePromptItem
    let appCards: [AppCardCandidate]
}

struct SectionPlan {
    let heading: String
    let keyPoints: [String]
    let imagePromptHint: String?  // 본문 이미지 프롬프트 힌트
}

struct DraftPackage {
    let title: String
    let bodyMarkdown: String
    let imagePrompts: [ImagePromptItem]
    let appCards: [PostAppInput]
    let seoMeta: SEOSuggestion
}

struct PublishPackage {
    let postId: String
    let seoMeta: SEOSuggestion
    let thumbnailValidated: Bool
    let imageAltsValidated: Bool
    let appCardsValidated: Bool
}
```

### T-85: PromptLibrary 시스템 (`Core/PromptLibrary.swift`)

```swift
struct PromptTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    let category: TemplateCategory
    let systemPrompt: String
    let userPromptTemplate: String      // {topic}, {sections}, {tone}, {length}
    let imagePromptTemplates: [ImagePromptTemplate]
    var isBuiltIn: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum TemplateCategory: String, Codable, CaseIterable {
    case appIntro = "앱 소개형"
    case comparison = "비교 리뷰형"
    case tutorial = "튜토리얼형"
    case newsSummary = "뉴스 요약형"
    case custom = "사용자 정의"
}

struct ImagePromptTemplate {
    let position: ImagePosition
    let aspectRatio: String
    let promptTemplate: String
}

enum ImagePosition: String, Codable { case cover, body(Int) }

// 저장: UserDefaults "promptTemplates" + Resources/PromptTemplates.json (번들 내장)
// 설정 UI: 템플릿 리스트(추가/편집/삭제/복제) + 내보내기(.json)/가져오기(.json)
```

**내장 템플릿 5종** (PromptTemplates.json):
1. **앱 소개형** — "이 앱이 하는 일/핵심 기능/차별점/추천 대상" 섹션 구조
2. **비교 리뷰형** — "비교 대상/공통 기능/차이점/장단점/결론" 섹션 구조
3. **튜토리얼형** — "전제 조건/단계별 절차/팁/문제 해결" 섹션 구조
4. **뉴스 요약형** — "배경/핵심 사실/영향/전망" 섹션 구조
5. **사용자 정의** — 빈 템플릿

### T-87: WorkspaceView (`Views/WorkspaceView.swift`)

```swift
// NavigationSplitView 3열 레이아웃
// 사이드바(170pt): 글 관리/시리즈/댓글/통계/광고/맥 소식/참고 자료
// 메인(가변): 에디터(가변 분할) + 액션바
// 인스펙터(280pt): 리서치 패널 / 도우미 패널 / 이미지 프롬프트 / SEO / 발행 체크리스트 (세그먼트 탭)
```

**사이드바 아이템 재정의**:
```swift
enum WorkspaceSidebarItem: String, CaseIterable, Identifiable {
    case posts = "글 관리"
    case series = "시리즈"
    case comments = "댓글"
    case stats = "통계"
    case ads = "광고"
    case macNews = "맥 소식"
    case references = "참고 자료"
    
    // assistant는 인스펙터 탭으로 이동 (별도 창 불필요)
}
```

### T-88: EditorView 모듈 분리

| 파일 | 책임 | 약 줄 수 |
|------|------|----------|
| `EditorCoreView.swift` | 본문 에디터(분할 뷰, 포커스 모드, 텍스트 뷰) | ~500 |
| `EditorToolbar.swift` | 상단 툴바(포맷/삽입/액션바) | ~300 |
| `EditorSheets.swift` | 이미지/앱/유튜브/비디오/도움말 시트 | ~400 |
| `EditorAutosave.swift` | 자동저장(2초 디바운스)/드래프트/오프라인 큐 | ~200 |
| `EditorSEO.swift` | SEO 패널(메타 프리뷰/편집/적용) | ~200 |

### T-89: 인스펙터 패널 (`Views/Inspector/`)

| 패널 | 내용 | 연계 |
|------|------|------|
| `ResearchPanel.swift` | 수집 결과 리스트(원문/요약/평가/키워드/출처) + 선택 시 본문 인용 | T-84 1단계 출력 |
| `AssistantPanel.swift` | AI 도우미 결과(참고 자료) + 편집/복사/에디터 적용 | T-71/T-72 연계 |
| `ImagePromptPanel.swift` | 프롬프트 세트 표시(커버+본문) + 템플릿 선택/편집/복사/생성 | T-83 + T-85 |
| `SEOPanel.swift` | 메타 프리뷰(제목/설명/키워드/OG) + 편집/자동생성/적용 | T-08/T-75 연계 |
| `PublishChecklist.swift` | 발행 전 자동 검증 리스트(통과/실패/자동수정 버튼) | T-92 |

### T-90: ActionBar (`Views/Editor/ActionBar.swift`)

```swift
// 에디터 하단 고정 바 — 6단계 진행 표시 + 액션 버튼
enum PipelineStep: Int, CaseIterable {
    case research = 0      // 🔍 리서치: 주제→수집/요약/앱후보
    case plan = 1          // 📝 기획: 구조/섹션/이미지프롬프트 제안(수정가능)
    case draft = 2         // ✍️ 초안: 본문+이미지프롬프트+앱카드 생성
    case images = 3        // 🖼 이미지: 프롬프트 세트→복사/생성/수동선택
    case prepare = 4       // ✅ 발행준비: SEO/슬러그/카테고리/태그/썸네일 검증
    case publish = 5       // 🚀 발행: 로컬초안→서버동기화→웹반영
    
    var icon: String { ["magnifyingglass", "list.bullet.clipboard", "pencil.and.outline", "photo.badge.sparkles", "checkmark.seal", "paperplane"][rawValue] }
    var label: String { ["리서치", "기획", "초안", "이미지", "발행준비", "발행"][rawValue] }
}

// 상태: .pending / .inProgress / .completed / .failed
// 각 단계 완료 시 다음 단계 활성화, 언제든 이전 단계로 돌아가 수정 가능
```

### T-91: 이미지 프롬프트 라이브러리 (`Views/Inspector/ImagePromptLibrary.swift`)

- T-83 생성 결과 + 템플릿 라이브러리 통합 표시
- 항목별: 라벨/비율/프롬프트 + [복사] [편집] [생성] [히스토리]
- 템플릿에서 새 프롬프트 생성 시 변수 치환(`{appName}`, `{feature}`, `{style}`)

### T-92: 발행 전 체크리스트 (`Views/Inspector/PublishChecklist.swift`)

| 검증 항목 | 자동 검사 | 실패 시 액션 |
|----------|----------|-------------|
| SEO 제목/설명/키워드 | 길이/키워드 포함 여부 | [자동 생성] 버튼 |
| 슬러그 중복/형식 | 고유성/영문+하이픈 | [자동 생성] |
| 카테고리/태그 | 필수 1개 이상 | [추천] 버튼 |
| 썸네일(커버) | 존재/16:9/용량 | [이미지 생성] 버튼 |
| 본문 이미지 alt | 전체 이미지 alt 존재 | [전체 alt 생성] 버튼 |
| 앱 카드 | storeInfo/다운로드링크 | [보완] 버튼 |
| 본문 길이/구조 | 최소 500자/제목 2개 이상 | [가이드] 표시 |

---

## 에러코드

- 신규: E-MAC-PIPE-1001(파이프라인 실패), E-MAC-PROMPT-1001(템플릿 오류), E-MAC-WS-1001(워크스페이스 상태)
- 재사용: E-MAC-AI-1001/1003/1007, E-MAC-NET-1001, E-MAC-SET-1001

## 롤백

- 커밋 단위 revert. WorkspaceView는 ContentView와 병행 테스트 후 전환 가능.

## 테스트 계획 (TC) — TDD 적용

| 번호 | 내용 | 플랫폼 |
|------|------|--------|
| TC-84-1 | WritingPipeline 5단계 순차 실행 → DraftPackage 생성 검증 | macos |
| TC-85-1 | 템플릿 CRUD + JSON 내보내기/가져오기 라운드트립 | macos |
| TC-87-1 | WorkspaceView 3열 레이아웃 렌더링 + 사이드바 전환 | macos |
| TC-88-1 | EditorCoreView 분할 드래그 + 포커스 모드 토글 | macos |
| TC-89-1 | 인스펙터 4패널 탭 전환 + 데이터 연계 | macos |
| TC-90-1 | ActionBar 6단계 순차 진행 + 이전 단계 복귀 | macos |
| TC-91-1 | 이미지 프롬프트 라이브러리 템플릿 적용 → 프롬프트 생성 | macos |
| TC-92-1 | PublishChecklist 전체 통과 시 발행 버튼 활성화 | macos |
| TC-93-1 | macOS↔웹 마크다운 렌더링 100% 일치 (a11y 덤프 비교) | common |
| TC-94-1 | Playwright: 워크스페이스 → 리서치 → 기획 → 초안 → 발행 전체 플로우 | web |

---

## UI/UX 디자인 표준 준수 (AGENTS.md 13장)

- **macOS (13.1)**: `macos-app-design` / `ios-the-final-5-percent` / `apple-design` 스킬 경유
  - 분할 뷰 드래그 핸들 네이티브 스타일, 포커스 모드 전환 애니메이션(.smooth), 툴바/사이드바 재질(.bar/.regularMaterial), 호버 상태(dsSurfaceHover), SF Symbols 전용
- **웹 (13.2)**: `frontend-design` → `apple-design` → `emil-design-eng` → `web-design-guidelines` 파이프라인
  - 글 상세: 목차 스크롤 스파이, 이미지 라이트박스, 다크모드 전환, 리덕드 모션 대응