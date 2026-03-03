#!/bin/bash
set -e

mkdir -p /var/www/zdnStorage/logs /var/www/zdnStorage/invoices_dev
chown -R www-data:www-data /var/www/zdnStorage/logs
chown -R www-data:www-data /var/www/zdnStorage/invoices_dev
chmod -R 0777 /var/www/zdnStorage/logs
chmod -R 0777 /var/www/zdnStorage/invoices_dev

umask 0000

exec php-fpm -F
