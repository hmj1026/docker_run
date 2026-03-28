#!/usr/bin/env bash
# Generate a self-signed TLS cert/key for nginx SSL termination.
# Usage: bash scripts/generate-cert.sh [domain]
# Default domain: www.posdev.test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSL_DIR="${PROJECT_ROOT}/nginx/ssl"
DOMAIN="${1:-www.posdev.test}"

mkdir -p "${SSL_DIR}"
CERT_PATH="${SSL_DIR}/laragon.crt"
KEY_PATH="${SSL_DIR}/laragon.key"

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout "${KEY_PATH}" \
  -out "${CERT_PATH}" \
  -subj "/C=TW/ST=Taipei/L=Taipei/O=POS/OU=Dev/CN=${DOMAIN}"

echo "Generated:"
echo "  Cert: ${CERT_PATH}"
echo "  Key : ${KEY_PATH}"
echo "Domain CN: ${DOMAIN}"
echo "Restart nginx after updating cert/key (docker compose restart nginx)."
