#!/usr/bin/env bash
# HTTP 冒煙測試：對運行中的環境逐一請求路徑，檢查狀態碼與錯誤頁標記。
# 用法: bash scripts/smoke.sh [路徑...]
#   路徑來源優先序: 參數 > 環境變數 SMOKE_PATHS（空白分隔） > docker-compose.yml 的 nginx 商戶掛載 > /dev/

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="www.posdev.test"

# 由 nginx 服務的 volumes 取出掛載到 /var/www/www.posdev/<dir> 的目錄
default_paths() {
  tr -d '\r' < "${ROOT_DIR}/docker-compose.yml" \
    | awk '
        /^  [a-z_]+:[[:space:]]*$/ { svc = $1; next }
        svc == "nginx:" { print }' \
    | grep -oE ':/var/www/www\.posdev/[A-Za-z0-9_.-]+[[:space:]]*$' \
    | sed -E 's#^:/var/www/www\.posdev/##; s/[[:space:]]+$//' \
    | sort -u \
    | sed -E 's#^(.*)$#/\1/#'
}

PATHS=()
if [ "$#" -gt 0 ]; then
  PATHS=("$@")
elif [ -n "${SMOKE_PATHS:-}" ]; then
  read -r -a PATHS <<< "${SMOKE_PATHS}"
else
  while IFS= read -r p; do
    [ -z "${p}" ] || PATHS+=("${p}")
  done < <(default_paths)
  if [ "${#PATHS[@]}" -eq 0 ]; then PATHS=("/dev/"); fi
fi

BODY_FILE="$(mktemp)"
trap 'rm -f "${BODY_FILE}"' EXIT

FAILED=0
for path in "${PATHS[@]}"; do
  code="$(curl -sk --max-time 15 --resolve "${HOST}:443:127.0.0.1" \
    -o "${BODY_FILE}" -w '%{http_code}' "https://${HOST}${path}" 2>/dev/null || true)"
  code="${code:-000}"
  reason=""
  if [ "${code}" = "000" ]; then
    reason="連線失敗或逾時"
  elif [ "${code}" -ge 500 ]; then
    reason="HTTP ${code}"
  elif grep -aqE 'Fatal error|Parse error|tracy-bs' "${BODY_FILE}"; then
    reason="回應含錯誤頁標記"
  fi
  if [ -n "${reason}" ]; then
    printf 'FAIL  %s  %s  (%s)\n' "${code}" "${path}" "${reason}"
    FAILED=1
  else
    printf 'PASS  %s  %s\n' "${code}" "${path}"
  fi
done

if [ "${FAILED}" -ne 0 ]; then
  echo "結果: FAIL"
  exit 1
fi
echo "結果: PASS"
