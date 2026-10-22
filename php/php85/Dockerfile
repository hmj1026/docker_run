# ================================================
# PHP 8.5 Dockerfile for POS
# 基於 Debian Bookworm
# ================================================
# 固定 8.5.12：已含 CVE-2026-109618 / CVE-2026-109619 修補 (php.net 2026-10-21)
FROM php:8.5.12-fpm-bookworm

# 設定環境變數
ARG PHP_MEMORY_LIMIT=-1
ARG PHP_UPLOAD_MAX_FILESIZE=30M
ARG PHP_POST_MAX_SIZE=32M
ARG PHP_MAX_EXECUTION_TIME=300
ARG PHP_TIMEZONE=Asia/Taipei

# 設定工作目錄
WORKDIR /var/www

# ================================================
# 安裝系統依賴
# ================================================
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libxml2-dev \
    libzip-dev \
    zlib1g-dev \
    libicu-dev \
    libonig-dev \
    g++ \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# ================================================
# 安裝 PHP 擴展
# ================================================
# GD 圖形處理
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd

# 資料庫擴展
RUN docker-php-ext-install mysqli pdo pdo_mysql

# 其他常用擴展
# PHP 8.5 起 OPcache 已內建於核心，不可再 docker-php-ext-install opcache（會重複載入）
RUN docker-php-ext-install \
    mbstring \
    xml \
    zip \
    bcmath \
    calendar \
    exif \
    gettext \
    sockets \
    intl

# ================================================
# 安裝 Xdebug 3.5.3 (支援 PHP 8.5)
# 用於程式碼覆蓋率報告 (phpunit --coverage-*)
# ================================================
RUN pecl install xdebug-3.5.3 && \
    docker-php-ext-enable xdebug

RUN echo "xdebug.mode=coverage" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.start_with_request=no" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# ================================================
# 安裝 Composer 2.9 (最新穩定版)
# ================================================
COPY --from=composer:2.9 /usr/bin/composer /usr/local/bin/composer

# ================================================
# 安裝 PHPUnit 13 (最新穩定版本)
# ================================================
RUN composer global require phpunit/phpunit:^13.0 --no-interaction --prefer-dist && \
    ln -s /root/.composer/vendor/bin/phpunit /usr/local/bin/phpunit

# ================================================
# 配置 PHP-FPM
# ================================================
# 複製 php.ini
COPY php.ini /usr/local/etc/php/php.ini

# 配置 PHP-FPM Pool
RUN echo "[www]" > /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "listen = 0.0.0.0:9000" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm = dynamic" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.max_children = 50" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.start_servers = 10" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.min_spare_servers = 5" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.max_spare_servers = 20" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.max_requests = 500" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "; CVE-2026-109618/109619 緩解：pool 層級鎖定，應用程式無法 ini_set 覆寫" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "php_admin_value[memory_limit] = -1" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "php_admin_flag[session.upload_progress.enabled] = off" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "php_admin_flag[fatal_error_backtraces] = off" >> /usr/local/etc/php-fpm.d/zz-docker.conf

# 建立日誌目錄
RUN mkdir -p /var/log/php && \
    chown -R www-data:www-data /var/log/php

# ================================================
# 設定權限
# ================================================
RUN chown -R www-data:www-data /var/www

# 暴露 PHP-FPM PORT
EXPOSE 9000

# 啟動 PHP-FPM (前台模式)
CMD ["php-fpm", "-F"]
