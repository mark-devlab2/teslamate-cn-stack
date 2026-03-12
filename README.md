# TeslaMate China Stack

TeslaMate 生产方案 for `car.himark.me`.

目标：

- `https://car.himark.me/` 提供 TeslaMate 主站
- `https://car.himark.me/api/` 提供 `tobiasehlert/teslamateapi`
- `https://car.himark.me/grafana/` 提供 Grafana
- 中国网络环境下通过外围兼容层改善地图与地址解析
- 统一接入 `aliyun-deploy-platform`

主要文档：

- [docs/deploy.md](./docs/deploy.md)
- [docs/upgrade.md](./docs/upgrade.md)
- [docs/rollback.md](./docs/rollback.md)
- [docs/troubleshooting.md](./docs/troubleshooting.md)

常用脚本：

- `scripts/generate-env.sh`：从 `.env.example` 生成带随机密钥的 `.env`
- `scripts/check-env.sh`：检查生产 `.env` 是否仍含占位值
- `scripts/render-platform-env.sh`：把服务仓 `.env` 渲染到平台仓 `runtime/teslamate-cn/service.env`
