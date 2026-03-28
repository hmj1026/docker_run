#!/usr/bin/env bash
# Switch PHP (and optionally MySQL) versions in .env
# Usage: bash scripts/switch-version.sh [php_version] [mysql_version]
#   - 無參數：進入互動式選單
#   - 有參數：驗證並切換版本

set -euo pipefail

# ================================================
# 支援的版本清單
# ================================================
SUPPORTED_PHP_VERSIONS=("56" "74" "80" "81" "82" "83")
SUPPORTED_MYSQL_VERSIONS=("5.7" "8.0" "8.4")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

# ================================================
# 驗證版本是否支援
# ================================================
validate_php_version() {
  local ver="$1"
  for supported in "${SUPPORTED_PHP_VERSIONS[@]}"; do
    if [[ "$ver" == "$supported" ]]; then
      return 0
    fi
  done
  return 1
}

validate_mysql_version() {
  local ver="$1"
  for supported in "${SUPPORTED_MYSQL_VERSIONS[@]}"; do
    if [[ "$ver" == "$supported" ]]; then
      return 0
    fi
  done
  return 1
}

# ================================================
# 顯示選單並取得使用者選擇
# ================================================
select_version() {
  local prompt="$1"
  shift
  local options=("$@")

  echo "$prompt"
  for i in "${!options[@]}"; do
    echo "  $((i+1)). ${options[i]}"
  done

  while true; do
    read -p "請選擇 (1-${#options[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
      echo "${options[$((choice-1))]}"
      return 0
    else
      echo "無效選擇，請重新輸入" >&2
    fi
  done
}

# ================================================
# 更新 .env 檔案
# ================================================
update_env_file() {
  local php_ver="$1"
  local mysql_ver="${2-}"

  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  local php_re="^PHP_VERSION="
  local mysql_re="^MYSQL_VERSION="

  while IFS= read -r line; do
    if [[ $line =~ $php_re ]]; then
      echo "PHP_VERSION=${php_ver}" >>"$tmp"
    elif [[ -n $mysql_ver && $line =~ $mysql_re ]]; then
      echo "MYSQL_VERSION=${mysql_ver}" >>"$tmp"
    else
      echo "$line" >>"$tmp"
    fi
  done <"$ENV_FILE"

  mv "$tmp" "$ENV_FILE"
  echo "✓ 已更新 PHP_VERSION=${php_ver}"
  if [ -n "$mysql_ver" ]; then
    echo "✓ 已更新 MYSQL_VERSION=${mysql_ver}"
  fi
}

# ================================================
# 互動式模式
# ================================================
interactive_mode() {
  echo "================================================"
  echo "Docker 版本切換工具 (互動式)"
  echo "================================================"
  echo ""

  # 選擇 PHP 版本
  PHP_VER=$(select_version "可用的 PHP 版本:" "${SUPPORTED_PHP_VERSIONS[@]}")
  echo "已選擇 PHP ${PHP_VER}"
  echo ""

  # 詢問是否切換 MySQL
  read -p "是否要切換 MySQL 版本? (y/N): " change_mysql
  if [[ "$change_mysql" =~ ^[Yy]$ ]]; then
    MYSQL_VER=$(select_version "可用的 MySQL 版本:" "${SUPPORTED_MYSQL_VERSIONS[@]}")
    echo "已選擇 MySQL ${MYSQL_VER}"
  else
    MYSQL_VER=""
  fi

  echo ""
  echo "================================================"
  update_env_file "$PHP_VER" "$MYSQL_VER"
  echo "================================================"
  echo ""
  echo "請執行以下指令以套用變更:"
  echo "  docker compose down && docker compose up -d --build"
}

# ================================================
# 命令列模式
# ================================================
command_line_mode() {
  local php_ver="$1"
  local mysql_ver="${2-}"

  # 驗證 PHP 版本
  if ! validate_php_version "$php_ver"; then
    echo "錯誤: 不支援的 PHP 版本 '$php_ver'" >&2
    echo "支援的版本: ${SUPPORTED_PHP_VERSIONS[*]}" >&2
    exit 1
  fi

  # 驗證 MySQL 版本 (如果有提供)
  if [[ -n "$mysql_ver" ]] && ! validate_mysql_version "$mysql_ver"; then
    echo "錯誤: 不支援的 MySQL 版本 '$mysql_ver'" >&2
    echo "支援的版本: ${SUPPORTED_MYSQL_VERSIONS[*]}" >&2
    exit 1
  fi

  update_env_file "$php_ver" "$mysql_ver"
  echo ""
  echo "請執行以下指令以套用變更:"
  echo "  docker compose down && docker compose up -d --build"
}

# ================================================
# 主程式
# ================================================
if [ $# -eq 0 ]; then
  # 無參數：進入互動式模式
  interactive_mode
else
  # 有參數：命令列模式
  command_line_mode "$1" "${2-}"
fi
