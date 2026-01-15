# PHP 環境版本對照表

本文件說明各 PHP 版本容器中安裝的 Composer 和 PHPUnit 版本。

## ⚠️ 重要更新（2025-12-03）

**PHP 5.6 特殊說明**: 由於 Composer 1.x 已於 2025/09/01 停止 Packagist.org 支援，PHP 5.6 的 PHPUnit 改用直接下載 PHAR 檔案的方式安裝，而非透過 Composer。

## 版本對照表

| PHP 版本 | Base Image | Composer 版本 | PHPUnit 版本 | 安裝方式 | 驗證狀態 |
|---------|-----------|--------------|-------------|---------|---------|
| **5.6** | php:5.6-fpm-stretch | **1.10.27** | **5.7.27** | PHAR | ✅ 已測試 |
| **7.4** | php:7.4-fpm-buster | **2.2.24** | **9.6.30** | Composer | ✅ 已測試 |
| **8.0** | php:8.0-fpm-bullseye | **2.8.x** | **9.6.x** | Composer | ✅ 已配置 |
| **8.1** | php:8.1-fpm-bullseye | **2.8.12** | **10.5.59** | Composer | ✅ 已測試 |
| **8.2** | php:8.2-fpm-bookworm | **2.8.x** | **10.5.x** | Composer | ✅ 已配置 |
| **8.3** | php:8.3-fpm-bookworm | **2.8.x** | **11.x** | Composer | ✅ 已配置 |

## 版本選擇原則

### Composer
- **PHP 5.6**: 使用 Composer 1.10.27（Composer 1.x 系列最終版本）
  - ⚠️ 注意：Packagist 已停止支援，僅能用於基本功能
- **PHP 7.4**: 使用 Composer 2.2.24（Composer 2.2 LTS，確保長期穩定）
- **PHP 8.0+**: 使用 Composer 2.8.x（最新穩定版，享受效能與功能改善）

### PHPUnit
- **PHP 5.6**: PHPUnit 5.7.27（PHP 5.6 最高相容版本，PHAR 安裝）
- **PHP 7.4 - 8.0**: PHPUnit 9.6.x（LTS 版本，廣泛相容）
- **PHP 8.1 - 8.2**: PHPUnit 10.5.x（PHPUnit 10 LTS）
- **PHP 8.3**: PHPUnit 11.x（最新穩定版本，支援 PHP 8.3 新特性）

## 安裝方式

所有 PHP 版本統一採用以下安裝方式：

### Composer
```dockerfile
COPY --from=composer:X.X.X /usr/bin/composer /usr/local/bin/composer
```
- 使用官方 Composer 映像檔，確保版本一致性
- 安裝至 `/usr/local/bin/composer`，全域可用

### PHPUnit

**PHP 7.4 - 8.3** (透過 Composer 安裝):
```dockerfile
RUN composer global require phpunit/phpunit:^X.X --no-interaction --prefer-dist && \
    ln -s /root/.composer/vendor/bin/phpunit /usr/local/bin/phpunit
```

**PHP 5.6** (直接下載 PHAR):
```dockerfile
RUN curl -L https://phar.phpunit.de/phpunit-5.7.27.phar -o /usr/local/bin/phpunit && \
    chmod +x /usr/local/bin/phpunit
```

**為什麼 PHP 5.6 使用 PHAR？**
- Composer 1.x 已於 2025 年 9 月 1 日停止 Packagist.org 支援
- 無法透過 `composer require` 安裝套件
- 改用官方 PHPUnit PHAR 檔案確保可正常運作
- 功能完全相同，僅安裝方式不同

## 使用指引

### 檢查版本
在容器內執行以下指令檢查版本：

```bash
# 檢查 Composer 版本
composer --version

# 檢查 PHPUnit 版本
phpunit --version

# 檢查 PHP 版本
php --version
```

### 使用 docker-compose 檢查

```bash
# 檢查 PHP 5.6 環境
docker-compose run --rm php56 composer --version
docker-compose run --rm php56 phpunit --version

# 檢查 PHP 7.4 環境
docker-compose run --rm php74 composer --version
docker-compose run --rm php74 phpunit --version

# 檢查 PHP 8.1 環境
docker-compose run --rm php81 composer --version
docker-compose run --rm php81 phpunit --version
```

### 執行單元測試

統一使用 `phpunit` 指令執行測試，不會因切換 PHP 版本而混淆：

```bash
# 在容器內直接執行
phpunit

# 透過 docker-compose 執行（PHP 7.4 範例）
docker-compose exec php74 phpunit /var/www/tests

# 執行特定測試檔案
phpunit tests/Unit/ExampleTest.php

# 執行測試並生成覆蓋率報告
phpunit --coverage-html coverage/
```

### 切換 PHP 版本測試

由於每個 PHP 版本都有對應相容的 PHPUnit 版本，可以安心切換測試：

```bash
# 使用 PHP 5.6 執行測試（PHPUnit 5.7）
PHP_VERSION=56 docker-compose exec php phpunit

# 使用 PHP 7.4 執行測試（PHPUnit 9.6）
PHP_VERSION=74 docker-compose exec php phpunit

# 使用 PHP 8.1 執行測試（PHPUnit 10.5）
PHP_VERSION=81 docker-compose exec php phpunit

# 使用 PHP 8.3 執行測試（PHPUnit 11）
PHP_VERSION=83 docker-compose exec php phpunit
```

## 設計理念

### 為什麼要全域安裝？

