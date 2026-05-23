# book.md — cwa_app 從零到 Phase 0 完成的思維手冊

> 寫給未來的你（或任何想學 LLM 怎麼幫忙開專案的人）。
> 不是 step-by-step cookbook，是**為什麼我這樣選**的記錄。
> 包含我犯的錯、停下來的時機、回頭改的決定。

---

## 序章 — 這本書是什麼，不是什麼

### 是什麼

- **思維手冊**。我每一步在想什麼、為什麼選 A 不選 B、為什麼有時候會停下來問你。
- **錯誤紀錄**。我跑錯指令、給錯建議、知識過時的時候，會誠實寫進來（不掩蓋）。
- **判斷模板**。希望你看完之後，下次自己開新專案時，腦袋裡有一個「Claude 會怎麼想」的副本可以參考。

### 不是什麼

- ❌ 不是「複製貼上指令」教學。同樣的決策搬到別的專案不一定對。
- ❌ 不是 Serverpod / Flutter / Neon 的官方教學（那是 docs 的工作）。
- ❌ 不是說「LLM 永遠對」。我犯了至少 3 個錯，都寫進來了。

### 怎麼讀

按章節順序讀。每章結尾有 **「教訓」** 一行小結，把該章的判斷模式抽出來。如果只想看精華，掃所有「教訓」就好。

---

## 第 0 章 — 起點與第一個矛盾

### 你給我的指示

> 「根據新的專案 你看看第一步可以建立什麼 先告訴我 還有 以下工具
> pytest mypy ruff
> 這些都要管理我的專案」

### 我為什麼沒有照做

照做最快 — 開 terminal、`uv tool install pytest mypy ruff`、寫個 `pyproject.toml`，5 分鐘搞定。

但**我先停了下來**，因為兩件事互相矛盾：

1. 專案的 [CLAUDE.md](CLAUDE.md) 鐵則 R1 寫得很大：「**全 Dart，不引入其他語言到 server**」
2. 我的記憶（`feedback_no_python_in_cwa_app.md`）有一條：使用者明確拒絕在這專案用 Python

而 `pytest` / `mypy` / `ruff` **都是 Python 工具**。

### 我怎麼處理矛盾

我沒有預設立場，先 **列出三種可能解釋** 給你選：

- (A) 你想要的是 Dart 等價工具（dart test / dart analyze / dart format）
- (B) 你搞錯目錄，這是要裝到 cwa-tg-bot 的
- (C) 你真的想打破 R1，那需要明確認可

你選了 (A)，問題解決，沒留下任何技術債。

### 如果我沒停下來會怎樣

最糟的情況：我裝了 Python toolchain，寫了 `pyproject.toml`，加了 GitHub Actions 跑 ruff/mypy/pytest。下次你想跑 `dart test`，發現 CI 在跑 Python lint 而你的專案根本沒有 .py 檔。**修起來比一開始問清楚痛 10 倍**。

### 教訓

> **使用者指示 ≠ 應該做的事。當指示跟既有規則衝突，先把矛盾擺到桌面上，給選項，不要自己猜。**

---

## 第 1 章 — 環境審計（裝東西前先看）

### 我做了什麼

在動任何安裝指令之前，我跑了 5 個檢查：

```bash
which dart && dart --version           # ❌ DART_NOT_FOUND
which flutter && flutter --version     # ❌ FLUTTER_NOT_FOUND
which serverpod && serverpod version   # ❌ SERVERPOD_NOT_FOUND
which docker && docker --version       # ❌ DOCKER_NOT_FOUND
which git && which curl                # ✅ git 2.34.1, curl 7.81.0
```

然後檢查作業系統與 PATH 環境：

