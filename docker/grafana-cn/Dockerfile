FROM teslamate/grafana:3.0.0 AS upstream

FROM python:3.13-alpine AS patcher

WORKDIR /work

COPY --from=upstream /dashboards /src/dashboards
COPY --from=upstream /dashboards_internal /src/dashboards_internal
COPY docker/grafana-cn/patch_dashboards.py /work/patch_dashboards.py
COPY docker/grafana-cn/home-cn.json /src/dashboards_internal/home.json

RUN python /work/patch_dashboards.py /src/dashboards /src/dashboards_internal

FROM teslamate/grafana:3.0.0

USER root

COPY --from=patcher /src/dashboards /dashboards
COPY --from=patcher /src/dashboards_internal /dashboards_internal

ENV GF_AUTH_ANONYMOUS_ENABLED=false \
    GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/dashboards_internal/home.json \
    GF_SERVER_SERVE_FROM_SUB_PATH=true

USER grafana

