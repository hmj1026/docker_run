# MySQL Dump 匯入紀錄

## 已確認事項

- 匯入檔預設路徑：`mysql/init/dump.sql`（可透過 `SQL_FILE` 環境變數覆寫）
- 目標 DB 名稱：由 `DB_NAME` 環境變數帶入（必填，無預設值）
- 容器：由 `CONTAINER_NAME` 環境變數帶入（預設 `pos_mysql`）

## 遇到的問題

### 問題 1：mysql.cnf 權限

- `mysql/conf.d/mysql.cnf` 權限是 `777`
- MySQL client 會警告 world-writable config file，並忽略該設定檔
- 不阻擋匯入，但會在 log 留下兩行警告

### 問題 2：dump 過大

- 大型 dump 檔案無法整包讀進記憶體，只能串流匯入
- 腳本以 `sed ... | docker exec -i ... mysql` pipe 處理

### 問題 3（主要失敗點）：MySQL 8 的 `utf8mb4_0900_ai_ci` collation

- 部分 dump 在「Final view structure」段使用 `SET collation_connection = utf8mb4_0900_ai_ci`
- MySQL 5.7 不認識這個 collation，匯入會在 view 段中止：
  ```
  ERROR 1273 (HY000): Unknown collation: 'utf8mb4_0900_ai_ci'
  ```
- 失敗時 BASE TABLE 通常已全部匯入完成，僅差 view 重建段
- dump 中此 collation 變體只有 `utf8mb4_0900_ai_ci` 一種（已 grep 確認）

## 修正方式

### 主匯入腳本：`scripts/import-mysql-dump.sh`

```bash
DB_NAME=mydb bash scripts/import-mysql-dump.sh
# 或
DB_NAME=mydb SQL_FILE=/path/to/dump.sql bash scripts/import-mysql-dump.sh
```

- 先建立 `${DB_NAME}` database（utf8mb4 / utf8mb4_unicode_ci）
- 串流匯入時 pipe 過 `sed 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g'`
  - 不修改原始 dump 檔（保留 `.bak` 硬連結作為備份）
  - 即時取代不相容的 collation
- 匯入失敗會寫入 `logs/mysql/import-mysql.log`

### 續傳腳本：`scripts/resume-mysql-views.sh`

當 BASE TABLE 已匯入完成、僅剩 view 段需要補完時使用：

```bash
DB_NAME=mydb FINAL_VIEW_START_LINE=60572 bash scripts/resume-mysql-views.sh
```

- 從 dump 的「Final view structure」段（行號由 `FINAL_VIEW_START_LINE` 指定）切到結尾
- 同樣 pipe 過 sed 取代 `utf8mb4_0900_ai_ci`
- 開始前先 `DROP VIEW IF EXISTS` 清掉所有現存 view（避免 first-pass stub 與 Final pass 結果混用）
- 完成後比對 view 數與 `EXPECTED_VIEW_COUNT`（預設 79，可覆寫）

## 驗證指令

```bash
# View 數量驗證
docker exec -i ${CONTAINER_NAME} mysql -uroot -e \
  "SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA='${DB_NAME}';"

# 整體物件數驗證
docker exec -i ${CONTAINER_NAME} mysql -uroot -e \
  "SELECT TABLE_TYPE, COUNT(*) FROM information_schema.tables \
   WHERE table_schema='${DB_NAME}' GROUP BY TABLE_TYPE;"

# 確認特定 view 已重建
docker exec -i ${CONTAINER_NAME} mysql -uroot -e \
  "SHOW CREATE VIEW ${DB_NAME}.<view_name>\G" | head -10
```
