# PLAN v2.10 web+macos — 소스 리팩토링 (T-63)

작성: 2026-08-18 · 상태: 구현 전 · 규모: 대형 (전파 범위 큼 — Phase 분리, 각 Phase 빌드 검증)

## 개요
- web/macOS 조사 완료 (explore 2건) — 우선순위 정리 후 순차 적용

## 결정 사항 (Phase 순서)
- **P1 안전성**: ① web error_message_ko.json에 E-WEB-POST-1001~1003 추가 (사용자 노출 버그) ② admin SeriesManager/AdsManager reload try-catch ③ macOS EditorView:1960(URL 강제언래핑)·SettingsView:86 크래시 제거
- **P2 데드 코드**: web — getPendingComments, extractAppId, seed_pages.ts(import 0건 확인 후) / macOS — dumpLogs, SEOSuggestion, WindowSize.main, generatedCoverProvider set만, generateImage rethrow + 미사용 토큰(Spacing.xs/sm/xl, Radius.lg, Font.dsHeading)
- **P3 web 구조**: ① generateMetadata 경량 함수 getPostMetaBySlug 분리 ② uploads 라우트 withApi 적용 ③ BodyFormat/PostContentType Prisma enum 통일 ④ SyncPost export + bulk 재사용 ⑤ fire-and-forget void 통일
- **P4 macOS 구조**: ① SQLite 3중복 → 공용 베이스 ② GeminiService withRetry/extractJSON/sha256/stripHTML·UA 통일 ③ (시간 시) 이미지 업로드 플로우 통합
- **P5 토큰/메시지**: ① 색상 리터럴 → ds 토큰 (CommandPalette/Editor/Series/Posts/Assistant/DebugPanel) ② error_message_ko.json Swift 조회 함수 + 하드코딩 문자열 대체

## 구현 단계
- [ ] T-63 P1: 안전성 5건
- [ ] T-63 P2: 데드 코드 정리 (빌드/테스트로 회귀 확인)
- [ ] T-63 P3: web 구조 (빌드 + E2E 재실행)
- [ ] T-63 P4: macOS 구조 (xcodebuild + 앱 실행 스모크)
- [ ] T-63 P5: 토큰/메시지 연동 (다크모드 시각 검증)

## 테스트 계획
- TC-63-1: web build + playwright 스모크 4건 통과 (구조 변경 후)
- TC-63-2: macOS xcodebuild 성공 + 앱 실행 + [PERF] 로그
- TC-63-3: 에러코드 노출 확인 — E-WEB-POST-* 메시지 반환 확인 (apiError 응답)

## 롤백
- Phase별 커밋 분리 — 개별 revert 가능

## 에러코드
- error_message_ko.json: E-WEB-POST-1001/1002/1003 추가 (문구 정의 포함)