# 平台与监控集成交接

## 当前状态

- 服务仓已推送到公开仓库：`https://github.com/mark-devlab2/teslamate-cn-stack`
- `aliyun-deploy-platform` 和 `openclaw-main-config` 本地都不是干净工作区
- 为避免把无关改动一起提交，本仓只提供最小必需改动的导出脚本，不直接改写那两个仓的 Git 历史

## TeslaMate 上线所需的最小平台改动

以下文件属于 TeslaMate 方案真正依赖的最小集合：

- `aliyun-deploy-platform/.github/workflows/build-publish.yml`
- `aliyun-deploy-platform/.github/workflows/validate-service.yml`
- `aliyun-deploy-platform/scripts/render-config.py`
- `aliyun-deploy-platform/services/teslamate-cn/`

作用：

- 让平台识别 `runtime.type=container-mirror`
- 让非 Node 服务仓跳过 `npm ci`
- 接入 `teslamate-cn` 的 Compose、镜像映射和部署目标

## TeslaMate 上线所需的最小监控改动

- `openclaw-main-config/ops/deploy_targets.yaml`
- `openclaw-main-config/ops/ops-watch.env.example`
- `openclaw-main-config/ops/watch_targets.yaml`
- `openclaw-main-config/scripts/health-check.sh`

作用：

- 为 `teslamate_cn` 增加部署目标
- 为 TeslaMate、API、Grafana 增加健康检查入口
- 把 `car.himark.me` 接入统一巡检

## 导出补丁

执行：

```sh
./scripts/export-integration-patches.sh
```

默认会在本仓生成两个本地补丁文件：

- `artifacts/integration-patches/aliyun-deploy-platform.teslamate-cn.patch`
- `artifacts/integration-patches/openclaw-main-config.teslamate-cn.patch`

说明：

- 这些补丁文件默认被 `.gitignore` 忽略，不会进入公开仓库
- 脚本按“TeslaMate 相关文件面”导出；如果这些文件本身还承载别的本地改动，补丁里也会一起出现
- 真正的最小必需变更以 `docs/integration-snippets.md` 为准
- 如果本地仓路径不同，可通过 `PLATFORM_REPO`、`OPS_REPO`、`OUTPUT_DIR` 覆盖

## 建议处理顺序

1. 先在服务仓完成生产 `.env`、DNS、证书和首启验收
2. 再导出平台补丁和监控补丁
3. 分别在 `aliyun-deploy-platform`、`openclaw-main-config` 审阅后再决定是否建分支提交
