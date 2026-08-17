# PLAN v2.7.0 — macOS 앱 전면 리뉴얼 (분위기·구조·UX 통일)

> 작성: 2026-08-18 · 플랫폼: macos · 사용자 승인: "어 승인 한다. A부터 끝까지 진행"
> 목표: 모든 탭을 macOS 표준(HIG) 패턴으로 전면 리뉴얼 — "딱 맥앱" 느낌

## 1. 개요
- v2.6.0(디자인 개편)이 "토큰+단축키" 수준이었다면, v2.7.0은 **전 화면 구조·인터랙션 표준화**
- 조사 근거: explore 에이전트 전체 오디트 (에디터 헤더 4줄, HSplitView, 필터 부재, 마스킹 부재 등 41건)
- 사용자 확정 사항: 시리즈는 NavigationSplitView 2열 + 시트 / 맥 소식 사이드바 독립 탭(+⌘8) / AI 도우미는 조회 폼 유지 + 표준 정리 / 설정은 별도 Settings scene(⌘,)

## 2. 결정 사항
| 항목 | 결정 |
|------|------|
| 에디터 메타 | 우측 Inspector(⌘⌥I) — Pages/Xcode 패턴 (접이식 토글 아님) |
| 시리즈 | NavigationSplitView 2열(사이드바 170pt) + "글 추가" 시트. HSplitView/5편 고정/하단 버튼 바 제거 |
| 맥 소식 | 도우미 창에서 분리 → 사이드바 독립 탭(+⌘8), AuthStore 단일화 |
| AI 도우미 | 채팅 버블 아님 — 조회 폼(입력+결과) 유지 + 표준 정리 |
| 설정 | 별도 Settings scene(⌘,) — 좌측 아이콘 탭(일반/서버/AI/캐시), SecureField, 연결 테스트, 캐시 초기화 |
| 통계 | 기간 선택(7/14/30일) + 새로고침(⌘R) 툴바 |
| 공통 | ErrorState/EmptyState/상태 바(하단)/배지 컴포넌트 신규 — 전 화면 공용 |
| UX 규칙 | 클릭=선택, 더블클릭·Return=열기, 스페이스=빠른 보기, ⌥⌘S 사이드바 토글, 삭제·이동 표준 애니메이션, 전 화면 `.help` 툴팁, 새로고침 후 선택·스크롤 유지 |
| 색 의미 체계 | dsSuccess/dsWarning/dsDanger 전 화면 동일 의미 동일 색. 브랜드 그라디언트는 사이드바 선택·1차 액션·로딩에만 |
| 단축키 | ⌘1~8 화면 전환(설정 제외), ⌘N 새 글, ⌘S 저장, ⌘Return 발행, ⌘K 팔레트, ⌘, 설정, ⌘R 새로고침, ⌘F 검색, ⌥⌘S 사이드바, ⌘⌥I Inspector |

## 3. 구현 단계 (T-번호)
### Phase A — 기반 (T-44~T-47)
- T-44: 공통 컴포넌트 신규(Core/CommonUI.swift) — ErrorState(아이콘+메시지+재시도)/EmptyState/StatusBar(하단 상태 바)/배지. 토큰 실적용 점검(시스템 색·하드코딩 → ds 토큰, Spacing/Radius)
- T-45: Settings scene 분리 — MacCanDoApp에 Settings scene, 사이드바 "설정" 제거, ContentView에서 설정 항목 삭제
- T-46: ContentView — ⌘1~8 hidden Button 패턴(기존 View 바인딩 제거), ⌥⌘S columnVisibility 토글, 사이드바 배지(댓글 대기/초안 수), 맥 소식 탭 추가(+⌘8)
- T-47: WindowManager — 닫은 창 딕셔너리 제거(windowWillClose), 창 크기 상수화(메인 1100×720/에디터 1000×640/도우미 900×600)

### Phase B — 에디터 (T-48)
- T-48: 헤더 4줄→1줄(제목+저장상태 아이콘+저장/발행), 메타(카테고리 FlowLayout/태그/시리즈/slug/커버)→우측 Inspector(⌘⌥I), 제목 자동 포커스, 저장 상태 색·아이콘, 이미지 시트 유지(연속 삽입), 미리보기 스크롤 유지+다크모드, ⌘N/⌘K 저장 후 목록 갱신(.postSaved 표준화), "새 시리즈" 취소 시 선택 유지

