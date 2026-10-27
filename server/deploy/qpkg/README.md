# QNAP App Center 启动管理包装

源文件：qpkg.cfg、package_routines、shared/LittleLearningSync.sh。使用 QNAP 官方 [QDK](https://github.com/qnap-dev/QDK) 构建，默认不带 QNAP 数字签名。

包装只管理已经部署的服务，不含 Go 二进制、令牌、数据库或真实存档。默认路径与运行用户是本家庭的部署约定：构建前请检查脚本中的 SERVICE 路径和 yangyao 用户名，以及 package_routines 的对应检查。

- QPKG 启动／停止／重启操作调用原目录 start.sh／stop.sh，并用 sudo -u 降为服务拥有者。
- 首次启动失败时，最多每5秒重试一次、持续5分钟，适应开机时存储或网络未就绪的情况；停用会取消重试。
- 卸载包装会停止服务，但不删除独立部署目录及其数据库。
- 不修改全局 autorun.sh、sudoers、防火墙，也不自动重启 NAS。

在配置好的 QDK 环境中，将本目录作为构建根目录执行：

```sh
qbuild
```

输出位于 build/LittleLearningSync_1.0.0.qpkg。安装前检查源码与文件校验码，并确认目标部署路径；用 App Center → Install Manually 选择文件，或将包复制到 NAS 后由管理员在 NAS 本机执行：

```sh
sudo /bin/sh /path/to/LittleLearningSync_1.0.0.qpkg
```

安装后检查 /etc/config/qpkg.conf 对应项的 Enable、Install_Path 和 Shell，以及 /etc/rcS.d/ 下的启动连结、服务进程用户和健康检查。不要仅凭安装命令结束判断成功。整机冷启动验证应留到计划内重启，避免打断 NAS 的其他用途。
