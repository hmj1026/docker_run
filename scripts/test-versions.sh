#!/usr/bin/env bash
# Iterate all PHP versions, rebuild, and verify PHP/Composer/PHPUnit.
# Usage: bash scripts/test-versions.sh

set -euo pipefail

VERSIONS=("56" "74" "80" "81" "82" "83")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "PHP 環境版本驗證測試"
echo "=========================================="
echo ""

for ver in "${VERSIONS[@]}"; do
  echo "=========================================="
  echo "測試 PHP ${ver} 環境"
  echo "=========================================="
  echo ""

  export PHP_VERSION="${ver}"

  echo "[PHP 版本]"
  docker compose -f "${ROOT_DIR}/docker-compose.yml" run --rm php php --version 2>/dev/null | grep "PHP" || true
  echo ""

  echo "[Composer 版本]"
  docker compose -f "${ROOT_DIR}/docker-compose.yml" run --rm php composer --version 2>/dev/null | grep "Composer" || true
  echo ""

  echo "[PHPUnit 版本]"
  docker compose -f "${ROOT_DIR}/docker-compose.yml" run --rm php phpunit --version 2>/dev/null | grep "PHPUnit" || true
  echo ""

  echo "PHP ${ver} 測試完成"
  echo ""
done

echo "=========================================="
echo "所有測試完成！"
echo "=========================================="
