# PHP Composer & PHPUnit 統一安裝專案

## 📋 專案概述

本專案為所有 PHP 版本容器（5.6, 7.4, 8.0, 8.1, 8.2, 8.3）統一安裝了對應的最高 LTS 版本 Composer 和 PHPUnit，確保開發和測試環境的一致性。

## ✨ 主要改進

### 問題解決
- ❌ **改進前**: 各 PHP 容器未安裝 Composer 和 PHPUnit
- ❌ **痛點**: 切換 PHP 版本時，測試工具版本不一致，容易混淆
- ✅ **改進後**: 所有容器統一使用 `composer` 和 `phpunit` 指令，版本明確且相容

### 核心特性
1. **版本明確**: 每個 PHP 版本使用最佳相容的 Composer 和 PHPUnit 版本
2. **全域安裝**: 統一使用系統層級安裝，避免專案依賴衝突
3. **LTS 優先**: 優先選擇長期支援版本，確保穩定性
4. **無縫切換**: 切換 PHP 版本時，測試工具自動對應正確版本

## ⚠️ 重要說明

**PHP 5.6 特別注意**: Composer 1.x 已於 2025/09/01 停止 Packagist 支援，因此 PHP 5.6 的 PHPUnit 改用直接下載 PHAR 檔案方式安裝。功能完全相同，僅安裝方式不同。

## 📊 版本對應表

| PHP 版本 | Composer | PHPUnit | 安裝方式 | 驗證狀態 |
|---------|---------|---------|---------|---------|
| 5.6 | 1.10.27 | 5.7.27 | PHAR | ✅ 已測試 |
| 7.4 | 2.2.24 | 9.6.30 | Composer | ✅ 已測試 |
| 8.0 | 2.8.x | 9.6.x | Composer | ✅ 已配置 |
| 8.1 | 2.8.12 | 10.5.59 | Composer | ✅ 已測試 |
| 8.2 | 2.8.x | 10.5.x | Composer | ✅ 已配置 |
| 8.3 | 2.8.x | 11.x | Composer | ✅ 已配置 |

## 🚀 使用方式

### 1. 切換 PHP 版本
在 `.env` 檔案中修改 `PHP_VERSION` 變數：

```bash
# 切換到 PHP 7.4
PHP_VERSION=74

# 切換到 PHP 8.1
PHP_VERSION=81
```

### 2. 重新建構容器
```bash
# 建構當前版本
docker-compose build php

# 或指定版本建構
PHP_VERSION=74 docker-compose build php
```

### 3. 檢查版本
```bash
# 檢查 Composer 版本
docker-compose run --rm php composer --version

# 檢查 PHPUnit 版本
docker-compose run --rm php phpunit --version

# 檢查 PHP 版本
docker-compose run --rm php php --version
```

### 4. 執行單元測試
```bash
# 在容器內執行測試
docker-compose exec php phpunit

# 執行特定測試檔案
docker-compose exec php phpunit /var/www/tests/Unit/ExampleTest.php

# 執行測試並生成覆蓋率
docker-compose exec php phpunit --coverage-html coverage/
```

## 🧪 自動化測試

### Windows 使用者

**PowerShell (推薦)**:
```powershell
# 執行 PowerShell 腳本
.\scripts\test-versions.ps1

# 如遇到執行原則錯誤
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\test-versions.ps1
```

**命令提示字元**:
```cmd
# 執行批次檔
scripts\test-versions.bat
```

### Linux/Mac 使用者
```bash
# 賦予執行權限
chmod +x scripts/switch-version.sh

# 執行切換腳本
./scripts/switch-version.sh
```

此腳本會自動測試所有 PHP 版本的 Composer 和 PHPUnit 安裝狀態。詳細測試指南請參考 [docs/TEST_GUIDE.md](docs/TEST_GUIDE.md)。

## 📁 檔案結構