```bash
lsb_release -a                         # Ubuntu 22.04.5 LTS
echo $SHELL                            # /bin/bash
ls ~/.bashrc ~/.profile                # bashrc 存在 → 改這個
ls ~/development ~/flutter ~/sdk       # 都不存在 → 可以隨便挑放
dpkg -l | grep -E "(curl|git|unzip|xz-utils|zip|libglu1-mesa)"
                                       # ✅ Flutter 需要的 apt deps 都齊了
```

### 為什麼不直接 `apt install` 開始裝

三個理由：

1. **盲裝會撞**。如果你已經有 `~/development/flutter/` 是別的版本，我蓋過去就害你回不去。
2. **裝的指令會因發行版/版本變動**。Ubuntu 20 跟 24 不同、有 snap 跟沒 snap 不同、用 zsh 跟 bash 改的 rc 檔不同。先查清楚才能下精準指令。
3. **可能根本不用裝**。如果你 `which docker` 回 `/usr/bin/docker`，我就不該再講「現在來裝 docker」這種廢話。

### 教訓

> **動指令之前，先「ls 一下現場」。20 秒的探勘可以省 20 分鐘的回滾。**

---

## 第 2 章 — Flutter SDK 安裝（一裝得二）

### 一個小知識救了一個指令

Flutter SDK 內含 Dart SDK。所以原本以為要裝 Dart + Flutter 兩個東西，實際上：

```bash
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
# 裝完同時有 flutter + dart
```

我沒有用 `apt install dart` 或 `snap install flutter` — 用 git clone 是 Flutter 官方推薦：版本受控、不會跟系統套件管理員打架、要砍直接 `rm -rf ~/development/flutter`。

### 為什麼是 `~/development/flutter` 不是 `/opt/flutter`

- `~/development/`：使用者自己的東西，**不用 sudo**
- `/opt/`：要 sudo，系統級，砍掉/升級要動權限

少用 sudo 是好習慣 — 系統級安裝犯錯的代價是「整台 OS 壞掉」，user 級安裝犯錯只是「我家目錄底下有垃圾」。

### PATH 編輯的最小侵入原則

只加一行：

```bash
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
```

不改其他人寫的東西、不重排既有 PATH、不加 alias、不裝 shell plugin。**只解決眼前的問題**。

### `flutter doctor` 抱怨 Android toolchain — 為什麼不慌

跑 `flutter doctor` 會看到：

```
[✗] Android toolchain - Unable to locate Android SDK.
[✗] Linux toolchain - clang++ is required...
```

新手會慌覺得「不是裝壞了嗎？」。但我**有意忽略它**，因為：

- 我們現在做 Phase 0（後端 skeleton），完全用不到 Android SDK
- Phase 2（Flutter app）才需要 Android toolchain
- 提前裝 Android Studio 要花你 30 分鐘下載 + 4 GB 空間，且裝完現在也派不上用場

「該裝的時候再裝」是個被低估的原則。早裝早累。

### 教訓

> **理解工具鏈的層次關係，能省一半的安裝指令。「裝它」之前先問「現在真的需要它嗎？還是 Phase N 才用得到？」**

---

## 第 3 章 — Docker 的「為何要」

### 你問了關鍵問題

> 「為何要 docker」

這個問題救了我。

### 我為什麼差點直接裝

Serverpod 官方 docs 第一頁的 quick start 寫的就是 `docker compose up`。我幾乎沒思考就把 Docker 列進「Step 2」，跟著官方教學走。**這是錯的**。

### 我反省後的論述

Serverpod 的 docker-compose 裡裝兩個東西：

| 服務 | 用途 | 一定要 Docker 嗎？ |
|---|---|---|
| Postgres | DB | 不一定 — 可以用雲端（Neon）或 apt 裝 native |
| Redis | cache、pub/sub、cross-instance coordination | 單機開發**根本可以關掉** |

也就是說「裝 Docker」這個動作，**邏輯上**等於「我選擇本機跑 Postgres + Redis container」。但**這不是唯一答案**。

我給了你 A/B/C 三個方案：

