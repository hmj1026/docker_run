# PHP 版本測試指南

## 🎯 快速測試

### 方法 1: 使用自動化腳本

#### Windows PowerShell (推薦)
```powershell
# 在 PowerShell 中執行
.\scripts\test-versions.ps1

# 如遇執行原則錯誤
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\test-versions.ps1
```

#### Windows 命令提示字元
```cmd
scripts\test-versions.bat
```

#### Linux/Mac
```bash
# 使用 switch-version.sh 來測試
chmod +x scripts/switch-version.sh
./scripts/switch-version.sh
```

---

## 🔍 手動測試單一版本

### 測試 PHP 5.6
```bash
# 設定版本
export PHP_VERSION=56  # Linux/Mac
set PHP_VERSION=56     # Windows CMD
$env:PHP_VERSION="56"  # Windows PowerShell

# 建構容器
docker-compose build php

# 驗證版本
docker-compose run --rm php php --version
docker-compose run --rm php composer --version
docker-compose run --rm php phpunit --version
```

### 測試 PHP 7.4
```bash
export PHP_VERSION=74  # Linux/Mac
set PHP_VERSION=74     # Windows CMD
$env:PHP_VERSION="74"  # Windows PowerShell

docker-compose build php
docker-compose run --rm php php --version
docker-compose run --rm php composer --version
docker-compose run --rm php phpunit --version
```

### 測試 PHP 8.1
```bash
export PHP_VERSION=81  # Linux/Mac
set PHP_VERSION=81     # Windows CMD
$env:PHP_VERSION="81"  # Windows PowerShell

docker-compose build php
docker-compose run --rm php php --version
docker-compose run --rm php composer --version
docker-compose run --rm php phpunit --version
```

---

## 📋 預期輸出

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

## 🐛 Windows 環境疑難排解

### 問題 1: "系統找不到指定的路徑"

**原因**: Git Bash 的路徑轉換問題

**解決方案 A - 使用 PowerShell (推薦)**:
```powershell
# 使用 PowerShell 執行
.\test-versions.ps1
```

**解決方案 B - 使用 CMD**:
```cmd
test-versions.bat
```

**解決方案 C - 直接測試單一版本**:
```cmd
set PHP_VERSION=74
docker-compose run --rm php composer --version
docker-compose run --rm php phpunit --version
```

### 問題 2: PowerShell 執行原則錯誤

如果遇到 "無法載入，因為這個系統上已停用指令碼執行"：

```powershell
# 暫時允許執行腳本（建議）
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 然後執行
.\test-versions.ps1
```

### 問題 3: docker-compose 指令找不到

確認 Docker Desktop 正在運行：
```cmd
docker --version
docker-compose --version
```

---

## 🧪 完整測試流程

### 建構所有版本（一次性）

#### Windows PowerShell
```powershell
# 建構所有 PHP 版本
$versions = @("56", "74", "80", "81", "82", "83")
foreach ($v in $versions) {
    $env:PHP_VERSION = $v
    Write-Host "Building PHP $v..." -ForegroundColor Yellow
    docker-compose build php
}
```

#### Windows CMD
```cmd
@echo off
for %%v in (56 74 80 81 82 83) do (
    echo Building PHP %%v...
    set PHP_VERSION=%%v
    docker-compose build php
)
```

#### Linux/Mac
```bash
# 建構所有 PHP 版本
for v in 56 74 80 81 82 83; do
    echo "Building PHP $v..."
    PHP_VERSION=$v docker-compose build php
done
```

---

## 📊 快速檢查指令

### 單行檢查（Windows PowerShell）
```powershell
# PHP 7.4
$env:PHP_VERSION="74"; docker-compose run --rm php sh -c "php --version && composer --version && phpunit --version"

# PHP 8.1
$env:PHP_VERSION="81"; docker-compose run --rm php sh -c "php --version && composer --version && phpunit --version"
```

### 單行檢查（Windows CMD）
```cmd
REM PHP 7.4
set PHP_VERSION=74 && docker-compose run --rm php sh -c "php --version && composer --version && phpunit --version"

REM PHP 8.1
set PHP_VERSION=81 && docker-compose run --rm php sh -c "php --version && composer --version && phpunit --version"
```

### 單行檢查（Linux/Mac）
```bash
# PHP 7.4
PHP_VERSION=74 docker-compose run --rm php sh -c "php --version && composer --version && phpunit --version"

# PHP 8.1
PHP_VERSION=81 docker-compose run --rm php sh -c "php --version && composer --version && phpunit --version"
```

---

## ✅ 驗證清單

測試每個 PHP 版本時，確認以下項目：

- [ ] PHP 版本正確
- [ ] Composer 版本正確
- [ ] PHPUnit 版本正確
- [ ] `composer --version` 指令可執行
- [ ] `phpunit --version` 指令可執行
- [ ] 容器啟動無錯誤

---

## 📝 版本對照快速參考

| PHP | Composer | PHPUnit | 安裝方式 |
|-----|----------|---------|---------|
| 5.6 | 1.10.27  | 5.7.27  | PHAR    |
| 7.4 | 2.2.24   | 9.6.30  | Composer|
| 8.0 | 2.8.x    | 9.6.x   | Composer|
| 8.1 | 2.8.12   | 10.5.59 | Composer|
| 8.2 | 2.8.x    | 10.5.x  | Composer|
| 8.3 | 2.8.x    | 11.x    | Composer|
