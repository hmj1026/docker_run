# POSDEV Docker 開發環境

## ✨ 新功能：統一 Composer & PHPUnit 環境 + 程式碼覆蓋率支援

所有 PHP 版本（5.6, 7.4, 8.0, 8.1, 8.2, 8.3）現已內建對應的最高 LTS 版本 Composer、PHPUnit 以及 Xdebug，可直接產生程式碼覆蓋率報告。

| PHP 版本 | Xdebug 版本 | 覆蓋率模式 |
|---------|------------|---------|
| 5.6     | 2.5.5      | `xdebug.coverage_enable=1`（預設啟用） |
| 7.4+    | 3.x        | `xdebug.mode=coverage`（step debug 預設關閉） |

📖 **詳細文件**: [docs/PHP_COMPOSER_PHPUNIT_SETUP.md](docs/PHP_COMPOSER_PHPUNIT_SETUP.md)

🧪 **快速測試**:
```bash
bash scripts/test-versions.sh
```

---

## 快速開始

如果您已經有 Laragon 環境，只需 3 步驟即可切換到 Docker：

```bash
# 1. 複製並設定環境變數
cp .env.example .env
# 編輯 .env，確認路徑正確（見下方「環境設定」）

# 2. 停止 Laragon（避免 PORT 衝突）
# 手動停止 Laragon 所有服務

# 3. 啟動 Docker 環境
docker compose build --no-cache
docker compose up -d

# 4. 訪問網站
# https://www.posdev.test/dev3/
```

## 前置需求

所有平台均需：
- Docker with Compose v2 plugin（`docker compose version` 可確認）
- 各專案目錄已存在（pos_dev、yii_framework、www.posdev）
- hosts 檔案已設定：`127.0.0.1 www.posdev.test`

| 平台 | Docker 安裝方式 | 路徑格式 |
|------|----------------|---------|
| Linux / WSL2 | Docker CE + Compose v2 plugin；需啟用 systemd | `/home/<username>/projects/...` |
| macOS | [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)（Compose v2 內建） | `/Users/<username>/projects/...` |
| Windows (WSL2) | WSL2 內安裝 Docker CE（效能最佳）或 Docker Desktop with WSL2 backend | `/home/<username>/projects/...` |
| Windows (Docker Desktop) | [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/) | `C:/Users/<username>/projects/...`（正斜線） |

## 專案目錄結構要求

本專案採用**分散管理模式**，目錄結構如下：

```
/home/<username>/projects/
├── pos_dev/              # POS 主程式（獨立開發目錄）
├── yii_framework/          # Yii 1.1 框架（共用）
└── www.posdev/             # Web 根目錄
    ├── dev/               # 商戶 dev3 入口
    ├── xxoo/              # 商戶 xxoo 入口
    ├── pos_dev/          # ⚠️ 符號連結或副本（指向獨立的 pos_dev）
    └── yii_framework/      # ⚠️ 符號連結或副本（指向獨立的 yii_framework）
```

### 容器內掛載對應關係

Docker 會將以下目錄掛載到容器內：

| Host 路徑                      | 容器內路徑                          | 說明                |
|--------------------------------|-----------------------------------|---------------------|
| `<projects>/pos_dev`           | `/var/www/www.posdev/pos_dev`   | POS 主程式        |
| `<projects>/yii_framework`    | `/var/www/www.posdev/yii_framework`| Yii 框架           |
| `<projects>/www.posdev`        | `/var/www/www.posdev`             | Web 根目錄（含商戶）|

> `<projects>` 依平台而異，見上方「前置需求」路徑格式。實際路徑以 `.env` 設定為準。

