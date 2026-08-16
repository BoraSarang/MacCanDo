#!/bin/bash
# MacCanDo 빌드 디스패처 (AGENTS.md 18장 표준)
# usage: ./build_and_run.sh debug web|macos|all | install macos | e2e web | env-check
set -e

MODE=$1
PLATFORM=$2

usage() {
  echo "usage: $0 debug web|macos|all | install macos | e2e web | env-check"
  exit 1
}

[ -z "$MODE" ] && usage

case "$MODE" in
  debug)
    case "$PLATFORM" in
      web)
        echo "[BUILD] web (Next.js dev)"
        ./scripts/env-expiry-check.sh || true
        if [ -d "web" ]; then
          (cd web && npm run dev)
        else
          echo "[BUILD] web/ 디렉토리가 없습니다. T-03에서 생성 예정."
        fi
        ;;
      macos)
        echo "[BUILD] macos (xcodebuild Debug)"
        ./scripts/env-expiry-check.sh || true
        if [ -d "macos" ]; then
          BV_FILE="macos/.build-version"
          BV=$(cat "$BV_FILE" 2>/dev/null || echo 0)
          BV=$((BV + 1))
          echo "$BV" > "$BV_FILE"
          echo "[BUILD] 빌드 번호: $BV (버전 1.0.0)"
          (cd macos && xcodegen generate && xcodebuild -project MacCanDo.xcodeproj -scheme MacCanDo -configuration Debug build MARKETING_VERSION=1.0.0 CURRENT_PROJECT_VERSION=$BV)
          APP=$(find ~/Library/Developer/Xcode/DerivedData -name "MacCanDo.app" -path "*Debug*" 2>/dev/null | head -1)
          echo "[BUILD] macos 빌드 성공 — 실행: open $APP"
        else
          echo "[BUILD] macos/ 디렉토리가 없습니다. T-06에서 생성 예정."
        fi
        ;;
      all)
        ./build_and_run.sh debug web || true
        ./build_and_run.sh debug macos || true
        ;;
      *)
        usage
        ;;
    esac
    ;;
  install)
    case "$PLATFORM" in
      macos)
        echo "[INSTALL] macos Release 빌드 + ~/Applications 배포"
        ./scripts/env-expiry-check.sh || true
        if [ -d "macos" ]; then
          BV_FILE="macos/.build-version"
          BV=$(cat "$BV_FILE" 2>/dev/null || echo 0)
          BV=$((BV + 1))
          echo "$BV" > "$BV_FILE"
          echo "[INSTALL] 빌드 번호: $BV (버전 1.0.0)"
          (cd macos && xcodegen generate && xcodebuild -project MacCanDo.xcodeproj -scheme MacCanDo -configuration Release clean build MARKETING_VERSION=1.0.0 CURRENT_PROJECT_VERSION=$BV)
          APP=$(find ~/Library/Developer/Xcode/DerivedData -name "MacCanDo.app" -path "*Release*" 2>/dev/null | head -1)
          DEST="$HOME/Applications/MacCanDo.app"
          mkdir -p "$HOME/Applications"
          pkill -x MacCanDo 2>/dev/null || true
          sleep 1
          rm -rf "$DEST"
          ditto "$APP" "$DEST"
          /usr/libexec/PlistBuddy -c "Delete :LSHasLocalizedDisplayName" "$DEST/Contents/Info.plist" 2>/dev/null || true
          /usr/libexec/PlistBuddy -c "Add :LSHasLocalizedDisplayName bool true" "$DEST/Contents/Info.plist"
          echo "[INSTALL] 배포 완료: $DEST"
          V=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$DEST/Contents/Info.plist")
          B=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$DEST/Contents/Info.plist")
          echo "[INSTALL] 배포 버전: $V (빌드 $B)"
          mdimport "$DEST" >/dev/null 2>&1 || true
          open "$DEST"
        else
          echo "[INSTALL] macos/ 디렉토리가 없습니다."
        fi
        ;;
      *)
        usage
        ;;
    esac
    ;;
  e2e)
    case "$PLATFORM" in
      web)
        echo "[E2E] web (Playwright)"
        if [ -d "web" ]; then
          (cd web && npx playwright test)
        else
          echo "[E2E] web/ 미생성 — T-09에서 실행"
        fi
        ;;
      *)
        usage
        ;;
    esac
    ;;
  env-check)
    ./scripts/env-expiry-check.sh
    ;;
  *)
    usage
    ;;
esac