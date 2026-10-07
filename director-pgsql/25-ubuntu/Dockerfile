# Bareos director Dockerfile
FROM ubuntu:noble@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

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
ENV BAREOS_DPKG_CONF="bareos-database-common bareos-database-common"

ARG BAREOS_KEY=https://download.bareos.org/current/xUbuntu_24.04/Release.key
ARG BAREOS_REPO=https://download.bareos.org/current/xUbuntu_24.04/
ARG BAREOS_KEY_FINGERPRINT=82834CF002D89BA55C1ED0AA42DA24A6DFEF9127

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update -qq \
 && apt-get install -qq -y --no-install-recommends curl gnupg ca-certificates \
 && curl -fsSL "${BAREOS_KEY}" -o /tmp/bareos.key \
 && test "$(gpg --batch --show-keys --with-colons /tmp/bareos.key | awk -F: '$1 == "fpr" { print $10 }')" = "${BAREOS_KEY_FINGERPRINT}" \
 && gpg --batch --dearmor -o /usr/share/keyrings/bareos.gpg /tmp/bareos.key \
 && rm -f /tmp/bareos.key \
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
COPY webui-admin.conf admin.conf.example /usr/local/share/bareos/

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

EXPOSE 9101

HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=90s \
    CMD ["bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/9101"]

VOLUME /etc/bareos

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-dir", "-u", "bareos", "-f"]