**重要說明：**
- `pos_dev` 和 `yii_framework` 使用獨立目錄管理，便於版本控制
- `www.posdev` 下的同名目錄會被 Docker 掛載覆蓋
- 所有修改在 Host 端的 `/home/<username>/projects/pos_dev` 會即時同步到容器
- 實際生效來源以 `.env` 為準
- 關於 WSL / Windows 路徑、`/dev3/` 路由、`main.php` 與 `dev3.php` 的完整關係，請看 [docs/ZDPOS_PATH_AND_BOOTSTRAP.md](docs/ZDPOS_PATH_AND_BOOTSTRAP.md)

## Docker 專案結構（本儲存庫）

- `docker-compose.yml`：nginx/php/mysql 服務定義
- `.env`：版本、路徑、Port、DB 參數
- `nginx/conf.d/www.posdev.test.conf`：虛擬主機設定（預設強制 HTTPS）
- `php/php{56,74,80,81,82,83}/`：各版本 PHP Dockerfile
- `mysql/init/`：資料庫初始化 SQL（不納入版本控制）
- `scripts/`：版本切換、憑證產生等工具腳本


## 環境設定

### 首次設定檢查清單

在執行 `docker compose up` 之前，請確認：

#### 1. 確認專案目錄結構正確
```bash
# 檢查獨立目錄是否存在 pos_dev 為 V1資料夾假定名稱，請替換成實際資料夾資訊
ls /home/<username>/projects/pos_dev
ls /home/<username>/projects/yii_framework
ls /home/<username>/projects/www.posdev

# www.posdev 應該包含商戶目錄（dev, xxoo 等）
ls /home/<username>/projects/www.posdev
```

#### 2. 設定 .env 環境變數
```bash
# 複製範本
cp .env.example .env

# 編輯 .env，依作業系統填入對應路徑格式（見 .env.example 說明）：
PROJECT_PATH=/home/<username>/projects/pos_dev
YII_FRAMEWORK_PATH=/home/<username>/projects/yii_framework
WEB_ROOT_PATH=/home/<username>/projects/www.posdev
```

#### 3. 設定資料庫連線（重要！）
所有商戶配置檔必須將資料庫 host 改為 `mysql`：

**修改檔案：**
- `www.posdev/dev/protected/config/dev.php`（或 db.php）
- `www.posdev/xxoo/protected/config/xxoo.php`
- 其他商戶的相同檔案

**修改內容：**
```php
'db' => array(
    'connectionString' => 'mysql:host=mysql;dbname=pos_dev',  // ⚠️ host 必須改為 mysql
    'username' => 'root',
    'password' => '',
    // ...
),
```

**錯誤示範：**
- ❌ `host=localhost`
- ❌ `host=127.0.0.1`

**正確示範：**
- ✅ `host=mysql`

#### 4. 設定 hosts 檔案
```bash
# Windows: 編輯 C:\Windows\System32\drivers\etc\hosts（需管理員權限）
# macOS/Linux: 編輯 /etc/hosts（需 sudo）

# 添加以下行：
127.0.0.1 www.posdev.test
```

#### 5. 確認 PORT 未被占用
```bash
# Linux / macOS:
lsof -i :80
lsof -i :443
lsof -i :3306

# Windows (PowerShell):
# netstat -ano | findstr :80
# netstat -ano | findstr :443
# netstat -ano | findstr :3306
```

#### 6. 確認 SSL 憑證存在
```bash
ls nginx/ssl/
# 應該有 laragon.crt 和 laragon.key
# 若不存在，執行 bash scripts/generate-cert.sh
```

#### 7. 確認 Docker 正在運行
```bash
docker ps  # 應該顯示容器列表（可能為空）

# Linux / WSL2 (Docker CE):
systemctl status docker

# macOS / Windows (Docker Desktop): 確認 Docker Desktop 已啟動
docker info >/dev/null 2>&1 && echo "Docker is running"
```

## 啟動
```bash
# 建置並啟動
docker compose build --no-cache
docker compose up -d

# 查看狀態
docker compose ps

# 追 logs
docker compose logs -f nginx
docker compose logs -f php
docker compose logs -f mysql
```

