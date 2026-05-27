# 手機測試手冊

> 在 Linux 主機上開發 cwa_app，怎麼把 app 跑到實機。
> 結論：**Android 直接接 USB 就能跑、iOS 要走 Codemagic 雲端 build**。

## 一句話總結

```bash
# Android（接 USB 後）
./scripts/dev.sh --android

# iOS
（Linux 不能 build，後續走 Codemagic，見最下方）
```

---

## Android

### 一次性設定（手機那邊）

1. **打開開發者選項**：
   設定 → 關於手機 → 點「**版本號碼**」連按 7 次
2. **開 USB 偵錯**：
   設定 → 系統 → 開發者選項 → **USB 偵錯** ON
3. **接 USB**（建議用原廠或品質好的線，便宜線可能只能充電）
4. 手機跳「**允許這台電腦進行 USB 偵錯？**」→ 勾「永遠允許」、點允許

> 沒跳對話框？拔線再插、或重啟手機。對話框只在「電腦 USB 偵錯指紋」第一次看到手機時跳。

### 確認電腦看得到手機

```bash
# Linux 套件：第一次需要裝 adb
sudo apt install android-tools-adb         # Ubuntu/Debian
# 或裝 Android Studio，adb 在 ~/Android/Sdk/platform-tools/

adb devices
# 應該看到：
# List of devices attached
# RFXXXXXXXX   device                     ← 這行有 "device" 才 OK
```

| 狀態 | 意義 | 處理 |
|---|---|---|
| `device` | 已授權，可用 | ✓ |
| `unauthorized` | 還沒授權 | 看手機螢幕點允許 |
| `offline` | adb daemon 卡住 | `adb kill-server && adb start-server` |
| `no permissions` | Linux udev 規則沒設 | 安裝 [android-sdk-platform-tools-common](https://packages.debian.org/sid/android-sdk-platform-tools-common) 或加 user 到 plugdev group |
| （沒列出）| 線 / 偵錯 / 驅動 | 換 USB 線、重啟手機 |

```bash
# Flutter 也要看得到
flutter devices
# 例：
# Pixel 7 (mobile) • 1234ABCD • android-arm64 • Android 14 (API 34)
```

### 起 app（用 dev.sh）

```bash
cd /home/neil/proj/cwa_app
./scripts/dev.sh --android
```

腳本做了：

1. 殺殘留 dart server
2. 啟動 Serverpod（背景）
3. 等 server ready
4. **跑 `adb reverse tcp:8080 tcp:8080`**（手機 localhost:8080 → 你電腦的）
5. `flutter run -d <手機 id>`

按 `r` hot reload、`R` hot restart、`q` 結束。Ctrl-C 兩邊一起收。

### 為什麼要 `adb reverse`

手機 app 程式碼裡寫 `http://localhost:8080`——但**手機自己的 localhost** 是手機 OS 本身，不是你的 Linux。`adb reverse tcp:8080 tcp:8080` 開一個反向 tunnel，**讓手機 localhost:8080 自動轉發到 PC 的 localhost:8080**。

替代方案是改 `cwa_app_flutter/assets/config.json` 的 `apiUrl` 成你 PC 的 LAN IP（`http://192.168.x.x:8080`），但每次換網路 IP 都要改，不如 adb reverse 乾淨。

### Android 上的 GPS

Geolocator 在 Android 會跳系統權限對話框。第一次：

1. App 啟動 → 跳「允許 cwa-app 取得這台裝置的位置？」
2. 點「**僅在使用 app 時**」即可
3. Hero 顯示 GPS 座標 + 雨勢

若一直「定位中…」：
- 走到窗邊或室外（室內 GPS 收訊弱）
- 確認手機系統設定 → 位置 ON
- 模擬器：Extended Controls → Location → 設一組座標（例如 25.0478, 121.5170 台北車站）

### 常見故障

**`flutter run` 噴 `Multiple devices found`**
你電腦同時連著手機 + emulator + Chrome。腳本會自動挑第一個 Android 裝置；想指定特定機跑：
```bash
flutter run -d 1234ABCD
```

**App 起得來但打 server 失敗**
看 hero 紅字。若是 `Failed to fetch / Connection refused` → adb reverse 沒生效，手動跑：
```bash
adb reverse tcp:8080 tcp:8080
adb reverse tcp:8081 tcp:8081
adb reverse --list   # 確認看得到
```

**Chrome 還連著 server 但手機要求一直 fail**
Serverpod log 看一下有沒有 inbound 請求。沒有的話表示 adb reverse 沒走通——確認手機跟 PC USB 連線還在（拔線會自動失效）。

**改了 server 的 endpoint，手機沒反映**
跟 Chrome 一樣：要重啟 server（Ctrl-C dev.sh → 重跑）並按 `R` 做 hot restart 讓 client SDK 重 init。

---

## iOS

### 為什麼麻煩

iOS app 必須在 macOS 上用 Xcode build——這是 Apple 的硬規定。你的開發機是 Linux，**本機 build 直接出局**。

### 路線：Codemagic 雲端 build（[plan.md](../plan.md) D3 決策）

1. 註冊 [Codemagic](https://codemagic.io/) 免費帳號（連 GitHub）
2. 在專案根加一個 `codemagic.yaml`（之後另開 task 做）
3. push 到 GitHub → Codemagic 自動 build iOS .ipa → 上 TestFlight
4. 手機裝 TestFlight app → 收 invite → 裝測試版

額外成本：

- Apple Developer Program **$99/年**（上 TestFlight 必需）
- Codemagic 免費 tier：每月 500 build 分鐘，個人 app 用不完

### 短期建議

**先把 Android 玩順、上 Play Store internal testing**（不用 99 美元、立刻能裝）。iOS 等核心功能（GPS、路徑監控、推播）都定型再啟動 Codemagic 流程，避免每次小改都跑雲端 build 浪費時間。

---

## 進階：emulator 跑

不想接實機？用 emulator：

```bash
# 列已建好的 emulator
flutter emulators

# 起一台
flutter emulators --launch Pixel_7_API_34

# 然後 ./scripts/dev.sh --android 會自動挑到 emulator
```

emulator 也支援 adb reverse，所以連 server 的方式一樣。GPS 要在 emulator 的 Extended Controls 手動餵座標（emulator 本身沒有 GPS 晶片）。
