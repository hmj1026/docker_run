# PHP 版本測試指南

## 快速測試

### 方法 1: 使用自動化腳本

```bash
# 測試所有 PHP 版本
bash scripts/test-versions.sh

# 互動式切換版本
bash scripts/switch-version.sh
```

---

## 手動測試單一版本

### 測試 PHP 5.6
```bash
export PHP_VERSION=56
docker compose build php
docker compose run --rm php php --version
docker compose run --rm php composer --version
docker compose run --rm php phpunit --version
```

### 測試 PHP 7.4
```bash
export PHP_VERSION=74
docker compose build php
docker compose run --rm php php --version
docker compose run --rm php composer --version
docker compose run --rm php phpunit --version
```

### 測試 PHP 8.1
```bash
export PHP_VERSION=81
docker compose build php
docker compose run --rm php php --version
docker compose run --rm php composer --version
docker compose run --rm php phpunit --version
```

---

## 預期輸出

### PHP 5.6
```
PHP 5.6.40 (cli)
Composer version 1.10.27 2023-09-29 10:50:23
PHPUnit 5.7.27 by Sebastian Bergmann and contributors.
```

### PHP 7.4
```
PHP 7.4.33 (cli)
Composer version 2.2.24 2024-06-10 22:51:52
PHPUnit 9.6.30 by Sebastian Bergmann and contributors.
```

### PHP 8.1
```
PHP 8.1.33 (cli)
Composer version 2.8.12 2025-09-19 13:41:59
PHPUnit 10.5.59 by Sebastian Bergmann and contributors.
```

---

## 疑難排解

### docker compose 指令找不到

確認 Docker 正在運行：
```bash
docker --version
docker compose --version

# Linux / WSL2 (Docker CE):
systemctl status docker

# macOS / Windows (Docker Desktop): 確認應用程式已啟動
docker info >/dev/null 2>&1 && echo "Docker is running"
```

---

## 完整測試流程

### 建構所有版本（一次性）

```bash
for v in 56 74 80 81 82 83 84 85; do
    echo "Building PHP $v..."
    PHP_VERSION=$v docker compose build php
done
```

---

## 快速檢查指令

```bash
# PHP 7.4
PHP_VERSION=74 docker compose run --rm php sh -c "php --version && composer --version && phpunit --version"

# PHP 8.1
PHP_VERSION=81 docker compose run --rm php sh -c "php --version && composer --version && phpunit --version"
```

---

## 驗證清單

測試每個 PHP 版本時，確認以下項目：

- [ ] PHP 版本正確
- [ ] Composer 版本正確
- [ ] PHPUnit 版本正確
- [ ] `composer --version` 指令可執行
- [ ] `phpunit --version` 指令可執行
- [ ] 容器啟動無錯誤

---

## 版本對照快速參考

| PHP | Composer | PHPUnit | 安裝方式 |
|-----|----------|---------|---------|
| 5.6 | 1.10.27  | 5.7.27  | PHAR    |
| 7.4 | 2.2.24   | 9.6.30  | Composer|
| 8.0 | 2.8.x    | 9.6.x   | Composer|
| 8.1 | 2.8.12   | 10.5.59 | Composer|
| 8.2 | 2.8.x    | 10.5.x  | Composer|
| 8.3 | 2.8.x    | 11.x    | Composer|
| 8.4 | 2.9.x    | 13.4.5  | Composer|
| 8.5 | 2.9.x    | 13.x    | Composer|

---

## PHP 8.4 並行測試與測試資料庫

php84 容器與主環境（pos_php 5.6）並行運作，互不影響；測試資料庫與正式開發資料庫隔離。相關變數見 `.env.example` 的「測試環境」區塊。

### php84 profile 與 vhost

```bash
make php84-up       # docker compose --profile php84 up -d --no-deps php84
make php84-down     # 停止並移除（不影響 php / nginx / mysql）
make php84-shell
make php84-test SUITE=unit WORKTREE=<worktree 路徑>
```