## 服務存取
- 瀏覽器：`https://www.posdev.test/dev/`（預設 301 轉 HTTPS）
- PHP-FPM：容器內 9000（nginx 已配置 fastcgi_pass php:9000）
- MySQL：`mysql://root@localhost:3306/pos_dev`（容器內用 host `mysql`）

## 產生自簽憑證
```bash
bash scripts/generate-cert.sh [domain]  # 預設 www.posdev.test；輸出到 nginx/ssl/laragon.{crt,key}
```
- 產生後需 `docker compose restart nginx`；瀏覽器仍需將 `nginx/ssl/laragon.crt` 加入信任。

## 切換 PHP / MySQL 版本

### 互動式模式（推薦）
無參數執行，從選單選擇版本（避免輸入錯誤）：
```bash
bash scripts/switch-version.sh
```

### 命令列模式（含驗證）
直接指定版本（會自動驗證版本是否支援）：
```bash
bash scripts/switch-version.sh 80 8.0
```

### 支援的版本
- **PHP**: 56, 74, 80, 81, 82, 83
- **MySQL**: 5.7, 8.0, 8.4

### 套用變更
修改版本後需重啟容器：
```bash
docker compose down && docker compose up -d --build
```

## 程式碼覆蓋率

所有 PHP Dockerfile 均已預裝 Xdebug，可直接執行覆蓋率報告。

### 產生覆蓋率報告

```bash
# Text 報告（快速確認）
docker exec -i -w //var/www/www.posdev/<project> pos_php \
  phpunit -c protected/tests/phpunit.xml --coverage-text

# HTML 報告（視覺化）
docker exec -i -w //var/www/www.posdev/<project> pos_php \
  phpunit -c protected/tests/phpunit.xml \
  --coverage-html protected/tests/coverage/html
```

### PHP 版本與 Xdebug 對照

| PHP 版本 | Xdebug 版本 | 預設行為 | Step Debug 啟用方式 |
|---------|------------|---------|------------------|
| 5.6     | 2.5.5      | 覆蓋率啟用，step debug 關閉 | `xdebug.default_enable=1` in ini |
| 7.4~8.3 | 3.x        | 僅覆蓋率，不影響 web 效能 | `XDEBUG_MODE=debug` 環境變數 |

### 故障排除

```bash
# 確認 Xdebug 版本與設定
docker exec -i pos_php php --ri xdebug | grep -E "version|mode|coverage"

# PHP 5.6 預期輸出（Xdebug 2.5.5）：
# xdebug.coverage_enable => On => On

# PHP 7.4+ 預期輸出（Xdebug 3.x）：
# xdebug.mode => coverage => coverage
```

---

## 常見問題
- 「連線不是私人連線」：自簽憑證，請信任 `nginx/ssl/laragon.crt` 或改用 HTTP。
- 500 / `CDbConnection failed to open the DB connection`：
  - 確認 `protected/config/dev3.php` 的 DB host 指向 `mysql`，帳密與 MySQL 容器一致。
  - 確認 MySQL 容器有對應 DB/使用者。
- 找不到 `../yii_framework`：請確保 `.env` 路徑與 `docker-compose.yml` 的卷掛載一致（如上預設）。
- 掛載失敗：確認 `.env` 路徑格式正確（Linux/WSL2: `/home/...`，macOS: `/Users/...`，Windows: `C:/Users/...`），並確認 Docker 服務正在執行。

## 停止 / 清理
```bash
docker compose down          # 停止並移除容器
docker compose down -v       # 同時移除 volumes（會刪資料庫）
docker system prune -f       # 清理未使用資源
```

## MySQL 初始化
- 本專案不追蹤初始化 SQL，請自行準備資料庫：
  - 建立資料庫與使用者（可在容器內 `docker compose exec mysql mysql -uroot` 手動執行）。
  - 若有匯入檔，放在 `mysql/init/`（未版控）後 `docker compose down && docker compose up -d` 會自動匯入。
  - 也可在容器內直接匯入：`docker compose exec -T mysql mysql -uroot < your.sql`
