#!/bin/bash
# MacCanDo 텍스트 검증 덤프 (7.6.1장 — 텍스트 전용 모델 대응 3종 세트)
# usage: ./scripts/a11y-dump.sh web|macos <이름>
# output: docs/screenshots/{platform}/{version}_{name}.{a11y.txt|storage.json|perf.json}
set -e

PLATFORM=$1
NAME=${2:-dump}
VERSION=${VERSION:-v0.1}
OUT="docs/screenshots/${PLATFORM}"
mkdir -p "$OUT"

case "$PLATFORM" in
  web)
    echo "[A11Y] web DOM/스토리지 덤프"
    if [ -d "web" ]; then
      echo "  (web/ 준비 후 Playwright로 DOM 스냅샷 + console 로그 수집 예정)"
      echo "{}" > "${OUT}/${VERSION}_${NAME}.storage.json"
      echo "[]" > "${OUT}/${VERSION}_${NAME}.perf.json"
    fi
    ;;
  macos)
    echo "[A11Y] macos 로그 덤프"
    LOG_DIR="$HOME/Library/Logs/MacCanDo"
    if [ -d "$LOG_DIR" ]; then
      cat "$LOG_DIR/debug.log" 2>/dev/null > "${OUT}/${VERSION}_${NAME}.a11y.txt" || echo "  로그 파일 없음"
    fi
    echo "{}" > "${OUT}/${VERSION}_${NAME}.storage.json"
    echo "{}" > "${OUT}/${VERSION}_${NAME}.perf.json"
    ;;
  *)
    echo "usage: ./scripts/a11y-dump.sh web|macos <이름>"
    exit 1
    ;;
esac
echo "[A11Y] 완료: ${OUT}/${VERSION}_${NAME}.{a11y.txt|storage.json|perf.json}"