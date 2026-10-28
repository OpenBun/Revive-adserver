# PHP 8.3.36 — patched for PHP2Shell (CVE-2026-109618 / CVE-2026-109619)
# See: https://www.wiz.io/blog/php2shell-php-rce
# Fixed releases: 8.2.35, 8.3.36, 8.4.27, 8.5.12 (8.1 and earlier: no upstream fix)
FROM php:8.3.36-apache-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        libicu-dev \
        libxml2-dev \
        libonig-dev \
        curl \
        unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        gd \
        intl \
        mysqli \
        opcache \
        pdo_mysql \
        zip \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*

# Harden against upload-progress related attack surface (defense in depth)
RUN printf '%s\n' \
      'session.upload_progress.enabled = Off' \
      'expose_php = Off' \
    > /usr/local/etc/php/conf.d/zz-security.ini

COPY --chown=www-data:www-data . /var/www/html/

RUN mkdir -p /var/www/html/var/plugins/DataObjects \
             /var/www/html/var/cache \
             /var/www/html/var/templates_compiled \
             /var/www/html/www/images \
    && chown -R www-data:www-data /var/www/html/var /var/www/html/www/images \
    && chmod -R u+rwX /var/www/html/var /var/www/html/www/images \
    && chmod +x /var/www/html/docker/entrypoint.sh /var/www/html/docker/cli-install.php \
    && sed -i 's/\r$//' /var/www/html/docker/entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS http://127.0.0.1/ || exit 1

ENTRYPOINT ["/var/www/html/docker/entrypoint.sh"]
