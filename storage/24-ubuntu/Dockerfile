# Dockerfile Bareos storage daemon
FROM ubuntu:noble

LABEL maintainer="barcus@tou.nu"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/barcus/bareos" \
      org.label-schema.version=$VERSION

ENV DEBIAN_FRONTEND=noninteractive

ARG BAREOS_PKG_RELEASE=pkg%2Fbareos-packages-v1
ARG BAREOS_PKG_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_PKG_ASSET=bareos-24-noble.tar.gz

# hadolint ignore=DL3020
ADD ${BAREOS_PKG_REPO}/releases/download/${BAREOS_PKG_RELEASE}/${BAREOS_PKG_ASSET} /tmp/bareos-pkgs.tar.gz

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir -p /tmp/bareos-debs \
 && tar -xzf /tmp/bareos-pkgs.tar.gz -C /tmp/bareos-debs \
 && apt-get update -qq \
 && apt-get install -qq -y --no-install-recommends \
    tzdata mtx scsitools sg3-utils mt-st \
    /tmp/bareos-debs/bareos-common_*.deb \
    /tmp/bareos-debs/bareos-storage_*.deb \
    /tmp/bareos-debs/bareos-storage-tape_*.deb \
    /tmp/bareos-debs/bareos-tools_*.deb \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/bareos-pkgs.tar.gz /tmp/bareos-debs

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod u+x /docker-entrypoint.sh

RUN tar czf /bareos-sd.tgz /etc/bareos/bareos-sd.d

EXPOSE 9103

VOLUME /etc/bareos
VOLUME /var/lib/bareos/storage

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/bareos-sd", "-u", "bareos", "-f"]
