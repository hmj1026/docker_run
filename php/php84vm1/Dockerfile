# ================================================
# PHP 8.4 FPM - 對齊 PROD vm1 (Ubuntu 24.04 + ondrej/php sury PPA)
# 與 php84 (官方映像、含 xdebug/PHPUnit) 並存，專供 php84.posdev.test
# ================================================
FROM ubuntu:24.04

ARG PHP_PKG_VERSION=8.4.27-1+ubuntu24.04.1+deb.sury.org+1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends software-properties-common gnupg ca-certificates \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php8.4=${PHP_PKG_VERSION} \
        php8.4-bcmath=${PHP_PKG_VERSION} \
        php8.4-cli=${PHP_PKG_VERSION} \
        php8.4-common=${PHP_PKG_VERSION} \
        php8.4-curl=${PHP_PKG_VERSION} \
        php8.4-fpm=${PHP_PKG_VERSION} \
        php8.4-gd=${PHP_PKG_VERSION} \
        php8.4-intl=${PHP_PKG_VERSION} \
        php8.4-mbstring=${PHP_PKG_VERSION} \
        php8.4-mysql=${PHP_PKG_VERSION} \
        php8.4-opcache=${PHP_PKG_VERSION} \
        php8.4-readline=${PHP_PKG_VERSION} \
        php8.4-xml=${PHP_PKG_VERSION} \
        php8.4-zip=${PHP_PKG_VERSION} \
        php8.4-soap=${PHP_PKG_VERSION} \
        php8.4-gmagick \
        php8.4-igbinary \
        php8.4-redis \
        libfcgi-bin \
    && apt-get purge -y software-properties-common \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 停用預設 pool，改用 zdpos-local（與 vm1 一致）；php.ini 保留套件預設
RUN mv /etc/php/8.4/fpm/pool.d/www.conf /etc/php/8.4/fpm/pool.d/www.conf.disabled \
    && mkdir -p /run/php /var/log/php /var/lib/php/sessions-zdpos /var/lib/php/wsdlcache-zdpos \
    && chown www-data:www-data /var/log/php /var/lib/php/sessions-zdpos /var/lib/php/wsdlcache-zdpos \
    && chmod 1733 /var/lib/php/sessions-zdpos

COPY zdpos-local.conf /etc/php/8.4/fpm/pool.d/zdpos-local.conf

WORKDIR /var/www
EXPOSE 9000
CMD ["php-fpm8.4", "-F", "-O"]
