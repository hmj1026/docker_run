# Docker 最佳實務審查報告

日期：2026-03-23
範圍：`docker-compose.yml`、`php/php56/Dockerfile`、`php/php74/Dockerfile`、`php/php80/Dockerfile`、`php/php81/Dockerfile`、`php/php82/Dockerfile`、`php/php83/Dockerfile`
基準：以相容性優先的方式審查，前提是此本地開發環境仍需支援 legacy PHP 5.6 與 7.4

## 摘要

此儲存庫部分符合 Docker 最佳實務，但尚未完整達標。

- 作為本地開發環境運作良好：PHP 映像有明確版本、設定檔掛載多為唯讀、各 PHP 版本也有獨立且可重現的 build context。
- 在容器硬化方面不足：PHP 映像仍以 root 執行，dev/test 工具直接內建於主要 runtime image，且所有服務都沒有宣告 `HEALTHCHECK`。
- 存在可避免的映像與啟動效率問題：repo 缺少 `.dockerignore`，而 nginx 容器每次啟動時都會安裝 `tzdata`。
- 有可理解但仍具風險的 legacy 例外：PHP 5.6 / 7.4 使用已終止支援的 Debian 基底，並改寫為 archived 套件來源。

整體結論：若定位為偏向 legacy 相容的本地開發堆疊，現況可接受；但若以現代容器最佳實務衡量，仍需進一步強化。

## 審查發現

### 高優先

1. PHP 容器以 root 執行，而非使用專屬的低權限 runtime 使用者。
   - 證據：所有 PHP Dockerfile 都以 `CMD ["php-fpm", "-F"]` 結尾，且未宣告 `USER`。
   - 檔案：
     - `php/php56/Dockerfile`
     - `php/php74/Dockerfile`
     - `php/php80/Dockerfile`
     - `php/php81/Dockerfile`
     - `php/php82/Dockerfile`
     - `php/php83/Dockerfile`
   - 影響：若 PHP 程序遭入侵，攻擊者將直接取得容器內 root 權限，安全性明顯弱於以非特權使用者執行 `php-fpm`。
   - 建議：在安裝套件與 extension 後，將最終 runtime 使用者切換為 `www-data`，並確認必要的可寫路徑都由該使用者持有。
   - 相容性說明：由於 compose 目前大量 bind mount 主機目錄，正式改為非 root 前，需先驗證權限行為是否正常。

2. Dev 與 test 工具直接安裝在主要 PHP runtime image 中。
   - 證據：
     - 所有維護中的 PHP 映像皆安裝了 Xdebug：
       - `php/php74/Dockerfile:69`
       - `php/php80/Dockerfile:61`
       - `php/php81/Dockerfile:61`
       - `php/php82/Dockerfile:61`
       - `php/php83/Dockerfile:61`
       - `php/php56/Dockerfile:71`
     - PHPUnit 也被安裝在執行 PHP-FPM 的同一個映像中：
       - `php/php74/Dockerfile:83`
       - `php/php80/Dockerfile:75`
       - `php/php81/Dockerfile:75`
       - `php/php82/Dockerfile:75`
       - `php/php83/Dockerfile:75`
       - `php/php56/Dockerfile:90`
   - 影響：映像較大、攻擊面增加、重建速度變慢，也缺乏 runtime 與測試職責的清楚分離。
   - 建議：至少拆成 `dev/test` 與 `runtime` 兩類 target；若要保留目前全功能映像，也應明確標註它是 dev 變體。
   - 相容性說明：以此 repo 目前的本地開發流程來看，保留「全包型」PHP 映像可以理解，但應視為有意識的取捨，而非最佳實務。

3. Repo root 與 PHP build context 內皆未提供 `.dockerignore`。
   - 證據：搜尋結果未找到 `.dockerignore`。
   - 影響：不必要的檔案可能被送進 Docker build context，導致建置變慢，也提高非預期檔案被打包進去的風險。
   - 建議：新增 root `.dockerignore`，必要時再針對 `php/php*/php.ini` 等必需檔案補例外規則。

### 中優先

4. nginx 容器在啟動時安裝套件，而不是在 build 階段完成。
   - 證據：`docker-compose.yml:13` 到 `docker-compose.yml:17` 在 `command` 內執行 `apk add --no-cache tzdata`。
   - 影響：容器啟動較慢、runtime 依賴網路、若套件鏡像變動也會降低可重現性。
   - 建議：將時區設定移入自訂 nginx image 或預先建好的 layer，runtime `command` 只保留啟動主程序。

5. 所有服務都沒有定義 `HEALTHCHECK`。
   - 證據：
     - 所有 PHP Dockerfile 均未包含 `HEALTHCHECK`
     - `docker-compose.yml` 也未為 `nginx`、`php`、`mysql` 定義 health check
   - 影響：compose 雖然能啟動服務，但無法可靠判斷服務是否真正 ready，會增加啟動競態與觀測上的弱點。
   - 建議：
     - `nginx`：探測內部 HTTP endpoint
     - `php`：探測 `php-fpm` readiness 或執行簡單的本地 PHP 指令
     - `mysql`：使用 `mysqladmin ping`

