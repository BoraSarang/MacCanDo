#!/bin/bash
# MacCanDo 시크릿/환경 변수 만료 체크 (8.12장 표준)
# .env.example 내 "# expires: YYYY-MM-DD owner: @xxx" 주석 파싱
# 30일 이내 경고, 만료 시 에러
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TODAY=$(date +%s)
WARN_DAYS=30
FOUND=0
FAILED=0

check_file() {
  local f=$1
  [ -f "$f" ] || return 0
  while IFS= read -r line; do
    if [[ "$line" == *"expires:"* ]]; then
      EXP=$(echo "$line" | sed -n 's/.*expires: \([0-9-]*\).*/\1/p')
      OWNER=$(echo "$line" | sed -n 's/.*owner: \([^ ]*\).*/\1/p')
      if [ -n "$EXP" ]; then
        EXPT=$(date -j -f "%Y-%m-%d" "$EXP" +%s 2>/dev/null || echo 0)
        DIFF=$(( (EXPT - TODAY) / 86400 ))
        FOUND=1
        if [ "$DIFF" -lt 0 ]; then
          echo "[SECRET] ERROR: $f 의 $EXP 만료됨 (owner: ${OWNER:-?})"
          FAILED=1
        elif [ "$DIFF" -le "$WARN_DAYS" ]; then
          echo "[SECRET] WARN: $f 의 $EXP ${DIFF}일 남음 (owner: ${OWNER:-?})"
        fi
      fi
    fi
  done < "$f"
}

echo "[SECRET] 환경 변수 만료 체크..."
check_file "$ROOT/.env.example"
check_file "$ROOT/web/.env.example"
check_file "$ROOT/macapp/.env.example"
check_file "$ROOT/macapp/MacCanDo/Config/Secrets.xcconfig"

if [ "$FAILED" -eq 1 ]; then
  echo "[SECRET] 만료된 시크릿 존재 — 빌드 중단 (bd create --label secret 권장)"
  exit 1
fi
[ "$FOUND" -eq 0 ] && echo "[SECRET] 만료 체크 항목 없음 (통과)"
echo "[SECRET] 완료"