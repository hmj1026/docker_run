# 專案檔案結構說明

## 📁 完整目錄結構

```
docker_run/
│
├── 📄 README.md                    # 專案主要說明文件
├── 📄 docker-compose.yml           # Docker Compose 配置
├── 📄 .dockerignore                # Docker build context 排除規則
├── 📄 .env                         # 環境變數配置
├── 📄 .env.example                 # 環境變數範例
│
├── 📂 php/                         # PHP 容器配置
│   ├── php56/
│   │   ├── Dockerfile              # ✅ Composer 1.10.27 + PHPUnit 5.7.27 (PHAR)
│   │   └── php.ini                 # PHP 5.6 配置
│   ├── php74/
│   │   ├── Dockerfile              # ✅ Composer 2.2.24 + PHPUnit 9.6.30
│   │   └── php.ini                 # PHP 7.4 配置
│   ├── php80/
│   │   ├── Dockerfile              # ✅ Composer 2.8.x + PHPUnit 9.6.x
│   │   └── php.ini                 # PHP 8.0 配置
│   ├── php81/
│   │   ├── Dockerfile              # ✅ Composer 2.8.12 + PHPUnit 10.5.59
│   │   └── php.ini                 # PHP 8.1 配置
│   ├── php82/
│   │   ├── Dockerfile              # ✅ Composer 2.8.x + PHPUnit 10.5.x
│   │   └── php.ini                 # PHP 8.2 配置
│   └── php83/
│       ├── Dockerfile              # ✅ Composer 2.8.x + PHPUnit 11.x
│       └── php.ini                 # PHP 8.3 配置
│
├── 📂 nginx/                       # Nginx 配置
│   ├── Dockerfile                  # 自訂 Nginx image（含時區資料）
│   ├── conf.d/
│   │   ├── 00-healthcheck.conf     # 內部健康檢查端點
│   │   └── *.conf                  # Nginx 站點配置
│   └── ssl/                        # SSL 憑證目錄
│
├── 📂 mysql/                       # MySQL 配置
│   ├── conf.d/
│   │   └── my.cnf                  # MySQL 配置
│   └── init/                       # 初始化 SQL 腳本
│
├── 📂 docs/                        # 📖 文件目錄
│   ├── PHP_COMPOSER_PHPUNIT_SETUP.md   # Composer & PHPUnit 配置說明
│   ├── DOCKER_BEST_PRACTICES_AUDIT.md  # Docker 最佳實務審查結果
│   ├── VERSION_REFERENCE.md            # 版本對照表與疑難排解
│   ├── PATH_AND_BOOTSTRAP.md           # 路徑、入口、路由與設定檔關係
│   ├── IMPLEMENTATION_PLAN.md          # 實作計畫與驗證記錄
│   ├── TEST_GUIDE.md                   # 測試指南
│   └── FILE_STRUCTURE.md               # 本文件
│
├── 📂 scripts/                     # 腳本目錄
│   ├── test-versions.sh            # PHP 版本測試
│   ├── switch-version.sh           # PHP 版本切換
│   ├── generate-cert.sh            # SSL 憑證生成
│   └── php-entrypoint.sh           # PHP 容器啟動腳本
│
├── 📂 logs/                        # 日誌目錄
│   ├── nginx/                      # Nginx 日誌
│   ├── php/                        # PHP-FPM 日誌
│   ├── mysql/                      # MySQL 日誌
│   └── zdnStorage/                 # 應用程式日誌
│
├── 📂 data/                        # 資料持久化
│   └── mysql/                      # MySQL 資料庫資料
│
└── 📂 openspec/                    # OpenSpec 配置 (可選)
```

---

## 📖 文件說明

### 核心文件
| 檔案 | 說明 |
|------|------|
| `README.md` | 專案主要說明，快速開始指引 |
| `docker-compose.yml` | Docker 容器編排配置 |
| `.dockerignore` | Docker build context 排除規則 |
| `.env` | 環境變數設定（未納入版控） |
| `.env.example` | 環境變數範例 |

