# PLAN v2.6.0 — macOS 디자인 개편

- **버전**: v2.6.0
- **플랫폼**: macos
- **날짜**: 2026-08-17
- **레퍼런스**: `~/.opencode/skills/macos-app-design/SKILL.md` (27섹션, 출력 형식 필수), `apple-design` (모션/재질 원리), `ios-the-final-5-percent` (타이포/색 계층)

## 개요

디자인 토큰(DesignTokens.swift)은 잘 구축됐으나 실제 적용이 부족 — macOS 규약(메뉴 바/단축키/sidebar 재질/hover/컨텍스트 메뉴/⌘K) 기준으로 개편.

## 결정 사항

1. **스킬 출력 형식**: 모든 코드 리뷰/변경은 `Before / After / What this changes` 테이블로 제시
2. **macOS 타겟**: 14.0 유지, macOS 26(Tahoe) Liquid Glass는 `#available(macOS 26.0)` 분기로 폴백 제공
3. **에디터 커스텀 헤더 → 표준 툴바 전환은 보류** (회귀 위험, 후속 버전)
4. **설정 창 별도 Settings scene 분리는 보류** (⌘, 는 ⌘K+메뉴로 부분 대응, 후속 버전)
5. **브랜드 퍼플(dsAccent)**: 강제하지 않고 시스템 accentColor 존중 — 브랜드 그라데이션(빈 상태)만 유지

## 아키텍처

### 현재 문제 (오디트 결과)

| 문제 | 위치 |
|------|------|
| 시스템 색 이탈 (.blue/.green/.orange/.pink/.teal) | StatsView.swift:32-37, CommentsView.swift:33,64-91, PostsView.swift:100,190 |
| 재질 0건 — 전부 불투명 | 사이드바/에디터 헤더/시트 전체 |
| hover 0건 (dsSurfaceHover 토큰 미사용) | 전 화면 |
| 컨텍스트 메뉴 0건 | 전 화면 |
| 단축키 2개뿐 (⌘⇧D, ⌘P) | MacCanDoApp.swift:52, EditorView.swift:449 |
| 메뉴 바 commands 1개뿐 | MacCanDoApp.swift:50-53 |
| minWidth 960 고정 + 복원 없음 + NSWindow 수동 생성 | MacCanDoApp.swift:42, WindowManager.swift |
| 이모지 사용 (📚👁⭐📢✅) | SeriesView, StatsView, PostsView, AdsView, CommentsView, MacNewsView |
| NavigationStack 이중 중첩 | PostsView:54, SeriesView:33, StatsView:13, CommentsView:14 |
| onTapGesture 행 클릭 | PostsView.swift:234 |

### 개편 구조

```
MacCanDoApp.swift        — .windowToolbarStyle(.unified) + defaultSize + commands (⌘N/⌘⇧N/⌘⌥S/⌘⇧D) + ⌘K 팔레트
ContentView.swift        — @SceneStorage 선택 복원, 사이드바 220pt, SF Symbols, 컨텍스트 메뉴
CommandPaletteView.swift — 신규: ⌘K 팔레트 (640×480, thick material, fuzzy 검색)
각 화면 뷰               — 토큰 통일 + hover + 컨텍스트 메뉴 + 이모지→SF Symbols
EditorView.swift         — ⌘S 저장, 헤더 재질, accentColor 정리
```

## 구현 단계

### Phase 1 — macOS 규약 복구

- **T-32** (완료 2026-08-17): 기존 글 초안 서버 우선 (로컬 초안이 서버 본문을 덮는 버그 수정)
- **T-33** 윈도우 아키텍처: `windowToolbarStyle(.unified)`, `defaultSize(1100×720)`, `.windowResizability(.contentMinSize)`, ContentView 선택 `@SceneStorage`, WindowManager NSWindow autosave
- **T-34** 메뉴 바 정비: File(새 글 ⌘N, 새 창 ⌘⇧N), View(사이드바 토글 ⌘⌥S, DebugPanel ⌘⇧D), Help(웹 도움말)
- **T-35** 사이드바: 폭 220pt(ideal), SF Symbols 전환(이모지 제거), 항목 컨텍스트 메뉴, 화면 전환 ⌘1~⌘7

### Phase 2 — 표면 (재질·색·타이포)

- **T-36** 색상 토큰 통일: StatsView/CommentsView/PostsView/AdsView 시스템 색 → ds 토큰
- **T-37** 재질: 에디터 헤더 `.bar`(or .regularMaterial), 시트/카드 `.regularMaterial` 폴백, DebugPanel은 유지
- **T-38** 타이포/아이콘: ds 타이포 계층 통일 + 이모지 전면 SF Symbols 교체 (조회수 eye, 📚 books.vertical 등)

### Phase 3 — 인터랙션

- **T-39** hover: 모든 클릭 요소 `.onHover` + dsSurfaceHover (목록 행, 카드, 캡슐, 아이콘 버튼)
- **T-40** 컨텍스트 메뉴: 글 목록(에디터 열기/웹에서 보기/삭제), 댓글(승인/스팸/삭제), 시리즈(편집/삭제), 사이드바
- **T-41** 단축키: ⌘N 새 글, ⌘S 저장(에디터), ⌘F 검색 포커스(.searchable 자동), ⌘Return 발행

### Phase 4 — 커맨드 팔레트

- **T-42** ⌘K 팔레트: 화면 전환 + 글 검색(제목/슬러그) + 액션(새 글/설정/DebugPanel), 640×480, 화살표/Return/Esc

## 테스트 계획

- **TC-33**: 앱 재시작 시 선택 화면 복원, 창 크기 유지
- **TC-34**: ⌘N 새 글 열림, ⌘⇧N 새 창, ⌘⌥S 사이드바 토글
- **TC-36**: 라이트/다크 전환 시 StatsView/CommentsView 색 정상
- **TC-39**: 마우스 호버 시 목록 행/버튼 배경 변화
- **TC-40**: 목록 우클릭 메뉴 동작 (에디터 열기/삭제 확인)
- **TC-42**: ⌘K → 글 검색 → Return으로 에디터 열기, Esc 닫기

## 롤백 계획

- git revert 커밋 (Phase 단위 커밋 유지)
- ⌘K 팔레트 문제 시 T-42만 revert (독립 파일)
- 재질 이슈 시 T-37만 revert

## 성능 예산

- 사이드바/팔레트 렌더 60fps 유지, 팔레트 열림 ≤ 100ms
- 메모리: 추가 뷰 1개 (CommandPaletteView) — 무시 가능

## 에러코드

- 신규 에러코드 없음 (기존 E-MAC-* 재사용)

## 권한/문서

- 권한 변경 없음
- docs/DESIGN.md macOS 섹션 업데이트 (T-33~T-42 후)
- docs/CHANGELOG.md v2.6.0 기록
