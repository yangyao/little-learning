# 千臻乐园 · Little Learning

给家里小朋友用的学习小游戏，支持 iPhone、Mac 预览和 Android TV。手机与电视通过家里的 NAS 同步积分。

没有账号、广告或订阅。学习游戏离线可用；NAS 连不上时仍能玩、通关和积累积分，兑换需要联网确认。

## 游戏和使用方式

共13款学习游戏、42个题组、902个可玩挑战：

| 游戏 | 内容 |
| --- | --- |
| 荷叶跳跳 | 加减法与数轴 |
| 断尺侦探 | 对齐测量、补刻度与无零断尺 |
| 森林野餐 | 平均分和有余数 |
| 拼音火车 | 声调与拼音组合 |
| 拼字工坊 | 汉字部件与偏旁 |
| 成语拼装 | 读线索、拼成语 |
| 字母面包房 | 拼写英语单词 |
| 滴答时钟 | 认识时间与经过时间 |
| 巧移火柴 | 移动一根火柴使算式成立 |
| 果篮分拣 | 分类、规划与撤销 |
| 七巧板拼图 | 移动、旋转与翻面 |
| 小鸭送信 | 排指令、规划路线 |
| 规律串珠 | 形状和颜色规律 |

打开后选择千一或臻一，两人的积分和进度分开。题组可以自由切换，同一挑战每个孩子只得分一次，复习不重复加分。电视版用方向键、确定和返回键操作，动物头像为原生绘制。

每个孩子在每台设备上有30分钟使用额度，用完休息2小时；选人页、后台和锁屏不计时。学习和游玩共用额度，购买游玩分钟不会增加总使用额度。

## 手机、电视和 NAS 同步

- 两端自动同步积分、兑换和撤销，不需要手动扫码。
- 离线获得的积分先存本机，恢复连接后再同步。
- 兑换由 NAS 确认，断线重试不会重复扣分，两台设备同时兑换也不会透支。
- 5积分兑换5分钟，只发到购买的设备一次，不会在其他设备复制时间。
- 进行中的棋盘、题组、剩余游玩分钟及使用额度各机独立。

服务端使用 Go＋SQLite，编译成一个二进制即可放在 NAS 上运行，支持历史导入和数据库备份。QNAP 可安装随附的 QPKG 包装，由 App Center 管理启用、停用和开机启动。

首次接入已有设备前，先备份并导入历史记录。NAS 保存的是积分账本，不能代替完整游戏存档的备份。

## 代码位置

| 目录 | 内容 |
| --- | --- |
| [ios/LittleLearning](ios/LittleLearning/README.md) | iPhone 客户端和 Mac 预览 |
| [android-tv](android-tv/README.md) | Android TV 客户端、遥控器界面 |
| [server](server/README.md) | NAS 同步服务、历史导入与备份工具 |
| [server/deploy/qpkg](server/deploy/qpkg/README.md) | QNAP 自启动包装 |
| [design](DESIGN.md) | 界面与交互说明 |

## 构建与配置

### iPhone / Mac

需要 macOS、Xcode 和 iOS 17 或更新系统。打开 `ios/LittleLearning/LittleLearning.xcodeproj`，选择自己的 Team 和 Bundle Identifier，再运行到设备或模拟器。

NAS 设置：复制 `Sources/Configuration/NASConfig.example.json` 为同目录 `NASConfig.json`，填写 NAS URL 与共享 token 后重新构建。Mac 预览可在该项目目录运行 `zsh scripts/package_mac_preview.sh`。

### Android TV

需要 JDK 17、Android SDK 34，在 `android-tv` 目录运行：

```sh
./gradlew assembleRelease
```

复制 `app/src/main/assets/nas-config.example.json` 为同目录 `nas-config.json`，填写相同的 NAS URL 和 token；使用 HTTP 时，将 `network_security_config.xml` 中的示例 NAS 地址改为实际地址。安装与遥控器说明见 [电视版 README](android-tv/README.md)。

### NAS

需要 Go 1.21 或更新版本进行编译；NAS 运行二进制时不需要 Go。在 `server` 目录运行：

```sh
go build -o learning-server ./cmd/learning-server
cp config.example.json config.json
# 编辑 config.json：设置监听地址并替换随机 token
./learning-server -config config.json
```

客户端与服务端使用同一个至少32字符的随机 token。Linux ARM64 构建、后台启动、QNAP 安装、迁移和备份命令见 [服务端 README](server/README.md)。

未配置 NAS 时，客户端仍可离线学习和积累积分，但不能兑换。真实配置、签名密钥、存档、数据库和安装包都不提交到仓库。

## 可选游玩资源

家庭安装版使用的泡泡龙、合成大西瓜源码和素材未随仓库分发；公开代码只保留本地游戏桥接接口。缺少游戏包时，游玩列表为空，13款学习游戏仍可独立运行。接入自己有权使用的资源，见 [iOS 说明](ios/LittleLearning/Sources/WebGames/README.md) 和 [电视说明](android-tv/THIRD_PARTY.md)。

## 本地检查

需要检查改动时，在对应目录运行即可：

```sh
# ios/LittleLearning
zsh scripts/check_core.sh
zsh scripts/check_store.sh

# android-tv
sh scripts/check.sh

# server
go test -race ./...
```

## License

[MIT](LICENSE) · Copyright © 2026 yangyao。仅覆盖仓库提供的原创代码与资源；第三方组件按各自许可证使用，未分发的游戏资源不在此授权范围内。
