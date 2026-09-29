# Bareos director Dockerfile
FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

LABEL maintainer="bareos@ddlns.net"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION
ARG TARGETARCH
ARG TARGETVARIANT

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/dark-vex/bareos" \
      org.label-schema.version=$VERSION

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Alpine 3.24's community repo ships bareos-25.0.3 for amd64 only, with
# the postgres catalog driver folded into the base 'bareos' package (no separate
# bareos-postgresql subpackage from Bareos 24 onward). aarch64 is not
# published upstream for this version; install our own custom-built .apk (see
# bareos-alpine-packages/) for that arch instead.
ARG BAREOS_APK_RELEASE=pkg%2Fbareos-alpine-packages-v4
ARG BAREOS_APK_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_APK_VER=25-alpine3.24
ARG BAREOS_APK_SHA256_AARCH64=113a797543cd23c7983a41d6ca586e00466f086db1d5d5868c09e96ba411b747

COPY bareos-apk@dark-vex.rsa.pub /etc/apk/keys/bareos-apk@dark-vex.rsa.pub

RUN apk upgrade --no-cache \
 && apk add --no-cache postgresql-client curl tzdata tar \
 && if [ "$TARGETARCH" = "amd64" ]; then \
      apk add --no-cache bareos; \
    else \
      case "$TARGETARCH/$TARGETVARIANT" in \
        arm64/*) bareos_arch=aarch64; bareos_sha256="${BAREOS_APK_SHA256_AARCH64}" ;; \
        *) echo "unsupported arch $TARGETARCH/$TARGETVARIANT for custom bareos apk" >&2; exit 1 ;; \
      esac \
   && curl -fsSL "${BAREOS_APK_REPO}/releases/download/${BAREOS_APK_RELEASE}/bareos-${BAREOS_APK_VER}-${bareos_arch}.tar.gz" -o /tmp/bareos-apks.tar.gz \
   && echo "${bareos_sha256}  /tmp/bareos-apks.tar.gz" | sha256sum -c - \
   && mkdir -p /tmp/bareos-apks \
   && tar -xzf /tmp/bareos-apks.tar.gz -C /tmp/bareos-apks \
   && apk add --no-cache /tmp/bareos-apks/bareos-[0-9]*.apk /tmp/bareos-apks/bareos-libs-*.apk \
   && rm -rf /tmp/bareos-apks.tar.gz /tmp/bareos-apks; \
    fi

RUN tar czf /bareos-dir.tgz /etc/bareos
RUN mkdir /run/bareos \
 && chown bareos /run/bareos

COPY --chmod=755 webhook-notify /usr/local/bin/webhook-notify
COPY webui-admin.conf admin.conf.example /usr/local/share/bareos/

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

EXPOSE 9101

HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=90s \
    CMD ["nc", "-z", "127.0.0.1", "9101"]

VOLUME /etc/bareos
VOLUME /var/lib/bareos

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-dir", "-u", "bareos", "-f"]