```
docker_run/
├── php/
│   ├── php56/
│   │   └── Dockerfile          # ✅ 已更新：Composer 1.10.27 + PHPUnit 5.7
│   ├── php74/
│   │   └── Dockerfile          # ✅ 已更新：Composer 2.2.24 + PHPUnit 9.6
│   ├── php80/
│   │   └── Dockerfile          # ✅ 已更新：Composer 2.8 + PHPUnit 9.6
│   ├── php81/
│   │   └── Dockerfile          # ✅ 已更新：Composer 2.8 + PHPUnit 10.5
│   ├── php82/
│   │   └── Dockerfile          # ✅ 已更新：Composer 2.8 + PHPUnit 10.5
│   └── php83/
│       └── Dockerfile          # ✅ 已更新：Composer 2.8 + PHPUnit 11
├── docs/
│   ├── VERSION_REFERENCE.md    # 📖 版本對照與使用指引
│   ├── IMPLEMENTATION_PLAN.md  # 📝 實作計畫與驗證記錄
│   ├── PHP_COMPOSER_PHPUNIT_SETUP.md  # 📖 本文件
│   └── TEST_GUIDE.md           # 📖 測試指南
└── scripts/
    ├── test-versions.bat       # 🧪 測試腳本 (Windows CMD)
    ├── test-versions.ps1       # 🧪 測試腳本 (Windows PowerShell)
    ├── switch-version.bat      # 🔄 PHP 版本切換腳本 (Windows)
    └── switch-version.sh       # 🔄 PHP 版本切換腳本 (Linux/Mac)
```

## 🔧 技術實作細節

### Composer 安裝方式
```dockerfile
# 使用官方 Composer 映像檔
COPY --from=composer:X.X.X /usr/bin/composer /usr/local/bin/composer
```

### PHPUnit 安裝方式

**PHP 7.4 - 8.3** (透過 Composer):
```dockerfile
# 透過 Composer 全域安裝並建立符號連結
RUN composer global require phpunit/phpunit:^X.X --no-interaction --prefer-dist && \
    ln -s /root/.composer/vendor/bin/phpunit /usr/local/bin/phpunit
```

**PHP 5.6** (直接下載 PHAR):
```dockerfile
# 直接下載 PHPUnit PHAR 檔案
RUN curl -L https://phar.phpunit.de/phpunit-5.7.27.phar -o /usr/local/bin/phpunit && \
    chmod +x /usr/local/bin/phpunit
```

> **為什麼 PHP 5.6 不同？**
> Composer 1.x 已於 2025/09/01 停止 Packagist 支援，無法使用 `composer require` 安裝套件。改用官方 PHAR 檔案確保功能正常。

### 設計原則
1. **Single Source of Truth**: 容器層級定義版本，不依賴專案 composer.json
2. **Explicit over Implicit**: 明確指定版本，避免自動升級
3. **LTS First**: 優先使用長期支援版本
4. **Global Installation**: 全域安裝確保指令統一

## 📚 參考文件

- [docs/VERSION_REFERENCE.md](VERSION_REFERENCE.md) - 詳細版本對照與疑難排解
- [docs/IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) - 完整實作計畫與驗證記錄
- [docs/TEST_GUIDE.md](TEST_GUIDE.md) - 測試指南與疑難排解

## 🎯 驗證結果

### PHP 5.6 ✅
```
Composer version 1.10.27 2023-09-29 10:50:23
PHPUnit 5.7.27 by Sebastian Bergmann and contributors.
```

### PHP 7.4 ✅
```
Composer version 2.2.24 2024-06-10 22:51:52
PHPUnit 9.6.30 by Sebastian Bergmann and contributors.
```

### PHP 8.1 ✅
```
Composer version 2.8.12 2025-09-19 13:41:59
PHPUnit 10.5.59 by Sebastian Bergmann and contributors.
```

## ⚠️ 注意事項

1. **第一次使用**: 需要重新建構對應的 PHP 容器
   ```bash
   docker-compose build php
   ```

2. **版本切換**: 修改 `.env` 的 `PHP_VERSION` 後需重新建構
   ```bash
   PHP_VERSION=81 docker-compose build php
   ```

3. **快取問題**: 如遇到版本不正確，使用 `--no-cache` 強制重建
   ```bash
   docker-compose build --no-cache php
   ```

4. **權限問題**: PHPUnit 生成報告時可能需要寫入權限
   ```bash
   # 在容器內調整權限
   docker-compose exec php chown -R www-data:www-data /var/www
   ```

## 🆘 疑難排解

### Q: PHPUnit 找不到指令
```bash
# 檢查符號連結
docker-compose exec php ls -la /usr/local/bin/phpunit

# 手動建立符號連結
docker-compose exec php ln -sf /root/.composer/vendor/bin/phpunit /usr/local/bin/phpunit
```

### Q: Composer 版本不符
```bash
# 檢查實際版本
docker-compose exec php composer --version

# 重新建構容器
docker-compose build --no-cache php
```

### Q: 測試執行失敗
```bash
# 確認 PHP 版本
docker-compose exec php php --version

# 確認 PHPUnit 版本相容性
docker-compose exec php phpunit --version
```