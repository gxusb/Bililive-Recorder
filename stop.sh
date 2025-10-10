#!/bin/bash
###
# @Author       : Gxusb
# @Date         : 2021-08-06 10:28:46
# @LastEditTime : 2025-10-10 21:41:02
# @FileEncoding : -*- UTF-8 -*-
# @Description  : 停止 BililiveRecorder 应用程序
# @Copyright (c) 2025 by Gxusb, All Rights Reserved.
###

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ENV_PATH="$SCRIPT_DIR/config/config.ini"

# load config
if [[ -f "$ENV_PATH" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_PATH"
else
  echo "[31m[ERROR][0m config not found: $ENV_PATH, run install.sh" >&2
  exit 1
fi

# unified log helper
info_log() {
  echo -e "\033[32;1m[$(date '+%Y-%m-%d %T INFO')]\033[0m $*"
}

# 安全停止 BililiveRecorder
stop_BililiveRecorder() {
  local bin_name="BililiveRecorder.Cli" # 更精确的二进制名（避免误杀）
  local pids

  # 获取精确匹配的进程 PID（避免脚本名、路径等干扰）
  # 使用 pgrep -f 可能太宽泛，这里限定为包含完整路径或明确可执行文件名
  pids=$(pgrep -f "$bin_name")

  if [[ -n "$pids" ]]; then
    info_log "检测到运行中的进程，PID: $pids"
    info_log "发送 SIGTERM 信号，请求优雅退出..."

    # 发送 SIGTERM（15）
    kill "$pids" 2>/dev/null

    # 等待最多 10 秒让进程退出
    local count=0
    while [[ -n "$(pgrep -f "$bin_name")" ]] && [[ $count -lt 10 ]]; do
      sleep 1
      ((count++))
    done

    # 若仍未退出，强制 kill
    if [[ -n "$(pgrep -f "$bin_name")" ]]; then
      info_log "进程未响应 SIGTERM，发送 SIGKILL 强制终止..."
      kill -9 "$pids" 2>/dev/null
    fi

    # 记录日志
    echo "[$(date '+%Y-%m-%d %T INFO')] 应用程序已停止。" >>"${BR_INSTALL_PATH}/Application.log"
    info_log "BililiveRecorder 已停止。"
  else
    info_log "未检测到运行中的 BililiveRecorder 进程。"
  fi
}

stop_BililiveRecorder
