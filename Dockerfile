FROM ghcr.io/paymenter/paymenter:latest

USER root

RUN set -eux; \
    apk add --no-cache curl tar libstdc++ libgcc; \
    curl -fSL "https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64_musl.tar.gz" \
        -o /tmp/ioncube.tar.gz; \
    tar -xzf /tmp/ioncube.tar.gz -C /tmp; \
    EXTENSION_DIR="$(php -r 'echo ini_get("extension_dir");')"; \
    cp "/tmp/ioncube/ioncube_loader_lin_8.3.so" \
       "${EXTENSION_DIR}/ioncube_loader_lin_8.3.so"; \
    echo "zend_extension=${EXTENSION_DIR}/ioncube_loader_lin_8.3.so" \
       > /usr/local/etc/php/conf.d/00-ioncube.ini; \
    rm -rf /tmp/ioncube /tmp/ioncube.tar.gz