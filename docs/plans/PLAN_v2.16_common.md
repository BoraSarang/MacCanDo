# PLAN v2.16 — T-96 웹 검색 소스 확대 (WritingPipeline 1단계 실구현)

## 개요
WritingPipeline 1단계(`collectAndNormalize`)의 `collectFromSource`가 스텁(`return ([], [])`) 상태.
T-96에서 RSS 수집 실구현 + DuckDuckGo 웹 검색 소스를 추가해 리서치 자동화를 완성한다.

## 결정 사항
- 검색 엔진: **DuckDuckGo HTML** (`https://html.duckduckgo.com/html/?q=`) — API 키 불필요, 무료
- RSS: 기존 `NewsCollector.fetchRaw` 재사용 (XMLParser 검증됨)
- 관련성 필터: 제목/스니펫에 토픽 키워드 매칭 (대소문자 무시)
- AI 요약: 수집 후 상위 N개만 `.wizard` 체인으로 요약 (비용 절감)

## 아키텍처
```
collectAndNormalize(topic)
├── RSS 소스들 (MacNewsStore.loadSources) → NewsCollector.fetchRaw → RawNewsItem
├── [신규] WebSearchService.search(topic) → SearchResult (DDG HTML 파싱)
├── 관련성 필터 (토픽 키워드 매칭)
├── 상위 8개 AI 요약 → summary/keywords/rating
└── ResearchBundle (CollectedItem + AppCandidate + keywords)
```

### 신규 파일
- `Core/WebSearchService.swift`: DDG 검색 + HTML 정규식 파싱 + SearchResult 모델

### 수정 파일
- `Core/WritingPipeline.swift`: collectFromSource 실구현 + 웹검색 통합 + AI 요약

## 구현 단계
- T-96a: WebSearchService (DDG 검색, E-MAC-NET-1002 에러코드)
- T-96b: WritingPipeline.collectFromSource 실구현 (RSS→CollectedItem 변환)
- T-96c: 웹검색 통합 + 관련성 필터 + AI 요약 연결
- T-96d: 빌드 검증 + 문서

## 테스트 계획
- xcodebuild BUILD SUCCEEDED
- 실측: 앱 실행 → ActionBar 1단계 실행 → 수집 로그 확인 ([PERF] 포함)

## 롤백 계획
- git revert 단일 커밋 / WebSearchService 파일 삭제로 완전 분리 가능

## 에러코드
- E-MAC-NET-1002: 웹 검색 실패 (DDG 응답 비정상/차단)

## 성능 예산
- 1단계 전체 ≤ 15초 (RSS 병렬 + DDG 1회 + AI 요약 8건)
