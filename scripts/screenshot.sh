#!/bin/bash
# MacCanDo 스크린샷 캡처 (7.6장 표준)
# usage: ./scripts/screenshot.sh web|macos <화면명>
set -e

PLATFORM=$1
NAME=${2:-default}
VERSION=${VERSION:-v0.1}
OUT="docs/screenshots/${PLATFORM}"
mkdir -p "$OUT"

case "$PLATFORM" in
  web)
    echo "[SHOT] web — Playwright 스크린샷 (web/ 미생성 시 건너뜀)"
    if [ -d "web" ]; then
      (cd web && npx playwright screenshot --viewport-size=1440,900 "http://localhost:3000" "${OUT}/${VERSION}_${NAME}.png" 2>/dev/null || echo "  dev 서버가 실행 중이어야 합니다")
    fi
    ;;
  macos)
    echo "[SHOT] macos — screencapture"
    screencapture -x "${OUT}/${VERSION}_${NAME}.png"
    ;;
  *)
    echo "usage: ./scripts/screenshot.sh web|macos <화면명>"
    exit 1
    ;;
esac
echo "[SHOT] 저장: ${OUT}/${VERSION}_${NAME}.png"