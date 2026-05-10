# Bareos director Dockerfile
FROM ubuntu:jammy

LABEL maintainer="barcus@tou.nu"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/barcus/bareos" \
      org.label-schema.version=$VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV BAREOS_DPKG_CONF="bareos-database-common bareos-database-common"

ARG BAREOS_PKG_RELEASE=pkg%2Fbareos-packages-v1
ARG BAREOS_PKG_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_PKG_ASSET=bareos-22-jammy.tar.gz

ADD ${BAREOS_PKG_REPO}/releases/download/${BAREOS_PKG_RELEASE}/${BAREOS_PKG_ASSET} /tmp/bareos-pkgs.tar.gz

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir -p /tmp/bareos-debs \
 && tar -xzf /tmp/bareos-pkgs.tar.gz -C /tmp/bareos-debs \
 && echo "${BAREOS_DPKG_CONF}/dbconfig-install boolean false" \
    | debconf-set-selections \
 && echo "${BAREOS_DPKG_CONF}/install-error select ignore" \
    | debconf-set-selections \
 && echo "${BAREOS_DPKG_CONF}/database-type select pgsql" \
    | debconf-set-selections \
 && echo "${BAREOS_DPKG_CONF}/missing-db-package-error select ignore" \
    | debconf-set-selections \
 && echo 'postfix postfix/main_mailer_type select No configuration' \
    | debconf-set-selections \
 && apt-get update -qq \
 && apt-get install -qq -y --no-install-recommends \
    curl tzdata postgresql-client \
    /tmp/bareos-debs/bareos-bconsole_*.deb \
    /tmp/bareos-debs/bareos-common_*.deb \
    /tmp/bareos-debs/bareos-director_*.deb \
    /tmp/bareos-debs/bareos-database-common_*.deb \
    /tmp/bareos-debs/bareos-database-postgresql_*.deb \
    /tmp/bareos-debs/bareos-database-tools_*.deb \
    /tmp/bareos-debs/bareos-tools_*.deb \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/bareos-pkgs.tar.gz /tmp/bareos-debs

RUN tar czf /bareos-dir.tgz /etc/bareos

COPY webhook-notify /usr/local/bin/webhook-notify
RUN chmod u+x /usr/local/bin/webhook-notify

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

EXPOSE 9101

VOLUME /etc/bareos

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-dir", "-u", "bareos", "-f"]
