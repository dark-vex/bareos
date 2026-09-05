# Bareos Web-ui Dockerfile
FROM alpine:3.24

LABEL maintainer="bareos@ddlns.net"

ARG TARGETARCH
ARG TARGETVARIANT

# Alpine 3.24's community repo ships bareos-webui-nginx-25.0.3 for amd64 only.
# armv7 and aarch64 are not published upstream for this version; install our own
# custom-built .apk (see bareos-alpine-packages/) for those arches instead.
ARG BAREOS_APK_RELEASE=pkg%2Fbareos-alpine-packages-v2
ARG BAREOS_APK_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_APK_VER=25-alpine3.24

RUN apk upgrade --no-cache \
 && if [ "$TARGETARCH" = "amd64" ]; then \
      apk add --no-cache bareos-webui-nginx; \
    else \
      case "$TARGETARCH/$TARGETVARIANT" in \
        arm64/*) bareos_arch=aarch64 ;; \
        arm/v7) echo "armv7 is not supported for this Bareos version: upstream bug (time_t static_assert in the filedaemon Python plugin) blocks the custom build, see bareos-alpine-packages/README.md" >&2; exit 1 ;; \
        *) echo "unsupported arch $TARGETARCH/$TARGETVARIANT for custom bareos apk" >&2; exit 1 ;; \
      esac \
   && apk add --no-cache curl tar \
   && curl -fsSL "${BAREOS_APK_REPO}/releases/download/${BAREOS_APK_RELEASE}/bareos-${BAREOS_APK_VER}-${bareos_arch}.tar.gz" -o /tmp/bareos-apks.tar.gz \
   && mkdir -p /tmp/bareos-apks \
   && tar -xzf /tmp/bareos-apks.tar.gz -C /tmp/bareos-apks \
   && apk add --no-cache --allow-untrusted /tmp/bareos-apks/bareos-webui-[0-9]*.apk /tmp/bareos-apks/bareos-webui-nginx-*.apk \
   && apk del curl \
   && rm -rf /tmp/bareos-apks.tar.gz /tmp/bareos-apks; \
    fi

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh
RUN tar cfvz /bareos-webui-config.tgz /etc/bareos-webui
RUN tar cfvz /bareos-webui-code.tgz /usr/share/bareos-webui
RUN mkdir -p /run/nginx

EXPOSE 9100

VOLUME /etc/bareos-webui

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
