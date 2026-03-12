# 部署说明

## 1. 架构说明

- 访问入口：
  - `https://car.himark.me/` -> TeslaMate
  - `https://car.himark.me/api/` -> `tobiasehlert/teslamateapi` 兼容 API
  - `https://car.himark.me/grafana/` -> Grafana
- 仅 `nginx` 暴露公网 `80/443`
- 所有业务容器位于同一 `internal` 网络
- 中国优化拆分：
  - TeslaMate 主站地图：`tile-proxy`
  - TeslaMate 地址解析：`cn-geocoder`
  - Grafana 地图：统一走 `/tiles/`

## 2. 目录结构

```text
teslamate-cn-stack/
├── .deploy/
├── .github/workflows/
├── docker/
│   ├── acme/
│   ├── cn-geocoder/
│   ├── grafana-cn/
│   ├── mosquitto/
│   ├── nginx/
│   ├── postgres/
│   ├── teslamate/
│   ├── teslamateapi/
│   └── tile-proxy/
├── docs/
├── scripts/
├── test/
├── docker-compose.yml
└── .env.example
```

## 3. 需要你自己填写的值

- `.env`：
  - `POSTGRES_PASSWORD`
  - `ENCRYPTION_KEY`
  - `SECRET_KEY_BASE`
  - `SIGNING_SALT`
  - `MOSQUITTO_PASSWORD`
  - `GRAFANA_ADMIN_PASSWORD`
  - `BASIC_AUTH_USERNAME`
  - `BASIC_AUTH_PASSWORD`
  - `API_TOKEN`
  - `ACME_EMAIL`
  - `AMAP_WEB_SERVICE_KEY`
- DNS：
  - `car.himark.me` -> 阿里云服务器公网 `A`
  - 只有确认 IPv6 可用时再加 `AAAA`
- 证书：
  - `TLS_MODE=acme` 时确保 80/443 对外可达
  - `TLS_MODE=manual` 时准备 `runtime/certs/fullchain.pem` 与 `runtime/certs/privkey.pem`
- Tesla 登录：
  - 首次打开 `https://car.himark.me/` 后，在 TeslaMate 登录页完成 Tesla 账号授权

## 4. 初始部署步骤

1. 新建仓库并推送本目录内容。
2. 复制 `.env.example` 为 `.env` 并填写真实值。
3. 运行 `scripts/init.sh prepare` 生成运行目录与 Basic Auth 文件。
4. 本地验证配置：
   - `sh test/validate.sh`
5. 首次本地或目标机启动：
   - `docker compose --env-file .env up -d`
6. 首次完成后运行：
   - `scripts/init.sh bootstrap`
7. 打开 `https://car.himark.me/`，完成 Tesla 登录。

## 5. 平台接入部署步骤

1. 将本仓推送到 GitHub。
2. 在服务仓配置 GitHub Secrets：
   - `ALIYUN_HOST`
   - `ALIYUN_SSH_USER`
   - `ALIYUN_SSH_PRIVATE_KEY`
   - `ACR_USERNAME`
   - `ACR_PASSWORD`
3. 在平台仓 `runtime/teslamate-cn/service.env` 填入生产 `.env` 等效值。
4. 合并平台仓与监控仓的 TeslaMate 变更。
5. `push main` 触发：
   - GitHub Actions 构建镜像
   - 推送到 ACR
   - 服务器 `pull/restart/health check`

## 6. 初始化步骤

1. `scripts/init.sh prepare`
   - 目的：创建运行目录和 Basic Auth 文件
   - 风险：如果 `.env` 仍是样例值，会生成错误凭据
   - 验证：`ls runtime/nginx/htpasswd`
2. `docker compose up -d`
   - 目的：拉起全栈
   - 风险：证书、DNS、Tesla API、AMap Key 任一缺失都可能导致部分能力降级
   - 验证：`docker compose ps`
3. `scripts/init.sh bootstrap`
   - 目的：写入中文与默认单位配置
   - 风险：直接更新 TeslaMate `settings` 表，必须在数据库可达时执行
   - 验证：打开 TeslaMate 设置页确认语言/单位

## 7. HTTPS 与 DNS