### Phase C — 목록형 4화면 (T-49~T-52)
- T-49: 게시글 관리 — 행 96px 썸네일+서브타이틀 표준화, 툴바 메뉴 필터(전체/초안/발행)+새로고침, 상태 바(글 수·초안 수), 삭제 실패 피드백, 임시저장 즉시 갱신(.postSaved 시 loadDrafts 병행), 더블클릭/Return 열기, hover 시 액션 버튼만
- T-50: 시리즈 — NavigationSplitView 2열, 글 목록 전체 공간+드래그 정렬, "글 추가"(⌘+) 표준 시트(검색+체크박스), 툴바(새 시리즈/편집/삭제), 검색 교체 버그 수정
- T-51: 댓글 — segmented 필터 AppStorage 유지, 상태 변경 로컬 반영(스크롤 유지), 에러 피드백
- T-52: 광고 — NavigationStack+타이틀, List 섹션, 토글 로컬 반영, 재시도 버튼

### Phase D — 나머지 5화면 (T-53~T-56)
- T-53: 통계 — 기간(7/14/30)+새로고침 툴바, 차트 기간 연동, 카드 표준화
- T-54: 설정 상세 — SecureField(토큰/키), 연결 테스트(api/categories 호출), 캐시 초기화 버튼, 저장 후 필드 유지
- T-55: 맥 소식 — 사이드바 독립 탭, MacNewsView @EnvironmentObject auth(시드 에디터 AuthStore() 제거), List 표준화
- T-56: AI 도우미 표준 정리(.orange→dsWarning, ⌘C 충돌 제거, 미리보기 다크모드) + 팔레트(TTL 갱신, 검색 규칙 일치, 설정 화면 목록에서 제거)

### Phase E — 검증·배포 (T-57)
- T-57: 전체 빌드(BUILD SUCCEEDED) → 앱 재실행 로그 검증 → ~/Applications 배포(build_and_run.sh install macos) → CHANGELOG/TODO/DESIGN 문서 → 커밋

## 4. 테스트 계획 (TC)
- TC-2.7-01: ⌘1~8 전환 + ⌥⌘S 사이드바 토글 + ⌘, 설정 창
- TC-2.7-02: 에디터 — Inspector(⌘⌥I) 메타 이동, 저장 상태 아이콘, 자동 포커스, 이미지 연속 삽입, 저장 후 목록 갱신
- TC-2.7-03: 시리즈 — 2열 선택, 글 추가 시트, 드래그 정렬, 검색 시 시리즈 목록 유지
- TC-2.7-04: 게시글 — 필터(초안/발행), 더블클릭 열기, 삭제 실패 표시, 상태 바 수치
- TC-2.7-05: 댓글 — 필터 유지(탭 전환 후), 승인 후 스크롤 유지
- TC-2.7-06: 통계 — 기간 변경 시 차트 갱신, 새로고침
- TC-2.7-07: 설정 — SecureField 마스킹, 연결 테스트, 캐시 초기화
- TC-2.7-08: 맥 소식 — 사이드바 탭 진입, 글 작성 시드 에디터에 메인 토큰 전달
- TC-2.7-09: 도우미 — ⌘C 충돌 없음, 다크모드 미리보기
- TC-2.7-10: 팔레트 — 글 목록 신선도(재오픈 시 갱신), 검색 규칙 일치

## 5. 롤백 계획
- git revert + xcodebuild Debug 재빌드 + ~/Applications 재배포 (이전 빌드 10 보존: /tmp/MacCanDo-v10-backup.app)
- 설정 scene 제거 시 사이드바 설정 항목 복구
- 에디터 Inspector 제거 시 기존 메타 헤더 복원 (EditorView.git HEAD 참조)

## 6. 성능 예산
- Cold Start ≤1.5s (기존 유지), 메모리 ≤300MB — 에디터 Inspector는 토글 시에만 구성(메타 뷰 경량화)
- 팔레트 글 목록 TTL 60초 — 재오픈 시 60초 내 재로드 생략
- 사이드바 배지: 댓글 대기 수 60초 타이머 1회 + .postSaved/화면 진입 시 갱신 (무한 폴링 금지)

## 7. 에러 코드
- 신규 없음 — 기존 E-MAC-* 체계 사용 (저장/삭제/로드 실패 피드백은 ErrorState 경유)
