# MacCanDo — 기술 설계 (DESIGN)

> 버전: v0.1.0-draft (2026-08-16) · 플랫폼: web + macos

---

## 1. 아키텍처 개요

```
┌─────────────────────────────────────────────────┐
│ web/ — Next.js 풀스택 (공개 블로그 + API Routes)   │
│  ├─ 프론트: 목록/상세/카테고리/검색/댓글            │
│  └─ API Routes: 게시글 CRUD, 댓글, 로그인,        │
│     다운로드 게이트, 통계, 업로드                   │
├─────────────────────────────────────────────────┤
│ macapp/ — SwiftUI 관리자 앱 (관리자 전용)          │
│  ├─ 로컬 SQLite: 자동저장 + 오프라인 작성 큐        │
│  ├─ MD/HTML 에디터 + 실시간 미리보기               │
│  ├─ 스토어 정보 자동 조회                          │
│  ├─ 배포 동기화 / 백업·복구                        │
│  └─ AI SEO (Gemini Free)                        │
├─────────────────────────────────────────────────┤
│ Neon (외부 Postgres) — 데이터 단일 진실            │
└─────────────────────────────────────────────────┘
```

## 2. [web] 기술 스택

| 항목 | 선택 | 비고 |
|------|------|------|
| 프레임워크 | Next.js (App Router) | Vercel 무료 호스팅 |
| 언어 | TypeScript | |
| 인증 | NextAuth (Google OAuth) | 무료 |
| DB | Neon Postgres | 외부 DB, Vercel 파트너 |
| ORM | Prisma | 마이그레이션 포함 |
| 검색 | pg_trgm 전문검색 | DB 내장, 무료 |
| 파일 | 개발: 로컬 → 배포: Cloudflare R2 | 무료 egress |
| 댓글 스팸 방지 | honeypot + rate limit + 관리자 승인 | |
| 통계 | 자체 집계 테이블 | 관리자 전용 |
| AI | Gemini API Free Tier | SEO 메타/태그/요약 |

### 2.1 데이터 모델 (Neon)
- `users` — Google OAuth (email, name, role[admin/user])
- `categories` — 계층형 (parent_id, slug, name, sort)
- `posts` — id, category_id, title, slug, body_format[md|html], body, excerpt,
  thumbnail_url, status[draft|published], store_info(JSON: app_id/url/name),
  seo_meta(JSON: title/desc/tags), view_count, published_at, created_at, updated_at
- `comments` — id, post_id, user_id, parent_id, content, status[pending|approved|spam],
  created_at
- `download_links` — id, post_id, label, url, type[torrent|free|official],
  click_count, sort
- `stats` — daily: date, post_id, views, clicks, comments, users
- `backups` — id, type[online->local|local->online], status, file_key, created_at