1. **統一執行方式**: 所有環境都使用 `phpunit` 指令，避免 `./vendor/bin/phpunit` 混淆
2. **版本明確性**: 容器層級明確定義版本，不依賴專案的 `composer.json`
3. **獨立測試環境**: 可在沒有專案依賴的情況下執行基礎測試
4. **避免版本衝突**: 測試工具版本由環境管理，不與專案依賴混淆

### 為什麼選擇 LTS 版本？

- **穩定性**: LTS（Long Term Support）版本獲得更長時間的維護與安全更新
- **相容性**: 減少因版本升級導致的破壞性變更
- **最佳實踐**: 生產環境優先使用經過廣泛驗證的穩定版本

## 維護注意事項

### 更新版本時機

1. **Composer**:
   - 定期檢查安全性更新
   - 主要版本升級需評估相容性
   - ⚠️ PHP 5.6 的 Composer 1.x 已無法使用 Packagist

2. **PHPUnit**:
   - 在同一主要版本內（如 9.6.x）可定期更新次版本
   - 跨主要版本升級（如 9 → 10）需評估測試程式碼相容性
   - PHP 5.6 的 PHPUnit PHAR 可從 https://phar.phpunit.de/ 更新

### 重新建構映像檔

修改 Dockerfile 後需重新建構：

```bash
# 重新建構單一版本
PHP_VERSION=56 docker-compose build php

# 重新建構所有 PHP 版本（需要逐一切換）
for v in 56 74 80 81 82 83; do
  PHP_VERSION=$v docker-compose build php
done

# 強制重新建構（不使用快取）
PHP_VERSION=74 docker-compose build --no-cache php
```

## 相容性矩陣

### Composer 相容性
| Composer 版本 | PHP 最低需求 | PHP 最高支援 | Packagist 支援 |
|--------------|-------------|------------|--------------|
| 1.10.x | 5.3 | 8.0 | ❌ 已停止 (2025/09/01) |
| 2.2.x | 7.2 | 8.2 | ✅ 支援 |
| 2.8.x | 7.2 | 8.3+ | ✅ 支援 |

### PHPUnit 相容性
| PHPUnit 版本 | PHP 最低需求 | PHP 最高支援 | 安裝方式 |
|-------------|-------------|------------|---------|
| 5.7.x | 5.6 | 7.0 | PHAR |
| 9.6.x | 7.3 | 8.2 | Composer |
| 10.5.x | 8.1 | 8.3+ | Composer |
| 11.x | 8.2 | 8.3+ | Composer |

## 驗證結果

### PHP 5.6 ✅ (2025-12-03)
```bash
$ PHP_VERSION=56 docker-compose run --rm php composer --version
Composer version 1.10.27 2023-09-29 10:50:23

$ PHP_VERSION=56 docker-compose run --rm php phpunit --version
PHPUnit 5.7.27 by Sebastian Bergmann and contributors.
```

### PHP 7.4 ✅ (2025-12-03)
```bash
$ PHP_VERSION=74 docker-compose run --rm php composer --version
Composer version 2.2.24 2024-06-10 22:51:52

$ PHP_VERSION=74 docker-compose run --rm php phpunit --version
PHPUnit 9.6.30 by Sebastian Bergmann and contributors.
```

### PHP 8.1 ✅ (2025-12-03)
```bash
$ PHP_VERSION=81 docker-compose run --rm php composer --version
Composer version 2.8.12 2025-09-19 13:41:59

$ PHP_VERSION=81 docker-compose run --rm php phpunit --version
PHPUnit 10.5.59 by Sebastian Bergmann and contributors.
```

## 疑難排解

### PHPUnit 找不到
```bash
# 確認 PHPUnit 是否存在
docker-compose exec php which phpunit

# 檢查執行權限
docker-compose exec php ls -la /usr/local/bin/phpunit

# PHP 5.6 重新下載 PHAR
docker-compose exec php curl -L https://phar.phpunit.de/phpunit-5.7.27.phar -o /usr/local/bin/phpunit
docker-compose exec php chmod +x /usr/local/bin/phpunit

# PHP 7.4+ 重建符號連結
docker-compose exec php ln -sf /root/.composer/vendor/bin/phpunit /usr/local/bin/phpunit
```

### Composer 版本不符
```bash
# 檢查實際版本
docker-compose exec php composer --version

# 重新建構容器確保版本正確
PHP_VERSION=74 docker-compose build --no-cache php
```

### PHP 5.6 Composer 無法安裝套件
這是正常現象！Packagist 已停止支援 Composer 1.x。解決方案：
- 如需安裝套件，請使用專案本地的 composer.json（如果可行）
- 考慮升級到 PHP 7.4 或更高版本
- 使用 PHAR 方式安裝獨立工具（如 PHPUnit）

### 權限問題
```bash
# PHPUnit 可能需要寫入權限（如生成覆蓋率報告）
docker-compose exec php chmod -R 755 /var/www/tests
docker-compose exec php chown -R www-data:www-data /var/www
```

## PHP 5.6 限制說明

由於 PHP 5.6 已於 2019 年 1 月停止官方支援，且 Composer 1.x 也已停止 Packagist 支援，使用上有以下限制：

### 可用功能
- ✅ Composer 基本功能（查看版本、自動載入等）
- ✅ PHPUnit 完整功能（透過 PHAR）
- ✅ 執行現有專案

### 不可用功能
- ❌ 透過 Composer 從 Packagist 安裝新套件
- ❌ 更新現有套件（composer update）
- ❌ 獲得安全性更新

### 建議
如果您的專案仍在使用 PHP 5.6，強烈建議：
1. 規劃升級至 PHP 7.4 或更高版本
2. 使用容器環境進行隔離，避免安全風險
3. 不要在生產環境使用 PHP 5.6
