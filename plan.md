# CWA App — 實作計畫

> 從 [cwa-tg-bot](../cwa-tg-bot/) 取氣象演算「概念」，**全部用 Flutter + Dart 重寫**（不沿用 Python 程式碼）。
> 設計依據：[Figma CWA App Workflow](https://www.figma.com/board/bpGWEoHTqNY2diz4Z6qXH4/CWA-App-Workflow)

## 目標

純 Dart 跨平台 App，提供：

**沿用 cwa-tg-bot 的功能（演算法概念照搬，程式碼 Dart 重寫）**
- GPS 即時雨勢
- 地名搜尋 → 雨勢
- 北/中/南區域雷達圖
- 喜愛點管理
- AI 降雨分析（Gemini）

**Telegram 做不到的新功能**
- 🔔 系統級背景推播
- 🧭 **導航中沿路徑降雨監控**（核心差異化）
- ⏱️ 雷達歷史動畫時間軸
- 📱 主畫面 Widget

## 架構

```
┌──────────────────────────┐         ┌─────────────────────────┐
│  cwa_app_flutter         │ ──HTTPS──▶│  cwa_app_server          │
│  (iOS / Android)         │          │  (Serverpod)             │
│                          │ ◀──FCM───│                          │
│  - Riverpod              │          │  Endpoints:              │
│  - go_router             │          │   - RadarEndpoint        │
│  - dio                   │          │   - FavoriteEndpoint     │
│  - geolocator            │          │   - SubscribeEndpoint    │
│  - google_maps_flutter   │          │                          │
│  - home_widget           │          │  FutureCalls (排程):     │
│  - firebase_messaging    │          │   - PollRadarFrames (6m) │
│                          │          │   - CheckFavoritesPush(6m)│
│  使用 cwa_app_client      │          │                          │
│  (auto-generated)        │          │  Algorithm (Dart 重寫):  │
└──────────────────────────┘          │   - RadarFetcher         │
                                      │   - DbzAnalyzer          │
                                      │   - CoordProjection      │
                                      │   - GeminiAnalyst        │
                                      └────────┬─────────────────┘
                                               │
                                        ┌──────▼──────┐
                                        │ Postgres    │
                                        │ (Neon)      │
                                        └─────────────┘
```

## Python → Dart 對照表（演算法概念照搬，套件替換）

| cwa-tg-bot (Python) | cwa_app_server (Dart) | 用途 |
|---|---|---|
| `requests` + S3 抓 PNG | `package:http` | 抓 CWA 雷達 PNG |
| `Pillow` | `package:image` | PNG 解碼、像素讀取、標註 |
| `pyproj` (WGS84 ↔ AEQD) | `package:proj4dart` | 地理投影（GPS → 像素座標）|
| `psycopg2` | Serverpod ORM (內建 postgres) | DB 連線 |
| `google-generativeai` | `package:google_generative_ai` | Gemini AI 降雨分析 |
| `python-telegram-bot` | ❌ 無需求 | （換成 Flutter UI）|
| APScheduler / cron | Serverpod **Future Calls** | 排程 |

**演算法本身不變**：
- 雷達站座標 + dBZ 色碼表 → 一字不漏照抄（在 `cwa-tg-bot/config/settings.py`）
- 像素分析：WGS84 → AEQD → 像素位置 → 取色 → 比對 dBZ 表 → 強度等級
- Rolling buffer 設計（每站最新 5 張、PK = `(station_key, img_time)`）

## 待決策事項

| # | 議題 | 選項 | 預設建議 |
|---|------|------|---------|
| ~~D1~~ | ~~後端要新 repo 還是擴 cwa-tg-bot？~~ | — | **N/A**（已決定純 Dart 重寫）|
| D2 | 地圖 SDK | Google Maps / Mapbox | **Google Maps** — 已有 GOOGLE_MAPS_KEY |
| D3 | iOS build 路線 | Mac local / Codemagic 雲端 | **Codemagic** — 使用者在 Linux |
| ~~D4~~ | ~~後端部署~~ | — | ✅ **Fly.io**（Serverpod 官方 Dockerfile 直接 deploy）|
| ~~D5~~ | ~~DB~~ | — | ✅ **獨立新 Neon project + database `cwa_app`**（Neon 免費 = 100 projects/org、0.5GB & 100 CU-hours **per project**，獨立 project = 配額不跟 cwa-tg-bot 互吃；cwa-tg-bot 退役時直接砍 project）|

### 本機開發策略（2026-05-23 拍板）

- **不裝 Docker**。Serverpod 預設 `docker-compose.yaml` 裡的 Postgres + Redis 都跳過
- DB 一律打 Neon（dev / prod 同一個 Neon project，不同 database；之後可開 branch 隔 prod）
- `config/development.yaml` 設 `redis: enabled: false`
  - 失去：分散式 cache、多 instance pub/sub
  - 不影響：CRUD、Future Calls（寫 Postgres `serverpod_future_call` table，不靠 Redis）
  - 要擴 multi-instance 再回頭開 Redis

## 進行中工作（live status — 2026-05-26）

> 這節是 session 中斷 / quota 用完時的續工指南。把當前狀態落在這裡，下個 session 直接接。

### 目前位置：Phase 2 視覺骨架 + Phase 0/1 第一片端到端 slice

**已完成**
- Flutter 端 Home 畫面：Apple Weather 風天空背景 + 玻璃卡片堆疊（summary / hourly / radar / AI）。檔案：
  - `cwa_app_flutter/lib/theme/app_theme.dart`
  - `cwa_app_flutter/lib/features/home/home_screen.dart`
  - `cwa_app_flutter/lib/main.dart`（已指向 `HomeScreen`，AppShell 留檔備用）
- 設計框架定案：4 個畫面（Now / Radar / Route / Favorites），其餘擱置
- Nav bar 共識：**底部漂浮玻璃 pill（3 icon）**＝🗺 Radar / 📍 Now / ⭐ Favorites；右上 gear → Settings；Route 走 Now 頁面內 CTA，不佔 tab
- Server 端開始建：
  - `cwa_app_server/pubspec.yaml` 加了 `http: ^1.2.0` + `image: ^4.5.0`
  - `cwa_app_server/lib/src/config/radar_config.dart`（雷達站 / dBZ 色表 / 區域邊界 / S3 URL，照搬 cwa-tg-bot/config/settings.py）

### 進行中 slice：GPS 雨勢功能（cwa-tg-bot parity）

決定的 scope：完整 parity — Client 拿 GPS → Server 抓 PNG + 投影 + dBZ 分析 → 回傳「中雨/沒下雨」+ PNG，Hero 與 Radar 卡都吃真實資料。

**待辦（依序）**
- [x] Server：`config/radar_config.dart`（雷達站 + dBZ 色表）
- [x] Server：`algorithm/coord_projection.dart`（手寫 AEQD：WGS84 → 公尺 → 像素）
- [x] Server：`algorithm/dbz_analyzer.dart`（顏色匹配 + 強度分級 + analyze_point_dbz）
- [x] Server：`services/radar_fetcher.dart`（HTTP 抓 PNG + JSON metadata + in-memory cache）
- [x] Server：`protocol/nearby_radar.spy.yaml`（DTO：ok/dbz/shortLabel/humanText/stationName/imageTime/pngBytes/userPxX/userPxY/inRange/isBlindZone/errorMessage）
- [x] Server：`endpoints/radar_endpoint.dart`（`getNearby(lat, lon)`）
- [x] 跑 `cd cwa_app_server && dart pub get && serverpod generate`
- [x] Flutter：`pubspec.yaml` 加 `geolocator ^13.0.1`
- [x] Flutter：iOS `Info.plist` + Android `AndroidManifest.xml` 加位置權限字串
- [x] Flutter：HomeScreen 改 StatefulWidget，內含 `_Phase` 狀態機（initial/locating/fetching/ready/error）
- [x] Flutter：Hero 與 RadarCard 改吃 state，pull-to-refresh、retry 都有
- [x] `flutter analyze` 與 `dart analyze`（server）全綠 ✅

**還沒做的（這輪刻意 skip）**
- 標註紅點 + 中心裁切（mark_location）：前端目前用 BoxFit.cover 顯示整張 3600×3600 PNG
- AI 降雨分析（Gemini）：Hero 下方 AI 卡仍是 mock 文字
- Reverse geocode 顯示行政區名：Hero 位置現在顯示「觀測站名稱（北部(樹林) / 中部(南屯) / 南部(林園)）」當代理
- Backup 雷達站邏輯
- 未來一小時雨勢 hourly card 仍是 mock（CWA 沒對應 nowcast endpoint，可能改成「最近 60min 動畫」）

**注意事項**
- AEQD 公式：`R=6378137`；`c = acos(sin(lat0)·sin(lat) + cos(lat0)·cos(lat)·cos(lon−lon0))`；`k = c/sin(c)`；`x = R·k·cos(lat)·sin(lon−lon0)`；`y = R·k·(cos(lat0)·sin(lat) − sin(lat0)·cos(lat)·cos(lon−lon0))`；像素：`px_x = 1800 + (x/1000)·11.96`, `px_y = 1800 − (y/1000)·11.96`
- dBZ → 文字分級（同 cwa-tg-bot）：`<=0` 無雨 / `<15` 微雨 / `<30` 一般雨 / `<45` 明顯雨 / `>=45` 強降雨
- backup 雷達站邏輯（單站盲區時切其他站）這次先**不做**，YAGNI；之後遇到盲區再加
- 標註紅點 + 裁切（mark_location）也先**不做**，回傳整張 3600×3600 PNG，前端先用 BoxFit + 比例縮放看；下一輪再做標註

### 下一輪 slice（之後再做）
1. 標註紅點 + 中心裁切（mark_location 等價）
2. AI 降雨分析 endpoint（Gemini）
3. Reverse geocode 顯示行政區名
4. Backup 雷達站邏輯

## 階段拆解

對應 Figma 6 步驟，但**執行順序重排**：先做後端 skeleton + 最高風險功能 spike，再做環境收尾。

### Phase 0 — Serverpod backend skeleton（2–3 天）

**目標**：跑得起 server，有第一個 endpoint 回得到雷達圖。

- [x] 安裝 Flutter SDK（含 Dart）→ `~/development/flutter`，已加 PATH
- [ ] 安裝 Serverpod CLI (`dart pub global activate serverpod_cli`)
- [x] Neon 開新 project + database `cwa_app`（ap-southeast-1）
- [ ] `serverpod create cwa_app` → 產出 `cwa_app_server` / `cwa_app_client` / `cwa_app_flutter` 三個 package
- [ ] 改 `config/development.yaml` + `config/passwords.yaml`：連 Neon、`redis.enabled: false`
- [ ] 寫第一個 endpoint：`RadarEndpoint.getRegional(station)`
  - [ ] Dart 實作 `RadarFetcher`（抓 CWA S3 PNG）
  - [ ] 回傳 raw PNG bytes 或 base64
- [ ] `serverpod generate` → client 自動更新
- [ ] curl 測通

**Done 標準**：本機跑 `dart run bin/main.dart`，client 呼叫 `client.radar.getRegional('north')` 回得到 PNG。

### Phase 1 — 演算法核心移植（3–4 天）

> 這是工作量大頭：把 Python 演算法用 Dart 重寫。

- [ ] `DbzAnalyzer`：照 cwa-tg-bot/config/settings.py 的 dBZ 色碼表
  - [ ] 寫單元測試：丟入 RGB → 預期 dBZ 強度
- [ ] `CoordProjection`：WGS84 ↔ AEQD（用 proj4dart）
  - [ ] 寫單元測試：北部雷達站 (24.998, 121.443) → 應落在影像中心附近
- [ ] `RadarRenderer`：套 cwa-tg-bot/services/radar_render.py 的演算法，用 `package:image` 重寫
  - [ ] 給 GPS → 回傳「標註過的雷達圖 + 命中強度」
- [ ] `GeminiAnalyst`：丟雷達數據 → 回 AI 文字描述

**Done 標準**：`RadarEndpoint.getNearby(lat, lon)` 回傳跟 cwa-tg-bot 一模一樣（圖片標註、AI 描述）的結果。

### Phase 2 — Flutter app 骨架（1–2 天）

- [ ] 在 `cwa_app_flutter/` 加套件：`flutter_riverpod` / `go_router` / `geolocator` / `firebase_messaging`
- [ ] 三畫面骨架
  - [ ] Home：「附近雨勢」「區域雷達」「我的喜愛點」
  - [ ] Radar Detail：雷達圖 + AI 分析卡片
  - [ ] Settings：訂閱、推播權限
- [ ] 用自動生成的 `cwa_app_client` 串第一個 endpoint
- [ ] Android emulator 跑通端到端

**Done 標準**：Home 按鈕 → 取 GPS → 顯示後端回的雷達圖。

### Phase 3 — 新功能 spike（按風險高→低）

#### 3A. 路徑降雨監控 PoC（最高風險，5–7 天）

> 核心差異化功能，**最有可能卡關，先做**。

- [ ] `google_maps_flutter` 整合，畫起點→終點路徑（Google Directions API）
- [ ] 後端加 `RouteEndpoint.checkPath(List<LatLng>)`
  - [ ] 沿路徑每 N km 取樣
  - [ ] 並行查每點 dBZ
  - [ ] 回傳「命中雨區的路段 + 強度」
- [ ] Flutter 把命中路段標紅
- [ ] **整合導航模式**：每 30 秒重新查當前位置 + 未來 N km
- [ ] **未知數**：Google Maps Flutter 記憶體 / 雷達圖 overlay 怎麼疊 / 電量消耗

#### 3B. 背景推播（2–3 天）

- [ ] Serverpod **Future Call**：`CheckFavoritesPush`，每 6 min 跑
  - [ ] 掃所有 `subscribed=true` 的使用者 favorites
  - [ ] 拉最新雷達 buffer 比對
  - [ ] 命中 → 透過 Firebase Admin SDK 送 FCM
- [ ] Flutter 加 `firebase_messaging`
  - [ ] 註冊 token → 上傳到後端 `SubscribeEndpoint.registerDevice`
  - [ ] 處理前台/背景/終止三種狀態

#### 3C. 雷達動畫時間軸（2 天）

- [ ] Future Call `PollRadarFrames`：每 6 min 抓 3 站 PNG 進 `radar_frames` table（按 cwa-tg-bot rolling buffer 設計）
- [ ] `RadarEndpoint.getFrames(station, n)` 回最新 n 張
- [ ] Flutter：PageView + 自動播放、可拖時間軸

#### 3D. Widget（3–4 天，原生工作量大）

- [ ] `home_widget` 套件
- [ ] iOS：WidgetKit Swift extension
- [ ] Android：AppWidgetProvider Kotlin
- [ ] Widget：第一個 favorite 的雷達縮圖 + 「現在下雨/沒下」

### Phase 4 — 測試

- [ ] 後端：`dart test` for analyzer / projection / renderer
- [ ] 前端：`flutter test` for widgets
- [ ] Android 實機 adb install
- [ ] iOS 實機 TestFlight

### Phase 5 — 編譯與上架

- [ ] Backend → Fly.io（Serverpod 提供 Dockerfile）
- [ ] Android Linux 本機 `flutter build appbundle` → Google Play
- [ ] iOS Codemagic 雲端 build → TestFlight → App Store
- [ ] Apple Developer 帳號 $99/年

## 風險登記

| 風險 | 機率 | 影響 | 緩解 |
|---|---|---|---|
| Dart `image` 套件效能比 Pillow 慢 | 中 | 中 | 早期 benchmark；不夠快就上 isolate 平行處理 |
| 路徑監控做不到實用程度 | 中 | 高（核心賣點） | Phase 3A 提前 spike，做不出來退回到「定點訂閱」 |
| iOS 上架被退 | 中 | 中 | 早上 TestFlight |
| Serverpod 學習曲線拖慢進度 | 中 | 中 | Phase 0 設 3 天時限，超過考慮退回 Dart Frog |
| Fly.io free tier 冷啟動讓推播延遲 | 高 | 中 | 早期可接受；上線前升等 |
| Google Maps 月費爆預算 | 低 | 中 | 設 quota alert |

## 下一步（按優先序）

1. **回答 D2–D5 決策**（5 分鐘）
2. **動手 Phase 0**：安裝 Dart SDK + Serverpod CLI、`serverpod create cwa_app`
3. 同步看 `cwa-tg-bot/config/settings.py` 把 dBZ 色碼表、雷達站座標**先抄一份到** `cwa_app_server/lib/src/config/`（純資料、最容易先做）

> 此計畫為活文件，隨進度更新。完成項目改 ✅，調整決策直接編輯表格。