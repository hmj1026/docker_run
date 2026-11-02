#!/usr/bin/env bash
# 在容器內執行指令，並自動把宿主機目錄對應成容器路徑。
# 用法: scripts/cexec.sh [--service php|php84] [--as-root] [--log <slug>] <dir> -- <cmd...>
#   --service   目標服務（預設 php）
#   --as-root   強制以 root 執行（php84 預設以 HOST_UID:HOST_GID 執行）
#   --log SLUG  輸出同步寫入 logs/test/<時間戳>-<slug>.log（保留指令結束碼）
# 路徑對應: PROJECT_PATH -> PROJECT_CONTAINER_PATH；WEB_ROOT_PATH -> /var/www/www.posdev；
#           php84 另可使用 PROJECTS_ROOT 下的任意路徑（同路徑掛載）；亦接受 /var/www/ 開頭的容器路徑。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
# shellcheck source=scripts/_env.sh
source "${ROOT_DIR}/scripts/_env.sh"
load_env "${ROOT_DIR}"

usage() {
  sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

SERVICE="php"
AS_ROOT=0
LOG_SLUG=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --service) SERVICE="${2:-}"; shift 2 ;;
    --as-root) AS_ROOT=1; shift ;;
    --log) LOG_SLUG="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) break ;;
    -*) echo "未知選項: $1" >&2; usage >&2; exit 2 ;;
    *) break ;;
  esac
done

if [ "$#" -lt 3 ]; then usage >&2; exit 2; fi
DIR="$1"; shift
if [ "$1" != "--" ]; then echo "缺少 -- 分隔符" >&2; usage >&2; exit 2; fi
shift

case "${SERVICE}" in php|php84) ;; *) echo "不支援的服務: ${SERVICE} (php|php84)" >&2; exit 2 ;; esac
if [ -n "${LOG_SLUG}" ] && ! [[ "${LOG_SLUG}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "--log slug 僅允許英數、. _ -" >&2; exit 2
fi

# 判斷 $1 是否位於 $2 之下（含相等）
is_under() {
  [ -n "$2" ] || return 1
  [ "$1" = "$2" ] || [[ "$1" == "$2"/* ]]
}

# 依序嘗試各根目錄，回傳對應的容器路徑
map_dir() {
  local dir="$1" real root
  if [[ "${dir}" == /var/www/* ]]; then echo "${dir}"; return 0; fi
  real="$(realpath "${dir}" 2>/dev/null)" || return 1
  if [ -n "${PROJECT_PATH:-}" ]; then
    root="$(realpath "${PROJECT_PATH}" 2>/dev/null || echo "${PROJECT_PATH}")"
    if is_under "${real}" "${root}"; then echo "${PROJECT_CONTAINER_PATH}${real#"${root}"}"; return 0; fi
  fi
  if [ -n "${WEB_ROOT_PATH:-}" ]; then
    root="$(realpath "${WEB_ROOT_PATH}" 2>/dev/null || echo "${WEB_ROOT_PATH}")"
    if is_under "${real}" "${root}"; then echo "/var/www/www.posdev${real#"${root}"}"; return 0; fi
  fi
  if [ "${SERVICE}" = "php84" ] && [ -n "${PROJECTS_ROOT:-}" ]; then
    root="$(realpath "${PROJECTS_ROOT}" 2>/dev/null || echo "${PROJECTS_ROOT}")"
    if is_under "${real}" "${root}"; then echo "${real}"; return 0; fi
  fi
  return 1
}

if ! MAPPED="$(map_dir "${DIR}")"; then
  echo "無法對應目錄: ${DIR}" >&2
  echo "可接受的根目錄:" >&2
  echo "  PROJECT_PATH=${PROJECT_PATH:-<未設定>}" >&2
  echo "  WEB_ROOT_PATH=${WEB_ROOT_PATH:-<未設定>}" >&2
  echo "  PROJECTS_ROOT=${PROJECTS_ROOT:-<未設定>} (僅 --service php84)" >&2
  echo "  /var/www/ 開頭的容器路徑" >&2
  exit 2
fi

ARGS=(exec -T -w "${MAPPED}")
if [ "${SERVICE}" = "php84" ] && [ "${AS_ROOT}" -eq 0 ]; then
  ARGS+=(--user "${HOST_UID:-1000}:${HOST_GID:-1000}" -e HOME=/work)
fi
ARGS+=("${SERVICE}" "$@")

if [ -z "${LOG_SLUG}" ]; then
  exec docker compose "${ARGS[@]}"
fi

mkdir -p logs/test
LOG_FILE="logs/test/$(date +%Y%m%d-%H%M%S)-${LOG_SLUG}.log"
echo "log: ${LOG_FILE}"
set +e
docker compose "${ARGS[@]}" 2>&1 | tee "${LOG_FILE}"
exit "${PIPESTATUS[0]}"
