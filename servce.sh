#!/bin/bash
###
# @Author       : Gxusb
# @Date         : 2021-08-07 14:25:21
# @LastEditTime : 2025-10-09 03:07:53
# @FileEncoding : -*- UTF-8 -*-
# @Description  : 跨平台 BililiveRecorder 服务管理（Linux systemd + macOS launchd）
# @Copyright (c) 2025 by Gxusb, All Rights Reserved.
###

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ENV_PATH="$SCRIPT_DIR/config/config.ini"

# 加载配置
if [[ -f "$ENV_PATH" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_PATH"
else
  echo "❌ 配置文件未找到: $ENV_PATH，请先运行 install.sh"
  exit 1
fi

info_log() {
  echo -e "\\033[32;1m[$(date '+%Y-%m-%d %T INFO')]\\033[0m $*"
}

# === 系统检测 ===
OS=$(uname -s)
if [[ "$OS" == "Linux" ]]; then
  IS_LINUX=1
elif [[ "$OS" == "Darwin" ]]; then
  IS_MACOS=1
else
  echo "❌ 不支持的操作系统: $OS"
  exit 1
fi

# === 公共校验 ===
CLI_BIN="$BR_INSTALL_PATH/Application/BililiveRecorder.Cli"
if [[ ! -f "$CLI_BIN" ]]; then
  info_log "[ERROR] 可执行文件不存在: $CLI_BIN"
  exit 1
fi

# === Linux systemd 服务 ===
if [[ -n "${IS_LINUX:-}" ]]; then
  if [[ $EUID -ne 0 ]]; then
    echo "⚠️  在 Linux 上管理 systemd 服务需要 root 权限"
    echo "请使用: sudo $0"
    exit 1
  fi

  SERVICE_FILE="/etc/systemd/system/brec.service"

  create_linux_service() {
    cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=BililiveRecorder Live Stream Recorder
After=network.target

[Service]
Type=simple
User=$(logname 2>/dev/null || echo "$SUDO_USER")
WorkingDirectory=$BR_INSTALL_PATH
ExecStart=$CLI_BIN run --bind http://*:2233 --http-basic-user "$BR_USERNAME" --http-basic-pass "$BR_PASSWORD" "$BR_INSTALL_PATH/Downloads"
Restart=on-failure
RestartSec=5
StandardOutput=append:$BR_INSTALL_PATH/Application.log
StandardError=append:$BR_INSTALL_PATH/Application.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable brec.service
    systemctl start brec.service
    info_log "✅ systemd 服务已创建并启动"
    info_log "查看状态: sudo systemctl status brec"
  }

  delete_linux_service() {
    if [[ -f "$SERVICE_FILE" ]]; then
      systemctl stop brec.service 2>/dev/null || true
      systemctl disable brec.service 2>/dev/null || true
      rm -f "$SERVICE_FILE"
      systemctl daemon-reload
      info_log "✅ systemd 服务已删除"
    else
      info_log "⚠️ 服务文件不存在"
    fi
  }
fi

# === macOS launchd 服务 ===
if [[ -n "${IS_MACOS:-}" ]]; then
  LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.gxusb.bililiverecorder.plist"
  mkdir -p "$HOME/Library/LaunchAgents"

  create_macos_service() {
    cat >"$LAUNCHD_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.gxusb.bililiverecorder</string>
    <key>ProgramArguments</key>
    <array>
        <string>$CLI_BIN</string>
        <string>run</string>
        <string>--bind</string>
        <string>http://*:2233</string>
        <string>--http-basic-user</string>
        <string>$BR_USERNAME</string>
        <string>--http-basic-pass</string>
        <string>$BR_PASSWORD</string>
        <string>$BR_INSTALL_PATH/Downloads</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$BR_INSTALL_PATH</string>
    <key>StandardOutPath</key>
    <string>$BR_INSTALL_PATH/Application.log</string>
    <key>StandardErrorPath</key>
    <string>$BR_INSTALL_PATH/Application.log</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

    # 加载并启动
    launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
    launchctl load "$LAUNCHD_PLIST"
    launchctl start com.gxusb.bililiverecorder

    info_log "✅ launchd 服务已创建并启动"
    info_log "查看状态: launchctl list | grep bililiverecorder"
  }

  delete_macos_service() {
    if [[ -f "$LAUNCHD_PLIST" ]]; then
      launchctl stop com.gxusb.bililiverecorder 2>/dev/null || true
      launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
      rm -f "$LAUNCHD_PLIST"
      info_log "✅ launchd 服务已删除"
    else
      info_log "⚠️ 服务文件不存在"
    fi
  }
fi

# === 菜单 ===
show_menu() {
  if [[ -n "${IS_LINUX:-}" ]]; then
    title="Linux systemd"
    create_fn="create_linux_service"
    delete_fn="delete_linux_service"
  else
    title="macOS launchd"
    create_fn="create_macos_service"
    delete_fn="delete_macos_service"
  fi

  while true; do
    cat <<-EOF

######## ${title} 服务管理 ########
  1) 创建并启用服务
  2) 停止并删除服务
  3) 退出
EOF

    read -rp "请选择 [1-3]: " choice
    case "$choice" in
      1) "$create_fn" ;;
      2) "$delete_fn" ;;
      3) info_log "退出"; exit 0 ;;
      *) echo "❌ 无效选项"; sleep 1 ;;
    esac
  done
}

show_menu