### 2.2 API 엔드포인트 (API Routes)
| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | /api/posts | 목록 (카테고리/검색/페이지네이션) |
| GET | /api/posts/[slug] | 상세 |
| GET/POST | /api/posts/[slug]/comments | 댓글 목록/작성 |
| GET | /api/categories | 카테고리 트리 |
| GET | /api/posts/[slug]/downloads | 다운로드 링크 (게이트 통과 시) |
| POST | /api/auth/* | NextAuth Google OAuth |
| GET | /api/stats | 통계 (관리자 전용) |
| POST | /api/admin/posts | 게시글 등록/수정 (맥 앱 연동) |
| POST | /api/admin/upload | 이미지/파일 업로드 |
| POST | /api/admin/sync/bulk | 맥 앱 오프라인 큐 일괄 동기화 |

### 2.3 다운로드 게이트 로직
1. 비로그인 → 로그인 유도 (링크 숨김)
2. 로그인 + 해당 게시글 댓글 1개 이상 → 링크 표시
3. 관리자 → 항상 표시

## 3. [macos] 기술 스택

| 항목 | 선택 |
|------|------|
| 프레임워크 | SwiftUI + AppKit 혼용 (네이티브) |
| 로컬 저장 | SQLite (GRDB) |
| 에디터 | NSTextView + WebKit 미리보기 (MD: cmark-gfm 변환) |
| 네트워크 | URLSession (API 호출, 오프라인 큐) |
| AI | Gemini API (free tier) |
| 스토어 조회 | App Store Search API / iTunes Lookup API (무료) |

### 3.1 오프라인 동기화
1. 모든 변경은 로컬 SQLite에 먼저 기록 (자동 저장)
2. 변경 큐(offline-queue)에 작업 추가
3. 온라인 시 POST /api/admin/sync/bulk 로 일괄 동기화
4. 충돌: 서버 timestamp 우선 (Last-Write-Wins)

### 3.2 백업/복구
1. 백업: 온라인 DB → 로컬 SQLite (전체 덤프)
2. 복구: 로컬 백업 파일 → 테스트(검증) 통과 후 온라인 DB 반영
3. 바로 복구하지 않고 테스트 후 적용

### 3.3 윈도우 & 화면 상태 (v2.6.0)
| 항목 | 설계 |
|------|------|
| 툴바 | `.windowToolbarStyle(.unified)` — macOS 26에서 Liquid Glass 자동 대응 (semantic API만 사용) |
| 기본 크기 | `.defaultSize(1100×720)` + `.windowResizability(.contentMinSize)` |
| 화면 복원 | `@AppStorage("sidebar.selection")` — **SceneStorage 사용 금지** (macOS 종료 시 저장 미보장, 통계→글 관리 리셋 버그 경험) |
| 창 복원 | `NSWindow.setFrameAutosaveName` — `MacCanDo-Assistant`, `MacCanDo-Editor-{sanitizedKey}` |
| 메뉴 바 | File(새 글 ⌘N), View(DebugPanel ⌘⇧D), Help(웹사이트) — 기본 newItem 대체 |
| 단축키 | ⌘1~7 화면 전환, ⌘S 초안 저장, ⌘Return 발행, ⌘K 팔레트 |
| ⌘K 팔레트 | `CommandPaletteView` — 화면 6개 + 액션(새 글/도우미/DebugPanel) + 글 검색 → 에디터 열기, 640×460, 화살표/Return/Esc |

### 3.4 디자인 시스템 (v2.6.0)
- 색상: `Color.dsPrimary/dsAccent/dsSuccess/dsWarning/dsDanger/dsSurfaceHover` 토큰 전 화면 통일 — 시스템 색 직접 사용 금지
- 재질: 헤더 `.bar`, 팔레트 `.regularMaterial`
- 아이콘: 이모지 금지, SF Symbols 전용
- hover: 목록 행/카드 `dsSurfaceHover` + `.onHover`
- 컨텍스트 메뉴: 글(에디터/웹/삭제), 댓글(승인/스팸/복구), 시리즈(편집/삭제), 광고(지정/해제), 맥 소식(원문/글 작성), 사이드바(새 글/열기)

## 4. [공통] 디버그 패널 & 로깅 (19장)

### 4.1 DebugPanel
| 플랫폼 | 위치 | 여는 방법 |
|--------|------|-----------|
| macos | NSWindow(.floating) 640x360 | Cmd+Shift+D |
| web | DevTools overlay | Ctrl+Shift+D |

표시: 실시간 DebugLogger 로그 / API 호출 기록 / 오프라인 큐 상태 / SQLite 동기화 상태 / 성능·캐시 정보

### 4.2 DebugLogger 규격 (19.1장)
- 포맷: `[HH:mm:ss.SSS] [LEVEL] [FEATURE] 메시지`
- 레벨: INFO / WARN / ERROR / PERF / CACHE
- 모든 신규 기능 진입점에 `[INFO] [FEATURE] <기능명> 진입/완료` 로그 의무
- 실패 경로: `[ERROR] E-MAC-{CAT}-{NUM4}` + error_message_ko.json 매핑
- API 호출: `API→ GET /api/posts` / `API← 200 42ms` (8.6장 GBridge 표준)

## 5. 보안

- 시크릿: .env (gitignore) + env-expiry-check.sh 만료 체크
- NextAuth 세션 쿠키 (httpOnly)
- Rate Limit: 댓글/API 100 req/min
- CORS: 관리자 API는 맥 앱/관리자 세션만 허용
- XSS: 댓글 HTML 이스케이프, MD 렌더링 샌드박스