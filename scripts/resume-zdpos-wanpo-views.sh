#!/usr/bin/env bash
set -euo pipefail

# Resume zdpos_wanpo import: re-create views from the dump's "Final view structure"
# section. Original import failed at line 60959 because the dump (MySQL 8.0+)
# uses utf8mb4_0900_ai_ci, which MySQL 5.7 does not support.
#
# Strategy:
#   1. Drop every existing view in zdpos_wanpo (clears first-pass stubs and the
#      partial Final-pass result).
#   2. Slice the dump from FINAL_VIEW_START_LINE to EOF.
#   3. Stream-replace utf8mb4_0900_ai_ci -> utf8mb4_unicode_ci on the fly.
#   4. Pipe into the MySQL client.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_FILE="${SQL_FILE:-${ROOT_DIR}/mysql/init/02.zdpos_wanpo_0426.sql}"
DB_NAME="${DB_NAME:-zdpos_wanpo}"
CONTAINER_NAME="${CONTAINER_NAME:-pos_mysql}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
LOG_DIR="${LOG_DIR:-${ROOT_DIR}/logs/mysql}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/import-zdpos-wanpo.log}"
FINAL_VIEW_START_LINE="${FINAL_VIEW_START_LINE:-60572}"

mkdir -p "${LOG_DIR}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
}

fail() {
  log "ERROR: $*"
  exit 1
}

mysql_args=(-u"${MYSQL_USER}")
[[ -n "${MYSQL_PASSWORD}" ]] && mysql_args+=(-p"${MYSQL_PASSWORD}")

run_mysql() {
  docker exec -i "${CONTAINER_NAME}" mysql "${mysql_args[@]}" "$@"
}

[[ -f "${SQL_FILE}" ]] || fail "SQL file not found: ${SQL_FILE}"

docker exec -i "${CONTAINER_NAME}" sh -lc 'mysqladmin ping -h 127.0.0.1 --silent' >/dev/null 2>&1 \
  || fail "MySQL container ${CONTAINER_NAME} is not ready"

log "Resume starting"
log "SQL file: ${SQL_FILE}"
log "Slicing from line: ${FINAL_VIEW_START_LINE}"
log "Target DB: ${DB_NAME}"

EXPECTED_VIEW_COUNT="${EXPECTED_VIEW_COUNT:-79}"
MAX_ITERATIONS="${MAX_ITERATIONS:-5}"

count_views() {
  run_mysql -N -B -e \
    "SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA='${DB_NAME}';" 2>/dev/null \
    | grep -v '^mysql:' | tail -n1
}

# Each "Final view structure" section in the dump starts with DROP VIEW IF EXISTS
# (and DROP TABLE IF EXISTS), so re-running the slice is idempotent. Views are
# emitted alphabetically and may reference each other out of dependency order;
# with mysql --force we iterate until every view resolves.
log "Streaming Final view structure section into mysql (collation sanitized)"
for i in $(seq 1 "${MAX_ITERATIONS}"); do
  log "Iteration ${i}/${MAX_ITERATIONS}"
  tail -n +"${FINAL_VIEW_START_LINE}" "${SQL_FILE}" \
    | sed 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g' \
    | docker exec -i "${CONTAINER_NAME}" mysql "${mysql_args[@]}" \
        --force --default-character-set=utf8mb4 "${DB_NAME}" \
        >>"${LOG_FILE}" 2>&1 || true

  CURRENT="$(count_views)"
  log "  view count after iteration ${i}: ${CURRENT}"
  if [[ "${CURRENT}" == "${EXPECTED_VIEW_COUNT}" ]]; then
    break
  fi
done

FINAL_COUNT="$(count_views)"
if [[ "${FINAL_COUNT}" != "${EXPECTED_VIEW_COUNT}" ]]; then
  fail "View count mismatch: got ${FINAL_COUNT}, expected ${EXPECTED_VIEW_COUNT}"
fi

log "Resume completed. View count in ${DB_NAME}: ${FINAL_COUNT}"
