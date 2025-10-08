# Bililive-Recorder for MacOS/Linux

上游项目 [BililiveRecorder](https://github.com/Bililive/BililiveRecorder) 地址

>录播姬命令行版与桌面版的功能完全一致，两个版本共用同一套核心代码，只在与用户交互的外壳代码上不同。
录播姬命令行版与桌面版的配置文件也是通用的，可以在桌面版配置好相关参数后用命令行版加载运行。

# Bililive-Recorder for macOS / Linux

上游项目: https://github.com/Bililive/BililiveRecorder

录播姬的命令行版本（CLI）与桌面版共享同一套核心代码。此仓库提供了包装脚本，用于在 macOS / Linux 上安装、配置、启动与管理 CLI 服务。

快速上手
1. 克隆仓库并运行安装脚本（首次运行会交互生成 `config/config.ini`）：

```bash
git clone https://github.com/gxusb/Bililive-Recorder.git && cd Bililive-Recorder
bash install.sh
```

2. 启动服务（在 `config/config.ini` 已生成且配置正确的前提下）：

```bash
./start.sh
# 或直接调用脚本内部的 run_app()
```

3. 停止服务：

```bash
./stop.sh
```

4. 交互编辑配置：

```bash
./set_config.sh
# 该脚本会调用 Application/BililiveRecorder.Cli configure
```

主要目录与文件
- `Application/`：已解压的发行包（包含 `BililiveRecorder.Cli` 二进制与 .dll）。不要修改这些二进制文件。
- `config/config.ini`：所有脚本读取的环境变量（`BR_INSTALL_PATH`、`BR_USERNAME`、`BR_PASSWORD`、`BR_USE_PROXY` 等）。`install.sh` 在首次运行会生成它。
- `Downloads/`：录制输出目录，`config.json`（若不存在，`install.sh` 会生成默认的 `Downloads/config.json`）。
- `Logs/`：脚本会将旧的 `Application.log` 归档到这里（`YYYY-MM-DD-Application.log`）。

常用命令示例
- 直接运行（示例 macOS 路径）：

```bash
./Application/BililiveRecorder.Cli run "/Users/${USER}/Desktop/BilibiliLive"
```

- 后台运行并写日志：

```bash
nohup ./Application/BililiveRecorder.Cli run "/path/to/Downloads" >>/path/to/Application.log 2>&1 &
```

- 使用脚本的后台启动（`start.sh` 已实现）：

```bash
./start.sh
```

创建 systemd 服务（示例）
在 Linux 上，如果你想把服务安装为 systemd 单元，可以使用类似下面的 unit：

```service
[Unit]
Description=BililiveRecorder
After=network.target
[Service]
ExecStart=/opt/Bililive-Recorder/Application/BililiveRecorder.Cli run --bind "http://*:2233" --http-basic-user "用户名" --http-basic-pass "密码" "/opt/Bililive-Recorder/Downloads"
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
[Install]
WantedBy=multi-user.target
```

提示：仓库内的 `servce.sh` 提供了 `Create_service` / `Delete_service` 的辅助函数，会生成 `/etc/systemd/system/brec.service` 并调用 `systemctl daemon-reload`。

实现细节与注意事项
- 所有 shell 脚本遵循 `set -euo pipefail` 风格，包含辅助函数 `info_log()`, `safe_stop()`, `log_archive()`。新增脚本请保持相同风格。
- `install.sh` 会检测操作系统与架构（例如 `osx-x64`, `osx-arm64`, `linux-x64`, `linux-arm64`），并下载匹配的发行包：

```bash
APP_VERSION=$(curl -sL "https://api.github.com/repos/Bililive/BililiveRecorder/releases/latest" | grep '"tag_name"' | head -n1 | cut -d'"' -f4)
APP_URL="https://github.com/Bililive/BililiveRecorder/releases/download/${APP_VERSION}/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}.zip"
```

- 日志归档：`start.sh` 在启动前会把现有的 `Application.log` 追加到 `Logs/YYYY-MM-DD-Application.log` 并删除原文件（以避免无限增大）。不要删除此归档逻辑。
- `config/config.ini` 是脚本之间的契约：不要随意修改加载路径或变量名（除非同时更新所有引用脚本并在 PR 中注明）。
- 不要修改 `Application/` 下的二进制或已编译库（`.dll`, `.dylib`, `BililiveRecorder.Cli` 等）。所有功能性修改应通过：
	- 调整 `config/config.ini` / `Downloads/config.json`，或
	- 修改并测试脚本（保持脚本风格与错误处理）。

常见问题与故障排查（快速清单）
- 启动失败：检查 `${BR_INSTALL_PATH}/Application.log` 的最后 20 行（`tail -n 20 ${BR_INSTALL_PATH}/Application.log`）。
- 找不到 `config/config.ini`：如果脚本提示找不到配置，请先运行 `bash install.sh`（首次运行会交互生成该文件）。
- 权限问题：确保 `Application/BililiveRecorder.Cli` 可执行：

```bash
chmod +x Application/BililiveRecorder.Cli
```

- systemd 未生效：修改 `/etc/systemd/system/brec.service` 后运行：

```bash
systemctl daemon-reload
systemctl restart brec.service
systemctl status brec.service
```

其他参考
- 使用教程（社区）： https://lxnchan.cn/bilibili-Rec.html

---
原 README 中的交互示例和帮助文本已被保留并合并到本 README 的相应部分。如果需要我可以将原始交互片段（例如房间添加流程）恢复为附录或将 README 拆分为 `README.md` + `USAGE.md`。
`systemctl enable brec`
