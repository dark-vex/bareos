# Bareos director Dockerfile
FROM ubuntu:noble

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

ARG BAREOS_KEY=http://download.bareos.org/current/xUbuntu_24.04/Release.key
ARG BAREOS_REPO=http://download.bareos.org/current/xUbuntu_24.04/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update -qq \
 && apt-get install -qq -y --no-install-recommends curl gnupg ca-certificates \
 && curl -fsSL "${BAREOS_KEY}" | gpg --dearmor -o /usr/share/keyrings/bareos.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/bareos.gpg] ${BAREOS_REPO} /" \
      > /etc/apt/sources.list.d/bareos.list \
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
    bareos-bconsole \
    bareos-common \
    bareos-director \
    bareos-database-common \
    bareos-database-postgresql \
    bareos-database-tools \
    bareos-tools \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/bareos.list

RUN tar czf /bareos-dir.tgz /etc/bareos

COPY --chmod=755 webhook-notify /usr/local/bin/webhook-notify

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

EXPOSE 9101

VOLUME /etc/bareos

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-dir", "-u", "bareos", "-f"]
