# E2E 시나리오 정의서 (T-09)

> 플랫폼: web · 도구: Playwright (`npm run test:e2e`)
> 기준: `E2E_BASE_URL` 기본 `http://localhost:3000` (dev 서버 필요)

## 시나리오 목록

| TC | 대상 | 시나리오 | 상태 |
|----|------|----------|------|
| TC-E2E-WEB-001 | 홈 | 카테고리(글 있는 것만 노출) + 최신 게시글 카드 | ✅ 통과 |
| TC-E2E-WEB-001b | 검색 | 검색어 입력 → `/search?q=` 결과 노출 | ✅ 통과 |
| TC-E2E-WEB-002 | 글 상세 | 제목/메타/본문/댓글 영역 + Google 로그인 안내 | ✅ 통과 |
| TC-E2E-WEB-002b | 시리즈 목록 | 현재 글 '보고 있는 글' 강조 + 다른 편 링크 이동 | ✅ 통과 |
| TC-E2E-WEB-003 | 시리즈 | 모아보기 1~N편 순서 (Homebrew→TetherLens→CleanMyMac X) | ✅ 통과 |
| TC-E2E-WEB-003b | 카테고리 | 유틸리티 글 목록 노출 | ✅ 통과 |
| TC-E2E-WEB-004 | 헬스 | `/api/health` 200 | ✅ 통과 |

## 실행

```bash
cd web
npm run test:e2e        # 전체 (chromium)
npm run test:e2e:ui     # UI 모드
```

## CI 게이트 (예정)

- `main` push 시 `npm run test:e2e` 실행, 1개라도 실패하면 실패 처리
- 스크린샷/트레이스는 실패 시에만 `test-results/`에 저장