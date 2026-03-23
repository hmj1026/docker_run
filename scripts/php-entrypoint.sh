#!/bin/bash
set -e

mkdir -p /var/www/zdnStorage/logs /var/www/zdnStorage/invoices_dev
chown -R www-data:www-data /var/www/zdnStorage/logs
chown -R www-data:www-data /var/www/zdnStorage/invoices_dev
chmod -R 0777 /var/www/zdnStorage/logs
chmod -R 0777 /var/www/zdnStorage/invoices_dev

# Fix assets directories for www.posdev projects
find /var/www/www.posdev -maxdepth 2 -name "assets" -type d -exec chown www-data:www-data {} \;

# Remove empty published asset hash directories left behind by interrupted Yii publishes.
while IFS= read -r -d '' empty_publish_dir; do
  echo "Removing empty asset publish directory: ${empty_publish_dir}"
  rmdir "${empty_publish_dir}"
done < <(find /var/www/www.posdev -mindepth 3 -maxdepth 3 -type d -path "*/assets/*" -empty -print0)

umask 0000

exec php-fpm -F
