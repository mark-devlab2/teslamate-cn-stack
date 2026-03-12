#!/bin/sh
set -eu

: "${MOSQUITTO_USERNAME:?MOSQUITTO_USERNAME is required}"
: "${MOSQUITTO_PASSWORD:?MOSQUITTO_PASSWORD is required}"

mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log

mosquitto_passwd -b -c /mosquitto/config/passwordfile "$MOSQUITTO_USERNAME" "$MOSQUITTO_PASSWORD"

cat >/mosquitto/config/mosquitto.conf <<EOF
persistence true
persistence_location /mosquitto/data/
listener 1883 0.0.0.0
allow_anonymous false
password_file /mosquitto/config/passwordfile
log_dest stdout
EOF

exec "$@"
