#!/usr/bin/env bash
# 逐版本建置並驗證 PHP / Composer / PHPUnit。
# 用法: bash scripts/test-versions.sh [--no-cache] [版本...]
#   版本: 56 74 80 81 82 83 84 85（預設全部）

set -euo pipefail

ALL_VERSIONS=(56 74 80 81 82 83 84 85)
STEP_TIMEOUT=120

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

usage() {
  cat <<USAGE
用法: bash scripts/test-versions.sh [--no-cache] [版本...]
  版本      56 74 80 81 82 83 84 85（預設全部）
  --no-cache  建置時不使用快取
  -h, --help  顯示說明
USAGE
}

expected_prefix() {
  case "$1" in
    56) echo "5.6" ;;
    74) echo "7.4" ;;
    80) echo "8.0" ;;
    81) echo "8.1" ;;
    82) echo "8.2" ;;
    83) echo "8.3" ;;
    84) echo "8.4" ;;
    85) echo "8.5" ;;
    *) return 1 ;;
  esac
}

NO_CACHE=()
VERSIONS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --no-cache) NO_CACHE=(--no-cache) ;;
    -*) echo "未知參數: $1" >&2; usage >&2; exit 2 ;;
    *)
      expected_prefix "$1" >/dev/null || { echo "不支援的版本: $1" >&2; exit 2; }
      VERSIONS+=("$1")
      ;;
  esac
  shift
done
if [ "${#VERSIONS[@]}" -eq 0 ]; then VERSIONS=("${ALL_VERSIONS[@]}"); fi

GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
export GIT_SHA

FAILED=0
SUMMARY=()
ERR_FILE="$(mktemp)"
trap 'rm -f "${ERR_FILE}"' EXIT

# run_step <版本> <步驟名> <指令...>：stdout 存入 STEP_OUT，回傳 PASS/FAIL/TIMEOUT 於 STEP_STATUS
run_step() {
  local ver="$1" name="$2" rc=0
  shift 2
  STEP_OUT="$(timeout "${STEP_TIMEOUT}" "$@" 2>"${ERR_FILE}")" || rc=$?
  if [ "${rc}" -eq 0 ]; then
    STEP_STATUS="PASS"
  elif [ "${rc}" -eq 124 ]; then
    STEP_STATUS="TIMEOUT"
  else
    STEP_STATUS="FAIL"
  fi
  if [ "${STEP_STATUS}" != "PASS" ]; then
    echo "  [${ver}] ${name} ${STEP_STATUS} (exit ${rc})"
    sed 's/^/    stderr: /' "${ERR_FILE}"
  fi
}

php_run() {
  docker compose run --rm --no-deps -T php "$@"
}

for ver in "${VERSIONS[@]}"; do
  echo "=========================================="
  echo "測試 PHP ${ver}"
  echo "=========================================="
  export PHP_VERSION="${ver}"
  expect="$(expected_prefix "${ver}")"
  s_build="FAIL"; s_php="SKIP"; s_composer="SKIP"; s_phpunit="SKIP"

  if docker compose build "${NO_CACHE[@]}" php 2>"${ERR_FILE}" >/dev/null; then
    s_build="PASS"
  else
    echo "  [${ver}] build FAIL"
    tail -n 20 "${ERR_FILE}" | sed 's/^/    stderr: /'
  fi

  if [ "${s_build}" = "PASS" ]; then
    run_step "${ver}" "php" php_run php -r 'echo PHP_VERSION;'
    s_php="${STEP_STATUS}"
    if [ "${s_php}" = "PASS" ]; then
      case "${STEP_OUT}" in
        "${expect}"*) echo "  PHP_VERSION=${STEP_OUT}" ;;
        *) s_php="FAIL"; echo "  [${ver}] 版本不符: 預期 ${expect}.x，實際 '${STEP_OUT}'" ;;
      esac
    fi

    run_step "${ver}" "composer" php_run composer --version
    s_composer="${STEP_STATUS}"
    [ "${s_composer}" != "PASS" ] || echo "  ${STEP_OUT%%$'\n'*}"

    run_step "${ver}" "phpunit" php_run phpunit --version
    s_phpunit="${STEP_STATUS}"
    [ "${s_phpunit}" != "PASS" ] || echo "  ${STEP_OUT%%$'\n'*}"

    rev="$(docker image inspect "${COMPOSE_PROJECT_NAME:-pos}-php:${ver}" \
      --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' 2>/dev/null || echo "N/A")"
    echo "  image revision: ${rev}"
  fi

  for s in "${s_build}" "${s_php}" "${s_composer}" "${s_phpunit}"; do
    if [ "${s}" = "FAIL" ] || [ "${s}" = "TIMEOUT" ]; then FAILED=1; fi
  done
  SUMMARY+=("$(printf '%-6s %-8s %-8s %-9s %-8s' "${ver}" "${s_build}" "${s_php}" "${s_composer}" "${s_phpunit}")")
  echo ""
done

echo "=========================================="
printf '%-6s %-8s %-8s %-9s %-8s\n' VER BUILD PHP COMPOSER PHPUNIT
printf '%s\n' "${SUMMARY[@]}"
echo "=========================================="

if [ "${FAILED}" -ne 0 ]; then
  echo "結果: FAIL"
  exit 1
fi
echo "結果: PASS"