- **A. Docker**：方便、跟 prod 一致、但多 daemon
- **B. apt native install**：輕量、但要管 user/port
- **C. 雲端 Neon**：跟 prod 完全一致、本機零負擔

### 你選 C，整個 Docker 消失

選 C 後，下游一連串簡化：

- 不用 `sudo apt install docker.io`（不用動系統）
- 不用 `usermod -aG docker $USER`（不用改權限）
- 不用 `docker compose up -d`（不用記額外指令）
- 不用 `docker-compose.yaml` 維護（Serverpod 產的那份直接忽略）

**一個「為何要」的問題，省了 5 個下游動作**。

### Redis 關掉的論證

Redis 關掉會失去：分散式 cache、multi-instance pub/sub。

但 Phase 0–3 我們：
- 只跑單一 Serverpod instance → 不需要 multi-instance pub/sub
- Future Calls 存 Postgres `serverpod_future_call` table → **不靠 Redis**
- 簡單 CRUD → 不需要分散式 cache

**現在不需要 = 現在不裝**。等真的需要時（multi-instance / streaming endpoint）再回頭開。

### 教訓

> **官方教學的「Step 1」常常是給典型使用情境設計的。問「我們是不是典型？」可以省下整個依賴。**

---

## 第 4 章 — Neon decision：shared vs dedicated project

### 我一開始建議「借 cwa-tg-bot 的 Neon project」

理由是：「Neon 免費只能開一個 project，所以兩個 app 必須共用」。

**這個論述是錯的，因為我的知識過時了。**

### 你的一句話救了我第二次

> 「還是說免費額度 可以開一個以上的 project?」

我本來會繼續按錯誤前提走。你問了，我才意識到要驗證。

### 我怎麼驗證

用 `WebFetch` 抓 neon.com/pricing 即時資料。結果：

```
✅ 100 projects per organization（不是 1 個！）
✅ 0.5 GB storage per project（不是 pooled）
✅ 100 CU-hours per project（不是 pooled）
```

**我原本的論述完全翻轉**：
- 共用 project 的「好處」是省 project 額度 → 但 project 上限 100，根本不缺
- 共用 project 的「壞處」是兩 app 互相吃 storage / compute 配額 → 反而變成嚴重缺點

### 我怎麼回滾錯誤決定

不只更新口頭建議，**回頭改三個地方**：

1. `plan.md` 的 D5 決策表（劃掉「借 project」，改成「新 project」）
2. `memory/project_cwa_app_dev_infra.md`（整段論述重寫）
3. `memory/reference_cwa_tg_bot.md`（「shared project」改成「separate project」）

**未來的我（下次對話）會讀到正確的版本**，不會被舊論述誤導。

### 教訓兩條

> 1. **不要相信腦袋裡的「上限數字」**。雲端服務的免費額度變動頻繁，**定價頁是 source of truth**，用 WebFetch 即時抓。
> 2. **決策翻轉時，把翻轉本身寫進去**。「為什麼從 A 改 B」比結論本身更有價值 — 未來自己回頭看才知道哪些假設變了。

---

## 第 5 章 — Serverpod CLI 是什麼

### 你問了：「這是要做什麼」

我前面講「裝 Serverpod CLI」太快，沒解釋它是什麼。你問了我才意識到自己跳步驟。

### 我的回答結構

**先講指令做什麼**（4 行各自）→ **再講 CLI 本身的用途**（4 個子命令）→ **再給類比**（rails / django-admin / create-next-app）。

從「具體」到「抽象」到「類比」，三層理解。

### Serverpod CLI 特殊在哪

不像 rails 只管 backend，**Serverpod 同時管 server + 自動生成 client SDK**。所以：

- 改一個 endpoint → 跑 `serverpod generate` → server 端序列化 + Flutter 端 client SDK 一起更新
- 改一個 model → 跑 `serverpod create-migration` → SQL migration 檔產出來
- 改一個 protocol → 跑 `serverpod generate` → DTO 兩邊同步

