# Bareos director Dockerfile
FROM ubuntu:jammy@sha256:076e7bf82319619f28dd0aa9c02ab34b055ad37100395b4f49a2ffba04fb5e11

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

ARG BAREOS_PKG_RELEASE=pkg%2Fbareos-packages-v1
ARG BAREOS_PKG_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_PKG_ASSET=bareos-23-jammy.tar.gz

ARG PGDG_KEY=https://www.postgresql.org/media/keys/ACCC4CF8.asc
ARG PGDG_KEY_FINGERPRINT=B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8
ARG PGDG_SUITE=jammy

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update -qq \
 && apt-get upgrade -qq -y \
 && apt-get install -qq -y --no-install-recommends ca-certificates curl gnupg \
 && mkdir -p /tmp/bareos-debs \
 && curl -fsSL "${BAREOS_PKG_REPO}/releases/download/${BAREOS_PKG_RELEASE}/${BAREOS_PKG_ASSET}" -o /tmp/bareos-pkgs.tar.gz \
 && tar -xzf /tmp/bareos-pkgs.tar.gz -C /tmp/bareos-debs \
 && curl -fsSL "${PGDG_KEY}" -o /tmp/pgdg.key \
 && test "$(gpg --batch --show-keys --with-colons /tmp/pgdg.key | awk -F: '$1 == "fpr" { print $10 }')" = "${PGDG_KEY_FINGERPRINT}" \
 && gpg --batch --dearmor -o /usr/share/keyrings/pgdg.gpg /tmp/pgdg.key \
 && rm -f /tmp/pgdg.key \
 && echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt ${PGDG_SUITE}-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update -qq \
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
 && apt-get install -qq -y --no-install-recommends \
    tzdata postgresql-client-18 \
    /tmp/bareos-debs/bareos-bconsole_*.deb \
    /tmp/bareos-debs/bareos-common_*.deb \
    /tmp/bareos-debs/bareos-director_*.deb \
    /tmp/bareos-debs/bareos-database-common_*.deb \
    /tmp/bareos-debs/bareos-database-postgresql_*.deb \
    /tmp/bareos-debs/bareos-database-tools_*.deb \
    /tmp/bareos-debs/bareos-tools_*.deb \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/pgdg.list /tmp/bareos-pkgs.tar.gz /tmp/bareos-debs

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