6. Legacy 版本依賴已終止支援的 base image。
   - 證據：
     - `php/php56/Dockerfile:5` 使用 `php:5.6-fpm-stretch`
     - `php/php74/Dockerfile:5` 使用 `php:7.4-fpm-buster`
     - 兩份 Dockerfile 都將 `apt` 套件來源改寫為 archived Debian mirrors
   - 影響：這些映像不再獲得正常的安全更新，且需依賴 archive workaround，會提高供應鏈與維護風險。
   - 建議：將這些版本明確視為 legacy-only 通道，避免任何 production 用途，並清楚記錄其安全性屬於例外狀態，而非合規狀態。

7. MySQL 明確允許空的 root 密碼。
   - 證據：`docker-compose.yml:104` 設定了 `MYSQL_ALLOW_EMPTY_PASSWORD=yes`。
   - 影響：若環境僅限隔離的本地開發，可勉強接受；但從安全最佳實務角度來看，這仍然不合標準。
   - 建議：只有在專案明確以快速建立可拋棄的本地環境為目標時才保留，並註明此設定不得沿用到共用環境或 production-like 環境。

### 低優先

8. PHP Dockerfile 皆為單階段，未針對最小化 runtime 輸出做最佳化。
   - 證據：每份 PHP Dockerfile 都只使用單一 `FROM`，並在同一個映像中安裝 build dependencies、extensions、Composer、PHPUnit 與 Xdebug。
   - 影響：映像較大，且職責分離較弱。
   - 建議：對現代 PHP 8.x 映像可考慮改為 multi-stage 或拆成不同 image target；對 PHP 5.6 與 7.4，除非映像大小或重建速度已成為實際痛點，否則可暫時視為 legacy 限制。

9. 部分套件安裝區塊仍可再提高可重現性並減少 layer 體積。
   - 證據：
     - `apt-get install -y` 未搭配 `--no-install-recommends`
     - extension 安裝分散在多個 `RUN` layer
     - PHP 8.x 映像中 `composer:2.8` 只固定到 major/minor，未鎖定到更精確的 patch tag
   - 影響：映像略大，且 build 的可重現性稍弱。
   - 建議：加上 `--no-install-recommends`、在有助於快取的前提下整併相關步驟，並在需要高可重現性時將 Composer 固定到精確 patch 版本。

10. Compose 的服務依賴只處理了啟動順序，未處理 ready 狀態。
    - 證據：
      - `docker-compose.yml:36` 的 nginx 僅使用 `depends_on: [php]`
      - `docker-compose.yml:86` 的 php 僅使用 `depends_on: [mysql]`
    - 影響：目前只保證啟動順序，不能保證依賴服務已可正常使用。
    - 建議：若要讓啟動流程更可預測，應搭配 health check 一起使用。

## 現況中已做得不錯的部分

- PHP 版本選擇明確，並透過 `php/php56`、`php/php74`、`php/php80`、`php/php81`、`php/php82`、`php/php83` 分開 build context。
- `.env.example` 已明確提供 `NGINX_VERSION=1.24-alpine` 與 `MYSQL_VERSION=5.7` 的預設值，優於直接使用 `latest`。
- nginx 設定、SSL 檔案、MySQL 設定、初始化腳本與 PHP entrypoint script 多數都以 `:ro` 方式掛載。
- `docker-compose config -q` 可通過，表示目前 compose 檔案在既有環境下語法正確。

## 分類結論

### 符合最佳實務

- 明確指定版本，而非使用 `latest`
- 多個設定資產採用唯讀掛載
- 依 PHP 版本分開 Dockerfile

### 可接受的 Legacy 例外

- PHP 5.6 與 7.4 維持單階段 build
- 對 EOL runtime 使用 archived Debian sources
- 在明確僅限本地環境時允許 MySQL 空密碼
- 為了加速本地開發而將 Composer、PHPUnit、Xdebug 打包進 dev image

### 不符合最佳實務

- PHP 容器以 root 執行
- 缺少 `.dockerignore`
- 在 nginx 的 runtime `command` 內安裝套件
- 缺少 `HEALTHCHECK`
- runtime 與 test/debug 工具未清楚分離

## 建議修正優先順序

1. 新增 `.dockerignore`。
2. 將 nginx 時區套件安裝移出 `docker-compose.yml` 的 runtime `command`。
3. 為 `nginx`、`php`、`mysql` 補上 health check。
4. 在驗證 bind mount 權限後，讓 PHP runtime 改用非 root 使用者。
5. 從 PHP 8.1+ 開始，將 PHP 映像拆分為 `dev/test` 與 `runtime`。
6. 將 PHP 5.6 / 7.4 明確標記為例外通道，並更清楚記錄其已不受支援的安全狀態。