這就是 CLAUDE.md R5「改 endpoint / protocol 後一定要跑 `serverpod generate`」的由來。**沒跑 generate，Flutter 端會看不到你的改動**。

### `~/.pub-cache/bin` 不在 PATH 的小坑

```bash
dart pub global activate serverpod_cli
# Warning: Pub installs executables into $HOME/.pub-cache/bin, which is not on your path.
```

Flutter SDK 加了 `~/development/flutter/bin` 到 PATH，但**沒順便加** `~/.pub-cache/bin`。Dart 全域 package 預設裝那邊，要自己補一條：

```bash
echo 'export PATH="$HOME/.pub-cache/bin:$PATH"' >> ~/.bashrc
```

這種「裝完一個工具，但找不到」的坑，第一次遇到要 30 分鐘 debug。**看 warning 訊息**就能秒解。

### 教訓

> **解釋技術概念時，先具體後抽象再類比。跳到抽象太快，學的人會卡在「但這到底是什麼」。**

---

## 第 6 章 — `serverpod create` 與已存在的目錄

### 一個尷尬的命名衝突

`serverpod create cwa_app` 會建一個叫 `cwa_app/` 的資料夾。但**我們已經身在 `/home/neil/proj/cwa_app/` 裡了**（裡面有 plan.md、README.md、CLAUDE.md、.git）。

### 三個方案我攤開分析

| 方案 | 結果 | 評估 |
|---|---|---|
| A. 在 /tmp 跑，搬 sub-package 進來 | 平鋪在現有 dir | ✅ 推薦 |
| B. 接受巢狀 | `cwa_app/cwa_app/cwa_app_server/...` | ❌ 醜 |
| C. 把現有檔搬走再搬回 | 過程混亂 | ⚠️ 風險高 |

「攤開選項 + 標推薦度」是我給你選的標準格式。你會看到我**從不只給一個方案**，而是 2-4 個比較，**附上推薦度但不強迫**。原因：你比我更了解你的環境與偏好，**最終決策權永遠在你**。

### 執行時遇到的意外：Dart workspace 結構

跑完 `serverpod create cwa_app` 我去 `/tmp/cwa_app_init/cwa_app/` 看，發現產出**不只 3 個 sub-package**：

```
cwa_app/
├── cwa_app_server/      ← 預期的
├── cwa_app_client/      ← 預期的
├── cwa_app_flutter/     ← 預期的
├── pubspec.yaml         ← 沒料到 — workspace root pubspec
├── pubspec.lock
├── .dart_tool/
├── .github/workflows/
├── .vscode/
└── .gitignore
```

`pubspec.yaml` 裡寫：

```yaml
name: _
workspace:
  - cwa_app_client
  - cwa_app_server
  - cwa_app_flutter
```

這是 **Dart workspace**。如果只搬 3 個 sub-package，外層的 workspace root 沒搬，`pub get` 會找不到依賴關係。**整批要搬**。

### 我為什麼當下沒慌

因為**事前先 ls 過**：

```bash
ls -la /tmp/cwa_app_init/cwa_app/
```

看到 8 個項目後才動手搬。如果我盲目跑 `mv cwa_app_*  /target/` 三條，就只搬走 3 個 sub-package，外層 `pubspec.yaml` 留在 /tmp，之後 `dart pub get` 會炸。

### .gitignore 衝突的處理

新舊 .gitignore 內容不同：

- **舊的**（你寫的）：4920 字元，涵蓋 Flutter / iOS / Android / Firebase / 密碼
- **新的**（Serverpod 產的）：105 字元，只有 `.dart_tool/` 跟 `pubspec_overrides.yaml`

我**保留舊的**（功能完全覆蓋新的），只**補一條** `pubspec_overrides.yaml`（舊的沒有）。

選擇邏輯：「**保留 superset，補缺漏的條目**」。

