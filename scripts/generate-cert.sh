#!/usr/bin/env bash
# Generate a self-signed TLS cert/key (with SAN) for nginx SSL termination.
# Usage: bash scripts/generate-cert.sh [domain ...]
#   第一個 domain 作為 CN；所有 domain 與預設清單一併寫入 subjectAltName。
#   額外 SAN 以 CERT_EXTRA_SAN 傳入（逗號分隔，需含前綴），例如：
#   CERT_EXTRA_SAN="IP:192.168.2.23" bash scripts/generate-cert.sh
# 既有憑證會先備份為 *.bak-<timestamp>。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSL_DIR="${PROJECT_ROOT}/nginx/ssl"
CERT_PATH="${SSL_DIR}/laragon.crt"
KEY_PATH="${SSL_DIR}/laragon.key"
DAYS="${CERT_DAYS:-825}"

if [ "$#" -gt 0 ]; then
  DOMAINS=("$@")
else
  DOMAINS=("www.posdev.test")
fi
CN="${DOMAINS[0]}"

# 預設 SAN：本機、posdev 各 vhost（含 php84）、歷史上使用的 zdpos.test 網域
DEFAULT_SAN="DNS:localhost,IP:127.0.0.1,DNS:www.posdev.test,DNS:php84.posdev.test,DNS:mypos.posdev.test,DNS:*.posdev.test,DNS:www.zdpos.test,DNS:*.www.zdpos.test,DNS:*.test"

SAN="${DEFAULT_SAN}"
for d in "${DOMAINS[@]}"; do
  case ",${SAN}," in
    *",DNS:${d},"*) ;;
    *) SAN="${SAN},DNS:${d}" ;;
  esac
done
if [ -n "${CERT_EXTRA_SAN:-}" ]; then
  SAN="${SAN},${CERT_EXTRA_SAN}"
fi

mkdir -p "${SSL_DIR}"
ts="$(date +%Y%m%d-%H%M%S)"
for f in "${CERT_PATH}" "${KEY_PATH}"; do
  if [ -f "${f}" ]; then
    cp -p "${f}" "${f}.bak-${ts}"
  fi
done

openssl req -x509 -nodes -days "${DAYS}" -newkey rsa:2048 \
  -keyout "${KEY_PATH}" \
  -out "${CERT_PATH}" \
  -subj "/C=TW/ST=Taipei/L=Taipei/O=POS/OU=Dev/CN=${CN}" \
  -addext "subjectAltName=${SAN}" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "extendedKeyUsage=serverAuth"

chmod 644 "${CERT_PATH}"
chmod 600 "${KEY_PATH}"

echo "Generated:"
echo "  Cert: ${CERT_PATH}"
echo "  Key : ${KEY_PATH}"
echo "  CN  : ${CN}"
echo "  SAN : ${SAN}"
echo "  Days: ${DAYS}"
echo "Reload nginx: docker compose exec nginx nginx -s reload"
echo "瀏覽器/OS 若曾信任舊憑證，需改為信任新的 ${CERT_PATH}。"
