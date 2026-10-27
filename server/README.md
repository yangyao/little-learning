# NAS 积分同步服务

Go 单一二进制和 SQLite，无需容器、Go 运行环境或外部数据库。供家庭局域网中的客户端同步两份积分账本。

客户端应保留本地存档：离线学习、通关和得分不依赖 NAS；新兑换由服务器联网确认。同步对象是不可变积分事件，不覆盖进行中的棋盘、题组、剩余游玩时间或设备的使用限额。

## 构建与验证

构建需要 Go 1.21 或更新版本（SQLite 的 Linux x64 依赖使用标准库 slices）。NAS 运行编译后的单一二进制，不需要安装 Go。

```sh
go test -race ./...
go build -o learning-server ./cmd/learning-server
python3 scripts/check_http.py ./learning-server

# QNAP ARM64 等 Linux aarch64 设备
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags='-s -w' -o learning-server-linux-arm64 ./cmd/learning-server
```

HTTP 检查默认生成合成数据，验证鉴权、并发扣分、幂等重试、重复撤销、备份和进程重启。不会连接家庭的实际服务或读取家庭存档。

## 配置与运行

复制 `config.example.json` 为 `config.json`，替换随机令牌。示例监听回环地址；供家中设备使用时，把 listen 改为 NAS 的固定局域网地址。令牌须至少32字符，且由客户端使用同一个值。

```sh
cp config.example.json config.json
chmod 600 config.json
# 编辑 config.json，替换随机令牌和监听地址
./learning-server -config config.json
```

也可将二进制命名为 `learning-server`，连同 config.json、start.sh 和 stop.sh 放在同一目录，执行 `./start.sh`。脚本会切换到自身目录、阻止重复启动，并让服务在 SSH 退出后继续运行。此脚本针对 Linux / QNAP；本机 macOS 开发可直接运行二进制。

所有原始存档、导入文件、令牌、数据库和安装成品均不应提交。仓库仅含代码、示例配置和静态奖励规则目录。

## 客户端接入

仓库已提供 [iOS／macOS 客户端](../ios/LittleLearning/README.md) 和 [Android TV 客户端](../android-tv/README.md)。iOS 的私密设置位于 Sources/Configuration/NASConfig.json，Android 位于 app/src/main/assets/nas-config.json；两端都有不带令牌的 example 文件，真实设置被 Git 忽略。默认没有配置时可以离线学习，但不能兑换。初次接入旧设备前，先完成历史备份与导入。

## 协议

`GET /healthz` 仅返回 `{"status":"ok"}`。`POST /v1/sync` 要求 `Authorization: Bearer <token>`，正文示意：

```json
{
  "device": "persistent-device-id",
  "children": {"qianyi": [], "zhenyi": []},
  "operation": {
    "id": "e4448971-9c71-4aa0-8b0f-913c41396b2b",
    "child": "qianyi",
    "kind": "redemption",
    "title": "绘本",
    "points": 5,
    "reference": ""
  }
}
```

`operation` 可省略。响应为 children 中的完整规范账本、balances，以及可选的 applied 或 error。200 表示成功，409 表示冲突或拒绝，并附当前服务端快照。客户端不能在历史兑换缺失时直接覆盖本机账本。

事件包含 UUID id、Unix 毫秒 date、kind、reference、title、amount。award 按每个孩子的挑战 reference 去重，兑换按 UUID 去重，refund 按原兑换 reference 去重。已知挑战与分值由 internal/syncdb/catalog.json 验证。

新兑换必须通过 operation：redemption 扣指定积分；refund 撤销一笔普通兑换；playTime 固定扣5分。SQLite 事务检查余额，避免两台设备同时透支。客户端先持久化操作 UUID，在超时或重启后重试同一笔；不能离线创建新支出并直接上传。

游玩时间只应发给请求设备一次。客户端须把发放记录和服务端确认原子保存；其他设备仅采用支出，不重复导入游玩分钟。

服务使用局域网 HTTP，不用于直接暴露到公网。客户端应限制 NAS 目标地址且不跟随重定向。

## 历史迁移与备份

先导出并备份每台设备的完整原始存档，再用 scripts/prepare_history.py 规范化。该工具适配目前 iOS 与 Android TV 存档格式，合并奖项及交易事件，不相加设备余额：

```sh
python3 scripts/prepare_history.py /private/path/to/backups artifacts/history.json
./learning-server -config config.json -import artifacts/history.json
./learning-server -config config.json -backup data/manual-backup.db
```

备份目录需要 iphone-* 子目录中的 collection-v1.family-v1.json，以及 tv/family-tv-v1.json。导入单个事务完成，负余额或冲突整次回滚；重复导入不会重复记分。新增旧设备时，先核对并导入它的历史兑换，再让客户端连接服务。

数据库使用 WAL，服务每24小时生成一次一致备份，保留最近14份。手动备份也可在服务运行时执行。不要只复制活跃数据库的 .db 而遗漏 WAL；优先使用 -backup 生成的文件。

## QNAP 开机启动

[deploy/qpkg](deploy/qpkg/README.md) 包含供 QNAP 官方 QDK 打包的 App Center 服务包装。注册启用后，由 QTS 开机运行；包装只管理现有部署目录，不包含令牌或家庭数据。安装需要管理员权限，可经 App Center 或直接在 NAS 本机执行安装包。
