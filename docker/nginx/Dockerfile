FROM nginx:1.27-alpine

RUN apk add --no-cache bash curl inotify-tools openssl

COPY docker/nginx/templates/car.himark.me.conf.template /etc/nginx/templates/default.conf.template
COPY docker/nginx/docker-entrypoint.d/30-validate-secrets.sh /docker-entrypoint.d/30-validate-secrets.sh
COPY docker/nginx/docker-entrypoint.d/40-start-watch.sh /docker-entrypoint.d/40-start-watch.sh
COPY docker/nginx/bin/watch-certs.sh /usr/local/bin/watch-certs.sh

RUN chmod 755 /docker-entrypoint.d/30-validate-secrets.sh /docker-entrypoint.d/40-start-watch.sh /usr/local/bin/watch-certs.sh
