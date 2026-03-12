#!/bin/sh
set -eu

: "${DOMAIN:?DOMAIN is required}"
: "${TLS_MODE:=manual}"

mkdir -p /acme.sh /certs /var/www/acme

if [ "$TLS_MODE" != "acme" ]; then
  exec tail -f /dev/null
fi

: "${ACME_EMAIL:?ACME_EMAIL is required in acme mode}"
: "${ACME_CA_SERVER:=letsencrypt}"

staging_arg=""
if [ "${ACME_STAGING:-0}" = "1" ]; then
  staging_arg="--staging"
fi

ensure_cert() {
  acme.sh --set-default-ca --server "$ACME_CA_SERVER" >/dev/null 2>&1 || true
  if [ ! -f /certs/fullchain.pem ] || [ ! -f /certs/privkey.pem ]; then
    acme.sh --register-account -m "$ACME_EMAIL" >/dev/null 2>&1 || true
    # shellcheck disable=SC2086
    acme.sh --issue --webroot /var/www/acme -d "$DOMAIN" --server "$ACME_CA_SERVER" $staging_arg
  fi
  acme.sh --install-cert -d "$DOMAIN" \
    --fullchain-file /certs/fullchain.pem \
    --key-file /certs/privkey.pem \
    --reloadcmd "true"
}

ensure_cert

while :; do
  sleep 12h
  acme.sh --cron --home /acme.sh || true
  ensure_cert
done
