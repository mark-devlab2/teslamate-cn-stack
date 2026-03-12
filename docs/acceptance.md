# 验收清单

- [ ] `https://car.himark.me/` 打开时先弹出 Basic Auth
- [ ] Basic Auth 后可进入 TeslaMate
- [ ] `https://car.himark.me/grafana/` 打开 Grafana 登录页
- [ ] Grafana 不允许匿名访问
- [ ] `https://car.himark.me/api/ping` 无 token 返回 `401`
- [ ] `https://car.himark.me/api/ping` 携带 Bearer token 返回 `200`
- [ ] `https://car.himark.me/_health/teslamate` 返回 `200`
- [ ] `https://car.himark.me/api/readyz` 返回 `200`
- [ ] Grafana `02 行程轨迹` 地图面板可显示底图
- [ ] Grafana `03 到访地点` 地图面板可显示底图
- [ ] 新产生的充电或行驶记录写入中文地址
- [ ] `scripts/backup.sh` 能输出完整备份目录
- [ ] `scripts/restore.sh` 可在测试环境恢复
- [ ] `scripts/fix-addresses.sh` 运行后空地址数量下降
- [ ] `teslamateapi` commands 默认关闭

