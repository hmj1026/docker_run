#!/bin/bash
set -e

mkdir -p /var/www/zdnStorage/logs /var/www/zdnStorage/invoices_dev
chown -R www-data:www-data /var/www/zdnStorage/logs
chown -R www-data:www-data /var/www/zdnStorage/invoices_dev
chmod -R 0777 /var/www/zdnStorage/logs
chmod -R 0777 /var/www/zdnStorage/invoices_dev

# Fix assets directories for www.posdev projects
find /var/www/www.posdev -maxdepth 2 -name "assets" -type d -exec chown www-data:www-data {} \;
# Yii runtime 目錄須同時可被 www-data（FPM，擁有者）與宿主機使用者（群組 HOST_GID，php84 測試）寫入；
# 否則新掛載專案的 runtime 會導致 Error 500。2775 = 群組可寫 + setgid，新檔沿用群組。
find /var/www/www.posdev -maxdepth 3 -type d -path "*/protected/runtime" \
  -exec chown "www-data:${HOST_GID:-1000}" {} \; -exec chmod 2775 {} \;

# Remove empty published asset hash directories left behind by interrupted Yii publishes.
while IFS= read -r -d '' empty_publish_dir; do
  echo "Removing empty asset publish directory: ${empty_publish_dir}"
  rmdir "${empty_publish_dir}"
done < <(find /var/www/www.posdev -mindepth 3 -maxdepth 3 -type d -path "*/assets/*" -empty -print0)

umask 0000

# -----------------------------------------------------------
# Background permission watcher for zdnStorage
# Corrects permissions on directories/files created at runtime
# with wrong mode (e.g., PHP mkdir() with non-octal 755).
# Runs every 60 seconds with minimal overhead.
# -----------------------------------------------------------
(
  set +e
  trap 'exit 0' TERM INT
  while true; do
    sleep 60 &
    wait $!
    find /var/www/zdnStorage -type d ! -perm 0777 -exec chmod 0777 {} + 2>/dev/null
    find /var/www/zdnStorage -type f ! -perm 0666 -exec chmod 0666 {} + 2>/dev/null
  done
) &
WATCHER_PID=$!
trap "kill $WATCHER_PID 2>/dev/null" TERM INT

exec php-fpm -F
