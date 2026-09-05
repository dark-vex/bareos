# Bareos Web-ui Dockerfile
FROM alpine:3.21

LABEL maintainer="bareos@ddlns.net"

ARG TARGETARCH

# Alpine 3.21's community repo ships bareos-webui-nginx-23.0.4 for amd64 and
# armv7 directly. aarch64 is not published upstream for this version; install
# our own custom-built .apk (see bareos-alpine-packages/) for that arch instead.
ARG BAREOS_APK_RELEASE=pkg%2Fbareos-alpine-packages-v2
ARG BAREOS_APK_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_APK_ASSET=bareos-23-alpine3.21-aarch64.tar.gz

RUN apk upgrade --no-cache \
 && if [ "$TARGETARCH" = "arm64" ]; then \
      apk add --no-cache curl tar \
   && curl -fsSL "${BAREOS_APK_REPO}/releases/download/${BAREOS_APK_RELEASE}/${BAREOS_APK_ASSET}" -o /tmp/bareos-apks.tar.gz \
   && mkdir -p /tmp/bareos-apks \
   && tar -xzf /tmp/bareos-apks.tar.gz -C /tmp/bareos-apks \
   && apk add --no-cache --allow-untrusted /tmp/bareos-apks/bareos-webui-[0-9]*.apk /tmp/bareos-apks/bareos-webui-nginx-*.apk \
   && apk del curl \
   && rm -rf /tmp/bareos-apks.tar.gz /tmp/bareos-apks; \
    else \
      apk add --no-cache bareos-webui-nginx; \
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