### 搬完要重跑 `pub get` 的細節

`.dart_tool/` 裡有絕對路徑快取。從 `/tmp/...` 搬到 `/home/...`，路徑變了，**workspace 解析會錯**。所以搬完立刻 `dart pub get` 重新建立 lookup。

跑完看到 `Got dependencies!` 才算搬家成功。

### 教訓

> **工具預設假設「乾淨空 dir」。現實常常不是。動手前先 ls 看「實際結構」，動手後立刻驗證「沒搞壞」。**

---

## 第 7 章 — 密碼洩漏事件（我犯的錯 + 你犯的錯）

這是這次過程最嚴重的一段，我必須誠實記錄。

### 你的錯：把完整 connection string 貼給我

```
postgresql://neondb_owner:npg_AszJu8jMged4@ep-cool-mud-aow1d8pp-pooler...
                          ^^^^^^^^^^^^^^^^ 真的密碼
```

### 為什麼這是「真的洩漏」

對話內容會：

1. **進我的 context window** — 整段對話我會持續看到，直到 session 結束
2. **被 Anthropic 伺服器 log 保留** — 用於安全、debug、policy 審查
3. **可能進入訓練資料**（雖然 Anthropic 政策說一般 API 對話不會，但這是政策保證不是技術不可能）

簡單講：**任何進入 LLM 對話的字串，從此你就要當作「世上又多了一份副本」**。

### 我立刻做了什麼

```
⚠️ 先停下來 — 安全問題
你把真的密碼貼到對話了...請馬上去 Neon 重置
```

不繼續任何工作、不假裝沒看到。**安全事件第一優先處理**，因為等你後續操作完成才講，密碼被誰拿到都不知道。

### 我犯的錯：自己跑 openssl 產密碼

為了幫你產新密碼，我跑了：

```bash
openssl rand -base64 32 | tr -d '/+=' | head -c 32
# → gUO6kXqlpJ6I5fZodIHNTVDu5uDvnOgP
```

**這也洩漏了**。因為 Bash 的輸出會回到我的 context。**我以為自己在幫你**，實際上等於剛剛叫你「不要貼密碼」自己就跑去看了一個密碼。

我立刻承認：

```
⚠️ 我搞砸了 — 我自己跑了那個指令，所以 gUO6kXqlpJ6I5fZodIHNTVDu5uDvnOgP 現在也在我的對話 context 裡，
等於洩漏。別用這條。
```

然後給正確流程：**你在你的 terminal 跑 openssl**，輸出不會經過我。

### 正確流程是什麼

1. **產密碼**：你的 terminal，不是經由我
2. **存密碼**：直接寫進 `passwords.yaml`，不貼對話
3. **設密碼到 Neon**：你貼到 Neon SQL Editor，不貼對話
4. **我從頭到尾不看到那條字串**

這個流程的核心：**LLM 對話 = 公開區。任何密碼/token/key 都不應該經過它**。

### 教訓三條

> 1. **威脅模型上，LLM 對話 = 已洩漏面**。敏感資訊永遠不貼。
> 2. **我自己也不該「為了幫忙」去看密碼**。要協助生成密碼，應該寫**指令給使用者**，不是自己跑指令然後告訴他結果。
> 3. **承認錯誤要快**。發現我做錯時，下一條訊息開頭直接 ⚠️ 我搞砸了，不掩飾、不轉移焦點。掩飾比錯誤本身更傷信任。

---

## 第 8 章 — Pooler vs Direct connection

### 你貼的 hostname 帶 `-pooler`

```
ep-cool-mud-aow1d8pp-pooler.c-2.ap-southeast-1.aws.neon.tech
                    ^^^^^^^ 
```

我立刻指出：**Serverpod 不能用 pooler**。

### 為什麼不能

Neon 的 pooler 是 **PgBouncer transaction mode**。這個 mode 的特性：

