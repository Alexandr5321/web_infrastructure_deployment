FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y \
        rsyslog \
        gettext-base \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/rsyslog /var/spool/rsyslog /var/log

COPY rsyslog.conf /etc/rsyslog/rsyslog.conf.template
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
