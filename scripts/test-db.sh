#!/usr/bin/env bash
# 測試資料庫管理：建立受限使用者、建立/刪除/列出測試用資料庫。
# 用法: scripts/test-db.sh [--host mysql|mariadb101] <init|ping|list|create NAME|drop NAME|reset --yes>
#   init     建立 TEST_DB_USER 並授權（僅限 TEST_DB_PREFIXES 前綴的資料庫 + clone 來源唯讀）
#   ping     以 TEST_DB_USER 經 TCP 連線驗證 (SELECT CURRENT_USER())
#   list     列出符合前綴的資料庫
#   create   建立資料庫（名稱須符合前綴）
#   drop     刪除資料庫（名稱須符合前綴；其餘一律拒絕，結束碼 3）
#   reset    刪除所有符合前綴的資料庫，需加 --yes
# 密碼一律以 MYSQL_PWD 環境變數傳入容器，不出現在命令列或輸出。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
# shellcheck source=scripts/_env.sh
source "${ROOT_DIR}/scripts/_env.sh"
load_env "${ROOT_DIR}"

usage() { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

HOST="mysql"
YES=0
POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

case "${HOST}" in mysql|mariadb101) ;; *) echo "--host 僅支援 mysql|mariadb101" >&2; exit 2 ;; esac
CMD="${1:-}"
[ -n "${CMD}" ] || { usage >&2; exit 2; }
shift || true

CONTAINER="${COMPOSE_PROJECT_NAME:-pos}_${HOST}"
TEST_DB_USER="${TEST_DB_USER:-posdev_test}"
TEST_DB_PREFIXES="${TEST_DB_PREFIXES:-test_}"
IFS=',' read -r -a PREFIXES <<< "${TEST_DB_PREFIXES}"

# 以 root 執行 SQL（SQL 由 stdin 傳入）
root_sql() {
  MYSQL_PWD="${MYSQL_ROOT_PASSWORD:-}" docker exec -i -e MYSQL_PWD "${CONTAINER}" mysql -uroot "$@"
}

# 跳脫 SQL 字串內容
sql_str() { printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g"; }

# 以 \_ 跳脫 _，供 GRANT / LIKE 的萬用字元比對
escape_us() { printf '%s' "${1//_/\\_}"; }

# 名稱守門：格式 + 前綴；不符合以結束碼 3 離開
guard_name() {
  local name="${1:-}" p
  if ! [[ "${name}" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "拒絕: 資料庫名稱僅允許 [A-Za-z0-9_]: ${name}" >&2; exit 3
  fi
  for p in "${PREFIXES[@]}"; do
    [ -n "${p}" ] || continue
    if [[ "${name}" == "${p}"* ]] && [ "${#name}" -gt "${#p}" ]; then return 0; fi
  done
  echo "拒絕: ${name} 不符合允許前綴 (${TEST_DB_PREFIXES})" >&2
  exit 3
}

list_dbs() {
  local p
  for p in "${PREFIXES[@]}"; do
    [ -n "${p}" ] || continue
    echo "SHOW DATABASES LIKE '$(escape_us "${p}")%';" | root_sql -N -B
  done
}

cmd_init() {
  : "${TEST_DB_PASSWORD:?TEST_DB_PASSWORD 未設定 (.env)}"
  local pw u p
  pw="$(sql_str "${TEST_DB_PASSWORD}")"; u="$(sql_str "${TEST_DB_USER}")"
  local setpw
  if [ "${HOST}" = "mariadb101" ]; then
    # MariaDB 10.1 不支援 ALTER USER ... IDENTIFIED BY
    setpw="SET PASSWORD FOR '${u}'@'%' = PASSWORD('${pw}');"
  else
    setpw="ALTER USER '${u}'@'%' IDENTIFIED BY '${pw}';"
  fi
  {
    echo "CREATE USER IF NOT EXISTS '${u}'@'%' IDENTIFIED BY '${pw}';"
    echo "${setpw}"
    for p in "${PREFIXES[@]}"; do
      [ -n "${p}" ] || continue
      echo "GRANT ALL PRIVILEGES ON \`$(escape_us "${p}")%\`.* TO '${u}'@'%';"
    done
    if [ -n "${TEST_DB_CLONE_SOURCE:-}" ]; then
      echo "GRANT SELECT, SHOW VIEW, TRIGGER ON \`$(escape_us "${TEST_DB_CLONE_SOURCE}")\`.* TO '${u}'@'%';"
    fi
    echo "FLUSH PRIVILEGES;"
  } | root_sql
  echo "init OK: ${TEST_DB_USER}@% on ${CONTAINER} (prefixes: ${TEST_DB_PREFIXES})"
}

cmd_ping() {
  : "${TEST_DB_PASSWORD:?TEST_DB_PASSWORD 未設定 (.env)}"
  MYSQL_PWD="${TEST_DB_PASSWORD}" docker exec -e MYSQL_PWD "${CONTAINER}" \
    mysql -h127.0.0.1 -u"${TEST_DB_USER}" -N -B -e 'SELECT CURRENT_USER()'
}

case "${CMD}" in
  init) cmd_init ;;
  ping) cmd_ping ;;
  list) list_dbs ;;
  create)
    guard_name "${1:-}"
    echo "CREATE DATABASE IF NOT EXISTS \`$1\`;" | root_sql
    echo "created: $1" ;;
  drop)
    guard_name "${1:-}"
    echo "DROP DATABASE IF EXISTS \`$1\`;" | root_sql
    echo "dropped: $1" ;;
  reset)
    if [ "${YES}" -ne 1 ]; then echo "reset 會刪除所有符合前綴的資料庫，請加 --yes" >&2; exit 2; fi
    while IFS= read -r db; do
      [ -n "${db}" ] || continue
      guard_name "${db}"
      echo "DROP DATABASE IF EXISTS \`${db}\`;" | root_sql
      echo "dropped: ${db}"
    done < <(list_dbs) ;;
  *) usage >&2; exit 2 ;;
esac
