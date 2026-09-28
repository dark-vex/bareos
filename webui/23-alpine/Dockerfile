# Bareos Web-ui Dockerfile
FROM alpine:3.21@sha256:ce64758a109eb420d874a118f87920e625e12d3634e03b4a5573fd9f6e5d3507

LABEL maintainer="bareos@ddlns.net"

ARG TARGETARCH

# Alpine 3.21's community repo ships bareos-webui-nginx-23.0.4 for amd64 and
# armv7 directly. aarch64 is not published upstream for this version; install
# our own custom-built .apk (see bareos-alpine-packages/) for that arch instead.
ARG BAREOS_APK_RELEASE=pkg%2Fbareos-alpine-packages-v4
ARG BAREOS_APK_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_APK_ASSET=bareos-23-alpine3.21-aarch64.tar.gz
ARG BAREOS_APK_SHA256_AARCH64=1a3c7c2e9e6d74a292fb32d198ef5f3122f36b5f4fe0d4e7d902e0114433d772

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

COPY bareos-apk@dark-vex.rsa.pub /etc/apk/keys/bareos-apk@dark-vex.rsa.pub

RUN apk upgrade --no-cache \
 && if [ "$TARGETARCH" = "arm64" ]; then \
      apk add --no-cache curl tar \
   && curl -fsSL "${BAREOS_APK_REPO}/releases/download/${BAREOS_APK_RELEASE}/${BAREOS_APK_ASSET}" -o /tmp/bareos-apks.tar.gz \
   && echo "${BAREOS_APK_SHA256_AARCH64}  /tmp/bareos-apks.tar.gz" | sha256sum -c - \
   && mkdir -p /tmp/bareos-apks \
   && tar -xzf /tmp/bareos-apks.tar.gz -C /tmp/bareos-apks \
   && apk add --no-cache /tmp/bareos-apks/bareos-webui-[0-9]*.apk /tmp/bareos-apks/bareos-webui-nginx-*.apk \
   && apk del curl \
   && rm -rf /tmp/bareos-apks.tar.gz /tmp/bareos-apks; \
    else \
      apk add --no-cache bareos-webui-nginx; \
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
