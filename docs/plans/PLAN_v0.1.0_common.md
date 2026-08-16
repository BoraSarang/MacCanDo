# PLAN v0.1.0 — 공통 초기 구현 (common)

> 생성: 2026-08-16 · 플랫폼: common (web + macos)
> 관련 이슈: MacCanDo-7k6 (T-01), MacCanDo-bkn (T-02)

## 1. 개요

표준 인프라(T-00) 완료 후, 첫 구현 단계:
- T-01: DebugPanel + DebugLogger + API 로깅 골격 (공통)
- T-02: Neon 스키마 + Prisma 마이그레이션 (web)

## 2. 결정 사항

1. **Prisma 7 + driver adapter**: `@prisma/adapter-pg` 필수 (datasource url은 prisma.config.ts로 이동)
2. **Prisma 7 로깅**: `$on("query")` 이벤트 제거됨 → client extension(`$extends`)으로 쿼리 로깅
3. **error_message_ko.json**: 루트가 단일 진실, web 빌드 시 `prebuild/predev/prestart`에서 `web/lib/`로 복사 (Turbopack이 프로젝트 루트 밖 import 차단)
4. **API 규격**: `{ ok, data?, error?: { code, message } }` — withApi 래퍼로 try-catch/로깅/에러코드 공통화
5. **macos 골격**: Xcode 프로젝트는 T-06에서 생성, 소스(DebugLogger/DebugPanel/APIClient)는 지금 작성
6. **Neon 채널 바인딩**: `channel_binding=require` — pg 클라이언트 경고 발생하나 동작 정상 (verify-full로 경고 억제는 후속)

## 3. 아키텍처

- web: `lib/logger.ts`(DebugLogger 규격) → `lib/db.ts`(Prisma 확장) → `lib/api.ts`(withApi 래퍼) → `app/api/*`
- macos: `Debug/DebugLogger.swift` → `Debug/DebugPanel.swift`(Cmd+Shift+D) → `API/APIClient.swift`

## 4. 구현 단계

| 단계 | 내용 | 상태 |
|------|------|------|
| 4.1 | web/ Next.js 16 생성 + Prisma 7 설치 | ✅ |
| 4.2 | Neon 연결 확인 + 스키마 + 마이그레이션(init) | ✅ |
| 4.3 | 시드 (카테고리 4 + 관리자) | ✅ |
| 4.4 | lib/logger.ts + lib/api.ts + lib/db.ts | ✅ |
| 4.5 | /api/health 검증 (API→/진입/PERF/API←/P95) | ✅ |
| 4.6 | macos DebugLogger/DebugPanel/APIClient 골격 | ✅ |
| 4.7 | next build + lint 통과 | ✅ |

## 5. 테스트 계획

| 번호 | 내용 | 결과 |
|------|------|------|
| TC-06 | /api/health 호출 시 API 로깅 5종 확인 | ✅ 2026-08-16 |
| TC-01~05 | web 기능 테스트 | T-03 이후 |

## 6. 검증 결과

- `next build` 성공 (/, /_not-found, /api/health)
- `npm run lint` 오류 0
- /api/health: `{ ok: true, data: { status: "ok", db: "connected", categoryCount: 4 } }`
- 로그: `API→ GET /api/health` / `[INFO] Health 진입` / `[PERF] Category.count (940ms)` / `API← 200 950ms` / `[PERF] P95 초과 위험`
- 콜드 스타트 940ms는 첫 요청/풀러 콜드 스타트 — Warm 시 정상화 예상 (후속 관찰)

## 7. 롤백 계획

- 마이그레이션 롤백: `npx prisma migrate resolve` + DROP 후 재적용
- web 로깅 제거: lib/ 3파일 git revert
- macos 골격 제거: macapp/ 소스 삭제 (T-06에서 재작성)

## 8. 후속 작업

- T-03 (MacCanDo-0b1): web 기반 — 목록/카테고리/상세/검색
- T-06 (MacCanDo-102): macos 앱 골격 (Xcode 프로젝트 + DebugPanel 통합)