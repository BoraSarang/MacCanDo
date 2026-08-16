# AGENTS.macos.md — macOS 플랫폼 특화 규칙 (MacCanDo)

> 공통 규칙은 AGENTS.md(공통 가이드 v2.1)를 따르고, 본 파일은 macOS 전용 규칙만 명시한다.

## 1. 스택 (고정 — 네이티브)

- SwiftUI + AppKit (Xcode 프로젝트, `macapp/`)
- SQLite (GRDB) — 로컬 오프라인 저장소
- WebKit — MD/HTML 미리보기 렌더링
- URLSession — API 호출 (오프라인 큐 연동)
- Gemini API Free — AI SEO 지원
- iTunes Lookup API — 스토어 정보 자동 조회

## 2. 디렉토리 구조

```
macapp/
├── MacCanDo/              # 앱 소스
│   ├── App/               # App entry, AppState
│   ├── Views/             # SwiftUI 뷰
│   ├── Editor/            # MD/HTML 에디터 + 미리보기
│   ├── Database/          # SQLite (GRDB) + 마이그레이션
│   ├── Sync/              # 오프라인 큐 + 동기화 + 배포
│   ├── Backup/            # 백업/복구
│   ├── API/               # API 클라이언트 (GBridge 규격)
│   ├── AI/                # Gemini SEO
│   ├── Debug/             # DebugLogger + DebugPanel
│   └── Utils/
└── MacCanDo.xcodeproj
```

## 3. 규칙

1. **DebugLogger 의무**: 모든 신규 화면/동작 진입점에 `[INFO] [FEATURE] <기능명> 진입/완료` 로그
2. **DebugPanel**: Cmd+Shift+D → NSWindow(.floating) 640x360, 로그/API/큐/성능 표시
3. **API 로깅**: `API→ {METHOD} {path}` / `API← {status} {ms}` — DebugPanel 실시간 표시
4. 에러: `[ERROR] E-MAC-{CAT}-{NUM4}` + error_message_ko.json 매핑 (사용자 얼럿)
5. 오프라인 큐: 모든 쓰기는 로컬 SQLite 먼저 → 큐 적재 → 온라인 시 POST /api/admin/sync/bulk
6. 충돌 해결: 서버 timestamp 우선 (LWW)
7. 자동 저장: 에디터 2초 디바운스, 앱 종료 시 flush
8. 배포: 임시(draft) → 배포(published) 상태 전환 시에만 API 반영
9. 백업: 온라인→로컬 덤프, 복구는 테스트(검증) 통과 후 적용
10. 시크릿: .env (gitignore), Keychain 사용 권장, env-expiry-check.sh 체크

## 4. 성능 예산

- Cold Start ≤ 1.5s, 메모리 ≤ 300MB, 60fps
- AI 캐시: SQLite LRU 캐시 hit ≥ 70% ([CACHE] 로그)

## 5. 빌드/검증

```bash
./build_and_run.sh debug macos    # xcodebuild + 실행
./scripts/screenshot.sh macos     # screencapture
./scripts/a11y-dump.sh macos      # 로그 덤프
```