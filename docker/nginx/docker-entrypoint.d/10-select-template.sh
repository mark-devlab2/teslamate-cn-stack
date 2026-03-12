#!/bin/sh
set -eu

case "${TLS_MODE:-manual}" in
  offload)
    cp /etc/nginx/templates/car.himark.me.offload.conf.template /etc/nginx/templates/default.conf.template
    ;;
esac
