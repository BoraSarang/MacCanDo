# PLAN v1.1.0 — macOS 에디터 MD 전용 2칸 + 확장 마크다운 문법

> 문서 우선 원칙 — 코드 수정 전 작성 (2026-08-16)
> bd: MacCanDo-T10 (T-07 후속)

## 1. 개요

사용자 결정: MD/HTML 모드 전환 제거 → **MD로만 작성**, 미리보기는 실시간 2칸 레이아웃.
요구사항: 이미지/YouTube/동영상 삽입(원하는 위치), 유튜브 사이즈·자동재생·시작시간 제어, MD 사용법 안내, 폰트/색상(HTML 인라인 화이트리스트).

## 2. 결정 사항

1. **MD 전용**: bodyFormat 세그먼트 제거, 저장은 항상 MD. 기존 HTML 글은 열 때 HTML→MD 자동 변환.
2. **2칸 레이아웃**: 좌=NSTextView(MD), 우=WKWebView(HTML 미리보기, 500ms 디바운스 실시간). 토글로 우측 숨김 가능.
3. **확장 MD 문법 (MacCanDo 표준)** — macOS/웹 렌더러 동일 규격:
   - `[youtube:VIDEO_ID]` — 기본 560x315
   - `[youtube:VIDEO_ID width=800 height=450 autoplay=1 start=90]` — 옵션
   - `[img:URL width=600 caption=캡션]` — 옵션 이미지
   - `[video:URL width=640 autoplay=0]` — MP4
   - 표준 `![alt](url)` 이미지
   - HTML 인라인 화이트리스트: `<span style>`, `<font color size>` (폰트/색상 요구 대응)
4. **삽입 툴바**: 굵게/기울임/취소선/제목/링크/이미지/유튜브/동영상 — 커서 위치 삽입 (NSTextView.selectedRange)
5. **MD 사용법 시트**: 문법 표 + 유튜브 옵션 예시
6. **웹 렌더러**: `web/lib/markdown.ts` 신규(동일 스펙), `/post/[slug]`에서 ReactMarkdown 대체

## 3. 구현 단계

| T# | 작업 | 파일 |
|----|------|------|
| T-10a | macOS 렌더러 확장 (youtube/img/video/HTML 화이트리스트) | `macos/.../Core/MarkdownRenderer.swift` |
| T-10b | HTML→MD 변환기 (기존 글 열기용) | `macos/.../Core/HTMLToMarkdown.swift` |
| T-10c | 에디터 2칸 개편 + 툴바 + 삽입 다이얼로그 + 사용법 시트 | `macos/.../Views/EditorView.swift` |
| T-10d | 웹 렌더러 + 글 상세 교체 | `web/lib/markdown.ts`, `web/app/post/[slug]/page.tsx` |
| T-10e | 검증: 빌드 + 미리보기/삽입/자동저장 + 웹 렌더 일치 | — |

## 4. 테스트 계획

- TC-MD-01: 2칸 레이아웃 + MD 입력 → 실시간 HTML 미리보기
- TC-MD-02: `[youtube:ID start=90 autoplay=1]` → iframe URL 파라미터 확인
- TC-MD-03: 이미지/동영상 삽입 → 커서 위치 삽입 + 미리보기 반영
- TC-MD-04: 기존 HTML 글 열기 → MD 변환 후 편집 → MD로 저장
- TC-MD-05: 웹 게시물 렌더 = 미리보기 렌더 (동일 문법)
- TC-MD-06: 자동저장 유지 (3초 디바운스 → SQLite)

## 5. 롤백

- 렌더러/에디터 수정 파일 git revert (커밋 없는 미커밋 상태이므로 파일 복원 주의)
- 웹: /post/[slug] ReactMarkdown 복원
- drafts.sqlite 초안 폐기: `DELETE FROM drafts;`

## 6. 성능 예산

- 미리보기 디바운스 500ms, 렌더 ≤10ms (본문 100KB 기준)
- 에디터 입력 → 미리보기 갱신 60fps 유지