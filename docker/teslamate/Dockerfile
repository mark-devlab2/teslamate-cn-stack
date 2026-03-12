FROM elixir:1.19.5-otp-26 AS builder

ARG TESLAMATE_VERSION=3.0.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg zstd brotli patch \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
     | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && NODE_MAJOR=22 \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
     | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mix local.rebar --force && \
    mix local.hex --force

ENV MIX_ENV=prod
WORKDIR /opt/app

RUN curl -fsSL "https://github.com/teslamate-org/teslamate/archive/refs/tags/v${TESLAMATE_VERSION}.tar.gz" \
    | tar -xz --strip-components=1 -C /opt/app

COPY docker/teslamate/patches /tmp/patches

RUN for patch_file in /tmp/patches/*.patch; do patch -p1 < "$patch_file"; done

RUN mix deps.get --only "$MIX_ENV"
RUN mix deps.compile

RUN npm ci --prefix ./assets --progress=false --no-audit --loglevel=error

RUN mix assets.deploy

RUN mix compile

RUN SKIP_LOCALE_DOWNLOAD=true mix release --path /opt/built

FROM debian:trixie-slim AS app

ENV LANG=C.UTF-8 \
    SRTM_CACHE=/opt/app/.srtm_cache \
    HOME=/opt/app

WORKDIR $HOME

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      libodbc2 \
      libsctp1 \
      libssl3t64 \
      libstdc++6 \
      netcat-openbsd \
      tini \
      tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 --system nonroot \
    && useradd --uid 10000 --system --gid nonroot --home-dir /home/nonroot --shell /sbin/nologin nonroot \
    && chown -R nonroot:nonroot .

USER nonroot:nonroot

COPY --from=builder --chown=nonroot:nonroot --chmod=555 /opt/app/entrypoint.sh /entrypoint.sh
COPY --from=builder --chown=nonroot:nonroot --chmod=555 /opt/built .

RUN mkdir -p "$SRTM_CACHE"

EXPOSE 4000

ENTRYPOINT ["tini", "--", "/bin/dash", "/entrypoint.sh"]
CMD ["bin/teslamate", "start"]
