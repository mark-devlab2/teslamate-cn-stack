# 平台与监控最小变更片段

本文件是权威最小集合，只描述 TeslaMate 接入真正需要的新增内容。

如果目标仓对应文件上还有别的本地变更，以这里的片段为准做人工合并。

## `aliyun-deploy-platform`

### `.github/workflows/build-publish.yml`

目的：

- 让 `runtime.type=container-mirror` 的服务仓跳过 `npm ci`

关键变更：

```yaml
      - name: Resolve build contract
        id: contract
        run: |
          python3 .deploy-platform/scripts/render-config.py build-contract "${{ inputs.build_config_path }}" > contract.json
          python3 - <<'PY'
          import json
          import os

          doc = json.load(open("contract.json", "r", encoding="utf-8"))
          runtime_type = doc.get("runtime", {}).get("type", "node")
          with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as fh:
              fh.write(f"service_id={doc['serviceId']}\n")
              fh.write(f"default_target={doc.get('deploy', {}).get('defaultTarget', 'full')}\n")
              fh.write(f"runtime_type={runtime_type}\n")
          PY

      - name: Set up Node.js
        if: ${{ steps.contract.outputs.runtime_type == 'node' }}

      - name: Install service dependencies
        if: ${{ steps.contract.outputs.runtime_type == 'node' }}
```

### `.github/workflows/validate-service.yml`

目的：

- 校验阶段也识别 `runtime.type=container-mirror`

关键变更：

```yaml
      - name: Resolve contracts
        id: contract
```

```yaml
          RUNTIME_TYPE="$(python3 - <<'PY'
          import json

          doc = json.load(open("contract.json", "r", encoding="utf-8"))
          print(doc.get("runtime", {}).get("type", "node"))
          PY
          )"
          {
            printf 'service_id=%s\n' "$SERVICE_ID"
            printf 'runtime_type=%s\n' "$RUNTIME_TYPE"
          } >>"$GITHUB_OUTPUT"
```

```yaml
      - name: Set up Node.js
        if: ${{ steps.contract.outputs.runtime_type == 'node' }}

      - name: Install service dependencies
        if: ${{ steps.contract.outputs.runtime_type == 'node' }}
```

### `scripts/render-config.py`

目的：

- 让 build contract 支持 `runtime.type`

关键变更：

```python
runtime = doc.get("runtime", {})
if not isinstance(runtime, dict):
    raise SystemExit("build contract runtime must be an object")
runtime_type = str(runtime.get("type", "node")).strip() or "node"
if runtime_type not in {"node", "container-mirror"}:
    raise SystemExit(f"unsupported runtime.type: {runtime_type}")
```

```python
"runtime": {
    **runtime,
    "type": runtime_type,
},
```

### `services/teslamate-cn/`

需要完整纳入：

- `deploy.yaml`
- `compose.prod.yml`
- `compose.prod.env.example`

## `openclaw-main-config`

### `ops/deploy_targets.yaml`

新增一个部署目标：

```yaml
  - id: teslamate_cn
    node: aliyun
    strategy: service_target_image_pull_restart
    health_check: http_health
    rollback: previous_image_tag
    targets:
      - teslamate
      - api
      - grafana
      - edge
      - full
```

### `ops/ops-watch.env.example`

新增示例环境变量：

```env
TESLAMATE_HEALTH_URL="https://car.himark.me/_health/teslamate"
TESLAMATE_API_HEALTH_URL="https://car.himark.me/api/readyz"
TESLAMATE_GRAFANA_HEALTH_URL="https://car.himark.me/grafana/login"
```

### `ops/watch_targets.yaml`

新增两个巡检目标：

```yaml
  - id: teslamate_cn_web
    type: service
    owner_project: teslamate_cn
    interval: 5m
    check_method: http_health
    severity: critical
    notify_policy: fail_twice
    auto_recovery_policy: restart_candidate

  - id: teslamate_cn_deployment
    type: deployment_target
    owner_project: teslamate_cn
    interval: 15m
    check_method: last_deploy_status
    severity: high
    notify_policy: immediate
    auto_recovery_policy: none
```

### `scripts/health-check.sh`

新增 TeslaMate 三条 HTTP 检查：

```sh
check_http "teslamate" "${TESLAMATE_HEALTH_URL:-}"
check_http "teslamate_api" "${TESLAMATE_API_HEALTH_URL:-}"
check_http "teslamate_grafana" "${TESLAMATE_GRAFANA_HEALTH_URL:-}"
```
