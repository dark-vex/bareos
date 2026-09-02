FROM docker:27

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk update \
 && apk add --no-cache curl bash jq \
 && curl -Lo /usr/local/bin/wizcli https://downloads.wiz.io/v1/wizcli/latest/wizcli-linux-amd64 \
 && chmod +x /usr/local/bin/wizcli \
 && rm -rf /var/cache/apk/*

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
