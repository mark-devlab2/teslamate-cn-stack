# 常见故障排查

## 1. `car.himark.me` 打不开

- 检查 DNS `A` 记录是否已生效
- 检查 80/443 是否放行
- 检查 `nginx` 容器：
  - `docker compose logs nginx`

## 2. ACME 签发失败

- 确认 `TLS_MODE=acme`
- 确认 `ACME_EMAIL` 不为空
- 确认 `/.well-known/acme-challenge/` 可从公网访问
- 若中国网络环境导致签发链路不稳定，切换：
  - `TLS_MODE=manual`

## 3. TeslaMate 登录 Tesla 失败

- 检查 `TESLA_AUTH_HOST`
- 中国大陆账号应使用：
  - `TESLA_API_HOST=https://owner-api.vn.cloud.tesla.cn`
  - `TESLA_WSS_HOST=wss://streaming.vn.cloud.tesla.cn`

## 4. 地图底图不显示

- 检查 `tile-proxy`：
  - `docker compose logs tile-proxy`
- 检查 `.env`：
  - `TILE_URL_TEMPLATE`
  - `TILE_FALLBACK_URL_TEMPLATE`
- 用浏览器直接访问：
  - `https://car.himark.me/tiles/1/1/1.png`

## 5. 地址仍为空或不准确

- 检查 `AMAP_WEB_SERVICE_KEY`
- 检查 `cn-geocoder`：
  - `docker compose logs cn-geocoder`
- 执行：
  - `scripts/fix-addresses.sh`
- 如果是历史某一时间段数据错误，执行窗口修复：
  - `scripts/fix-addresses.sh --window-start 2026-03-01T00:00:00Z --window-end 2026-03-07T23:59:59Z`

## 6. `/api/` 返回 401

- 确认请求头：
  - `Authorization: Bearer <API_TOKEN>`
- 检查 `.env` 中 `API_TOKEN`
- 检查 Nginx 模板渲染后的配置：
  - `docker compose exec -T nginx nginx -T`

## 7. Grafana 子路径异常

- 检查：
  - `GF_SERVER_ROOT_URL=https://car.himark.me/grafana`
  - `GF_SERVER_SERVE_FROM_SUB_PATH=true`
- 清理浏览器缓存后重试

