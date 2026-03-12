#!/bin/sh
set -eu

CERT_DIR=/etc/nginx/tls

while [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; do
  sleep 5
done

inotifywait -m -e close_write,move,create "$CERT_DIR" | while read -r _dir _event file; do
  case "$file" in
    fullchain.pem|privkey.pem)
      nginx -s reload >/dev/null 2>&1 || true
      ;;
  esac
done

