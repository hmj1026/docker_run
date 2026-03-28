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

確認 Docker CE 正在運行：
```bash
systemctl status docker
docker --version
docker compose --version
```

---

## 完整測試流程

### 建構所有版本（一次性）

```bash
for v in 56 74 80 81 82 83; do
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
