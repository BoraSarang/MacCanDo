# PLAN v1.0.0 — macOS 글 관리 에디터 (T-07)

> 플랫폼: macos + web (API) | 날짜: 2026-08-16 | 상태: 진행중

## 1. 개요

macOS 앱에서 블로그 게시글을 작성/수정/발행하는 MD/HTML 에디터 구현.
편집 중 로컬 SQLite에 자동저장(오프라인 대비), 저장/발행은 웹 API 경유.

## 2. 결정 사항

- 에디터: 네이티브 SwiftUI + NSTextView 래퍼 (코드 편집 경험)
- 미리보기: WKWebView + 경량 마크다운→HTML 변환기 (서버 의존 없음)
- 자동저장: 로컬 SQLite(초안) 3초 디바운스 + 수동 "저장" 시 서버 반영
- 배포 플래그: status DRAFT/PUBLISHED (발행 시 publishedAt 설정, 재발행 시 갱신)
- slug: 제목 기반 자동 생성 + 중복 시 -2, -3 접미사
- 인증: Settings의 API 토큰 (T-06, Bearer)

## 3. 구현 단계

| T | 작업 | 상태 |
|---|------|------|
| T-07a | web: lib/posts.ts (slug/저장/발행/삭제) + POST/PUT/DELETE/GET /api/admin/posts(/[id]) | |
| T-07b | web: error_message_ko.json 에러코드 (E-WEB-POST-*) | |
| T-07c | macos: PostModels (Post/Category/PostInput) + DraftStore (SQLite) | |
| T-07d | macos: MarkdownRenderer + EditorView (NSTextView + WKWebView + 자동저장) | |
| T-07e | macos: PostsView 개편 (목록 + 새 글 + 편집 네비게이션) | |
| T-07f | 빌드 + 실행 검증 + 세션 로그 | |

## 4. API 명세 (web)

- `POST /api/admin/posts` — body: { title, slug?, categoryId?, bodyFormat, body, excerpt?, status } → 201 { post }
- `GET /api/admin/posts/[id]` — DRAFT 포함 단건 → { post }
- `PUT /api/admin/posts/[id]` — body: 동일 + status (PUBLISHED 시 publishedAt=now) → { post }
- `DELETE /api/admin/posts/[id]` — 200 { ok }
- `GET /api/admin/posts?all=1` — 관리자용 전체 목록 (기존 통계 API와 공존)

에러코드: E-WEB-AUTH-1001(401), E-WEB-VALID-1001(검증), E-WEB-POST-1001(저장), E-WEB-POST-1002(삭제), E-WEB-POST-1003(미존재), E-WEB-POST-1004(slug 중복)

## 5. 테스트

- TC-MAC-01: 새 글 작성 → 자동저장 → 미리보기 → 저장 → 목록 반영
- TC-MAC-02: 발행 → 웹 공개 목록에 노출 확인
- TC-MAC-03: DRAFT 저장 → 웹 목록에 미노출
- TC-MAC-04: 앱 종료 후 재실행 → 초안 복구
- TC-MAC-05: 오프라인 → 자동저장만 → 온라인 후 서버 저장

## 6. 롤백

- web: 기존 라우트와 독립 (신규 추가만) → git revert로 제거
- macos: EditorView/DraftStore 파일 삭제 + PostsView 원복

## 7. 성능 예산

- 에디터 열기 ≤ 500ms, 자동저장 ≤ 100ms, 미리보기 렌더 ≤ 200ms