- 容器內以相同的宿主機路徑掛載 `PROJECTS_ROOT`，worktree、`.git` 指標、`.scratch` symlink 與 `docker exec -w <宿主機路徑>` 皆可直接使用。
- 瀏覽器入口 `https://php84.posdev.test/`：hosts 需加入 `127.0.0.1 php84.posdev.test`，新增 vhost 後需由使用者自行 reload nginx。
- 憑證 SAN 檢查結果：`nginx/ssl/laragon.crt` 的 SAN 為 `*.test`、`*.localhost` 等，萬用字元只比對單層，**不涵蓋** `php84.posdev.test`（且該憑證已於 2026-05-05 到期）。Playwright 請設定 `ignoreHTTPSErrors: true`，或用 `scripts/generate-cert.sh` 重新產生憑證。
- 注意：不要對測試容器使用 `--read-only` root 檔案系統（PHPUnit / composer / Yii 會寫入暫存與 assets，會直接失敗）。

### cexec.sh 路徑對應

`scripts/cexec.sh [--service php|php84] [--as-root] [--log <slug>] <dir> -- <cmd...>`

| 宿主機目錄 | 容器路徑 |
|-----------|---------|
| `PROJECT_PATH` 之下 | `PROJECT_CONTAINER_PATH` + 子路徑 |
| `WEB_ROOT_PATH` 之下 | `/var/www/www.posdev` + 子路徑 |
| `PROJECTS_ROOT` 之下（僅 php84） | 同路徑 |
| `/var/www/` 開頭 | 原樣使用 |

其他路徑以結束碼 2 拒絕並列出可接受的根目錄。

### uid 對應與 /work

php84 的 `cexec.sh` 預設以 `HOST_UID:HOST_GID` 執行（避免產生 root 擁有的檔案），`HOME=/work`、`COMPOSER_HOME=/work/.composer`（宿主機 `work/php84/`，已 git-ignore）。`php`（5.6 FPM）維持 root；`--as-root` 可強制 root。PHPUnit 安裝於 `/opt/composer`，任何 uid 皆可執行。

### 測試日誌

統一寫入 `logs/test/<時間戳>-<slug>.log`（`cexec.sh --log <slug>`、`make php84-test`）；指令結束碼會被保留。

### 測試資料庫 (test-db.sh)

```bash
scripts/test-db.sh [--host mysql|mariadb101] init | ping | list | create <name> | drop <name> | reset --yes
```

- `init` 建立 `TEST_DB_USER`（密碼取自 `TEST_DB_PASSWORD`），授權 `TEST_DB_PREFIXES` 前綴的資料庫（預設 `test_`、`zdpos_217_sb_`）完整權限，並對 `TEST_DB_CLONE_SOURCE` 僅給 `SELECT, SHOW VIEW, TRIGGER`。
- 前綴守門：`create` / `drop` 的名稱必須符合 `^[A-Za-z0-9_]+$` 且以允許前綴開頭，否則結束碼 3（例如 `drop zdpos_dev_2` 一定被拒絕）。
- 密碼以 `MYSQL_PWD` 環境變數傳入容器，不出現在命令列。

`provision-splitbill-gate-db.sh` 需要 `ZDPOS_MYSQL_USER` / `ZDPOS_MYSQL_PASSWORD`：執行 `make splitbill-gate-env` 取得 export 範例（只顯示 `$TEST_DB_PASSWORD` 參照，不顯示密碼）。

### MariaDB 10.1（正式環境 collation 對照）

正式環境為 MariaDB 10.1（`utf8` / `utf8_general_ci`），與開發用 MySQL 5.7（`utf8mb4_unicode_ci`）排序行為不同。需要驗證 collation 時：

```bash
make mariadb101-up && scripts/test-db.sh --host mariadb101 init
make mariadb101-down     # 資料保留在 data/mariadb101/
```

預設對外 PORT 為 `MARIADB101_PORT`（3307）。

### Docker daemon 位址池

自訂 network 過多時可能耗盡預設位址池。範本：`docs/docker/daemon.json.example`（`default-address-pools` + `live-restore`），套用到 `/etc/docker/daemon.json` 需重啟 Docker，請自行評估。`make check` 在缺少設定時只會顯示 WARN。
