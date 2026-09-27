FROM python:3.14-alpine@sha256:9e9fde4d32eedce0b661d9ab91e826b62dddf28e928c230ec55f1866cac66b01

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

ENV UVICORN_LOG_LEVEL=info

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uvicorn", "--host", "0.0.0.0", "bareos_restapi:app"]
