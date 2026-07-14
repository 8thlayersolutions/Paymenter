# Stage 1:
# Build the PHP container with all needed PHP dependencies and ionCube.
FROM --platform=$TARGETOS/$TARGETARCH php:8.3-fpm-alpine AS final

WORKDIR /app

# Install system packages, PHP extensions, Redis, and required build tools
RUN apk add --no-cache --update \
        ca-certificates \
        dcron \
        curl \
        git \
        supervisor \
        tar \
        unzip \
        nginx \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        icu-dev \
        autoconf \
        make \
        g++ \
        gcc \
        libc-dev \
        linux-headers \
        gmp-dev \
    && docker-php-ext-configure zip \
    && docker-php-ext-install bcmath gd pdo_mysql zip intl sockets gmp \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del autoconf make g++ gcc libc-dev

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin \
    --filename=composer

# Install PHP dependencies first for better Docker layer caching
COPY composer.json composer.lock ./

RUN composer install --no-dev --no-autoloader --no-scripts

# Copy the full Paymenter source
COPY . ./

# Finish optimized Composer install
RUN composer install --no-dev --optimize-autoloader

# Prepare Laravel/Paymenter permissions, cron, nginx/php directories
RUN cp .env.example .env \
    && chmod 777 -R bootstrap storage/* \
    && rm -rf .env bootstrap/cache/*.php \
    && chown -R nginx:nginx . \
    && rm /usr/local/etc/php-fpm.conf \
    && echo "* * * * * /usr/local/bin/php /app/artisan schedule:run >> /dev/null 2>&1" >> /var/spool/cron/crontabs/root \
    && mkdir -p /var/run/php /var/run/nginx


# Stage 2:
# Build frontend assets with Node.
FROM --platform=$TARGETOS/$TARGETARCH node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm install

COPY . ./

COPY --from=final /app/vendor /app/vendor

RUN npm run build


# Stage 3:
# Production image
FROM final AS production

# Copy compiled frontend assets
COPY --from=build /app/public /app/public

# Copy themes and extensions to default locations for renewal on startup
RUN cp -r /app/themes /app/themes_default \
    && cp -r /app/extensions /app/extensions_default

# Environment variable to skip default themes/extensions renewal
# Set PAYMENTER_SKIP_DEFAULT=true to keep custom modifications to defaults
ENV PAYMENTER_SKIP_DEFAULT=false

# Copy Docker service configuration files
COPY .github/docker/default.conf /etc/nginx/http.d/default.conf
COPY .github/docker/www.conf /usr/local/etc/php-fpm.conf
COPY .github/docker/supervisord.conf /etc/supervisord.conf

# Install ionCube Loader for PHP 8.3 on Alpine/musl
RUN set -eux; \
    apk add --no-cache libstdc++ libgcc; \
    curl -fSL "https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64_musl.tar.gz" \
        -o /tmp/ioncube.tar.gz; \
    tar -xzf /tmp/ioncube.tar.gz -C /tmp; \
    PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"; \
    EXTENSION_DIR="$(php -r 'echo ini_get("extension_dir");')"; \
    ls -la /tmp/ioncube; \
    cp "/tmp/ioncube/ioncube_loader_lin_${PHP_VERSION}.so" \
       "${EXTENSION_DIR}/ioncube_loader_lin_${PHP_VERSION}.so"; \
    echo "zend_extension=${EXTENSION_DIR}/ioncube_loader_lin_${PHP_VERSION}.so" \
       > /usr/local/etc/php/conf.d/00-ioncube.ini; \
    rm -rf /tmp/ioncube /tmp/ioncube.tar.gz; \
    php -v

EXPOSE 80

ENTRYPOINT ["/bin/ash", ".github/docker/entrypoint.sh"]

CMD ["supervisord", "-n", "-c", "/etc/supervisord.conf"]