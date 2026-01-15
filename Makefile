# ================================================
# POSDEV Docker 環境快速指令集
# ================================================
# 注意: Windows 環境下可能需要安裝 Make 工具
# 或直接參考下方指令使用 docker-compose 指令
# ================================================

.PHONY: help up down restart build logs shell db-shell php-version mysql-version clean

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

# 啟動所有容器
up:
	docker-compose up -d

# 停止並移除所有容器
down:
	docker-compose down

# 重啟所有容器
restart:
	docker-compose restart

# 重新建置並啟動容器
build:
	docker-compose down
	docker-compose build --no-cache
	docker-compose up -d

# 查看所有容器日誌
logs:
	docker-compose logs -f

# 查看 Nginx 日誌
logs-nginx:
	docker-compose logs -f nginx

# 查看 PHP 日誌
logs-php:
	docker-compose logs -f php

# 查看 MySQL 日誌
logs-mysql:
	docker-compose logs -f mysql

# 進入 PHP 容器 Shell
shell:
	docker-compose exec php bash

# 進入 MySQL 容器 Shell
db-shell:
	docker-compose exec mysql mysql -uroot -p$(MYSQL_ROOT_PASSWORD) pos_dev

# 顯示 PHP 版本
php-version:
	docker-compose exec php php -v

# 顯示 MySQL 版本
mysql-version:
	docker-compose exec mysql mysql --version

# 清理未使用的映像與 Volume
clean:
	docker system prune -f
	@echo "清理完成! 資料庫 Volume 已保留。"

# 完全清理 (包含 Volume,會刪除資料庫)
clean-all:
	docker-compose down -v
	docker system prune -af
	@echo "警告: 所有資料已清除!"
