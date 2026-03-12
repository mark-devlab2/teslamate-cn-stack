#!/bin/sh
set -eu

: "${DOMAIN:?DOMAIN is required}"
: "${API_TOKEN:?API_TOKEN is required}"
: "${BASIC_AUTH_FILE:?BASIC_AUTH_FILE is required}"

mkdir -p /etc/nginx/tls /var/www/acme /var/log/nginx

if [ ! -f "$BASIC_AUTH_FILE" ]; then
  echo "missing basic auth file: $BASIC_AUTH_FILE" >&2
  exit 1
fi

case "${TLS_MODE:-manual}" in
  offload)
    ;;
  manual)
    [ -f /etc/nginx/tls/fullchain.pem ] || {
      echo "missing /etc/nginx/tls/fullchain.pem for manual TLS mode" >&2
      exit 1
    }
    [ -f /etc/nginx/tls/privkey.pem ] || {
      echo "missing /etc/nginx/tls/privkey.pem for manual TLS mode" >&2
      exit 1
    }
    ;;
  *)
    if [ ! -f /etc/nginx/tls/fullchain.pem ] || [ ! -f /etc/nginx/tls/privkey.pem ]; then
      openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout /etc/nginx/tls/privkey.pem \
        -out /etc/nginx/tls/fullchain.pem \
        -days 1 \
        -subj "/CN=${DOMAIN}" >/dev/null 2>&1
    fi
    ;;
esac
