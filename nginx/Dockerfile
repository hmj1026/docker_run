ARG NGINX_VERSION=1.24-alpine
FROM nginx:${NGINX_VERSION}

ARG PHP_TIMEZONE=Asia/Taipei
ENV TZ=${PHP_TIMEZONE}

RUN apk add --no-cache tzdata \
    && test -f "/usr/share/zoneinfo/${TZ}" \
    && cp "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && echo "${TZ}" > /etc/timezone
