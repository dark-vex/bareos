# Bareos Web-ui Dockerfile
FROM ubuntu:noble

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

ARG BAREOS_KEY=http://download.bareos.org/current/xUbuntu_24.04/Release.key
ARG BAREOS_REPO=http://download.bareos.org/current/xUbuntu_24.04/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update -qq \
 && apt-get install -qq -y --no-install-recommends curl gnupg ca-certificates \
 && curl -fsSL "${BAREOS_KEY}" | gpg --dearmor -o /usr/share/keyrings/bareos.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/bareos.gpg] ${BAREOS_REPO} /" \
      > /etc/apt/sources.list.d/bareos.list \
 && apt-get update -qq \
 && apt-get install -qq -y --no-install-recommends \
    tzdata \
    bareos-webui \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/bareos.list

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

RUN tar czf /bareos-webui.tgz /etc/bareos-webui

EXPOSE 80

VOLUME /etc/bareos-webui

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
