# 风险清单

## 已控制的风险

- TeslaMate 主代码只做两处最小补丁，可回退到官方版本
- `/api/` 除了上游 `API_TOKEN` 之外，还由 Nginx 强制 Bearer token 校验
- TeslaMate 主站经 Basic Auth 二次保护
- Grafana 强制登录
- 只有反向代理暴露公网端口

## 残留风险

- AMap Key 属于外部依赖，失效后中国地址增强会降级到 Nominatim 或无法增强
- 中国地图底图没有默认绑定单一国内厂商，最终可用性仍取决于你配置的上游 tile URL
- TeslaMate 升级如果改动前端 `hooks.js` 或 geocoder 模块，现有 patch 可能需要重打
- `teslamateapi` 的上游 `API_TOKEN` 不保护全部只读接口，因此必须依赖反向代理层的额外鉴权
- 命令接口一旦开启，将具备远程车辆控制风险；当前默认关闭

## 建议

- 上线前先在目标机执行一次完整备份与恢复演练
- 将 `.env`、平台 `service.env`、Nginx htpasswd 和证书文件纳入受控备份
- AMap Key 建议单独申请、单独限流，不与其他业务共用
