# MacCanDo (맥캔두) — 제품 요구사항 정의서 (PRD)

> 버전: v0.1.0-draft (2026-08-16)
> 제작자: BoRaSaRang · 플랫폼: web (Next.js) + macos (SwiftUI)

---

## 1. 제품 개요

**MacCanDo** — "맥으로 이것도 할 수 있다"는 컨셉의 Mac 유틸리티 정보 블로그 시스템.

- Mac용 유용한 프로그램 소개 및 기능 설명
- 유용한 Mac 팁 제공
- Mac 관련 소식/정보 제공
- 카테고리별 정보 구성
- 로그인 사용자(Google) + 댓글 작성자에게 다운로드 링크 제공

## 2. 핵심 요구사항

### 2.1 공개 웹 (web)
1. 게시글 목록/상세/카테고리/검색 (Postgres 내장 검색 pg_trgm)
2. 게시글별 댓글 (대댓글, 스팸 방지: honeypot + rate limit + 관리자 승인 모드)
3. Google 로그인 (NextAuth)
4. 다운로드 게이트: 로그인 + 댓글 1개 작성 시 외부 링크 공개
5. 전체 통계: 웹/사이트/게시글/다운로드 통계 — 관리자 전용 /admin
6. SEO 최적화 (메타/OG/sitemap/구조화 데이터)
7. AI 지원: Gemini Free — SEO 메타/태그/요약 생성 (관리자 도구)

### 2.2 맥 관리 앱 (macos) — 관리자 전용
1. 게시글/카테고리 등록·삭제·관리
2. MD/HTML 두 가지 형식 작성 + 미리보기 지원
3. 자동 저장 + 오프라인 지원 (로컬 SQLite, 인터넷 연결 시 동기화)
4. 임시 저장 개념 → 배포 시 공개 (배포 플래그)
5. 스토어 정보 자동 조회: Store URL/ID 입력 시 앱 정보 박스 자동 표시
6. 이미지/파일 업로드
7. 백업/복구: 온라인 DB → 로컬 백업, 복구는 테스트 후 적용
8. AI SEO 지원 (Gemini Free)

### 2.3 데이터베이스
- 외부 DB 사용 (Neon Postgres) — 로컬 DB는 맥 앱 오프라인 저장소로만 사용

## 3. 비용 원칙

- 무료 우선: Vercel Hobby + Neon Free + Cloudflare R2 Free + Gemini Free + Google OAuth
- 부득이한 경우 가장 저렴한 방법 선택

## 4. 성능 예산 (7.5장)

| 지표 | web | macos |
|------|-----|-------|
| Cold Start | LCP ≤ 2.5s | ≤ 1.5s |
| 메모리 | JS ≤ 150MB | ≤ 300MB |
| 프레임 | 60fps | 60fps |

## 5. 디자인

- 컨셉: ⌘(Command) 키 + 체크마크 모티브 — "맥으로 이것도 할 수 있다"
- 색상: 시스템 블루(#007AFF) → 퍼플(#AF52DE) 그라디언트
- 웹 파비콘/로고 + 맥 유리질감 아이콘 (design 스킬로 생성)
- 스킬: design(로고/아이콘), ui-ux-pro-max(UI/팔레트/폰트), frontend-design(웹 UI), banner-design(OG/배너)