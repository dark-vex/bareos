FROM docker:27@sha256:aa3df78ecf320f5fafdce71c659f1629e96e9de0968305fe1de670e0ca9176ce

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk update \
 && apk add --no-cache curl bash git \
 && rm -rf /var/cache/apk/*

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
