FROM docker:27@sha256:aa3df78ecf320f5fafdce71c659f1629e96e9de0968305fe1de670e0ca9176ce

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG WIZCLI_VERSION=latest
ARG WIZCLI_GPG_FINGERPRINT=61DF40680AB1A80E51503B61CE4AE4BAD12EE02C

RUN apk update \
 && apk add --no-cache curl bash jq gnupg \
 && mkdir -p /tmp/wizcli \
 && curl -fsSLo /tmp/wizcli/wizcli-linux-amd64 "https://downloads.wiz.io/v1/wizcli/${WIZCLI_VERSION}/wizcli-linux-amd64" \
 && curl -fsSLo /tmp/wizcli/wizcli-linux-amd64-sha256 "https://downloads.wiz.io/v1/wizcli/${WIZCLI_VERSION}/wizcli-linux-amd64-sha256" \
 && curl -fsSLo /tmp/wizcli/wizcli-linux-amd64-sha256.sig "https://downloads.wiz.io/v1/wizcli/${WIZCLI_VERSION}/wizcli-linux-amd64-sha256.sig" \
 && curl -fsSLo /tmp/wizcli/public_key.asc "https://downloads.wiz.io/wizcli/public_key.asc" \
 && imported_fingerprint="$(gpg --with-colons --import-options show-only --import /tmp/wizcli/public_key.asc | awk -F: '/^fpr:/ { print $10; exit }')" \
 && [ "${imported_fingerprint}" = "${WIZCLI_GPG_FINGERPRINT}" ] \
 && gpg --import /tmp/wizcli/public_key.asc \
 && gpg --verify /tmp/wizcli/wizcli-linux-amd64-sha256.sig /tmp/wizcli/wizcli-linux-amd64-sha256 \
 && awk '{ print $1 "  /tmp/wizcli/wizcli-linux-amd64" }' /tmp/wizcli/wizcli-linux-amd64-sha256 > /tmp/wizcli/wizcli-linux-amd64-sha256.check \
 && sha256sum -c /tmp/wizcli/wizcli-linux-amd64-sha256.check \
 && mv /tmp/wizcli/wizcli-linux-amd64 /usr/local/bin/wizcli \
 && chmod +x /usr/local/bin/wizcli \
 && gpgconf --kill all \
 && apk del gnupg \
 && rm -rf /tmp/wizcli /root/.gnupg /var/cache/apk/*

COPY --from=ghcr.io/regclient/regctl:v0.11.6 /regctl /usr/local/bin/regctl
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
