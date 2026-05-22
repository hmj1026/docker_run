# Docker Desktop → Docker CE (WSL2) 遷移操作手冊

> Phase 4-8（程式碼/設定/文件修改）已完成。本手冊涵蓋需要手動執行的 Phase 1-3 和 Phase 9-10。
>
> **隨時可回滾**：原始 `/mnt/e/projects/docker_run` 不會被動到，重裝 Docker Desktop 即可恢復。

---

## Phase 1: 備份（Tasks 1.1 - 1.8）

在**現有的 Docker Desktop 環境**下執行，確保容器正在運行。

```bash
# 1.1 建立備份目錄
DATE=$(date +%Y%m%d)
mkdir -p /home/paul/backups/mysql-migration-${DATE}
cd /home/paul/backups/mysql-migration-${DATE}

# 1.2 全庫備份
docker exec pos_mysql mysqldump -u root --all-databases \
    --single-transaction --skip-lock-tables > all-databases.sql
ls -lh all-databases.sql

# 1.3 個別資料庫備份（6 個業務庫）
# Set LEGACY_DATABASES to the space-separated list of database names to migrate
for db in ${LEGACY_DATABASES}; do
    docker exec pos_mysql mysqldump -u root --single-transaction --skip-lock-tables "$db" > "${db}.sql"
    echo "${db}: $(ls -lh ${db}.sql | awk '{print $5}')"
done

# 1.4 記錄 baseline（表數/行數）
docker exec pos_mysql mysql -u root -N -e "
SELECT table_schema, COUNT(*) AS tables,
       SUM(table_rows) AS rows
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql','information_schema','performance_schema','sys')
GROUP BY table_schema;
" > baseline.txt
cat baseline.txt

# 1.5 停止容器
cd /mnt/e/projects/docker_run
docker-compose down --remove-orphans

# 1.6 物理備份 MySQL 資料目錄
cp -a /mnt/e/projects/docker_run/data/mysql \
      /home/paul/backups/mysql-migration-${DATE}/data-mysql-physical/

# 1.7 備份整個專案
cp -a /mnt/e/projects/docker_run \
      /home/paul/backups/docker_run-original-${DATE}

# 1.8 驗證 Gate
echo "=== Verification ==="
echo "SQL files:"
ls -lh /home/paul/backups/mysql-migration-${DATE}/*.sql
echo "Physical copy:"
du -sh /home/paul/backups/mysql-migration-${DATE}/data-mysql-physical/
echo "Project backup:"
ls -d /home/paul/backups/docker_run-original-${DATE}
```

**通過條件**：6 個 `.sql` 檔案非空、physical copy 約 948MB、project backup 目錄存在。

---

## Phase 2: 安裝 Docker CE（Tasks 2.1 - 2.8）

### 2.1 確認 systemd

```bash
cat /etc/wsl.conf
# 確認有以下內容，沒有就加上：
# [boot]
# systemd=true
```

加完後在 **Windows PowerShell**（非 WSL）執行：

```powershell
wsl --shutdown
```

然後重新開啟 WSL。

### 2.2 移除 Docker Desktop

在 **Windows** 端：
- 設定 > 應用程式 > 搜尋「Docker Desktop」> 解除安裝
- 或 PowerShell: `winget uninstall Docker.DockerDesktop`

### 2.3 - 2.7 安裝 Docker CE

回到 WSL2：

```bash
# 2.3 移除舊版
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null

# 2.4 加入官方 repo
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
     -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 2.5 安裝
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
     docker-buildx-plugin docker-compose-plugin

# 2.6 加入 docker 群組
sudo usermod -aG docker $USER
# 重新開啟終端機（或執行 newgrp docker）

# 2.7 啟用服務
sudo systemctl enable docker
sudo systemctl start docker
```

### 2.8 驗證 Gate

```bash
docker --version          # 應顯示 Docker version XX.X.X (不是 Desktop)
docker compose version    # 應顯示 Docker Compose version v2.x.x
docker run --rm hello-world  # 應成功且不需要 sudo
```

---

## Phase 3: 專案目錄設定（Tasks 3.1 - 3.3）