- 每個 SQL transaction 結束後，連線馬上被回收給 pool 重用
- **失去**：prepared statements、session variables、advisory locks、`LISTEN/NOTIFY`

Serverpod 的 `postgres` Dart 套件**重度依賴 prepared statements**（自動參數化 SQL、避免 SQL injection、效能優化）。Transaction-mode pooling 讓 prepared statements 在下個 query 找不到，**直接報錯**。

### 解法很簡單，但要知道才做得到

把 hostname 裡 `-pooler` 拿掉：

```
ep-cool-mud-aow1d8pp.c-2.ap-southeast-1.aws.neon.tech
                    ^^^ 沒有 -pooler 就是 direct
```

Neon 同時提供 pooled 跟 direct 兩個 endpoint。Dashboard 的 Connection Details 通常有 toggle 切換。

### 什麼時候才該用 pooler

- **Serverless**（Vercel / Lambda / Cloudflare Workers）：每次 invoke 都開新連線，pooler 幫忙 reuse
- **連線數爆炸的場景**：每秒幾百個短連線

Serverpod 是**長駐 process**，自己內部有 connection pool（預設 max 10），不需要外部 pooler。

### 教訓

> **中介層的「mode」比 hostname 更重要**。PgBouncer transaction mode、session mode、statement mode 各自打掉不同功能。看到「pooler」三個字，先問「打掉了什麼」。

---

## 第 9 章 — Neon UI 找不到 Roles 怎麼辦

### 問題

你截圖給我看，左側 sidebar 沒有「Roles」入口。我前面講「Branches → production → Roles」也找不到。Neon 新版 UI 把 role 管理藏得很深。

### 我怎麼跳出困境

不繼續猜 UI 路徑，**直接用 SQL Editor 改**：

```sql
ALTER USER neondb_owner WITH PASSWORD '<新密碼>';
```

這條 SQL 永遠有效，因為它是 Postgres 標準語法 — **無論 Neon UI 怎麼改版，SQL 不會變**。

### 這背後的思維

**UI 是包裝、協定/SQL 是核心。**

當 UI 卡住時，問自己：**這個 UI 是在發什麼指令？我能不能跳過 UI 直接發指令？**

對 Postgres 來說，幾乎所有管理動作都有對應 SQL：

| UI 操作 | SQL |
|---|---|
| Reset password | `ALTER USER ... WITH PASSWORD ...` |
| Create role | `CREATE ROLE ...` |
| Grant table access | `GRANT ... ON ... TO ...` |
| Create database | `CREATE DATABASE ...` |

對 GitHub 來說，UI 操作都有對應 `gh` CLI 或 REST API。對 Stripe / AWS / GCP 也一樣。

### 教訓

> **不要被 UI 困住。UI 是糖衣，協定/CLI/SQL 是本質。UI 改版時，本質永遠在。**

---

## 第 10 章 — 啟動驗證的層次

### 第一次跑（沒帶 --apply-migrations）

```
SERVERPOD initialized
Failed to get installed migrations: ... relation "serverpod_migrations" does not exist
WARNING: Table "serverpod_auth_idp_anonymous_account" is missing.
... (30 more)
```

**新手看到「WARNING」會慌**，以為東西壞了。但這個 warning **反而是好消息**。

### 為什麼是好消息

逐字拆解這個錯誤訊息：

1. `SERVERPOD initialized` → Serverpod 進程啟動成功 ✅
2. `Failed to get installed migrations` → 連到 DB 了 ✅（沒連到的話是 connection refused，不是這個錯）
3. `relation "serverpod_migrations" does not exist` → DB 是空的，正常 ✅（還沒 apply migration 當然沒這個 table）
4. `Table "serverpod_auth_idp_anonymous_account" is missing` → Serverpod 比較了 schema，發現 DB 沒這些 table → 又一次確認「連線正常 + 只是還沒 migrate」✅

**整段 error 全部都在說「連線成功 + 該 migrate 了」**。沒有任何一個字在說「連不到」。

