# PLAN v2.5 — 앱 카드 (글당 여러 앱) — web + macos

> 작성: 2026-08-17 · 버전: v2.5.0-appcard
> 참고: appstorrent 앱 상세 페이지 (3012-codepoint.html) 스펙 카드 + 사용자 확정 사항

## 개요

한 글에 여러 앱을 넣을 수 있도록 **앱 카드** 기능 추가.
- iterm2-tmux-oh-my-zsh처럼 1글 3앱 구성 가능
- 앱 카드 = 아이콘 + 이름 + 스펙(버전/개발자/가격/언어/호환 macOS/업데이트일/별점) + **공개 다운로드 버튼** + 홈페이지 링크
- 다운로드 2종: **앱 카드(공개)** + 기존 숨겨진 다운로드(로그인+댓글 1개, 게이트 유지)
- App Store URL → Apple lookup API 자동 추출 (뽑을 수 있는 것만)

## 결정 사항

1. 다운로드 구분: `DownloadLink.postAppId` 유무 — 있으면 앱 카드 공개 버튼, 없으면 기존 게이트 섹션
2. 본문 마커: `[app]`~`[/app]` 블록 (1개당 앱 1개, sort 순서대로 치환) — [gallery]와 동일 패턴
3. 자동 추출: `POST /api/admin/store-fetch` (itunes.apple.com 고정 → SSRF 방지)
4. 앱 데이터: `PostApp.storeInfo` Json 스냅샷 (추출 시점 값 저장 — API 변경/삭제에도 카드 유지)
5. 기존 `Post.storeInfo` 있는 글 → PostApp으로 1회 이관
6. macOS 에디터: 툴바 "앱 카드" 시트 (URL → 추출 미리보기 → 등록, `[app]` 삽입, 미리보기 렌더)
7. 언어: ISO 639-1 → 한국어명 사전 (미등록 코드는 원문 표시)

## 아키텍처

### DB (마이그레이션 `20260817X_post_app`)
```prisma
model PostApp {
  id          String   @id @default(cuid())
  postId      String
  sort        Int      @default(0)
  appId       String?  // App Store 앱 ID
  appUrl      String?  // App Store URL
  homepageUrl String?  // 홈페이지 (수동)
  storeInfo   Json?    // 추출 스냅샷 { appName, version, sellerName, price, formattedPrice, languages[], minimumOsVersion, currentVersionReleaseDate, rating, ratingCount, artworkUrl100, fileSizeBytes, sellerUrl }
  createdAt   DateTime @default(now())
  post          Post           @relation(fields: [postId], references: [id], onDelete: Cascade)
  downloadLinks DownloadLink[]
  @@index([postId])
}
// DownloadLink.postAppId String? 추가 + relation
```

### API
- `POST /api/admin/store-fetch` — { url } → 앱 ID 파싱 → lookup → 메타 반환 (admin 세션 검증, Apple 호스트 고정, 타임아웃 8s)
- 글 저장 API (POST/PUT `/api/admin/posts`) — `apps[]` 포함: 전체 교체 (deleteMany+createMany, 트랜잭션), 각 앱에 downloadLinks[]
- 기존 `storeInfo` 필드는 스키마 유지 (하위 호환), 웹 글 상세는 `apps` 우선

### 마크다운
- 웹 `lib/markdown.ts`: `[app]`~`[/app]` 블록 → `[APP-SLOT:0]` 토큰 → render 후 apps로 치환
- macOS `MarkdownRenderer.swift`: 동일 파싱 → 슬롯 토큰 → EditorView가 apps로 치환 (render(md, apps))
- 실제 카드 HTML은 페이지/에디터가 생성 (스펙 행 + 공개 다운로드 + 링크)

### 웹 UI (글 상세)
- `components/AppCard.tsx` (서버 컴포넌트): storeInfo + downloadLinks 렌더
- 게이트 섹션(글 하단 📥)은 기존 유지 — apps와 무관 (postAppId 없는 링크만)
- AppCard는 gallery-grid 아님 → PostBody 라이트박스 클릭과 충돌 없음

### macOS 에디터
- 툴바 버튼 (systemImage: "shippingbox") → 시트: 앱 목록 (sort 순서, 삭제) + "추가" → 다이얼로그 (App Store URL + 홈페이지 URL) → "정보 불러오기" (서버 store-fetch) → 추출 결과 미리보기 → 등록
- "마커 삽입": 커서에 `[app]\n[/app]` 삽입
- 미리보기: buildPreviewHTML에서 apps 치환
- saveToServer: apps 배열 포함

## 구현 단계

| # | 작업 | 상태 |
|---|------|------|
| T-15-1 | PLAN 문서 + 스키마 + 마이그레이션 | ✅ 2026-08-17 |
| T-15-2 | store-fetch API + 언어 사전 | ✅ 2026-08-17 |
| T-15-3 | 글 저장 API apps 처리 + lib (getPostBySlug apps) | ✅ 2026-08-17 |
| T-15-4 | 웹: markdown [app] + AppCard + 글 상세 | ✅ 2026-08-17 (렌더러 내장 buildAppCardHTML — 컴포넌트 분리 대신 순수 HTML 생성) |
| T-15-5 | macOS: MarkdownRenderer + EditorView 시트 | ✅ 2026-08-17 |
| T-15-6 | 기존 storeInfo → PostApp 이관 (스크립트 1회) | ⏳ 운영 글 storeInfo 없음 확인 — 대상 없음 (커밋 불필요) |
| T-15-7 | E2E + TSC + macOS 빌드 + 커밋 | ✅ 2026-08-17 (E2E 30/30) |

## 테스트 계획

- TC-APP-001: store-fetch — 유효 URL → 9개 필드 추출 / 무효 URL → 400
- TC-APP-002: 글 상세 — [app] 마커 3개 → 카드 3장 (순서 일치) / 마커 > 앱 수 → 초과 무시
- TC-APP-003: 앱 카드 다운로드 — 비로그인에도 버튼 공개 (게이트 없음)
- TC-APP-004: 기존 게이트 — 로그인+댓글 1개 전엔 하단 📥 잠김 (기존 회귀)
- TC-APP-005: macOS 미리보기 — [app] 카드 렌더 (swiftc CLI)
- E2E: appcard.spec.ts (TC-APP-001~004)

## 롤백

- git revert + 마이그레이션 down (PostApp drop, postAppId 컬럼 제거)
- 기존 storeInfo → PostApp 이관 전 DB 백업 (이관은 트랜잭션 + 기존 필드 유지)

## 에러코드

- E-WEB-STORE-1001: "앱 스토어 정보를 불러오지 못했습니다. 앱 ID를 확인해 주세요." (추출 실패)
- E-WEB-STORE-1002: "지원하지 않는 URL입니다. 앱 스토어 URL 또는 앱 ID를 입력해 주세요."