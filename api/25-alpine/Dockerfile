FROM python:3.14-alpine@sha256:f6a589d43c42b9e7f7dc67a12d37132491f362859a5d750607710cc56da3bc72

LABEL maintainer="bareos@ddlns.net"

ARG BUILD_DATE
ARG NAME
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$NAME \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/dark-vex/bareos" \
      org.label-schema.version=$VERSION

RUN apk upgrade --no-cache

RUN adduser -D -u 1000 bareos
USER 1000
WORKDIR /home/bareos

ENV PATH="/home/bareos/.local/bin:${PATH}"
COPY --chown=bareos requirements.txt /home/bareos/requirements.txt
RUN pip install --no-cache-dir --require-hashes -r /home/bareos/requirements.txt

COPY --chown=bareos docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+x /docker-entrypoint.sh

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=30s \
    CMD ["wget", "-q", "-T", "3", "-O", "/dev/null", "http://127.0.0.1:8000/docs"]

ENV UVICORN_LOG_LEVEL=info

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uvicorn", "--host", "0.0.0.0", "bareos_restapi:app"]
