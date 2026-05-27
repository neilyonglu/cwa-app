#!/usr/bin/env bash
#
# cwa_app 開發環境一鍵啟動。
#   1. 殺掉殘留的 dart server process（避免 8080/8081/8082 被佔）
#   2. 在背景啟動 Serverpod（log 寫到 /tmp/cwa_server.log）
#   3. 輪詢 http://localhost:8080/ 等 ready
#   4. 啟動 Flutter on Chrome（前景） — 預設
#      或：跑在連線中的 Android 裝置上（--android），自動跑 adb reverse
#
# Ctrl-C 或 Flutter 正常結束時，會自動把 server 一起收掉。
#
# 用法：
#   ./scripts/dev.sh                 # 啟動全套（Chrome）
#   ./scripts/dev.sh --android       # 啟動 server + 跑在 Android 實機 / emulator
#   ./scripts/dev.sh --migrate       # 第一次跑 / 改完 schema 後（多帶 --apply-migrations）
#   ./scripts/dev.sh --server-only   # 只起 server，不開 Flutter
#   ./scripts/dev.sh --flutter-only  # 只起 Flutter（前提：server 你自己手動跑）
#
# 手機測試詳情見 docs/mobile-testing.md。

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DART="${DART:-$HOME/development/flutter/bin/dart}"
FLUTTER="${FLUTTER:-$HOME/development/flutter/bin/flutter}"
SERVER_LOG="/tmp/cwa_server.log"

# ── 載入 .env（GEMINI_API_KEY 等密鑰）─────────────────
# 檔案在 gitignore 內、不會被 commit。沒 .env 也 OK，
# Gemini 分析會直接跳過。
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi

# ── 參數 ────────────────────────────────────────────
MIGRATE=0
SERVER_ONLY=0
FLUTTER_ONLY=0
ANDROID=0
for arg in "$@"; do
  case "$arg" in
    --migrate)       MIGRATE=1 ;;
    --server-only)   SERVER_ONLY=1 ;;
    --flutter-only)  FLUTTER_ONLY=1 ;;
    --android)       ANDROID=1 ;;
    -h|--help)
      sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
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
  exit 0
fi

cd "$ROOT/cwa_app_flutter"

if [ "$ANDROID" -eq 1 ]; then
  # 1. 確認 adb 在 PATH
  if ! command -v adb >/dev/null 2>&1; then
    say ""
    say "${c_r}✗ 找不到 adb${c_n}"
    say "  Ubuntu/Debian: ${c_d}sudo apt install android-tools-adb${c_n}"
    say "  或裝 Android Studio，把 ~/Android/Sdk/platform-tools 加到 PATH"
    exit 1
  fi

  # 2. 抓第一個已授權的 Android 裝置
  DEVICE=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
  if [ -z "$DEVICE" ]; then
    say ""
    say "${c_r}✗ 找不到已授權的 Android 裝置${c_n}"
    say "  確認：USB 連好、開發者選項 + USB 偵錯 ON、手機跳出對話框時點允許"
    say "  跑 ${c_d}adb devices${c_n} 看狀態（unauthorized = 沒授權、offline = adb 卡住）"
    say "  詳情見 docs/mobile-testing.md"
    exit 1
  fi
  say ""
  say "${c_g}→ Android 裝置：${c_n}$DEVICE"

  # 3. adb reverse 8080/8081（讓手機的 localhost 轉發到 PC）
  say "${c_y}→ adb reverse 8080 + 8081 + 8082${c_n}"
  adb -s "$DEVICE" reverse tcp:8080 tcp:8080 >/dev/null
  adb -s "$DEVICE" reverse tcp:8081 tcp:8081 >/dev/null
  adb -s "$DEVICE" reverse tcp:8082 tcp:8082 >/dev/null

  # 4. 跑 flutter run
  say "${c_g}→ 啟動 Flutter on $DEVICE${c_n}"
  exec "$FLUTTER" run -d "$DEVICE"
fi

say ""
say "${c_g}→ 啟動 Flutter chrome${c_n}"
exec "$FLUTTER" run -d chrome
