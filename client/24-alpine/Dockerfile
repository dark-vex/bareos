# Dockerfile Bareos client/file daemon
FROM alpine:3.23

LABEL maintainer="bareos@ddlns.net"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION
ARG TARGETARCH
ARG TARGETVARIANT

ENV BAREOS_DAEMON_USER bareos
ENV BAREOS_DAEMON_GROUP bareos

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/dark-vex/bareos" \
      org.label-schema.version=$VERSION

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Alpine 3.23's community repo ships bareos-24.0.7 for amd64 only.
# armv7 and aarch64 are not published upstream for this version; install our own
# custom-built .apk (see bareos-alpine-packages/) for those arches instead.
ARG BAREOS_APK_RELEASE=pkg%2Fbareos-alpine-packages-v2
ARG BAREOS_APK_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_APK_VER=24-alpine3.23
ARG BAREOS_APK_SHA256_AARCH64=8b7dd2797704bd792c49f59e3e20b29753b08b8c42ef9e4905d8d34323640b4d

RUN apk upgrade --no-cache \
 && apk add --no-cache openssh-client tar shadow bash su-exec \
 && if [ "$TARGETARCH" = "amd64" ]; then \
      apk add --no-cache bareos-filedaemon; \
    else \
      case "$TARGETARCH/$TARGETVARIANT" in \
        arm64/*) bareos_arch=aarch64; bareos_sha256="${BAREOS_APK_SHA256_AARCH64}" ;; \
        arm/v7) echo "armv7 is not supported for this Bareos version: upstream bug (time_t static_assert in the filedaemon Python plugin) blocks the custom build, see bareos-alpine-packages/README.md" >&2; exit 1 ;; \
        *) echo "unsupported arch $TARGETARCH/$TARGETVARIANT for custom bareos apk" >&2; exit 1 ;; \
      esac \
   && apk add --no-cache curl \
   && curl -fsSL "${BAREOS_APK_REPO}/releases/download/${BAREOS_APK_RELEASE}/bareos-${BAREOS_APK_VER}-${bareos_arch}.tar.gz" -o /tmp/bareos-apks.tar.gz \
   && echo "${bareos_sha256}  /tmp/bareos-apks.tar.gz" | sha256sum -c - \
   && mkdir -p /tmp/bareos-apks \
   && tar -xzf /tmp/bareos-apks.tar.gz -C /tmp/bareos-apks \
   && apk add --no-cache --allow-untrusted /tmp/bareos-apks/bareos-[0-9]*.apk /tmp/bareos-apks/bareos-libs-*.apk /tmp/bareos-apks/bareos-filedaemon-*.apk \
   && apk del curl \
   && rm -rf /tmp/bareos-apks.tar.gz /tmp/bareos-apks; \
    fi

RUN tar czf /bareos-fd.tgz /etc/bareos/bareos-fd.d
RUN mkdir /run/bareos \
 && chown bareos /run/bareos

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+x /docker-entrypoint.sh

EXPOSE 9102

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-fd", "-f"]