```bash
# 3.1 複製專案到 WSL2 原生路徑
cp -a /mnt/e/projects/docker_run /home/paul/projects/docker_run

# 3.2 確認 mysql/init/ SQL 檔案存在（git-ignored，約 1.8GB）
ls -lh /home/paul/projects/docker_run/mysql/init/
# 應有 ~12 個 SQL 檔案
# 如果沒有，從原始位置複製：
# cp /mnt/e/projects/docker_run/mysql/init/*.sql /home/paul/projects/docker_run/mysql/init/

# 3.3 清空 MySQL 資料目錄（之後會從 dump 還原）
rm -rf /home/paul/projects/docker_run/data/mysql/*
```

---

## Phase 9: 建置、啟動與資料庫還原（Tasks 9.1 - 9.5）

```bash
cd /home/paul/projects/docker_run

# 9.1 建置映像
docker compose build --no-cache

# 9.2 啟動容器
docker compose up -d

# 9.3 等待 MySQL 就緒
docker compose logs -f mysql
# 看到 "ready for connections" 後按 Ctrl+C 離開

# 9.4 還原資料庫
docker exec -i posdev_mysql mysql -u root \
    < /home/paul/backups/mysql-migration-*/all-databases.sql

# 9.5 驗證（與 baseline.txt 比對）
docker exec posdev_mysql mysql -u root -N -e "
SELECT table_schema, COUNT(*) AS tables,
       SUM(table_rows) AS rows
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql','information_schema','performance_schema','sys')
GROUP BY table_schema;
"
# 比對 /home/paul/backups/mysql-migration-*/baseline.txt
```

> **注意**：容器名稱前綴取決於 `.env` 中的 `COMPOSE_PROJECT_NAME`。預設 `posdev` 對應容器名 `posdev_mysql`、`posdev_php`、`posdev_nginx`。如果你的設定不同，請調整指令中的容器名稱。

---

## Phase 10: 煙霧測試（Tasks 10.1 - 10.10）

逐一執行，全部通過才算遷移成功：

```bash
cd /home/paul/projects/docker_run

# 10.1 容器狀態
docker compose ps
# 3 個容器都應顯示 Up

# 10.2 PHP -> MySQL 連線
docker exec posdev_php php -r \
    "new PDO('mysql:host=mysql;dbname=${DB_NAME}','root',''); echo 'OK';"

# 10.3 Nginx 設定
docker exec posdev_nginx nginx -t

# 10.4 專案檔案可存取
docker exec posdev_php ls /var/www/www.posdev/<project>/protected/

# 10.5 商戶目錄可存取
for dir in dev3 186 bdfy oklao neiwei popcorn winelake; do
    echo -n "${dir}: "
    docker exec posdev_php test -d /var/www/www.posdev/${dir} && echo "OK" || echo "MISSING"
done

# 10.6 HTTPS 回應
curl -k https://www.posdev.test/dev3/

# 10.7 PHP/Composer/PHPUnit 版本
make php-version

# 10.8 PHPUnit 單元測試
docker exec -i -w /var/www/www.posdev/<project> posdev_php \
    phpunit -c protected/tests/phpunit.xml --testsuite unit

# 10.9 Make 指令
make help
make shell    # 進入後 exit 離開
make db-shell # 進入後 exit 離開

# 10.10 確認無殘留 docker-compose（連字號）指令
grep -r "docker-compose" \
    --include="*.yml" --include="*.md" \
    --include="*.sh" --include="Makefile" .
# 應只有 docker-compose.yml 檔名引用，不應有 docker-compose 指令
```

---

## 結果判定

| 結果 | 下一步 |
|------|--------|
| 全部通過 | 遷移成功，可在數週後刪除 `/mnt/e/` 備份 |
| 部分失敗 | 查日誌排錯，參考 README.md 常見問題 |
| 重大失敗 | 回滾：重裝 Docker Desktop，回到 `/mnt/e/projects/docker_run` |

---

## 執行順序

```
Phase 1 (備份) --> Phase 2 (裝 Docker CE) --> Phase 3 (搬專案)
    --> Phase 9 (建置還原) --> Phase 10 (驗證)
```

每個 Phase 完成後，回到 `openspec/changes/migrate-docker-to-wsl/tasks.md` 手動勾選對應項目（`- [ ]` 改為 `- [x]`），方便追蹤進度。

全部完成後可用 `/opsx:archive` 封存此 change。
