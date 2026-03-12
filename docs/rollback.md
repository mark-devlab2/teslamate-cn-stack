# 回滚说明

## 快速回滚

适用场景：

- 升级后容器启动失败
- API 或前端出现明显回归
- 没有不可逆数据库迁移

步骤：

1. 在阿里云平台仓执行：
   - `scripts/rollback-service.sh --service-id teslamate-cn --target full`
2. 验证：
   - `https://car.himark.me/_health/teslamate`
   - `https://car.himark.me/api/readyz`
   - `https://car.himark.me/grafana/login`

## 数据级回滚

适用场景：

- 升级包含数据库迁移且旧版本不兼容
- 地址修复批处理误操作

步骤：

1. 停止栈：
   - `docker compose down`
2. 选择可用备份目录。
3. 执行：
   - `scripts/restore.sh <backup_dir>`
4. 如需同时回滚仓库配置：
   - `RESTORE_CONFIG=1 scripts/restore.sh <backup_dir>`

## 回滚风险

- 镜像回滚不自动回滚数据库
- 地址修复脚本如果在大窗口范围内运行，回滚应优先依赖数据库备份
- 手工证书模式下，回滚不会替换 TLS 证书文件

