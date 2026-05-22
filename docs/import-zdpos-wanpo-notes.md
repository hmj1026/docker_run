# zdpos_wanpo 匯入紀錄

## 已確認事項

- 匯入檔為 `mysql/init/02.zdpos_wanpo_0426.sql`（49GB，dump 來源是 MySQL 8.0+）
- dump 內容：306 BASE TABLE + 79 VIEW
- 目標 DB 名稱：`zdpos_wanpo`
- 容器：`pos_mysql`（MySQL 5.7.44）

## 遇到的問題

### 問題 1：mysql.cnf 權限

- `mysql/conf.d/mysql.cnf` 權限是 `777`
- MySQL client 會警告 world-writable config file，並忽略該設定檔
- 不阻擋匯入，但會在 log 留下兩行警告

### 問題 2：dump 過大

- `02.zdpos_wanpo_0426.sql` 檔案大小約 49GB
- 不能整包讀進記憶體，只能串流匯入

### 問題 3（主要失敗點）：MySQL 8 的 `utf8mb4_0900_ai_ci` collation

- 原始 dump 在「Final view structure」段使用 `SET collation_connection = utf8mb4_0900_ai_ci`
- MySQL 5.7 不認識這個 collation，匯入在第 60959 行中止：
  ```
  ERROR 1273 (HY000) at line 60959: Unknown collation: 'utf8mb4_0900_ai_ci'
  ```
- 失敗時 BASE TABLE（306 張，約 73GB 資料）已全部匯入完成，僅差 view 重建段
- dump 中此 collation 變體只有 `utf8mb4_0900_ai_ci` 一種（已 grep 確認）

## 修正方式

### 主匯入腳本：`scripts/import-zdpos-wanpo.sh`

- 先建立 `zdpos_wanpo` database（utf8mb4 / utf8mb4_unicode_ci）
- 串流匯入時 pipe 過 `sed 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g'`
  - 不修改 49GB 原檔（保留 `.bak` 硬連結作為原始 dump 備份）
  - 即時取代不相容的 collation
- 匯入失敗會寫入 `logs/mysql/import-zdpos-wanpo.log`

### 續傳腳本：`scripts/resume-zdpos-wanpo-views.sh`

當 BASE TABLE 已匯入完成、僅剩 view 段需要補完時使用：

- 從 dump 的「Final view structure」段（行號 `60572`，可由環境變數 `FINAL_VIEW_START_LINE` 覆寫）切到結尾
- 同樣 pipe 過 sed 取代 `utf8mb4_0900_ai_ci`
- 開始前先 `DROP VIEW IF EXISTS` 清掉所有現存 view（避免 first-pass stub 與 Final pass 結果混用）
- 完成後印出 view 數，預期 = 79

## 驗證指令

```bash
# View 數量應為 79
docker exec -i pos_mysql mysql -uroot -e \
  "SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA='zdpos_wanpo';"

# 整體物件數應為 BASE TABLE=306, VIEW=79
docker exec -i pos_mysql mysql -uroot -e \
  "SELECT TABLE_TYPE, COUNT(*) FROM information_schema.tables \
   WHERE table_schema='zdpos_wanpo' GROUP BY TABLE_TYPE;"

# 確認首個失敗 view 已重建
docker exec -i pos_mysql mysql -uroot -e \
  "SHOW CREATE VIEW zdpos_wanpo.invoice_record_view\G" | head -10
```
