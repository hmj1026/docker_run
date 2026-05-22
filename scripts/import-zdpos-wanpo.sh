#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_FILE="${SQL_FILE:-${ROOT_DIR}/mysql/init/02.zdpos_wanpo_0426.sql}"
DB_NAME="${DB_NAME:-zdpos_wanpo}"
CONTAINER_NAME="${CONTAINER_NAME:-pos_mysql}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
LOG_DIR="${LOG_DIR:-${ROOT_DIR}/logs/mysql}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/import-zdpos-wanpo.log}"
BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/mysql/init}"
BACKUP_FILE="${BACKUP_FILE:-${BACKUP_DIR}/02.zdpos_wanpo_0426.sql.bak}"

mkdir -p "${LOG_DIR}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG_FILE}"
}

fail() {
  log "ERROR: $*"
  exit 1
}

backup_sql_file() {
  if [[ ! -f "${BACKUP_FILE}" ]]; then
    ln "${SQL_FILE}" "${BACKUP_FILE}"
    log "Backed up SQL dump as hard link at ${BACKUP_FILE}"
  else
    log "Backup already exists at ${BACKUP_FILE}"
  fi
}

[[ -f "${SQL_FILE}" ]] || fail "SQL file not found: ${SQL_FILE}"

log "Starting import"
log "SQL file: ${SQL_FILE}"
log "Target DB: ${DB_NAME}"
log "Container: ${CONTAINER_NAME}"

backup_sql_file

if [[ -n "${MYSQL_PASSWORD}" ]]; then
  if ! docker exec -i "${CONTAINER_NAME}" mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e \
      "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
      >>"${LOG_FILE}" 2>&1; then
    fail "Failed to create database ${DB_NAME}"
  fi

  if ! sed 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g' "${SQL_FILE}" \
      | docker exec -i "${CONTAINER_NAME}" mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
        --default-character-set=utf8mb4 "${DB_NAME}" >>"${LOG_FILE}" 2>&1; then
    log "Import failed"
    log "Recorded the failure in ${LOG_FILE}"
    log "Common check: mysql.cnf is world-writable (777), so MySQL client warns and ignores it."
    exit 1
  fi
else
  if ! docker exec -i "${CONTAINER_NAME}" mysql -u"${MYSQL_USER}" -e \
      "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
      >>"${LOG_FILE}" 2>&1; then
    fail "Failed to create database ${DB_NAME}"
  fi

  if ! sed 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_ci/g' "${SQL_FILE}" \
      | docker exec -i "${CONTAINER_NAME}" mysql -u"${MYSQL_USER}" \
        --default-character-set=utf8mb4 "${DB_NAME}" >>"${LOG_FILE}" 2>&1; then
    log "Import failed"
    log "Recorded the failure in ${LOG_FILE}"
    log "Common check: mysql.cnf is world-writable (777), so MySQL client warns and ignores it."
    exit 1
  fi
fi

log "Import completed successfully"
