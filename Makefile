# ================================================
# POSDEV Docker 環境快速指令集
# ================================================
# 使用 docker compose (v2 plugin) 指令
# 支援平台: Linux, macOS (Docker Desktop), Windows (WSL2 / Git Bash)
# ================================================

# 從 .env 載入變數（檔案不存在時靜默跳過）
ENV_FILE ?= .env
-include $(ENV_FILE)
export

# 供 compose 的 image label 使用（取不到時為 unknown）
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
export GIT_SHA

.PHONY: help up down restart build logs shell db-shell php-version mysql-version clean preflight check hooks smoke

# 預設目標: 顯示說明
help:
	@echo "================================================"
	@echo "POSDEV Docker 環境管理指令"
	@echo "================================================"
	@echo ""
	@echo "環境控制:"
	@echo "  make up          - 啟動所有容器"
	@echo "  make down        - 停止並移除所有容器"
	@echo "  make restart     - 重啟所有容器"
	@echo "  make build       - 重新建置並啟動容器"
	@echo ""
	@echo "檢查與驗證:"
	@echo "  make preflight   - 啟動前修正 mysql 設定檔權限 (644)"
	@echo "  make check       - 執行設定檔守門檢查 (scripts/check-config.sh)"
	@echo "  make hooks       - 啟用 .githooks (pre-commit 檢查)"
	@echo "  make smoke       - 對運行中的環境做 HTTP 冒煙測試"
	@echo ""
	@echo "測試環境 (make/test.mk):"
	@echo "  make php84-up / php84-down - 啟動/移除 PHP 8.4 並行測試容器"
	@echo "  make php84-shell - 進入 php84 容器 (HOST_UID)"
	@echo "  make php84-test [SUITE=unit] [WORKTREE=路徑] - 在 php84 跑測試並寫入 logs/test/"
	@echo "  make test-db-init|test-db-ping|test-db-list [DB_HOST=mysql|mariadb101] - 測試資料庫"
	@echo "  make splitbill-gate-env - 顯示 splitbill gate 所需環境變數"
	@echo "  make mariadb101-up / mariadb101-down - MariaDB 10.1 對照組"
	@echo ""
	@echo "日誌與監控:"
	@echo "  make logs        - 查看所有容器日誌"
	@echo "  make logs-nginx  - 查看 Nginx 日誌"
	@echo "  make logs-php    - 查看 PHP 日誌"
	@echo "  make logs-mysql  - 查看 MySQL 日誌"
	@echo ""
	@echo "容器操作:"
	@echo "  make shell       - 進入 PHP 容器 Shell"
	@echo "  make db-shell    - 進入 MySQL 容器 Shell"
	@echo ""
	@echo "版本資訊:"
	@echo "  make php-version - 顯示 PHP 版本"
	@echo "  make mysql-version - 顯示 MySQL 版本"
	@echo ""
	@echo "清理:"
	@echo "  make clean       - 清理未使用的映像與 Volume"
	@echo ""
	@echo "================================================"

# 啟動前檢查：mysql 設定檔若為 world-writable 會被 mysqld 忽略（冪等）
preflight:
	@changed=0; \
	for f in mysql/conf.d/*.cnf mysql/mariadb101/conf.d/*.cnf; do \
	  [ -e "$$f" ] || continue; \
	  if [ "$$(stat -c '%a' "$$f")" != "644" ]; then chmod 644 "$$f"; changed=1; fi; \
	done; \
	if [ "$$changed" = "1" ]; then echo "preflight: 已將 mysql 設定檔 (*.cnf) 權限修正為 644"; fi

# 設定檔守門檢查
check:
	bash scripts/check-config.sh

# 啟用 git hooks
hooks:
	git config core.hooksPath .githooks

# HTTP 冒煙測試
smoke:
	bash scripts/smoke.sh

# 啟動所有容器
up: preflight
	docker compose up -d

# 停止並移除所有容器
down:
	docker compose down --remove-orphans

# 重啟所有容器
restart: preflight
	docker compose down --remove-orphans
	docker compose up -d

# 重新建置並啟動容器
build: preflight
	docker compose down --remove-orphans
	docker compose build --no-cache
	docker compose up -d

# 查看所有容器日誌
logs:
	docker compose logs -f

# 查看 Nginx 日誌
logs-nginx:
	docker compose logs -f nginx

# 查看 PHP 日誌
logs-php:
	docker compose logs -f php

# 查看 MySQL 日誌
logs-mysql:
	docker compose logs -f mysql

# 進入 PHP 容器 Shell
shell:
	docker compose exec php bash

# 進入 MySQL 容器 Shell
db-shell:
	@if [ -z "$(MYSQL_ROOT_PASSWORD)" ]; then \
	  docker compose exec mysql mysql -uroot $(MYSQL_DATABASE); \
	else \
	  docker compose exec mysql mysql -uroot -p$(MYSQL_ROOT_PASSWORD) $(MYSQL_DATABASE); \
	fi

# 顯示 PHP 版本
php-version:
	docker compose exec php php -v

# 顯示 MySQL 版本
mysql-version:
	docker compose exec mysql mysql --version

# ================================================
# KDS 專用 (mypos-kds-v1) 指令
# ================================================

# 進入 Node 容器
node-shell:
	docker compose exec node sh

# Node 套件安裝 (--legacy-peer-deps 處理 laravel-mix 5/webpack-plugin peer 衝突)
node-install:
	docker compose exec node npm install --legacy-peer-deps

# 跑 Jest (用本地 node_modules 中的 jest 27，避免 npx 拉 jest 30)
kds-jest:
	docker compose exec node ./node_modules/.bin/jest

# 在 PHP 容器內對 KDS 跑 composer install
kds-composer-install:
	docker compose exec php bash -c "cd /var/www/www.posdev/mypos_kds && composer install"

# 在 PHP 容器內對 KDS 跑 PHPUnit
kds-phpunit:
	docker compose exec php bash -c "cd /var/www/www.posdev/mypos_kds && phpunit"	

# 清理未使用的映像與 Volume
clean:
	docker system prune -f
	@echo "清理完成! 資料庫 Volume 已保留。"

# 完全清理 (包含 Volume,會刪除資料庫)
clean-all:
	docker compose down -v
	docker system prune -af
	@echo "警告: 所有資料已清除!"

# 測試環境指令
-include make/*.mk
