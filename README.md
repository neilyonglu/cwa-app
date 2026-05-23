# CWA App

> 台灣即時雷達降雨 App — Flutter 跨平台版本，**純 Dart 全端**（Serverpod 後端 + Flutter 前端）。
>
> 演算法概念來自 [cwa-tg-bot](../cwa-tg-bot/) 的 Python 實作，但**程式碼 100% Dart 重寫**，不沿用 Python codebase。

## 功能

**從 cwa-tg-bot 移植**
- 🌧️ GPS 即時雨勢
- 🔍 地名搜尋雨勢
- 📡 北/中/南區域雷達圖
- ⭐ 喜愛點管理（最多 5 個）
- 🤖 AI 降雨分析（Gemini）

**App 原生才能做的新功能**
- 🔔 系統級背景推播（命中下雨主動通知）
- 🧭 **導航中沿路徑降雨監控**
- ⏱️ 雷達歷史動畫時間軸（過去 ~30 分鐘）
- 📱 主畫面 Widget

## 技術堆疊

### 全端 Dart 單一語言

| 層 | 套件 |
|---|---|
| **後端框架** | [Serverpod](https://serverpod.dev/) |
| **資料庫** | PostgreSQL (Neon) — Serverpod 內建 ORM + migrations |
| **雷達 PNG 抓取** | `package:http` |
| **影像處理** | `package:image`（PNG decode、像素分析、標註）|
| **地理投影** | `package:proj4dart`（WGS84 ↔ AEQD）|
| **AI 分析** | `package:google_generative_ai`（Gemini）|
| **排程** | Serverpod **Future Calls** |
| **前端框架** | Flutter 3.x |
| **狀態管理** | `flutter_riverpod` |
| **路由** | `go_router` |
| **HTTP client** | Serverpod 自動生成的 `cwa_app_client`（底層 dio）|
| **GPS** | `geolocator` |
| **地圖** | `google_maps_flutter` |
| **推播** | `firebase_messaging` |
| **Widget** | `home_widget` + 原生 WidgetKit / AppWidget |

### CI / 部署
- **Android build**：Linux 本機 `flutter build appbundle`
- **iOS build**：[Codemagic](https://codemagic.io/) 雲端
- **後端部署**：Fly.io（Serverpod 官方教學首選）
- **DB**：Neon

## 專案結構

Serverpod 標準三 package 結構：

```
cwa_app/
├── plan.md                    # 實作計畫
├── README.md                  # 本檔
├── CLAUDE.md                  # 給 Claude Code 的指引
│
├── cwa_app_server/            # Dart 後端（Serverpod）
│   ├── lib/
│   │   ├── server.dart        # 入口
│   │   └── src/
│   │       ├── endpoints/     # REST endpoints
│   │       │   ├── radar_endpoint.dart
│   │       │   ├── favorite_endpoint.dart
│   │       │   ├── subscribe_endpoint.dart
│   │       │   └── route_endpoint.dart
│   │       ├── future_calls/  # Serverpod 排程
│   │       │   ├── poll_radar_frames.dart       (每 6 min)
│   │       │   └── check_favorites_push.dart    (每 6 min)
│   │       ├── algorithm/     # 演算法核心（Dart 重寫）
│   │       │   ├── radar_fetcher.dart
│   │       │   ├── dbz_analyzer.dart
│   │       │   ├── coord_projection.dart
│   │       │   ├── radar_renderer.dart
│   │       │   └── gemini_analyst.dart
│   │       ├── config/
│   │       │   ├── radar_stations.dart
│   │       │   └── dbz_color_table.dart
│   │       └── generated/     # Serverpod 自動生成（DO NOT EDIT）
│   ├── protocol/              # 共享 schema（自動生成 client）
│   ├── migrations/            # DB migrations
│   ├── config/                # passwords.yaml / development.yaml
│   ├── Dockerfile             # Serverpod 預設
│   └── pubspec.yaml
│
├── cwa_app_client/            # 自動生成的 client SDK（DO NOT EDIT）
│   ├── lib/
│   └── pubspec.yaml
│
└── cwa_app_flutter/           # Flutter app
    ├── lib/
    │   ├── main.dart
    │   ├── router.dart        # go_router
    │   ├── features/
    │   │   ├── home/
    │   │   ├── radar/         # 雷達圖 + AI 分析
    │   │   ├── route/         # 路徑降雨監控（差異化）
    │   │   ├── favorites/
    │   │   ├── timeline/      # 雷達動畫
    │   │   └── settings/
    │   ├── core/
    │   │   ├── client.dart    # Serverpod client singleton
    │   │   ├── location/
    │   │   └── push/
    │   └── widgets/           # 共用 UI
    ├── android/               # 含 AppWidget Kotlin
    ├── ios/                   # 含 WidgetKit Swift
    ├── test/
    └── pubspec.yaml
```

## 環境變數（Serverpod `config/passwords.yaml`）

| 變數 | 必填 | 說明 |
|---|---|---|
| `database` | ✅ | Postgres 密碼 |
| `redis` | ✅ | Redis 密碼（Serverpod 用）|
| `googleMaps` | ✅ | Google Cloud API key |
| `gemini` | ✅ | Google AI Studio key |
| `fcmServiceAccount` | ✅ | Firebase service account JSON 路徑 |

## 環境變數（Flutter，透過 `--dart-define`）

- `SERVERPOD_URL`：後端 URL（dev: `http://10.0.2.2:8080`、prod: Fly.io URL）
- `GOOGLE_MAPS_API_KEY`：手機端地圖

## 本地開發

### 一次性安裝

```bash
# Dart SDK + Flutter（如未裝）
# Serverpod CLI
dart pub global activate serverpod_cli

# 在 cwa_app/ 底下用 Serverpod 建專案（首次）
serverpod create cwa_app
```

### 啟動後端

```bash
cd cwa_app_server
docker-compose up -d        # Postgres + Redis
dart bin/main.dart           # 後端跑在 :8080
```

### Code generation（改 endpoint 或 protocol 後跑）

```bash
cd cwa_app_server
serverpod generate
```

### 啟動前端

```bash
cd cwa_app_flutter
flutter pub get
flutter run --dart-define=SERVERPOD_URL=http://10.0.2.2:8080
```

## 部署

### 後端 → Fly.io
```bash
cd cwa_app_server
fly launch        # 首次
fly deploy        # 後續
```

### iOS → Codemagic → TestFlight
1. push 到 GitHub
2. Codemagic 接 repo，跑 `cd cwa_app_flutter && flutter build ipa`
3. 設 App Store Connect API key → 自動上傳 TestFlight

### Android → Linux 本機 → Google Play
```bash
cd cwa_app_flutter
flutter build appbundle --release
# 上傳 build/app/outputs/bundle/release/app-release.aab 到 Play Console
```

## 相關文件

- [plan.md](plan.md) — 階段、決策、風險
- [CLAUDE.md](CLAUDE.md) — Claude Code 工作指引
- [Figma Workflow](https://www.figma.com/board/bpGWEoHTqNY2diz4Z6qXH4/CWA-App-Workflow)
- [../cwa-tg-bot/](../cwa-tg-bot/) — 演算法概念來源（Python 實作，本專案不直接依賴）
- [Serverpod 文件](https://docs.serverpod.dev/)
