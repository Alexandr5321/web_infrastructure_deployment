#!/bin/sh

set -e

if [ -z "$REMOTE_SYSLOG_IP" ]; then
    echo "ERROR: REMOTE_SYSLOG_IP is not set"
    exit 1
fi

mkdir -p /var/spool/rsyslog
mkdir -p /var/log

chmod 700 /var/spool/rsyslog
chmod 755 /var/log

envsubst '${REMOTE_SYSLOG_IP}' \
    < /etc/rsyslog/rsyslog.conf.template \
    > /etc/rsyslog.conf

exec rsyslogd -n -f /etc/rsyslog.conf
