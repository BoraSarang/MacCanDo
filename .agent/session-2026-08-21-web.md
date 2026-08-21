# 세션 로그 — 2026-08-21 (web/common)

## 8줄 요약

1. **무엇을**: T-95 완료 처리 + JSON-LD 구조화 데이터(BlogPosting) 구현 + CHANGELOG.md 잘림 복구
2. **플랫폼**: web (JSON-LD) + common (문서 정리)
3. **빌드 결과**: `next build` 통과, Playwright E2E workspace-flow 7/7 passed (~19초). PERF/CACHE 해당 없음(웹 SEO 작업)
4. **남은 TODO**: T-96(웹 검색 소스 확대) 미착수, 0q1 운영 배포 ❄ defer 유지
5. **전달 로그**: 이전 세션의 TS 에러 원인은 JsonLd props 타입이 `Post | null` 포함 → `NonNullable<>` 래핑으로 해결. 불필요한 우회 코드(`p` 변수, map 콜백 어노테이션)는 전부 원복함. 에러코드 신규 없음.
6. **문서 업데이트**: TODO.md(T-95 ✅), CHANGELOG.md(v2.15 Web 섹션 갱신 + v2.13~v2.9 잘린 내용 433줄 복구 — 총 506줄/33버전)
7. **오프라인 큐**: 해당 없음
8. **E2E 결과**: workspace-flow.spec.ts 7 passed / 0 skipped — JSON-LD 테스트 skip 해제 후 BlogPosting 타입+headline+datePublished 검증 추가

## 상세

### JSON-LD 구현 (`web/app/post/[slug]/page.tsx`)
- `JsonLd` 컴포넌트: schema.org BlogPosting
- props 타입: `NonNullable<Awaited<ReturnType<typeof getPostBySlug>>>` — null 제거가 핵심
- 필드: headline/description/image/datePublished/dateModified/author/publisher(+logo)/mainEntityOfPage/keywords/articleSection/abstract
- siteUrl: `NEXT_PUBLIC_SITE_URL` 폴백 localhost:3000
- 배치: `<article>` 내 최상단 (`<script type="application/ld+json">`)

### E2E 강화 (`web/tests/e2e/workspace-flow.spec.ts`)
- 기존: `test.skip(true, "JSON-LD 미구현")`
- 변경: JSON.parse로 BlogPosting 타입 + headline + datePublished 검증

### CHANGELOG.md 복구
- 이전 세션에서 write()로 전면 덮어쓰며 v2.13 이하가 "..."로 잘림(75줄)
- `git show bbd4ea0~1:docs/CHANGELOG.md`(433줄)에서 복구 → v2.15 섹션 + 구버전 전체 = 506줄

## 다음 에이전트 참고
- T-96(웹 검색 소스 확대)은 PLAN_v2.15에서 분리 예약된 이슈 — 착수 시 bd 생성 권장
- macOS 앱: `/Users/lee/Applications/MacCanDo.app` 실행 중이었음 (pid 확인 필요)
- Views/Editor/*.swift, Views/Inspector/*.swift, WorkspaceView.swift는 빌드 미포함 데드코드 — EditorView.swift 인라인 버전이 실제 구현. 추후 xcodegen 재생성 시 충돌 주의