### 文件目錄 (docs/)
| 檔案 | 說明 |
|------|------|
| `PHP_COMPOSER_PHPUNIT_SETUP.md` | Composer & PHPUnit 統一安裝專案總覽 |
| `DOCKER_BEST_PRACTICES_AUDIT.md` | Docker Compose / Dockerfile 最佳實務審查結果 |
| `VERSION_REFERENCE.md` | 各 PHP 版本的 Composer 和 PHPUnit 版本對照表 |
| `PATH_AND_BOOTSTRAP.md` | 說明跨平台路徑、`/dev3/` bootstrap、`main.php` 與 `dev3.php` 的關係 |
| `IMPLEMENTATION_PLAN.md` | 完整實作計畫、階段說明與驗證記錄 |
| `TEST_GUIDE.md` | 測試指南、疑難排解與快速參考 |
| `FILE_STRUCTURE.md` | 專案檔案結構說明（本文件） |

### 腳本目錄 (scripts/)
| 檔案 | 說明 |
|------|------|
| `test-versions.sh` | 自動測試所有 PHP 版本 |
| `switch-version.sh` | PHP 版本切換腳本 |
| `generate-cert.sh` | 生成 SSL 自簽憑證 |
| `php-entrypoint.sh` | PHP 容器啟動腳本（權限修復） |

---

## 🎯 快速導航

### 我想要...

#### 了解 Composer & PHPUnit 配置
👉 閱讀 [docs/PHP_COMPOSER_PHPUNIT_SETUP.md](PHP_COMPOSER_PHPUNIT_SETUP.md)

#### 查看版本對照表
👉 閱讀 [docs/VERSION_REFERENCE.md](VERSION_REFERENCE.md)

#### 測試 PHP 環境
👉 閱讀 [docs/TEST_GUIDE.md](TEST_GUIDE.md)

#### 執行測試腳本
```bash
# 測試所有版本
bash scripts/test-versions.sh

# 互動式切換版本
bash scripts/switch-version.sh
```

#### 切換 PHP 版本
```bash
# 修改 .env 中的 PHP_VERSION
PHP_VERSION=74  # 可選: 56, 74, 80, 81, 82, 83

# 重新建構
docker compose build php
```

#### 查看實作細節
👉 閱讀 [docs/IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)

---

## 🔧 目錄用途說明

### `/php/`
包含所有 PHP 版本的 Dockerfile 和配置檔案。每個版本都已安裝對應的：
- **Composer**: 該環境支援的最高 LTS 版本
- **PHPUnit**: 相容的最高版本
- **PHP 擴展**: gd, mysqli, pdo, opcache, zip, intl 等

### `/docs/`
所有專案文件集中存放處，包括：
- 技術規格文件
- 使用指南
- 版本對照表
- 疑難排解

### `/scripts/`
自動化腳本與工具，包括：
- 測試腳本
- 版本切換腳本
- SSL 憑證生成腳本

### `/logs/`
所有服務的日誌輸出，方便除錯：
- Nginx 存取與錯誤日誌
- PHP-FPM 日誌
- MySQL 慢查詢日誌
- 應用程式日誌

### `/data/`
持久化資料儲存：
- MySQL 資料庫檔案

---

## 📝 版本控制

### 納入版控的檔案
- ✅ 所有 Dockerfile
- ✅ 所有配置檔案
- ✅ 文件 (docs/)
- ✅ 腳本 (scripts/)
- ✅ .env.example

### 不納入版控的檔案
- ❌ .env (個人環境設定)
- ❌ logs/ (日誌檔案)
- ❌ data/ (資料庫資料)
- ❌ SSL 憑證檔案

---

## 🔄 檔案更新記錄

### 2025-12-03
- ✅ 所有 PHP Dockerfile 加入 Composer 和 PHPUnit
- ✅ PHP 5.6 改用 PHAR 方式安裝 PHPUnit (Composer 1.x 已停止 Packagist 支援)
- ✅ 建立完整文件系統 (docs/)
- ✅ 建立測試腳本 (scripts/)
- ✅ 組織檔案結構

---

**最後更新**: 2025-12-03
