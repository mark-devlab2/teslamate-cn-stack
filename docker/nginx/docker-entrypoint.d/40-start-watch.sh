#!/bin/sh
set -eu

if [ "${TLS_MODE:-manual}" = "acme" ]; then
  /usr/local/bin/watch-certs.sh &
fi
