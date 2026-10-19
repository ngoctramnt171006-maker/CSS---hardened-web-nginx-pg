FROM postgres:16@sha256:ca0bd484cb98bf4b24eb1010e73fb3fcbd6714d240fbc1a10eea5b7dbecb641d
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-16-pgaudit \
 && rm -rf /var/lib/apt/lists/*


COPY db-entrypoint /usr/local/bin/custom-db-entrypoint

RUN chmod +x /usr/local/bin/custom-db-entrypoint

ENTRYPOINT ["custom-db-entrypoint"]
