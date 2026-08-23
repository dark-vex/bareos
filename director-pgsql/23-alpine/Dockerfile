# Bareos director Dockerfile
FROM alpine:3.21

LABEL maintainer="barcus@tou.nu"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION
ARG TARGETARCH

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/barcus/bareos" \
      org.label-schema.version=$VERSION

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Alpine 3.21's community repo ships bareos-23.0.4 for amd64 and armv7 directly.
# aarch64 is not published upstream for this version; install our own
# custom-built .apk (see bareos-alpine-packages/) for that arch instead.
ARG BAREOS_APK_RELEASE=pkg%2Fbareos-alpine-packages-v2
ARG BAREOS_APK_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_APK_ASSET=bareos-23-alpine3.21-aarch64.tar.gz

RUN apk add --no-cache postgresql-client curl tzdata tar \
 && if [ "$TARGETARCH" = "arm64" ]; then \
      curl -fsSL "${BAREOS_APK_REPO}/releases/download/${BAREOS_APK_RELEASE}/${BAREOS_APK_ASSET}" -o /tmp/bareos-apks.tar.gz \
   && mkdir -p /tmp/bareos-apks \
   && tar -xzf /tmp/bareos-apks.tar.gz -C /tmp/bareos-apks \
   && apk add --no-cache --allow-untrusted /tmp/bareos-apks/bareos-[0-9]*.apk /tmp/bareos-apks/bareos-libs-*.apk /tmp/bareos-apks/bareos-postgresql-*.apk \
   && rm -rf /tmp/bareos-apks.tar.gz /tmp/bareos-apks; \
    else \
      apk add --no-cache bareos bareos-postgresql; \
    fi

RUN tar czf /bareos-dir.tgz /etc/bareos
RUN mkdir /run/bareos \
 && chown bareos /run/bareos

COPY --chmod=755 webhook-notify /usr/local/bin/webhook-notify

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

EXPOSE 9101

VOLUME /etc/bareos
VOLUME /var/lib/bareos

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-dir", "-u", "bareos", "-f"]
