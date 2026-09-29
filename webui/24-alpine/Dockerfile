# Bareos Web-ui Dockerfile
FROM alpine:3.23@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0

LABEL maintainer="bareos@ddlns.net"

ARG TARGETARCH
ARG TARGETVARIANT

# Alpine 3.23's community repo ships bareos-webui-nginx-24.0.7 for amd64 only.
# aarch64 is not published upstream for this version; install our own
# custom-built .apk (see bareos-alpine-packages/) for that arch instead.
ARG BAREOS_APK_RELEASE=pkg%2Fbareos-alpine-packages-v4
ARG BAREOS_APK_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_APK_VER=24-alpine3.23
ARG BAREOS_APK_SHA256_AARCH64=492ae7d6f3e3fc79c2c6efbad08dc179b1c50caabd6401e23053449a670f1d38

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

COPY bareos-apk@dark-vex.rsa.pub /etc/apk/keys/bareos-apk@dark-vex.rsa.pub

RUN apk upgrade --no-cache \
 && if [ "$TARGETARCH" = "amd64" ]; then \
      apk add --no-cache bareos-webui-nginx; \
    else \
      case "$TARGETARCH/$TARGETVARIANT" in \
        arm64/*) bareos_arch=aarch64; bareos_sha256="${BAREOS_APK_SHA256_AARCH64}" ;; \
        *) echo "unsupported arch $TARGETARCH/$TARGETVARIANT for custom bareos apk" >&2; exit 1 ;; \
      esac \
   && apk add --no-cache curl tar \
   && curl -fsSL "${BAREOS_APK_REPO}/releases/download/${BAREOS_APK_RELEASE}/bareos-${BAREOS_APK_VER}-${bareos_arch}.tar.gz" -o /tmp/bareos-apks.tar.gz \
   && echo "${bareos_sha256}  /tmp/bareos-apks.tar.gz" | sha256sum -c - \
   && mkdir -p /tmp/bareos-apks \
   && tar -xzf /tmp/bareos-apks.tar.gz -C /tmp/bareos-apks \
   && apk add --no-cache /tmp/bareos-apks/bareos-webui-[0-9]*.apk /tmp/bareos-apks/bareos-webui-nginx-*.apk \
   && apk del curl \
   && rm -rf /tmp/bareos-apks.tar.gz /tmp/bareos-apks; \
    fi

RUN set -- /usr/sbin/php-fpm8* \
 && [ -x "$1" ] \
 && mkdir -p /usr/local/sbin \
 && ln -sf "$1" /usr/local/sbin/php-fpm \
 && set -- /etc/php8*/php-fpm.d \
 && [ -d "$1" ] \
 && printf '%s\n' '[global]' 'daemonize = no' 'error_log = /proc/self/fd/2' '[www]' 'listen = 9000' > "$1/zz-docker.conf"

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh
RUN tar cfvz /bareos-webui-config.tgz /etc/bareos-webui
RUN tar cfvz /bareos-webui-code.tgz /usr/share/bareos-webui
RUN mkdir -p /run/nginx

EXPOSE 9100

HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=30s \
    CMD ["wget", "-q", "-T", "3", "-O", "/dev/null", "http://127.0.0.1:9100/"]

VOLUME /etc/bareos-webui

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
