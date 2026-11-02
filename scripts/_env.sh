#!/usr/bin/env bash
# 共用：安全載入 .env（僅解析 KEY=VALUE，不執行內容；已存在的環境變數優先）
# 用法: source scripts/_env.sh ; load_env "$ROOT_DIR"
# 可用 ENV_FILE 指定其他檔案（同時設定 COMPOSE_ENV_FILES 讓 docker compose 讀同一份）

load_env() {
  local root="$1" file="${ENV_FILE:-$1/.env}" line key val
  [ -f "${file}" ] || return 0
  if [ -n "${ENV_FILE:-}" ]; then export COMPOSE_ENV_FILES="${ENV_FILE}"; fi
  while IFS= read -r line || [ -n "${line}" ]; do
    line="${line%$'\r'}"
    case "${line}" in ''|\#*) continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"
    [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    # 去除成對的外層引號
    if [[ "${val}" =~ ^\"(.*)\"$ ]] || [[ "${val}" =~ ^\'(.*)\'$ ]]; then val="${BASH_REMATCH[1]}"; fi
    if [ -z "${!key+x}" ]; then export "${key}=${val}"; fi
  done < "${file}"
}