- 調整 `.env` 確認 `MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD` 與你的初始化腳本一致。

## 驗證安裝

啟動後，請執行以下檢查確認環境正常：

### 1. 檢查容器狀態
```bash
docker compose ps

# 應該顯示 3 個容器都是 Up 狀態：
# pos_nginx    Up    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
# pos_php      Up    9000/tcp
# pos_mysql    Up    0.0.0.0:3306->3306/tcp
```

### 2. 檢查 Nginx 配置
```bash
docker compose exec nginx nginx -t

# 應該顯示：
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 3. 檢查 PHP 版本
```bash
docker compose exec php php -v

# 應該顯示當前 .env 設定的 PHP 版本（例如 PHP 5.6.40）
```

### 4. 檢查 MySQL 連線
```bash
docker compose exec mysql mysql -uroot -e "SHOW DATABASES;"

# 應該看到 pos_dev_2（或您設定的資料庫名稱）
```

### 5. 檢查檔案掛載
```bash
# 進入 PHP 容器
docker compose exec php bash

# 檢查目錄結構
ls -la /var/www/www.posdev/
# 應該看到 dev/, xxoo/, pos_dev/, yii_framework/ 等目錄

# 檢查 pos_dev 內容
ls -la /var/www/www.posdev/pos_dev/
# 應該看到 index.php, protected/ 等檔案

exit
```

### 6. 測試網站訪問
```bash
# 在瀏覽器開啟
https://www.posdev.test/dev/

# 或使用 curl 測試
curl -k https://www.posdev.test/dev/

# 應該看到網頁內容（不是 404 或 502）
```

### 7. 確認 Xdebug（覆蓋率驅動）
```bash
# 確認 Xdebug 已載入
docker exec -i pos_php php -m | grep -i xdebug
# 應顯示：xdebug

# 確認覆蓋率可用（不應出現 "No code coverage driver is available"）
docker exec -i -w //var/www/www.posdev/<project> pos_php \
  phpunit -c protected/tests/phpunit-fast.xml --coverage-text 2>&1 | head -5
```

### 8. 檢查日誌
```bash
# 檢查 Nginx 錯誤日誌
docker compose logs nginx | tail -20

# 檢查 PHP 錯誤日誌
docker compose logs php | tail -20

# 檢查 MySQL 錯誤日誌
docker compose logs mysql | tail -20

# 應該沒有嚴重錯誤（ERROR 或 CRITICAL）
```

### 常見驗證失敗原因

| 問題現象 | 可能原因 | 解決方式 |
|---------|---------|---------|
| 容器無法啟動 | PORT 被占用 | 停止 Laragon 或其他服務 |
| 404 錯誤 | Nginx 配置或路徑掛載錯誤 | 檢查 .env 路徑設定 |
| 商戶目錄 404 (dev3, 186 等) | docker-compose.yml 缺少該商戶的個別掛載 | 在 nginx 和 php 的 volumes 區段加入 `${WEB_ROOT_PATH}/<dir>:/var/www/www.posdev/<dir>` |
| zdnStorage 權限錯誤 | 新建目錄權限不正確 | 等待 60 秒（背景修復程序會自動修正），或重啟容器 |
| 500 錯誤 | PHP 錯誤或資料庫連線失敗 | 檢查日誌，確認 DB host=mysql |
| 找不到 yii_framework | 路徑掛載錯誤 | 確認 .env 中 YII_FRAMEWORK_PATH |
| 資料庫連線失敗 | DB host 未改為 mysql | 修改商戶配置檔 |

---

## 問題回報

如遇問題，請提供以下資訊：
1. `docker compose ps` 輸出
2. `docker compose logs [服務名]` 錯誤訊息
3. `.env` 配置（移除敏感資訊）
4. 錯誤截圖或瀏覽器開發者工具 Console 訊息
