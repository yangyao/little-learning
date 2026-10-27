# 千臻乐园 · Android TV 3.0

适配遥控器的原生 Android TV 客户端，包含与 iOS 共用题库的13款学习游戏、两个独立孩子档案、动物头像、积分账本和每人30分钟／休息2小时限制。

学习、通关、得分和本机存档离线可用。配置家庭 NAS 后，启动／回前台、得分后及前台每30秒自动同步积分和兑换；新兑换必须由服务器确认。未配置 NAS 时仍可学习和累积积分，兑换入口会提示先配置。

## 构建

需要 JDK 17、Android SDK 34、build-tools 34.0.0。Gradle wrapper 8.9、Android Gradle Plugin 8.5.2；首次构建需下载依赖。原生题库 content.json 和生成后的设计 token 已提交，直接构建不需要 Swift。

```sh
cd android-tv
# 配置 JAVA_HOME、ANDROID_HOME，或在 Android Studio 中打开此目录
./gradlew assembleDebug assembleRelease lintDebug lintRelease
zsh scripts/check.sh
```

APK 输出在 app/build/outputs/apk/，不提交到仓库。Release 目前沿用本机 debug 签名，适合个人开发；正式分发请使用自己的私密签名配置，勿提交密钥。更新已有设备必须保留原包名和签名并覆盖安装，不能通过卸载来解决存档迁移问题。

```sh
adb connect YOUR_TV_IP:5555
adb -s YOUR_TV_IP:5555 install -r app/build/outputs/apk/release/app-release.apk
```

安装后在电视空闲时从应用列表打开。不要为安装或测试关闭 ADB 调试或撤销已有授权。

## 配置 NAS

```sh
cp app/src/main/assets/nas-config.example.json app/src/main/assets/nas-config.json
```

填写 NAS URL 和与服务端一致、至少32字符的随机 token。真实 nas-config.json 已被 Git 忽略。使用 HTTP 时，另将 app/src/main/res/xml/network_security_config.xml 的示例域名／IP改成实际 NAS 地址；明文访问仅允许配置的 NAS 地址，HTTPS 使用系统证书验证。重新构建后生效。客户端不跟随 HTTP 重定向。

服务端与历史导入说明见 [server/README.md](../server/README.md)。初次让已有设备接入前，先备份并导入它的历史兑换。客户端不会用服务端快照静默覆盖未导入的本机支出。

- 奖励按每个孩子的稳定挑战 ID 去重；复习、重摆、切换题组不重复计分。
- 兑换先持久化 UUID，再提交 NAS；超时或重启后恢复同一请求，不重复扣分。普通兑换可撤销一次。
- 5分换5分钟只发给请求设备一次；远端购买只同步支出，不能复制游玩分钟。
- 棋盘、题组、网页场景、剩余游玩分钟和使用限额留在各设备。学习、游玩、首页和积分页共用总使用额度；选人页、后台和待机不计时。
- 家庭档案使用 AtomicFile；保存失败回滚、损坏文件保留，不自动清空数据。

## 可选网页游戏

**公开仓库不包含泡泡龙、合成大西瓜源码、素材或 APK。** 这些私有版本上游资源的再分发授权未完整确认。没有本地游戏包时「游玩」列表为空，13款原生游戏可独立运行。

只接入自己有权使用的本地 HTML5 游戏。接口及目录说明见 [可选游戏桥接说明](app/src/main/assets/webgames/README.md) 和 [第三方资源说明](THIRD_PARTY.md)。WebView 禁止外部网络、共享账号存储和不受控导航；游戏准备完成前不计游玩时间，暂停后不得继续物理、声音或输入。

## 题库与验证

```sh
# 仅修改 iOS Core 题库后才需重新导出，需要 macOS Swift 和 zsh
scripts/export-content.sh
python3 scripts/design-tokens.py
scripts/check.sh
```

scripts/check.sh 运行477项 Java 规则检查。Debug 构建另有独立的规则、存档、原生界面和 NAS 账本验证组件；Release 不包含这些组件。测试数据、截屏、私人设备记录、APK 和 NAS 配置均忽略提交。网页游戏的 Debug 检查需自行准备获授权的游戏包，不能在缺少可选包时当作原生学习构建失败。
