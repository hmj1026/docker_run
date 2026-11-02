#!/usr/bin/env bash
# 設定檔守門檢查：compose 語法、ini 一致性、mysql 權限、CRLF、nginx -t
# 用法: bash scripts/check-config.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

FAILED=0

pass() { echo "PASS  $1"; }
skip() { echo "SKIP  $1 ($2)"; }
fail() { echo "FAIL  $1"; FAILED=1; }

# 1. docker compose config
check_compose() {
  local name="docker compose config"
  if ! command -v docker >/dev/null 2>&1; then
    skip "${name}" "docker 不可用"
    return
  fi
  if err="$(docker compose config -q 2>&1)"; then
    pass "${name}"
  else
    fail "${name}"
    echo "${err}" | sed 's/^/      /'
  fi
}

# 取得 ini 內某 key 的有效值（最後一次賦值；忽略註解與 CR）
ini_value() {
  local file="$1" key="$2"
  tr -d '\r' < "${file}" \
    | awk -v k="${key}" '
        /^[[:space:]]*;/ { next }
        {
          line = $0
          sub(/[[:space:]]*;.*$/, "", line)
          n = index(line, "=")
          if (n == 0) next
          name = substr(line, 1, n - 1); gsub(/[[:space:]]/, "", name)
          if (name == k) { v = substr(line, n + 1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); last = v; found = 1 }
        }
        END { if (found) print last }'
}

# 2. ini 各版本一致
check_ini_parity() {
  local key ini value ver first mismatch
  for key in opcache.revalidate_freq opcache.validate_timestamps opcache.enable; do
    local name="ini parity ${key}"
    local -a lines=()
    first=""; mismatch=0
    for ini in php/php*/php.ini; do
      value="$(ini_value "${ini}" "${key}")"
      [ -n "${value}" ] || continue
      ver="$(basename "$(dirname "${ini}")")"
      lines+=("${ver}=${value}")
      if [ -z "${first}" ]; then first="${value}"; fi
      if [ "${value}" != "${first}" ]; then mismatch=1; fi
    done
    if [ "${#lines[@]}" -eq 0 ]; then
      skip "${name}" "各版本皆未定義"
    elif [ "${mismatch}" -eq 0 ]; then
      pass "${name} (${first})"
    else
      fail "${name}"
      printf '      %s\n' "${lines[@]}"
    fi
  done
}

# 3. mysql 設定檔不可 world-writable
check_mysql_perm() {
  local name="mysql conf.d 非 world-writable" f perm bad=0
  for f in mysql/conf.d/*.cnf mysql/mariadb101/conf.d/*.cnf; do
    [ -e "${f}" ] || continue
    perm="$(stat -c '%a' "${f}")"
    if [ $(( 8#${perm} & 8#002 )) -ne 0 ]; then
      echo "      ${f} 權限 ${perm} (mysqld 會忽略；執行 make preflight)"
      bad=1
    fi
  done
  if [ "${bad}" -eq 0 ]; then pass "${name}"; else fail "${name}"; fi
}

# 4. 不得含 CRLF
check_crlf() {
  local name="無 CRLF 換行" f bad=0
  local -a files=(docker-compose.yml Makefile)
  while IFS= read -r f; do files+=("${f}"); done < <(
    find nginx/conf.d -type f -name '*.conf' 2>/dev/null | sort
    find scripts -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort
    find php -maxdepth 2 -type f -name Dockerfile 2>/dev/null | sort
  )
  for f in "${files[@]}"; do
    [ -f "${f}" ] || continue
    if grep -q $'\r' "${f}"; then
      echo "      ${f}"
      bad=1
    fi
  done
  if [ "${bad}" -eq 0 ]; then pass "${name}"; else fail "${name}"; fi
}

# 5. nginx -t（容器運行中才執行）
check_nginx() {
  local name="nginx -t"
  if ! command -v docker >/dev/null 2>&1; then
    skip "${name}" "docker 不可用"
    return
  fi
  if ! docker compose ps --status running --services 2>/dev/null | grep -qx nginx; then
    skip "${name}" "nginx 容器未運行"
    return
  fi
  if out="$(docker compose exec -T nginx nginx -t 2>&1)"; then
    pass "${name}"
  else
    fail "${name}"
    echo "${out}" | sed 's/^/      /'
  fi
}

# 6. docker daemon default-address-pools（僅警告：缺少時自訂 network 可能耗盡預設位址池）
check_daemon_pools() {
  local name="docker daemon default-address-pools" f="/etc/docker/daemon.json"
  if [ ! -r "${f}" ]; then
    skip "${name}" "${f} 不可讀或不存在"
    return
  fi
  if grep -q 'default-address-pools' "${f}"; then
    pass "${name}"
  else
    echo "WARN  ${name} 未設定 (範本: docs/docker/daemon.json.example，說明見 docs/TEST_GUIDE.md)"
  fi
}

check_compose
check_ini_parity
check_mysql_perm
check_crlf
check_nginx
check_daemon_pools

if [ "${FAILED}" -ne 0 ]; then
  echo "結果: FAIL"
  exit 1
fi
echo "結果: PASS"
