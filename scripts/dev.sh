#!/usr/bin/env bash
#
# cwa_app 開發環境一鍵啟動。
#   1. 殺掉殘留的 dart server process（避免 8080/8081/8082 被佔）
#   2. 在背景啟動 Serverpod（log 寫到 /tmp/cwa_server.log）
#   3. 輪詢 http://localhost:8080/ 等 ready
#   4. 啟動 Flutter on Chrome（前景）
#
# Ctrl-C 或 Flutter 正常結束時，會自動把 server 一起收掉。
#
# 用法：
#   ./scripts/dev.sh                 # 啟動全套
#   ./scripts/dev.sh --migrate       # 第一次跑 / 改完 schema 後（多帶 --apply-migrations）
#   ./scripts/dev.sh --server-only   # 只起 server，不開 Flutter
#   ./scripts/dev.sh --flutter-only  # 只起 Flutter（前提：server 你自己手動跑）

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DART="${DART:-$HOME/development/flutter/bin/dart}"
FLUTTER="${FLUTTER:-$HOME/development/flutter/bin/flutter}"
SERVER_LOG="/tmp/cwa_server.log"

# ── 參數 ────────────────────────────────────────────
MIGRATE=0
SERVER_ONLY=0
FLUTTER_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --migrate)       MIGRATE=1 ;;
    --server-only)   SERVER_ONLY=1 ;;
    --flutter-only)  FLUTTER_ONLY=1 ;;
    -h|--help)
      sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# ── 顏色 ────────────────────────────────────────────
if [ -t 1 ]; then
  c_g='\033[32m'; c_r='\033[31m'; c_y='\033[33m'; c_d='\033[2m'; c_n='\033[0m'
else
  c_g=''; c_r=''; c_y=''; c_d=''; c_n=''
fi
say() { echo -e "$@"; }

# ── 收尾 ────────────────────────────────────────────
SERVER_PID=""
cleanup() {
  # 避免 trap 重複進來
  trap - INT TERM EXIT
  if [ "$FLUTTER_ONLY" -eq 0 ]; then
    say ""
    say "${c_y}→ 收掉 server${c_n}"
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
      kill "$SERVER_PID" 2>/dev/null || true
      sleep 0.5
      kill -9 "$SERVER_PID" 2>/dev/null || true
    fi
    # 補一刀：殺任何 cwa_app_server 的 dart 進程
    pkill -9 -f 'dart .*cwa_app_server.*bin/main\.dart' 2>/dev/null || true
    pkill -9 -f 'dart bin/main\.dart' 2>/dev/null || true
  fi
  exit 0
}
trap cleanup INT TERM EXIT

# ── 1. 清殘留 ────────────────────────────────────────
if [ "$FLUTTER_ONLY" -eq 0 ]; then
  if pgrep -f 'dart .*bin/main\.dart' >/dev/null 2>&1; then
    say "${c_y}→ 殺掉舊的 dart server process${c_n}"
    pkill -9 -f 'dart .*bin/main\.dart' 2>/dev/null || true
    sleep 1
  fi
fi

# ── 2. 啟動 server（背景） ───────────────────────────
if [ "$FLUTTER_ONLY" -eq 0 ]; then
  EXTRA_ARGS=""
  if [ "$MIGRATE" -eq 1 ]; then
    EXTRA_ARGS="--apply-migrations"
    say "${c_y}→ 帶 --apply-migrations${c_n}"
  fi
  say "${c_g}→ 啟動 server${c_n} ${c_d}(log: $SERVER_LOG)${c_n}"
  cd "$ROOT/cwa_app_server"
  # shellcheck disable=SC2086
  "$DART" bin/main.dart $EXTRA_ARGS > "$SERVER_LOG" 2>&1 &
  SERVER_PID=$!

  # ── 3. 等 ready ────────────────────────────────────
  printf "→ 等 server ready"
  READY=0
  for i in $(seq 1 30); do
    if curl -sS -o /dev/null http://localhost:8080/ 2>/dev/null; then
      say " ${c_g}✓${c_n} (${i}s)"
      READY=1; break
    fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      say ""
      say "${c_r}✗ server 進程已結束，看 log：${c_n}"
      tail -30 "$SERVER_LOG"
      exit 1
    fi
    printf "."
    sleep 1
  done
  if [ "$READY" -ne 1 ]; then
    say ""
    say "${c_r}✗ server 啟動超時（30s），看 log：${c_n}"
    tail -30 "$SERVER_LOG"
    exit 1
  fi

  say ""
  say "${c_d}另開 terminal 看即時 log： tail -f $SERVER_LOG${c_n}"
fi

# ── 4. 啟動 Flutter（前景）────────────────────────────
if [ "$SERVER_ONLY" -eq 1 ]; then
  say ""
  say "${c_g}→ server-only 模式，server 已 ready${c_n}"
  say "${c_d}  Ctrl-C 結束${c_n}"
  # 把 server log 接過來顯示
  tail -f "$SERVER_LOG"
else
  say ""
  say "${c_g}→ 啟動 Flutter chrome${c_n}"
  cd "$ROOT/cwa_app_flutter"
  "$FLUTTER" run -d chrome
fi
