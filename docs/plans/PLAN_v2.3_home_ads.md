# PLAN v2.3 — 홈 개편(광고 슬롯) + 세부 페이지 확장 + 정렬

## 개요
- 홈: 시리즈 배너(광고 슬롯) → 추천 → 최근 게시글 → 역할별 탐색
- 관리자 "광고" 메뉴 신설: 시리즈 배너 지정 + 추천 글 지정 (macOS + 웹 admin)
- 세부 페이지: 관련 게시글(태그→카테고리 폴백) + 이전/다음글(일반 글만)
- /apps 정렬 드롭다운 (최신순/조회수순), 목록 페이지 통일

## 결정 사항
- 슬롯 미지정/부족 시 자동 채움: 배너=전체 시리즈 최신순, 추천=조회수 top
- 추천 순서는 featuredOrder 기준, NULL이 뒤
- 시리즈 글은 이전/다음글 제외 (하단 시리즈 목록이 역할)

## 아키텍처
- 스키마: Post.featuredOrder Int?, Series.featuredOrder Int?
- lib/posts.ts: getPosts(sort), getFeaturedPosts, getRelatedPosts, getPrevNextPosts
- 웹: app/page.tsx(SeriesBanner+FeaturedPosts), app/post/[slug], app/apps·tips·news·category·tag 정렬
- admin: components/admin/AdsManager.tsx (웹 탭), macos AdsView.swift (광고 탭)
- API: PATCH posts/[id]·series/[id] featuredOrder 허용

## 구현 단계
- T-11-1 스키마+마이그레이션 (Neon 수동)
- T-11-2 lib + API
- T-11-3 홈 컴포넌트 + 세부 페이지 + 정렬
- T-11-4 admin (웹 + macOS)
- T-11-5 E2E + 빌드 + 커밋

## 테스트
- TC: 홈 배너 4개 / 추천 3개 / 정렬 전환 / 관련 글 3개 / 이전·다음 표시
- E2E series.spec.ts 확장 + 기존 15개 유지

## 롤백
- featuredOrder 컬럼 드롭 (마이그레이션 down), 홈 섹션 제거, 컴포넌트 revert
