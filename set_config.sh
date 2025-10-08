#!/bin/bash
###
# @Author       : Gxusb
# @Date         : 2021-08-07 14:25:21
# @LastEditTime : 2025-10-09 02:47:09
# @FileEncoding : -*- UTF-8 -*-
# @Description  : BililiveRecorder 配置管理脚本
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
  echo "❌ 配置文件未找到: $ENV_PATH，请先运行 install.sh" >&2
  exit 1
fi

info_log() {
  echo -e "\\033[32;1m[$(date '+%Y-%m-%d %T INFO')]\\033[0m $*"
}

# 检查 CLI 是否存在
CLI_BIN="$BR_INSTALL_PATH/Application/BililiveRecorder.Cli"
if [[ ! -f "$CLI_BIN" ]]; then
  info_log "[ERROR] BililiveRecorder.Cli 未找到，请先安装"
  exit 1
fi

# 主菜单（使用 while 循环，避免递归）
show_menu() {
  while true; do
    cat <<-EOF

######## BililiveRecorder 配置管理 ########
  1) 显示 configure 帮助信息
  2) 启动交互式配置向导
  3) 退出
EOF

    read -rp "请选择操作 [1-3]: " choice

    case "$choice" in
      1)
        info_log "显示帮助信息..."
        "$CLI_BIN" configure --help
        echo
        ;;
      2)
        info_log "启动交互式配置..."
        "$CLI_BIN" configure "$BR_INSTALL_PATH/Downloads"
        echo
        info_log "配置完成！配置文件位于: $BR_INSTALL_PATH/Downloads/config.json"
        ;;
      3)
        info_log "退出配置工具"
        exit 0
        ;;
      *)
        echo "❌ 无效选项，请输入 1、2 或 3"
        sleep 1
        ;;
    esac
  done
}

show_menu