### 學會讀「失敗訊息」的層次

錯誤訊息有兩種：

| 類型 | 例子 | 含意 |
|---|---|---|
| **連不到** | `Connection refused`、`Could not resolve host`、`SSL handshake failed`、`password authentication failed` | 真的有問題 |
| **連到了但內容不對** | `relation does not exist`、`column not found`、`permission denied`、`syntax error` | 連線 OK，邏輯問題 |

第二類其實**包含成功訊號**：能告訴你 `relation does not exist`，代表已經連到 DB 並查詢成功，只是查的目標不在而已。

### 第二次跑（帶 --apply-migrations）

```
applyMigrations: true
SERVERPOD initialized
Applied database migration: 20260523070729941
WebServer INFO: Webserver listening on http://localhost:8082
```

3 條訊息：(1) Migration 已套 (2) Server 起來了 (3) Web port listening。

**但 API server (8080) 跟 Insights (8081) 沒有 log 行**。新手會懷疑「是不是這兩個沒起來？」

### 我怎麼確認

不靠 log，**用作業系統 syscall 直接驗證**：

```bash
ss -tlnp | grep -E ":(8080|8081|8082)"
```

回應：

```
*:8080  users:(("dart:main.dart",pid=8549,fd=24))
*:8081  users:(("dart:main.dart",pid=8549,fd=23))
*:8082  users:(("dart:main.dart",pid=8549,fd=25))
```

3 個 port 都在 listen，pid 都是 8549（同一個 dart process）。**OS 比 log 更誠實**。

### 然後做最後驗證：curl 真的打 endpoint

```bash
curl -X POST http://localhost:8080/greeting/hello -d '{"name":"Neil"}'
{"message":"Hello Neil","author":"Serverpod","timestamp":"2026-05-23T11:20:19.832029Z"}
```

這條 curl 證明的事**遠超過你想像**：

1. ✅ TCP 連線到 8080
2. ✅ HTTP request 解析成功
3. ✅ Serverpod router 找到 `greeting/hello` endpoint
4. ✅ JSON body 反序列化（讀到 `name="Neil"`）
5. ✅ endpoint 邏輯執行（Dart code 跑了）
6. ✅ 結果序列化回 JSON
7. ✅ HTTP response 寫回

**一條 curl 驗證整個 stack**。比 100 行 unit test 更有說服力。

### 教訓

> **學會分層讀錯誤訊息。「沒成功」不等於「壞了」 — 有時候錯誤訊息本身就證明前面幾層全部 OK。**
> **再加：相信 OS、不要只相信 log。port 在不在 listen、process 在不在跑，用 `ss` / `ps` 看，不靠程式自報。**

---

## 第 11 章 — Phase 0 完成後的收尾

### 我做了三件「不寫程式碼」的事

1. **`TaskStop` 停掉背景 server** — 不再吃 Neon CU-hours 額度
2. **更新 [CLAUDE.md](CLAUDE.md) 的「開發指令」段** — 從「待補」改成實際可用的指令清單
3. **更新 [plan.md](plan.md) 的 Phase 0 checklist** — 完成的項目打勾，記錄 docker 移除的決策

### 為什麼這三件很重要

第一件**保護你的錢包**。Neon 免費 100 CU-hours/月，一個跑著的 idle Serverpod connection 不太會吃額度（Neon 5 分鐘 autosuspend），但**有條件就主動關**，不要養成「忘記關」的習慣。生產環境你會慶幸這個習慣存在。

第二件**保護未來的你**。CLAUDE.md 原本寫 `docker-compose up -d`，現在我們不用 Docker。如果不改，**3 個月後你回來看 CLAUDE.md**，會以為要先 `docker-compose up`，跑下去發現沒有 docker，浪費 20 分鐘 debug。**文件對齊現實是低成本高回報**。