- 默认自动签发：
  - `TLS_MODE=acme`
  - `acme` sidecar 使用 HTTP-01
  - Nginx 通过 `/.well-known/acme-challenge/` 提供验证文件
- 替代方案：
  - `TLS_MODE=manual`
  - 手工放置 `runtime/certs/fullchain.pem`
  - 手工放置 `runtime/certs/privkey.pem`
- 中国网络环境建议：
  - 如果 Let’s Encrypt 签发链路不稳定，直接切 `manual`

## 8. 健康检查

- 容器内健康检查：
  - TeslaMate: `http://127.0.0.1:4000/health_check`
  - TeslaMateApi: `http://127.0.0.1:8080/api/readyz`
  - cn-geocoder: `http://127.0.0.1:8080/healthz`
  - tile-proxy: `http://127.0.0.1:8080/healthz`
  - postgres: `pg_isready`
- 外部健康检查：
  - `https://car.himark.me/_health/teslamate`
  - `https://car.himark.me/api/readyz`
  - `https://car.himark.me/grafana/login`

## 9. teslamateapi 配置方法

- 上游仓库：
  - `https://github.com/tobiasehlert/teslamateapi`
- 上游镜像：
  - `tobiasehlert/teslamateapi:1.24.2`
- 当前实现：
  - `docker/teslamateapi/Dockerfile` 基于上游 `1.24.2` 薄包装，仅补充健康检查工具
- 关键环境变量：
  - `ENCRYPTION_KEY`
  - `DATABASE_HOST/DATABASE_NAME/DATABASE_USER/DATABASE_PASS`
  - `MQTT_HOST/MQTT_USERNAME/MQTT_PASSWORD`
  - `API_TOKEN`
  - `ENABLE_COMMANDS=false`
- 验证方法：
  - 无 token：
    - `curl -I https://car.himark.me/api/ping` -> `401`
  - 有 token：
    - `curl -H "Authorization: Bearer <API_TOKEN>" https://car.himark.me/api/ping`
  - readiness：
    - `curl https://car.himark.me/api/readyz`

## 10. 中国环境优化说明

- 作用于 TeslaMate 主站：
  - 通过两份最小 patch 将底图 URL 与 geocoder base URL 改成运行时可配置
  - 底图统一指向 `/tiles/`，由 `tile-proxy` 做缓存与上游切换
  - 地址解析统一指向 `cn-geocoder`，默认用高德逆地理编码并缓存 synthetic id
- 作用于 Grafana：
  - 所有 geomap panel 的 basemap 改为 `/tiles/{z}/{x}/{y}.png`
  - 首页改为中文总览页，常用 dashboard 优先
- 与 `teslamateapi` 无关：
  - 地图底图和地址解析优化不影响 API 数据结构
  - API 只消费 TeslaMate 的 PostgreSQL 与 MQTT 数据

## 11. 中文化与体验优化说明

- 可以完全优化的部分：
  - TeslaMate 默认语言设为 `zh`
  - 默认单位：`km / C / bar / rated`
  - Grafana 首页与常用 dashboard 标题排序
  - 时区默认 `Asia/Shanghai`
- 只能部分优化的部分：
  - TeslaMate 官方前端不是完整中文产品，少量细节文案仍跟随上游翻译覆盖率
  - 高德逆地理编码主要输出中文地址，跨语言切换能力有限
- 暂时无法彻底解决的部分：
  - 中国网络下底图可用性仍依赖你配置的 tile upstream
  - 若上游 TeslaMate 未来重构地图或 geocoder 模块，需要重打最小补丁

## 12. 安全配置说明

- 强制 HTTPS：80 仅用于 ACME challenge 与跳转
- TeslaMate 主站：Nginx Basic Auth 保护
- Grafana：必须登录，禁止匿名访问
- `/api/`：
  - Nginx Bearer token 校验
  - 限流
  - 只读接口也必须经过反向代理鉴权
- `teslamateapi`：
  - `API_TOKEN` 必填
  - `ENABLE_COMMANDS=false` 默认关闭
- 内部服务：
  - PostgreSQL / Mosquitto / TeslaMate / Grafana / TeslaMateApi 都不直接暴露公网端口
