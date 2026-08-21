# 세션 로그 — 2026-08-21 (web/macos/common)

## 8줄 요약

1. **무엇을**: T-95 완료 + JSON-LD(BlogPosting) 구현 + CHANGELOG 복구 + T-96 웹 검색 소스 확대 (WritingPipeline 1단계 실구현)
2. **플랫폼**: web (JSON-LD) + macos (T-96) + common (문서)
3. **빌드 결과**: web `next build` 통과, E2E workspace-flow 7/7 passed / macos `xcodebuild BUILD SUCCEEDED`, 배포 pid 45500
4. **남은 TODO**: 0q1 운영 배포 ❄ defer 유지. 파이프라인 2~5단계(planStructure/generateDraft/preparePublish)는 AI 의존 실측 미검증 상태
5. **전달 로그**: JsonLd props는 `NonNullable<Awaited<ReturnType<typeof getPostBySlug>>>` 필수(null 포함 시 TS7022/TS18047). DDG는 반복 요청 시 봇 탐지(anomaly-modal) 차단 — WebSearchService가 E-MAC-NET-1002 발생 후 RSS 폴백으로 파이프라인 중단 없음. Mojeek 폴백은 빈 응답으로 기각.
6. **문서 업데이트**: PLAN_v2.16_common.md 신규, TODO.md(T-95/T-96 ✅), CHANGELOG.md(v2.16 신설 + v2.13~v2.9 복구 완료 506줄), error_message_ko.json(E-MAC-NET-1002)
7. **오프라인 큐**: 해당 없음
8. **E2E 결과**: workspace-flow.spec.ts 7 passed / 0 skipped — JSON-LD 테스트는 BlogPosting 타입+headline+datePublished 검증으로 강화

## 상세

### T-95: JSON-LD (`web/app/post/[slug]/page.tsx`)
- `JsonLd` 컴포넌트: schema.org BlogPosting (headline/datePublished/author/publisher/keywords/articleSection 등)
- siteUrl: `NEXT_PUBLIC_SITE_URL` 폴백 localhost:3000

### T-96: 웹 검색 소스 확대 (macos)
- `Core/WebSearchService.swift` 신규: DDG HTML 검색 + 정규식 파싱 + anomaly 감지
- `WritingPipeline.collectFromSource` 스텁 제거 → NewsCollector.fetchRaw 재사용 + 관련성 필터
- AI 일괄 요약: 상위 8건 `.wizard` 체인 1회 호출 (SummaryEntry JSON 배열)
- pubDate RFC822/ISO8601 파서

### 검증 이슈
- DDG 첫 요청 성공(result__a 직접 URL 확인), 이후 반복 요청 차단 — 일시적 IP 플래그로 추정, 앱 사용 중 간헐적 성공 예상
- 스니펫 셀렉터는 a/div 양쪽 지원하도록 방어 구현

## 다음 에이전트 참고
- Views/Editor/*.swift, Views/Inspector/*.swift, WorkspaceView.swift는 빌드 미포함 데드코드 — EditorView.swift 인라인 버전이 실제 구현. xcodegen 재생성 시 충돌 주의
- MacCanDoApp WindowGroup은 여전히 ContentView() — WorkspaceView 연결 여부는 사용자 결정 대기
- 파이프라인 1단계 실측은 앱에서 ActionBar 리서치 실행 필요 (DDG 차단 해제 후)
