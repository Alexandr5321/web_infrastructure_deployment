#!/bin/sh

set -e

echo "Syslog receiver started on TCP port 514"

exec socat TCP-LISTEN:514,reuseaddr,fork -
