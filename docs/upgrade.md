# 升级说明

## 升级前检查

1. 确认 `.env`、平台 `service.env`、Nginx Basic Auth 文件已备份。
2. 执行一次基线备份：
   - `scripts/backup.sh`
3. 检查 release note：
   - TeslaMate `v3.0.0` 之后是否有数据库迁移或环境变量变化
   - `teslamateapi` 是否引入新增必填变量
4. 检查 AMap Key 是否仍有效。

## 升级 TeslaMate 主栈

1. 更新：
   - `docker/teslamate/Dockerfile` 中的 `TESLAMATE_VERSION`
   - `docker/grafana-cn/Dockerfile` 的上游 tag
2. 如果上游文件结构变化，重新验证两份 patch 是否仍可应用。
3. 运行：
   - `sh test/validate.sh`
4. 推送到 `main` 触发发布，或本地执行：
   - `docker compose build teslamate grafana`
   - `docker compose up -d teslamate grafana`

## 升级 teslamateapi

1. 更新 `docker/teslamateapi/Dockerfile` 的基础镜像 tag。
2. 验证 `ENABLE_COMMANDS` 默认值仍为 `false`。
3. 运行：
   - `sh test/validate.sh`
4. 平台部署可使用 `api` target，仅重启 API。

## 升级后验证项

1. `https://car.himark.me/_health/teslamate` 返回 `200`
2. `https://car.himark.me/api/readyz` 返回 `200`
3. `https://car.himark.me/grafana/login` 可打开
4. TeslaMate 首页可正常加载地图
5. Grafana `02 行程轨迹` 和 `03 到访地点` 底图可正常加载
6. 最近一条 drive 或 charge 能写入中文地址

