# ================================================
# PHP 5.6 Dockerfile for POS
# 基於 Debian Stretch (支援 mcrypt 擴展)
# ================================================
FROM php:5.6-fpm-stretch

# 設定環境變數
ARG PHP_MEMORY_LIMIT=512M
ARG PHP_UPLOAD_MAX_FILESIZE=100M
ARG PHP_POST_MAX_SIZE=100M
ARG PHP_MAX_EXECUTION_TIME=300
ARG PHP_TIMEZONE=Asia/Taipei

# 設定工作目錄
WORKDIR /var/www

# ================================================
# 修正 Debian Stretch EOL 問題 - 使用 archive 鏡像
# ================================================
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list

# ================================================
# 安裝系統依賴
# ================================================
RUN apt-get update -o Acquire::Check-Valid-Until=false && apt-get install -y --allow-unauthenticated \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libxml2-dev \
    libzip-dev \
    libmcrypt-dev \
    zlib1g-dev \
    libicu-dev \
    g++ \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# ================================================
# 安裝 PHP 擴展
# ================================================
# GD 圖形處理
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd

# 資料庫擴展
RUN docker-php-ext-install mysqli pdo pdo_mysql

# mcrypt 加密 (Yii 1.1 需要)
RUN docker-php-ext-install mcrypt

# 其他常用擴展
RUN docker-php-ext-install \
    mbstring \
    opcache \
    xml \
    zip \
    bcmath \
    calendar \
    exif \
    gettext \
    sockets \
    intl

# ================================================
# 安裝 Composer 1.10.27 (PHP 5.6 支援的最高版本)
# 注意: Composer 1.x 已於 2025/09/01 停止 Packagist 支援
# ================================================
COPY --from=composer:1.10.27 /usr/bin/composer /usr/local/bin/composer

# ================================================
# 安裝 PHPUnit 5.7.27 (PHP 5.6 支援的最高版本)
# 由於 Composer 1.x 無法從 Packagist 安裝套件，改用 PHAR 方式
# ================================================
RUN curl -L https://phar.phpunit.de/phpunit-5.7.27.phar -o /usr/local/bin/phpunit && \
    chmod +x /usr/local/bin/phpunit

# ================================================
# 配置 PHP-FPM
# ================================================
# 複製配置檔案
COPY php.ini /usr/local/etc/php/php.ini

# 配置 PHP-FPM Pool
RUN echo "[www]" > /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "listen = 0.0.0.0:9000" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm = dynamic" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.max_children = 50" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.start_servers = 10" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.min_spare_servers = 5" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.max_spare_servers = 20" >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo "pm.max_requests = 500" >> /usr/local/etc/php-fpm.d/zz-docker.conf

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
