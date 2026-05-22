# 路徑與路由關係

## 目的

這份文件只說明兩件事：

1. Docker 實際讀哪一份程式碼
2. `/dev3/`、`dev3.php`、`main.php` 的關係

---

## 專案位置

- `docker_run` 與所有專案目錄位於 Docker 可存取的原生路徑：
  - Linux / WSL2: `/home/<username>/projects/`
  - macOS: `/Users/<username>/projects/`
  - Windows (Docker Desktop): `C:/Users/<username>/projects/`（使用正斜線）
- Docker 直接從本地檔案系統讀取，無跨檔案系統邊界
- **實際哪一份會被容器使用，永遠以 `.env` 為準**

重點：

- 只看 `.env` 和 `docker inspect`
- 不要從設定檔內的路徑字串推測實際掛載來源

---

## Docker 實際讀哪一份程式碼

判斷順序固定如下：

1. 看 `docker_run/.env`
2. 看 `docker inspect <container>`
3. 再看入口檔與設定檔

重點：

- `.env` 決定 mount 來源
- `docker inspect` 驗證容器實際掛載結果
- PHP 設定檔內的 legacy 路徑字串，不代表 Docker 現在真的讀那個位置

---

## `/dev3/` 的實際路由關係

`/dev3/` 不是直接進主專案 root 的 `index.php`。

請求流程是：

1. 瀏覽器請求 `/dev3/...`
2. Nginx 依 web root 與 rewrite 規則，把請求導到 `dev3/index.php`
3. `dev3/index.php` 載入：
   - `../yii_framework/yii.php`
   - `../pos_dev/protected/config/dev3.php`
4. Yii 以 `dev3.php` 啟動應用程式

所以：

- `/dev3/` 的入口是 `www.posdev/dev3/index.php`
- `/dev3/` 的 Yii 設定檔是 `protected/config/dev3.php`

---

## `main.php` 與 `/dev3/` 的關係

主專案 root 的 `index.php` 會指向：

- `protected/config/main.php`

但 `/dev3/` 不走這條路。

`/dev3/` 走的是：

- `www.posdev/dev3/index.php`
- `protected/config/dev3.php`

因此：

- `main.php` 不是 `/dev3/` 的必要檔案
- `/dev3/` 能不能跑，重點在 `dev3/index.php` 與 `dev3.php`

---

## 以後遇到混亂時怎麼查

固定照這個順序：

1. 先看 `.env`
2. 再看 `docker inspect`
3. 再看 `dev3/index.php`
4. 最後看 `protected/config/dev3.php`

不要反過來從設定檔內的路徑字串推測實際掛載來源。
