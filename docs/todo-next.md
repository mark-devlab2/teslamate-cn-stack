# 上午待办清单

## 必填配置

- [ ] 填写 Tesla 账号接入信息并完成首次网页登录
- [ ] 配置 `car.himark.me` DNS `A` 记录到阿里云服务器
- [ ] 选择证书模式：
  - [ ] `TLS_MODE=acme`
  - [ ] 或 `TLS_MODE=manual`
- [ ] 填写 `AMAP_WEB_SERVICE_KEY`
- [ ] 设置 `API_TOKEN`
- [ ] 设置 TeslaMate Basic Auth 用户名和密码
- [ ] 设置 Grafana 管理员密码

## 首次上线动作

- [ ] 运行 `scripts/init.sh prepare`
- [ ] 启动栈并执行 `scripts/init.sh bootstrap`
- [ ] 打开 TeslaMate 完成 Tesla 登录授权
- [ ] 验证 `https://car.himark.me/api/ping` 的 Bearer token 行为
- [ ] 验证 `https://car.himark.me/grafana/` 登录

## 中国环境验证

- [ ] 检查 TeslaMate 主站底图是否正常加载
- [ ] 检查 Grafana `02 行程轨迹` 和 `03 到访地点` 地图是否正常加载
- [ ] 抽样检查最近 drive / charge 是否写入中文地址
- [ ] 如历史空地址明显，执行 `scripts/fix-addresses.sh`

## 运维基线

- [ ] 执行一次 `scripts/backup.sh`
- [ ] 记录本次上线镜像 tag 和备份目录
- [ ] 将生产 `.env`、平台 `service.env`、证书文件、htpasswd 纳入受控备份
