# Bareos Web-ui Dockerfile
FROM ubuntu:noble@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3

LABEL maintainer="bareos@ddlns.net"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/dark-vex/bareos" \
      org.label-schema.version=$VERSION

ENV DEBIAN_FRONTEND=noninteractive

ARG BAREOS_PKG_RELEASE=pkg%2Fbareos-packages-v1
ARG BAREOS_PKG_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_PKG_ASSET=bareos-24-noble.tar.gz

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update -qq \
 && apt-get install -qq -y --no-install-recommends ca-certificates curl \
 && mkdir -p /tmp/bareos-debs \
 && curl -fsSL "${BAREOS_PKG_REPO}/releases/download/${BAREOS_PKG_RELEASE}/${BAREOS_PKG_ASSET}" -o /tmp/bareos-pkgs.tar.gz \
 && tar -xzf /tmp/bareos-pkgs.tar.gz -C /tmp/bareos-debs \
 && apt-get install -qq -y --no-install-recommends \
    tzdata \
    /tmp/bareos-debs/bareos-webui_*.deb \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/bareos-pkgs.tar.gz /tmp/bareos-debs

RUN a2enmod proxy_fcgi setenvif \
 && set -- /etc/apache2/conf-available/php*-fpm.conf \
 && [ -f "$1" ] \
 && a2enconf "$(basename "$1" .conf)" \
 && set -- /usr/sbin/php-fpm* \
 && [ -x "$1" ] \
 && ln -sf "$1" /usr/local/sbin/php-fpm \
 && mkdir -p /run/php

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

RUN tar czf /bareos-webui.tgz /etc/bareos-webui

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=30s \
    CMD ["curl", "-fsS", "-o", "/dev/null", "http://127.0.0.1:80/"]

VOLUME /etc/bareos-webui

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
