FROM alpine:latest

RUN apk add \
        supervisor \
        drill \
        gettext \
        bind-tools \
        sudo \
        openssl \
        curl

ARG UNBOUND_VERSION=1.17.1-r1

RUN apk add \
        unbound=${UNBOUND_VERSION} \
    && rm -rf /etc/unbound/unbound.conf /etc/unbound/root.hints

ADD config/unbound.ini /etc/supervisor.d/supervisor-unbound.ini

ADD config/unbound.conf /etc/unbound/unbound.conf
ADD docker-entrypoint.sh /docker-entrypoint
COPY scripts /scripts
RUN chmod u+x /docker-entrypoint /scripts/*
RUN mkdir -p /etc/unbound/keys

RUN curl  --ipv4 https://www.internic.net/domain/named.root > /etc/unbound/root.hints

ENV BEBASID_FAMILY_UNBOUND=true

ENTRYPOINT ["/docker-entrypoint"]
CMD [ "/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]

HEALTHCHECK --interval=1m --timeout=30s --start-period=10s CMD drill @127.0.0.1 google.com || exit 1