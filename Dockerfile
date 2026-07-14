FROM ghcr.io/paymenter/paymenter:latest

USER root

COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/

RUN IPE_DEBUG=1 install-php-extensions ioncube_loader