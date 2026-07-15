FROM ghcr.io/paymenter/paymenter:latest

# Install SOAP extension
RUN apk add --no-cache libxml2-dev \
    && docker-php-ext-install soap

# Install glibc compatibility (required for ionCube on Alpine)
RUN wget -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r1/glibc-2.35-r1.apk \
    && apk add --no-cache --allow-untrusted --force-overwrite glibc-2.35-r1.apk \
    && rm glibc-2.35-r1.apk

# Install ionCube Loader (auto-detects PHP version)
RUN PHP_MAJOR=$(php -r "echo PHP_MAJOR_VERSION;") \
    && PHP_MINOR=$(php -r "echo PHP_MINOR_VERSION;") \
    && cd /tmp \
    && wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz \
    && tar xzf ioncube_loaders_lin_x86-64.tar.gz \
    && cp ioncube/ioncube_loader_lin_${PHP_MAJOR}.${PHP_MINOR}.so $(php -r "echo ini_get('extension_dir');")/ \
    && echo "zend_extension=ioncube_loader_lin_${PHP_MAJOR}.${PHP_MINOR}.so" > /usr/local/etc/php/conf.d/00-ioncube.ini \
    && rm -rf /tmp/ioncube /tmp/ioncube_loaders_lin_x86-64.tar.gz \
    && php -v