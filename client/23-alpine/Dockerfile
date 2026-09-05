# Dockerfile Bareos client/file daemon
FROM alpine:3.21

LABEL maintainer="bareos@ddlns.net"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION
ARG TARGETARCH

ENV BAREOS_DAEMON_USER bareos
ENV BAREOS_DAEMON_GROUP bareos

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/dark-vex/bareos" \
      org.label-schema.version=$VERSION

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Alpine 3.21's community repo ships bareos-23.0.4 for amd64 and armv7 directly.
# aarch64 is not published upstream for this version; install our own
# custom-built .apk (see bareos-alpine-packages/) for that arch instead.
ARG BAREOS_APK_RELEASE=pkg%2Fbareos-alpine-packages-v2
ARG BAREOS_APK_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_APK_ASSET=bareos-23-alpine3.21-aarch64.tar.gz

RUN apk upgrade --no-cache \
 && apk add --no-cache openssh-client tar shadow bash su-exec \
 && if [ "$TARGETARCH" = "arm64" ]; then \
      apk add --no-cache curl \
   && curl -fsSL "${BAREOS_APK_REPO}/releases/download/${BAREOS_APK_RELEASE}/${BAREOS_APK_ASSET}" -o /tmp/bareos-apks.tar.gz \
   && mkdir -p /tmp/bareos-apks \
   && tar -xzf /tmp/bareos-apks.tar.gz -C /tmp/bareos-apks \
   && apk add --no-cache --allow-untrusted /tmp/bareos-apks/bareos-[0-9]*.apk /tmp/bareos-apks/bareos-libs-*.apk /tmp/bareos-apks/bareos-filedaemon-*.apk \
   && apk del curl \
   && rm -rf /tmp/bareos-apks.tar.gz /tmp/bareos-apks; \
    else \
      apk add --no-cache bareos-filedaemon; \
    fi

RUN tar czf /bareos-fd.tgz /etc/bareos/bareos-fd.d
RUN mkdir /run/bareos \
 && chown bareos /run/bareos

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+x /docker-entrypoint.sh

EXPOSE 9102

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-fd", "-f"]
