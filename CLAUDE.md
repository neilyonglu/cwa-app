# CLAUDE.md

給 Claude Code 在這個專案下工作時的指引。

## 專案是什麼

`cwa_app/` 是台灣中央氣象署雷達降雨 App，**純 Dart 全端**：Flutter 前端 + Serverpod 後端。功能：GPS 雨勢查詢、區域雷達、AI 降雨分析、背景推播、路徑降雨監控（差異化）、雷達動畫、Widget。

**靈感來源**：[../cwa-tg-bot/](../cwa-tg-bot/) 是同作者的 Python Telegram bot。本專案**只參考演算法概念**（dBZ 色表、座標投影邏輯、rolling buffer 設計），**不沿用 Python 程式碼**。

當前狀態：規劃中（2026-05-23），尚未產生程式碼。先讀 [plan.md](plan.md)。

## 鐵則

### R1. 全 Dart，不引入其他語言到 server
- Backend 是 Serverpod (Dart)
- 不要寫 Python / TypeScript / Go server
- 不要呼叫 cwa-tg-bot 的 Python 程式碼當依賴
- 例外：iOS WidgetKit 必須用 Swift、Android AppWidget 必須用 Kotlin（這兩個無解）

### R2. 演算法概念照搬，程式碼 Dart 重寫
- 參考 cwa-tg-bot 的 `services/` 與 `config/settings.py` **看邏輯**
- **不要** copy paste Python 寫成「Dart 包裝 Python」的奇怪結構
- dBZ 色碼表、雷達站座標等**純資料**可以一字不漏抄到 `cwa_app_server/lib/src/config/`

### R3. 前後端分離
- Flutter **絕不**直接打 CWA / Gemini / Google Geocoding API
- 所有外部呼叫走 Serverpod endpoint（API key 安全 + 集中快取）
- 推播觸發、排程一律在 server 端

### R4. 重度運算只在 server
- 雷達 PNG 解碼、像素分析、座標投影 → server
- Flutter 收到的是「已標註的圖 + 結果 JSON」，**不要在手機上跑 image pixel loop**

### R5. 用 Serverpod 自動生成的 client
- 不要在 Flutter 手寫 HTTP client / DTO
- 改 endpoint 或 protocol 後**一定要跑** `serverpod generate`
- `cwa_app_client/` 是自動生成的，**DO NOT EDIT**

## 慣用工具與套件

### 後端 (Serverpod)
- HTTP：`package:http`（抓 CWA PNG）
- 影像：`package:image`
- 投影：`package:proj4dart`
- AI：`package:google_generative_ai`
- 推播：`package:firebase_admin`（或自家寫 FCM HTTP v1 呼叫）
- 排程：**Serverpod Future Calls**（不要自己 spawn Timer）
- DB：Serverpod ORM（不要直接寫 `postgres` package）

### 前端 (Flutter)
- 狀態：**Riverpod**（不要 Provider / Bloc / GetX）
- 路由：**go_router**
- HTTP：**Serverpod auto-generated client**（不要自己 dio）
- 序列化：Serverpod 自動處理；額外的本地 model 用 freezed
- 地圖：`google_maps_flutter`
- GPS：`geolocator`
- 推播：`firebase_messaging`

## 該做 / 不該做

### ✅ 該做
- 寫 endpoint 前先看 `cwa_app_server/lib/src/algorithm/` 是否已有對應演算法
- 改 protocol/endpoint 後立即跑 `serverpod generate`
- 任何雷達演算法都要寫單元測試（丟 RGB → 預期 dBZ、丟 GPS → 預期像素）
- Flutter feature 拆 `features/<name>/`，內含 `view/`、`controller/`、`model/`
- 用真實 CWA PNG 做測試（不要 mock 圖檔）

### ❌ 不該做
- 不要在 Flutter 端解 PNG 做像素 loop（後端做完回結果）
- 不要把 cwa-tg-bot 的 Telegram handlers 邏輯 copy 進來（那是 chat-based UI，不適用 app）
- 不要為「未來可能要支援」加抽象層（YAGNI）— 先 hardcode，需要時再抽
- 不要直接編輯 `cwa_app_client/`（自動生成）
- 不要繞過 Serverpod 排程器自己接 cron（會跟 future calls 衝突）

## 開發指令（待補）

> 等 Phase 0 跑起來後填入。

```bash
# 後端
cd cwa_app_server
docker-compose up -d
dart bin/main.dart

# Code generation（改 endpoint / protocol 後）
cd cwa_app_server && serverpod generate

# DB migration
cd cwa_app_server && serverpod create-migration

# 前端
cd cwa_app_flutter && flutter run

# 測試
cd cwa_app_server && dart test
cd cwa_app_flutter && flutter test
```

## 常見任務的入口檔

| 任務 | 改哪裡 |
|---|---|
| 新增 REST endpoint | `cwa_app_server/lib/src/endpoints/` |
| 新增 protocol / DTO | `cwa_app_server/lib/src/protocol/` → 跑 `serverpod generate` |
| 改雷達演算法 | `cwa_app_server/lib/src/algorithm/` |
| 改 dBZ 色碼 / 雷達站座標 | `cwa_app_server/lib/src/config/` |
| 改推播觸發條件 | `cwa_app_server/lib/src/future_calls/check_favorites_push.dart` |
| 新增 Flutter 畫面 | `cwa_app_flutter/lib/features/<name>/` + 註冊到 `router.dart` |
| 改 Widget 內容 | iOS: `cwa_app_flutter/ios/WidgetExtension/`、Android: `cwa_app_flutter/android/app/src/main/kotlin/.../widget/` |

## 相關文件

- [plan.md](plan.md) — 階段、決策、風險
- [README.md](README.md) — 對外說明、技術堆疊
- [../cwa-tg-bot/CLAUDE.md](../cwa-tg-bot/CLAUDE.md) — Python 參考實作的指引
- [Figma Workflow](https://www.figma.com/board/bpGWEoHTqNY2diz4Z6qXH4/CWA-App-Workflow)
- [Serverpod 文件](https://docs.serverpod.dev/)
