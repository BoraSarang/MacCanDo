# 배포 계획 v2.3 — 운영 출시 (MacCanDo-0q1)

> 상태: **계획만 수립 (실행 대기)** — 사용자가 "배포 하자"라고 하면 이 문서 순서로 진행.
> 최종 업데이트: 2026-08-17

## 1. 개요

현재 Vercel 배포 성공 상태 (`https://web-swart-ten-6dsx2wswjc.vercel.app`, DB 연결 확인).
운영 출시를 위해 4가지 작업이 필요하다. 코드 변경은 R2 이전에만 있고, 나머지는 콘솔/DNS 작업.

| # | 작업 | 유형 | 난이도 |
|---|------|------|--------|
| 1 | Vercel Deployment Protection 해제 | Vercel 콘솔 | 쉬움 |
| 2 | Google OAuth redirect 추가 | Google Cloud 콘솔 | 쉬움 |
| 3 | maccando.kr 도메인 연결 | DNS + Vercel | 중간 |
| 4 | public/uploads → Cloudflare R2 이전 | 코드 + 인프라 | 높음 |

## 2. 현재 상태 (2026-08-17 확인)

- [x] Vercel 배포 성공: `https://web-swart-ten-6dsx2wswjc.vercel.app`
- [x] DB(Neon) 연결 확인 — 단, `/api/health`가 배포본에서 404 (배포가 health 라우트 추가 전 커밋이거나 브랜치 상태 — **배포 시 최신 main 재배포 필요**)
- [x] 이미지 업로드는 로컬 디스크: `lib/image.ts` `UPLOAD_ROOT = public/uploads` — **서버리스에서 비휘발성 아님** (재배포 시 소실)
- [ ] 환경변수: `web/.env` 기준 — Vercel 콘솔에 `DATABASE_URL`, `JWT_SECRET`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `AUTH_SECRET` 등 전체 이관 필요 (`.env.example` 참조, gitleaks 통과 필수)

## 3. 실행 순서 (배포 당일)

### 단계 1 — 사전 점검
1. `./scripts/env-expiry-check.sh`로 시크릿 만료 확인
2. `git log` 확인 — 배포할 커밋 결정 (main)
3. 로컬 E2E 전체 통과 확인 (`npx playwright test`)
4. Vercel 콘솔 → 배포 환경변수 입력 (`.env`와 동일 값, **시크릿은 본인 수동 입력**)

### 단계 2 — Deployment Protection 해제
- Vercel 프로젝트 → Settings → Deployment Protection → **Off** (또는 검증용 비밀번호 유지 후 마지막에 해제)
- 이유: Google OAuth와 공개 접근 허용

### 단계 3 — Google OAuth redirect 추가
- Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client
- Authorized redirect URIs에 추가:
  - `https://web-swart-ten-6dsx2wswjc.vercel.app/api/auth/callback/google`
  - `https://maccando.kr/api/auth/callback/google` (도메인 연결 후)
- 확인: 콜백 URL이 환경변수 `AUTH_URL`(또는 NEXTAUTH_URL)과 일치해야 함 — 코드에서 `process.env.NEXTAUTH_URL`/`AUTH_URL` 사용처 확인 필요

### 단계 4 — maccando.kr 도메인 연결
- maccando.kr DNS 관리자 (가비아/호스팅케이알 등) → CNAME `maccando.kr → cname.vercel-dns.com`
- Vercel 프로젝트 → Settings → Domains → `maccando.kr` 추가
- (선택) www.maccando.kr 리다이렉트
- SSL 자동 발급 (Let's Encrypt) 확인
- 롤백: CNAME 제거 + Vercel Domains에서 삭제

### 단계 5 — R2 이미지 이전 (유일한 코드 작업)
설계:
1. **인프라**: Cloudflare R2 버킷 생성 (`maccando-uploads`), 공개 읽기 (custom domain `images.maccando.kr` + R2 public bucket 또는 캐시로), CORS 허용
2. **코드** (`lib/image.ts`):
   - `UPLOAD_ROOT`(로컬) 대신 R2 업로드: `PUT https://<account>.r2.cloudflarestorage.com/...` (S3 API 호환 — `@aws-sdk/client-s3` 또는 직접 fetch)
   - `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_ENDPOINT`(R2), `S3_BUCKET` 환경변수 추가 → `.env.example` + Vercel env
   - 업로드 URL 응답: `/uploads/...` → `https://images.maccando.kr/...` (또는 R2 호스트)로 변경
   - `trackImageUsage` 패턴(`/uploads/\d{8}/...`)을 R2 URL 패턴으로 확장
   - 서버 코드에서 파일 읽기 → R2 GET/Presigned URL
3. **마이그레이션**: 기존 `public/uploads` 파일 → R2 버킷 업로드 스크립트 (`scripts/migrate-uploads-r2.ts`, tsx --env-file)
4. **DB**: `Image` 테이블의 url(`/uploads/...`)을 R2 URL로 일괄 UPDATE (경로 prefix 교체)
5. **검증**: 기존 글 이미지 노출 + 신규 업로드 → R2 저장 확인
- 롤백: 환경변수에서 R2 사용 플래그 off (로컬 디스크 모드 유지 코드 경로 잔존) + DB url 원복

### 단계 6 — 최종 검증
1. `curl -s https://maccando.kr/api/health` → 200
2. 홈/글 상세/이미지/시리즈 스모크 (브라우저)
3. 관리자 로그인 (OAuth) → 글 작성 → 이미지 업로드 (R2 경로 확인)
4. E2E 전체 재실행 (배포 URL 기준)
5. `docs/CHANGELOG.md` + `docs/TODO.md` 갱신, bd close

## 4. 검증 체크리스트 (실행 시점)

- [ ] Vercel 배포가 최신 main (health 200 확인)
- [ ] 환경변수 전체 이관 완료 (`.env` ↔ Vercel diff 0)
- [ ] Deployment Protection 해제 후 공개 접근 OK
- [ ] Google OAuth 로그인 성공 (배포 도메인)
- [ ] maccando.kr SSL + 리다이렉트 동작
- [ ] 기존 이미지 전부 노출 (R2 이전 후)
- [ ] 신규 업로드 → R2 저장 확인
- [ ] gitleaks / env-expiry-check 통과

## 5. 롤백 계획

- 도메인: CNAME 제거 → 이전 배포 URL로 안내
- OAuth: redirect URI 제거 (사용자 영향 없음)
- R2: 로컬 디스크 모드로 즉시 복귀 (플래그) + Image url 일괄 원복 SQL
- 전체: Vercel → 이전 배포 롤백 (Instant Rollback)

## 6. 관련 파일

- `web/lib/image.ts` — 업로드/사용처 추적 (R2 이전 대상)
- `web/prisma/schema.prisma` — Image 모델 (url 필드)
- `web/.env.example` — 환경변수 추가 대상
- `web/scripts/` — 마이그레이션 스크립트 신규
- `docs/plans/PLAN_v2.3_deploy.md` — 본 문서