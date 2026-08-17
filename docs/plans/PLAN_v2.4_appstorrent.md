# PLAN v2.4 — appstorrent 참고 UI 개선 (T-12 ~ T-14)

> 상태: 진행 중 (2026-08-17)
> 참고: https://appstorrent.ru (사이드바 접힘, 상세 갤러리, OS/게임 카테고리)

## 1. 개요

appstorrent.ru의 UI 패턴을 참고해 3가지 개선:
1. **사이드바 접힘**: 화면/창이 좁아지면 라벨 숨기고 아이콘만 표시 (웹 + macOS)
2. **세부 페이지 갤러리**: 제품 설명 = 스크린샷 갤러리 표현 (`[gallery]` 확장 문법)
3. **카테고리 확장**: 웹 확장 + 기타 + OS + 게임 (총 10개) + 메뉴에 OS/게임 추가

## 2. 결정 사항

- 사이드바 접힘: 웹(/apps 카테고리 필터) + macOS(NavigationSplitView) 둘 다
- 갤러리 문법: `[gallery]` 블록 안의 `![alt](url)` 라인 수집 → 그리드. 웹=라이트박스 클릭 확대, macOS=그리드 정적 렌더 (렌더러 동일 규격)
- 카테고리: develop/design/work/productivity/system/media/web-extension/etc/os/games — 각각 icon(이모지) 보유
- Tahoe 글을 system → os로 이동 (macOS 소개)
- 게임은 데모 글 없이 빈 카테고리로 시작
- Header 메뉴: 맥 앱 / OS / 게임 / 맥 팁 / 맥 소식 (+ 시리즈 별도)

## 3. 구현 단계

### T-12 사이드바 접힘
- [x] `Category.icon String?` 마이그레이션
- [ ] 웹: /apps 사이드바 아이콘 + 좁으면 아이콘 컬럼 (CSS breakpoint, title 툴팁)
- [ ] macOS: 사이드바 폭 감지 → compact 모드 (SF Symbol만)

### T-13 갤러리 블록
- [ ] 웹 lib/markdown.ts: `[gallery]` ~ `[/gallery]` 파서 + 그리드 HTML
- [ ] 웹: 라이트박스 클라이언트 컴포넌트 (클릭 → 다이얼로그 확대)
- [ ] macOS MarkdownRenderer.swift: 동일 규격 그리드
- [ ] 샘플: 데모 글에 갤러리 사용 (사용법 문서화는 에디터 도움말)

### T-14 카테고리 확장 + 메뉴
- [ ] 시드: web-extension(🧩)/etc(📦)/os(🍎)/games(🎮) 추가 + 기존 6개 icon 부여 + Tahoe → os
- [ ] Header: OS(/category/os), 게임(/category/games) 메뉴 추가

## 4. 검증

- E2E: 카테고리 필터 10개, 갤러리 렌더, 사이드바 아이콘 모드(뷰포트), OS/게임 메뉴
- macOS: xcodebuild + 창 축소 동작 확인
- 기존 E2E 21개 회귀 없음

## 5. 롤백

- 웹: git revert + 시드 재실행 (카테고리는 멱등 upsert)
- macOS: git revert
- DB: 마이그레이션 down (icon 컬럼 제거는 시드 데이터 유지 가능 — 상위호환)

## 6. 관련 파일

- web/prisma/schema.prisma, migrations/*_category_icon/
- web/scripts/seed-category-tag.ts
- web/lib/markdown.ts, web/components/ (GalleryLightbox, CategoryFilter)
- web/app/apps/page.tsx, web/components/Header.tsx
- macos/MacCanDo/Core/MarkdownRenderer.swift, macos/MacCanDo/Views/ContentView.swift
- web/e2e/series.spec.ts
