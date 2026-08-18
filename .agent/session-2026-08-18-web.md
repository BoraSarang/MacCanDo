# 세션 로그 — 2026-08-18 web (v2.8 웹 리디자인)

1. **무엇을**: T-58 웹 리디자인 파이프라인 — frontend-design(브리프) → apple-design(모션/타이포) → emil-design-eng(디테일) → web-design-guidelines(감사). ⌘ 키캡 시그니처(Hero/Header), framer-motion spring(카드 hover/tap, FadeIn), 타이포 스케일(.type-*, balance, tnum), 이모지 39곳→SVG/텍스트, :focus-visible/reduced-motion/placeholder … 적용
2. **플랫폼**: web (Next.js 16.3.1, Tailwind v4, framer-motion v12 신규 의존성) — macos 영향 없음
3. **빌드/검증**: `npm run build` 성공(Compiled 918ms, 정적 27/27). dev 서버 검증: 키캡 그라데이션/타이포(-0.02em, 1.05, balance)/focus-visible/reduced-motion 규칙 존재, 카드 hover translateY(-3px)→복원, whileTap scale(0.985) 실측, 다크 모드 토큰(#151517/키캡 #2a2a2f→#1f1f23), 콘솔 에러 0, 상세 페이지 a11y 스냅샷(환영 배너/조회수 SVG/코드 복사/시리즈 📚 제거) 정상
3-2. **Lighthouse**: 최초 A11y 92/BP 96/SEO 100 → 수정 후 A11y 100/BP 96/SEO 100/Agentic 100. 수정: 중첩 `<a>`(PostCard 배지 Link→span — 하이드레이션 실패 근본 원인), WCAG AA 대비 토큰(라이트 primary #0062cc/muted #757580, 다크 #409cff/#8b8b95, btn-primary --ds-primary-btn 고정), 터치 타깃(badge min-h-6). 잔여 BP 1건 = 로컬 시리즈 커버 404(파일 누락, R2 미적용 인프라 — T-08 대기)
4. **남은 TODO**: T-09(macos 디자인 적용+E2E+배포 — 대기), T-08(R2 이미지 저장소 — Vercel 배포 시 uploads 휘발 이슈 해결 필요), 그 외 대기 항목 유지
5. **다음 에이전트 전달**: framer-motion 사용 시 "use client" 필요(PostCard/FeaturedPosts/SeriesBanner/Hero/Motion). 카테고리 이모지(💻🎨 등)는 DB 데이터라 aria-hidden 유지 정책. keycap 클래스가 시그니처(globals.css). 배포: `cd web && npx vercel deploy --prod` (SSO 보호 — 프로덕션 도메인 web-bo-ra-sa-rang.vercel.app). 감사 규칙은 ~/.opencode/skills/web-design-guidelines + Vercel web-interface-guidelines
6. **문서 업데이트**: docs/CHANGELOG.md(v2.8 추가), docs/TODO.md(T-58 ✅), docs/screenshots/web/v2.8_* (스크린샷 2 + a11y 덤프 1 + lighthouse 리포트)
7. **오프라인 큐**: 해당 없음 (web 정적/SSR, 큐 미사용)
8. **E2E/k6**: 해당 없음 (웹 E2E는 playwright 미구성 — Lighthouse + a11y 덤프 + 콘솔 0으로 대체)
9. **T-59 추가 (v2.9)**: bd MacCanDo-c80 닫음 — lib/stats.ts(bumpDailyStat/isSameUtcDay) 신규 + 훅 4곳(조회/다운로드/댓글/auth signIn). 복합 unique where는 postId null 불허 → findFirst+create/update. dev 검증 daily [{2026-08-18, views:2}]. PLAN_v2.9_web.md 작성
10. **T-60 추가 (v2.9.1)**: bd MacCanDo-hx2 PERF 검증 — /post/[slug] ƒ→● SSG (ISR 60s). 게이트(GateCheck)+조회수(PostViewCounter) 클라이언트 전환, API view/mine 2개 신규, incrementPostView 추출. TTFB 2957→55ms (-98%), FCP 112ms, CLS 0. TC-60 5건 통과 (SSG/TTFB/잠금문구/307차단/조회수46·daily 8). 트레이스 47MB 삭제 + perf.json 저장. PLAN_v2.9.1_web.md 작성. 커밋 2bef2fa push + Vercel 배포(web-jengnb752). bd hx2에 노트 기록 (E2E CI + macOS PERF/CACHE는 남음)
11. **T-61 추가 (v2.9.2)**: macOS DebugLogger [PERF] 레벨 신설 — Cold start 346ms (예산 1.5s), APIClient >1s [PERF] 로그. CACHE 점검: hit=false 16건 (저장 정상, hit 0 구조적). 커밋 66385e9
12. **T-62 추가 (v2.9.3)**: Playwright E2E — @playwright/test + channel chrome(시스템 크롬, 다운로드 0), 스모크 4건 4/4 (13.3s), GH Actions e2e.yml (main push, web/**). **GitHub 시크릿 DATABASE_URL 등록 전엔 CI 실패함** — 사용자 액션 필요. bd MacCanDo-hx2 close. 커밋 83921c8
13. **T-63 추가 (v2.10)**: 소스 리팩토링 (bd MacCanDo-27c close) — 커밋 3개 (20028d2/18ca4be/cb379ec)
    - P1 안전성: E-WEB-POST-1001~1003 json 추가(코드 문자열 그대로 노출되던 버그), SeriesManager/AdsManager reload catch, macOS EditorView URL 강제언래핑 크래시 2건
    - P2 데드코드: getPendingComments/extractAppId/seed_pages.ts, dumpLogs/SEOSuggestion.json/WindowSize.main/generatedCoverProvider/rethrow + 토큰 4종
    - P3 web: getPostMetaBySlug(중복 쿼리 2회→1회), uploads 4핸들러 withApi, debug/logs apiOk, BodyFormat/PostContentType Prisma enum, SyncPost export
    - P4 macOS: SQLiteStore.swift 베이스(3중복), GeminiService withRetry/extractJSON/sha256, WebHelpers.swift(stripHTML+UA 2중복)
    - P5: ErrorMessages.swift + error_message_ko.json 번들 리소스(pbxproj 등록) + E-MAC 키 13개, 하드코딩 13곳 교체, 색상 토큰화 34곳(사용자 전부 승인) + onChange 경고 4건
    - 검증: web tsc 0에러+build+E2E 4/4(11.6s), macos BUILD SUCCEEDED 경고 0, 앱 스모크(글 22/시리즈 5), 스크린샷 docs/screenshots/macos/v2.10_p5.png (텍스트 전용 모델 — 코드 검증 대체)
    - 남은 이슈: cyf(로고 디자인), 0q1(운영 배포), T-08 R2(보류), GitHub 시크릿 DATABASE_URL 등록(CI 전)
