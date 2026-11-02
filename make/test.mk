# ================================================
# 測試環境指令 (PHP 8.4 並行測試 / 測試資料庫 / MariaDB 10.1)
# 由 Makefile 以 -include make/*.mk 載入；變數來自 .env
# ================================================

.PHONY: php84-up php84-down php84-shell php84-test \
	test-db-init test-db-ping test-db-list splitbill-gate-env \
	mariadb101-up mariadb101-down

# php84-test 參數
#   WORKTREE  待測 worktree（宿主機路徑，須位於 PROJECTS_ROOT 之下）
#   SUITE     fast | unit | integration | full（對應 run-tests.sh 子命令）
WORKTREE ?= $(PROJECTS_ROOT)/www.posdev/zdpos-217-php84
SUITE ?= unit

# 啟動 php84 容器（--no-deps：不動到 php / nginx / mysql）
php84-up: preflight
	docker compose --profile php84 up -d --no-deps php84

# 停止並移除 php84 容器
php84-down:
	docker compose --profile php84 stop php84
	docker compose --profile php84 rm -f php84

# 進入 php84 容器 Shell（以 HOST_UID:HOST_GID 身分）
php84-shell:
	docker compose exec --user $(or $(HOST_UID),1000):$(or $(HOST_GID),1000) -e HOME=/work php84 bash

# 在 php84 容器跑測試；優先使用 worktree 的 run-tests.sh（文件化入口），缺少時直接呼叫 phpunit
# 日誌: logs/test/<時間戳>-php84-<SUITE>.log
php84-test: SHELL := /bin/bash
php84-test:
	@if [ -z "$(PROJECTS_ROOT)" ] && [ "$(origin WORKTREE)" != "command line" ]; then \
	  echo "PROJECTS_ROOT 未設定 (.env)，或以 WORKTREE=<路徑> 指定"; exit 2; fi
	@if [ -f "$(WORKTREE)/protected/tests/scripts/run-tests.sh" ]; then \
	  mkdir -p logs/test; log="logs/test/$$(date +%Y%m%d-%H%M%S)-php84-$(SUITE).log"; \
	  echo "log: $$log"; \
	  # run-tests.sh 以未加引號的 $$DOCKER_CMD 展開，故可把 --user/-e 旗標前置於容器名，
	  # 讓測試以宿主機 uid 執行，避免留下 root 擁有的 .phpunit.result.cache 等檔案。
	  ZDPOS_PHP_CONTAINER="--user $(or $(HOST_UID),1000):$(or $(HOST_GID),1000) -e HOME=/work $(COMPOSE_PROJECT_NAME)_php84" ZDPOS_DOCKER_WORKDIR=$(WORKTREE) \
	    bash "$(WORKTREE)/protected/tests/scripts/run-tests.sh" $(SUITE) 2>&1 | tee "$$log"; \
	  exit $${PIPESTATUS[0]}; \
	else \
	  scripts/cexec.sh --service php84 --log php84-$(SUITE) $(WORKTREE) -- \
	    vendor/bin/phpunit -c protected/tests/phpunit.xml --testsuite $(SUITE); \
	fi

# 測試資料庫（scripts/test-db.sh；DB_HOST=mysql|mariadb101）
DB_HOST ?= mysql
test-db-init:
	bash scripts/test-db.sh --host $(DB_HOST) init

test-db-ping:
	bash scripts/test-db.sh --host $(DB_HOST) ping

test-db-list:
	bash scripts/test-db.sh --host $(DB_HOST) list

# 顯示 provision-splitbill-gate-db.sh 所需環境變數（不印出密碼值）
splitbill-gate-env:
	@echo "# 先載入 .env，再 export（密碼僅以變數參照，不顯示內容）:"
	@echo "set -a; . ./.env; set +a"
	@echo 'export ZDPOS_MYSQL_USER="$$TEST_DB_USER" ZDPOS_MYSQL_PASSWORD="$$TEST_DB_PASSWORD"'
	@echo "# 容器: ZDPOS_MYSQL_CONTAINER=$(COMPOSE_PROJECT_NAME)_mysql (預設 pos_mysql)"
	@echo "# 需先執行: make test-db-init"

# MariaDB 10.1（正式環境 collation 對照組）
mariadb101-up: preflight
	docker compose --profile mariadb101 up -d --no-deps mariadb101

mariadb101-down:
	docker compose --profile mariadb101 stop mariadb101
	docker compose --profile mariadb101 rm -f mariadb101
