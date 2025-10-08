#!/bin/bash
###
# @Author       : Gxusb
# @Date         : 2021-08-06 10:13:36
# @LastEditTime : 2025-10-08 21:04:32
# @FileEncoding : -*- UTF-8 -*-
# @Description  : 启动 BililiveRecorder 应用程序
# @Copyright (c) 2025 by Gxusb, All Rights Reserved.
###

# 加载配置
ENV_PATH="$(dirname "$0")/config/config.ini"
if [[ -f "$ENV_PATH" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_PATH"
fi

info_log() {
  echo -e "\\033[32;1m[$(date '+%Y-%m-%d %T INFO')]\\033[0m $*"
}

# 安全停止进程（复用优化版）
safe_stop() {
  local bin="BililiveRecorder.Cli"
  local pids
  pids=$(pgrep -f "$bin")

  if [[ -n "$pids" ]]; then
    info_log "检测到运行中的进程 (PID: $pids)，尝试优雅停止..."
    kill "$pids" 2>/dev/null

    local i=0
    while [[ -n "$(pgrep -f "$bin")" ]] && [[ $i -lt 10 ]]; do
      sleep 1
      ((i++))
    done

    if [[ -n "$(pgrep -f "$bin")" ]]; then
      info_log "进程未退出，强制终止..."
      kill -9 "$pids" 2>/dev/null
    fi
    echo "[$(date '+%Y-%m-%d %T INFO')] 应用程序已停止。" >> "${BR_INSTALL_PATH}/Application.log"
  else
    info_log "未检测到运行中的进程。"
  fi
}

# 日志归档
log_archive() {
  local log_file="${BR_INSTALL_PATH}/Application.log"
  local log_dir="${BR_INSTALL_PATH}/Logs"
  mkdir -p "$log_dir"

  if [[ -f "$log_file" ]]; then
    local today=$(date +%Y-%m-%d)
    local archive="${log_dir}/${today}-Application.log"
    info_log "归档日志到: $archive"
    cat "$log_file" >> "$archive"
    rm -f "$log_file"
  else
    info_log "无日志文件可归档 ($log_file 不存在)"
  fi
}

# 启动主程序
run_app() {
  local cli="${BR_INSTALL_PATH}/Application/BililiveRecorder.Cli"

  # 检查可执行文件是否存在
  if [[ ! -f "$cli" ]]; then
    info_log "[ERROR] 可执行文件不存在: $cli"
    exit 1
  fi

  if [[ ! -x "$cli" ]]; then
    info_log "[WARN] 文件不可执行，尝试添加权限"
    chmod +x "$cli" || { info_log "[ERROR] 无法添加执行权限"; exit 1; }
  fi

  # 停止旧进程 + 归档日志
  safe_stop
  log_archive

  # 启动应用
  info_log "正在启动 BililiveRecorder..."
  nohup "$cli" run \
    --bind "http://*:2233" \
    --http-basic-user "$BR_USERNAME" \
    --http-basic-pass "$BR_PASSWORD" \
    "$BR_INSTALL_PATH/Downloads" \
    >> "${BR_INSTALL_PATH}/Application.log" 2>&1 &

  # 等待进程启动
  sleep 2

  if pgrep -f "BililiveRecorder.Cli" > /dev/null; then
    info_log "✅ 应用程序启动成功！访问 http://<IP>:2233"
    echo "[$(date '+%Y-%m-%d %T INFO')] 应用程序启动成功！" >> "${BR_INSTALL_PATH}/Application.log"
    echo "[$(date '+%Y-%m-%d %T INFO')] Web 端口: 2233" >> "${BR_INSTALL_PATH}/Application.log"
  else
    info_log "❌ 应用程序启动失败！请检查日志：${BR_INSTALL_PATH}/Application.log"
    tail -n 20 "${BR_INSTALL_PATH}/Application.log"
    exit 1
  fi
}

run_app