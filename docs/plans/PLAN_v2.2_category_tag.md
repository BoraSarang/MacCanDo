# PLAN v2.2 — 카테고리(역할) + 태그 도입

## 개요
- 기존 카테고리(유틸리티/생산성/맥 팁/맥 소식)를 **역할 기반 6개 카테고리 + 다대다**로 재구성
- **태그**(자유 생성, 다대다) 신규 도입
- **콘텐츠 타입**(ARTICLE/TIP/NEWS)으로 "맥 팁/맥 소식" 메뉴 분리
- 메뉴: `맥 앱(허브) | 맥 팁 | 맥 소식 | 시리즈`

## 결정 사항 (사용자 확정)
1. 카테고리 6개 (평탄, 이름 = 역할): Develop / Design / Work / Productivity / System / Media
2. 카테고리 다대다 허용 (한 글 여러 카테고리)
3. 태그 자유 생성 허용 (#재미 태그 OK)

## 스키마
- `PostCategory(postId, categoryId)` 조인 (기존 Post.categoryId 제거)
- `Tag(id, name, slug)` + `PostTag(postId, tagId)` 조인
- `Post.contentType` enum(ARTICLE/TIP/NEWS) — 맥 팁/맥 소식 메뉴용

## 구현 단계
- T-10-1: 스키마 + Neon 수동 마이그레이션
- T-10-2: 데이터 이전 (글 13편 → 카테고리 6개 매핑 + contentType + 태그 시드)
- T-10-3: lib/posts.ts 다대다 재작성 + admin API (categoryIds/tags/contentType)
- T-10-4: 웹 — /apps 허브 + 카테고리 필터, /tips, /news, /tag/[slug], 글 상세 태그, 메뉴 개편
- T-10-5: macOS — 에디터 카테고리 다중 선택/태그 입력/글 타입 + 목록 표시
- T-10-6: E2E + 검증 + 커밋

## 카테고리 세트
| slug | name | 설명 |
|------|------|------|
| develop | Develop | 코딩/터미널/AI 도구 |
| design | Design | 디자인/이미지/컬러 |
| work | Work | 문서/메모/할 일/미팅 |
| productivity | Productivity | 런처/클립보드/창 관리/단축키 |
| system | System | 정리/보안/모니터링 |
| media | Media | 오디오/비디오/스크린샷 |

## 롤백
- git revert + Neon: DROP TABLE PostCategory/Tag/PostTag, ALTER Post ADD categoryId 복원

## 에러코드
- E-WEB-VALID-1003: 태그 이름 형식 오류 (신규)