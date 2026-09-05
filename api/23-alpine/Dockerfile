FROM python:3.10-alpine

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

RUN pip install --no-cache-dir --upgrade pip==22.0.4

RUN adduser -D -u 1000 bareos
USER 1000
WORKDIR /home/bareos

ENV PATH="/home/bareos/.local/bin:${PATH}"
RUN pip install --no-cache-dir "bareos-restapi>=23*,<24*"

COPY --chown=bareos docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+x /docker-entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uvicorn","--log-level", "debug", "--host", "0.0.0.0", "bareos_restapi:app", "--reload"]
