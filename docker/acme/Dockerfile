FROM neilpang/acme.sh:3.1.1

COPY docker/acme/run.sh /run.sh

RUN chmod 755 /run.sh

ENTRYPOINT ["/run.sh"]

