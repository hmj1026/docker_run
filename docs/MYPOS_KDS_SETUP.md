# MyPOS KDS 本地開發環境建置指南

> 本文檔說明如何配置本地 Docker 開發環境，使其與測試環境 (www.pos.com) 保持一致。

## 目錄

1. [環境架構對照](#環境架構對照)
2. [環境需求](#環境需求)
3. [快速開始](#快速開始)
4. [詳細設定步驟](#詳細設定步驟)
5. [驗證安裝](#驗證安裝)
6. [常見問題排解](#常見問題排解)
7. [測試環境與本地環境對照表](#測試環境與本地環境對照表)

---

## 環境架構對照

### 測試環境 (www.pos.tw)

| 項目 | 設定值 |
|------|--------|
| **Web Server** | Nginx 1.24 |
| **PHP 版本** | PHP 5.6 |
| **資料庫** | MySQL 5.7 |
| **DB Host** | 192.168.2.246 |
| **專案路徑** | `/var/www/www.pos.com/mypos_kds` |
| **訪問 URL** | `https://www.pos.com/mypos_kds/public/` |

### 本地 Docker 環境

| 項目 | 設定值 |
|------|--------|
| **Web Server** | Nginx 1.24-alpine (Docker) |
| **PHP 版本** | PHP 5.6 (Docker) |
| **資料庫** | MySQL 5.7 (Docker) |
| **DB Host** | `mysql` (Docker 內部) |
| **專案路徑** | `/var/www/www.posdev/mypos_kds` |
| **訪問 URL** | `https://mypos.posdev.test/public/` |

---

## 環境需求

### 軟體需求

- **Docker Desktop** (Windows 10/11 + WSL2 或 macOS 12+)
- **Git** (用於專案版控)
- **文字編輯器** (VS Code 推薦)

### 專案目錄結構

請確保以下專案目錄已正確配置：

```
E:\projects\
├── docker_run\              # Docker 環境設定 (本儲存庫)
├── mypos_kds\               # MyPOS KDS Laravel 專案
├── pos_dev\                 # POS 主專案
├── pos_oklahoma\            # POS Oklahoma
├── conductor_202_test\      # Conductor 測試
├── yii_framework\           # Yii 1.1 框架
└── www.posdev\              # Web 根目錄 (含商戶入口)
```

---

## 快速開始

### 1. 複製環境變數設定

```bash
cd E:\projects\docker_run
cp .env.example .env
```

### 2. 編輯 `.env` 確認路徑

```ini
# E:\projects\docker_run\.env

# 專案路徑映射
PROJECT_PATH=E:/projects/pos_dev
MYPOS_KDS_PATH=E:/projects/mypos_kds
YII_FRAMEWORK_PATH=E:/projects/yii_framework
WEB_ROOT_PATH=E:/projects/www.posdev
```

### 3. 設定 hosts 檔案

以**管理員權限**編輯 `C:\Windows\System32\drivers\etc\hosts`：

```
127.0.0.1 www.posdev.test
127.0.0.1 mypos.posdev.test
```

### 4. 設定 mypos_kds 的 .env

編輯 `E:\projects\mypos_kds\.env`：

```ini
APP_NAME=MyPOS智助點餐
APP_ENV=local
APP_KEY=                                    # ⚠️ 請執行 php artisan key:generate 生成
APP_DEBUG=true
APP_LOG_LEVEL=debug
APP_URL=https://mypos.posdev.test/public

APP_ALLOW_ORIGIN=*.posdev.test

# 重要：使用 Docker 內部的 MySQL 服務名稱
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=pos_dev_2
DB_USERNAME=root
DB_PASSWORD=
```

> ⚠️ **重要**：`DB_HOST` 必須設為 `mysql`，這是 Docker 容器的服務名稱，不是 `localhost` 或 `127.0.0.1`。

### 5. 啟動 Docker 環境

```bash
cd E:\projects\docker_run

# 建置並啟動容器
docker-compose build --no-cache
docker-compose up -d

# 查看容器狀態
docker-compose ps
```

### 6. 訪問系統

開啟瀏覽器訪問：`https://mypos.posdev.test/public/`

---

## 詳細設定步驟

### Step 1: Docker 環境驗證

確認 Docker Desktop 正在運行：

```bash
docker --version
docker-compose --version
```

### Step 2: SSL 憑證確認

確認 SSL 憑證存在：

```bash
ls E:\projects\docker_run\nginx\ssl\
# 應該看到 laragon.crt 和 laragon.key
```

若不存在，執行：

```powershell
.\scripts\generate-cert.ps1
# 或
scripts\generate-cert.bat
```

### Step 3: Nginx 配置說明

#### mypos_kds.conf 關鍵配置

```nginx
# 檔案位置: docker_run/nginx/conf.d/mypos_kds.conf

server {
    listen 443 ssl http2;
    server_name mypos.posdev.test;
    
    # 專案根目錄
    root /var/www/www.posdev/mypos_kds;
    
    # Laravel 入口處理
    location ^~ /public/ {
        try_files $uri $uri/ /public/index.php?$query_string;
    }
}
```

此設定模擬測試環境的以下規則：

```nginx
# 測試環境 (www.pos.tw)
location ~ ^/([^/]+)/public(/.*)?$ {
    set $firstdir $1;
    set $rest $2;
    try_files /$firstdir/public$rest /$firstdir/public/index.php$is_args$args;
}
```

### Step 4: 資料庫初始化

#### 方法 A：匯入現有資料庫

```bash
# 將 SQL 檔案放入 mysql/init/ 目錄
cp your-database.sql E:\projects\docker_run\mysql\init\

# 重新啟動容器（會自動執行 init 目錄中的 SQL）
docker-compose down
docker-compose up -d
```

#### 方法 B：手動建立資料庫

```bash
# 進入 MySQL 容器
docker-compose exec mysql mysql -uroot

# 在 MySQL 中執行
CREATE DATABASE IF NOT EXISTS pos_dev_2 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 若需要建立專用使用者
CREATE USER IF NOT EXISTS 'develop'@'%' IDENTIFIED BY 'YOUR_SECURE_PASSWORD';
GRANT ALL PRIVILEGES ON pos_dev_2.* TO 'develop'@'%';
FLUSH PRIVILEGES;
```

### Step 5: Laravel 環境初始化

```bash
# 進入 PHP 容器
docker-compose exec php bash

# 切換到專案目錄
cd /var/www/www.posdev/mypos_kds

# 安裝依賴（如果 vendor 目錄不存在）
composer install

# 產生 APP_KEY（如果尚未設定）
php artisan key:generate

# 清除快取
php artisan config:clear
php artisan cache:clear
php artisan view:clear

exit
```

---

## 驗證安裝

### 1. 檢查容器狀態

```bash
docker-compose ps

# 預期輸出：
# pos_nginx    Up    0.0.0.0:80->80, 0.0.0.0:443->443
# pos_php      Up    9000
# pos_mysql    Up    0.0.0.0:3306->3306
```

### 2. 檢查 Nginx 配置

```bash
docker-compose exec nginx nginx -t

# 預期輸出：
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 3. 檢查 PHP 版本

```bash
docker-compose exec php php -v

# 預期輸出：
# PHP 5.6.40 ...
```

### 4. 測試資料庫連線

```bash
docker-compose exec mysql mysql -uroot -e "SHOW DATABASES;"

# 應該看到 pos_dev_2
```

### 5. 測試網頁訪問

```bash
# 使用 curl 測試
curl -k https://mypos.posdev.test/public/

# 或開啟瀏覽器訪問
# https://mypos.posdev.test/public/
```

### 6. 測試 Laravel 路由

訪問以下 URL 驗證路由：

| 路由 | 預期結果 |
|------|----------|
| `https://mypos.posdev.test/public/` | 首頁或重導登入 |
| `https://mypos.posdev.test/public/login` | 登入頁面 |
| `https://mypos.posdev.test/public/link/kds/dev_2` | KDS 連結設定並跳轉登入頁 |

---

## KDS 連結路由說明

### `/link/kds/{dbName}` 路由機制

KDS 系統使用特殊的連結路由來設定應用程式並導向登入頁面：

```
https://mypos.posdev.test/public/link/kds/{dbName}
```

#### 參數說明

| 參數 | 說明 | 範例 |
|------|------|------|
| `{dbName}` | **資料庫名稱後綴**，對應 `pos_{dbName}` | `dev_2` → `pos_dev_2` |

#### 常見使用範例

| 資料庫名稱 | 對應 URL |
|-----------|----------|
| `pos_dev` | `https://mypos.posdev.test/public/link/kds/dev` |
| `pos_dev_2` | `https://mypos.posdev.test/public/link/kds/dev_2` |
| `pos_dev3` | `https://mypos.posdev.test/public/link/kds/dev3` |

> ⚠️ **重要**：URL 中的 `{dbName}` 必須與實際資料庫名稱的後綴一致。例如：
> - 若您的 `.env` 設定為 `DB_DATABASE=pos_dev_2`
> - 則應使用 URL：`https://mypos.posdev.test/public/link/kds/dev_2`

#### 路由運作流程

```mermaid
graph TD
    A[訪問 /public/link/kds/dev_2] --> B[ApplicationController@link]
    B --> C[設定 localStorage]
    C --> D[localStorage.ApplicationId = 加密的 dev_2]
    D --> E[localStorage.ApplicationHome = .../public/kds]
    E --> F[重導向 /public/login]
    F --> G[顯示 KDS 登入頁面]
```

#### 測試環境對照

| 環境 | 完整 URL |
|------|----------|
| **本地 Docker** (DB: pos_dev_2) | `https://mypos.posdev.test/public/link/kds/dev_2` |
| **測試環境** (DB: pos_dev) | `https://www.posdev.com/mypos_kds/public/link/kds/dev` |
| **測試環境** (入口捷徑) | `https://www.posdev.com/dev/kds` → 自動重導 |

---

## 常見問題排解

### Q1: 「連線不是私人連線」錯誤

**原因**：使用自簽 SSL 憑證

**解決方案**：
1. 點擊「進階」→「繼續前往 (不安全)」
2. 或將 `nginx/ssl/laragon.crt` 加入系統信任

---

### Q2: 資料庫連線失敗

**錯誤訊息**：`SQLSTATE[HY000] [2002] Connection refused`

**原因**：`DB_HOST` 設定錯誤

**解決方案**：
確認 `mypos_kds/.env` 中：
```ini
DB_HOST=mysql    # ✅ 正確
# DB_HOST=localhost      # ❌ 錯誤
# DB_HOST=127.0.0.1      # ❌ 錯誤
```

---

### Q3: 404 錯誤

**原因**：Nginx 路由或路徑掛載錯誤

**檢查步驟**：
```bash
# 檢查專案是否正確掛載
docker-compose exec php ls -la /var/www/www.posdev/mypos_kds/

# 應該看到 app/, public/, vendor/ 等目錄
```

---

### Q4: 500 Internal Server Error

**檢查步驟**：

1. 查看 Laravel 日誌：
   ```bash
   docker-compose exec php tail -f /var/www/www.posdev/mypos_kds/storage/logs/laravel.log
   ```

2. 查看 Nginx 錯誤日誌：
   ```bash
   docker-compose logs nginx | tail -30
   ```

3. 確認 storage 目錄權限：
   ```bash
   docker-compose exec php chmod -R 777 /var/www/www.posdev/mypos_kds/storage
   docker-compose exec php chmod -R 777 /var/www/www.posdev/mypos_kds/bootstrap/cache
   ```

---

### Q5: 找不到 yii_framework

**原因**：`.env` 路徑設定錯誤

**解決方案**：
確認 `docker_run/.env` 中路徑正確：
```ini
YII_FRAMEWORK_PATH=E:/projects/yii_framework
```

---

### Q6: PORT 已被占用

**錯誤訊息**：`port is already allocated`

**解決方案**：
1. 停止 Laragon 或其他服務
2. 或修改 `docker_run/.env` 的 PORT 設定：
   ```ini
   HTTP_PORT=8080
   HTTPS_PORT=8443
   ```

---

## 測試環境與本地環境對照表

### URL 對照

| 測試環境 URL | 本地開發 URL |
|-------------|-------------|
| `https://www.pos.com/mypos_kds/public/` | `https://mypos.posdev.test/public/` |
| `https://www.pos.com/mypos_kds/public/login` | `https://mypos.posdev.test/public/login` |
| `https://www.pos.com/mypos_kds/public/link/kds/dev` | `https://mypos.posdev.test/public/link/kds/dev` |
| `https://www.pos.com/dev/kds` | N/A (本地直接訪問 KDS) |

### 路由規則對照

| 規則類型 | 測試環境 | 本地環境 |
|---------|---------|---------|
| Laravel 入口 | `location ~ ^/([^/]+)/public(/.*)?$` | `location ^~ /public/` |
| 處理方式 | `try_files → index.php` | `try_files → index.php` |

### 資料庫連線對照

| 項目 | 測試環境 | 本地環境 |
|------|---------|---------|
| DB_HOST | 192.168.2.246 | mysql |
| DB_DATABASE | pos_dev | pos_dev_2 |
| DB_USERNAME | root | root |
| DB_PORT | 3306 | 3306 |

---

## 附錄：Docker 常用指令

```bash
# 啟動容器
docker-compose up -d

# 停止容器
docker-compose down

# 重新建置
docker-compose build --no-cache

# 查看日誌
docker-compose logs -f [服務名]

# 進入容器
docker-compose exec php bash
docker-compose exec nginx sh
docker-compose exec mysql bash

# 重啟單一服務
docker-compose restart nginx

# 清理未使用資源
docker system prune -f
```

---

## 版本歷史

| 版本 | 日期 | 說明 |
|------|------|------|
| 1.0 | 2026-01-13 | 初版建立 |