第三件**保護未來的 LLM**。下次我（或其他 Claude session）打開 plan.md，看到 Phase 0 全打勾，知道可以直接進 Phase 1，不會重新跑 environment check。

### 文件對齊的小儀式

我每次做完一個有架構意義的決定，會問自己 3 個問題：

1. **plan.md 要不要改？**（決策表、checklist、階段拆解）
2. **CLAUDE.md 要不要改？**（鐵則、入口檔表、開發指令）
3. **memory 要不要改？**（project / feedback / reference / dev infra）

不是每次都全改。但**每次都問**。

### 教訓

> **「動完工」不等於「完工」。寫完 code 之後還有：清現場、改文件、存記憶。這三件少做一件，欠的債三天後就找上你。**

---

## 第 12 章 — 我的判斷模式總覽

把前 11 章的「教訓」濃縮成一張表，作為這本書的索引。

### 開工前

| 場景 | 我的反應 |
|---|---|
| 使用者指令跟既有規則衝突 | 停下來，給選項，不猜 |
| 要裝新工具 | 先 `which` 看現況 |
| 官方教學 step 1 是 X | 問「我們是不是典型？X 是不是必要？」 |
| 雲端服務的免費額度 | 不相信記憶，WebFetch 拿即時資料 |

### 動手中

| 場景 | 我的反應 |
|---|---|
| 工具要建檔/建 dir | 先 `ls` 看現有結構，再決定怎麼搬 |
| 多個方案猶豫 | 攤開 2-4 個比較表，標推薦但不強迫 |
| UI 找不到入口 | 跳過 UI，用協定/SQL/CLI 直接做 |
| 啟動失敗 | 分層讀錯誤訊息：連不到 vs 連到了但內容不對 |
| 不靠 log 證明 server 起來 | 用 `ss` / `ps` / `curl` 從 OS 層驗證 |

### 風險處理

| 場景 | 我的反應 |
|---|---|
| 使用者貼了密碼 | 立刻喊停，要求 reset，告知威脅模型 |
| 我自己不小心看到密碼 | 立刻 ⚠️ 承認、要求 reset、修流程 |
| 決策需要動到系統（sudo / 改 PATH） | 先講要做什麼，等使用者點頭 |
| 不可逆動作（force push / 刪 branch） | 永遠先問 |
| 可逆動作（編輯文件） | 直接做，做完報告 |

### 決策反轉

| 場景 | 我的反應 |
|---|---|
| 發現之前的決策依據錯了 | 不只口頭更正，改 plan.md + memory，留下「為什麼翻轉」 |
| 知識可能過時 | WebFetch 驗證，不靠記憶硬撐 |

### 收尾

| 場景 | 我的反應 |
|---|---|
| 階段完成 | 停背景 process、改 CLAUDE.md、改 plan.md、更新 memory |
| 完成回報給使用者 | 簡短列已完成項目 + 提下一步建議 + 等使用者拍板 |

---

## 結語 — 給未來看這本書的人

這本書的每一章都有一個共通結構：

```
1. 你給我一個指令或問題
2. 我先停下來想：有沒有矛盾？有沒有更好的方案？
3. 我把選項攤開給你看
4. 你選一個
5. 我執行 + 驗證
6. 我更新文件 + 記憶
```

第 2 步是這整套流程的關鍵。**「停下來想」這 5 秒，省下你後面可能要花的 5 小時 debug**。

如果你看完之後，下次自己（或跟 Claude）開新專案時：

- 動手前會問「現況是什麼」
- 看到「Step 1: Install X」會問「不裝會怎樣」
- 看到雲端服務數字會 WebFetch 驗證
- 看到 UI 卡住會想「SQL 怎麼寫」
- 動完工會問「文件要不要改」

那這本書就值了。

---

> 寫於 2026-05-23，cwa_app Phase 0 完成當天。
> 後續 Phase 1+ 的決策會繼續累積，這本書會繼續長大。
