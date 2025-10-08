#!/bin/bash
###
# @Author       : Gxusb
# @Date         : 2021-08-06 10:13:36
# @LastEditTime : 2025-10-09 01:02:59
# @FileEncoding : -*- UTF-8 -*-
# @Description  : 启动 BililiveRecorder 应用程序
# @Copyright (c) 2025 by Gxusb, All Rights Reserved.
###

set -euo pipefail

# 获取脚本目录（更可靠）
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

# 日志函数
info_log() {
  echo -e "\\033[32;1m[$(date '+%Y-%m-%d %T INFO')]\\033[0m $*"
}

# 安全停止进程
safe_stop() {
  local bin="BililiveRecorder.Cli"
  # 使用 pgrep -f 但排除自身（避免脚本名匹配）
  local pids
  pids=$(pgrep -f "$bin" | grep -v "$$" || true)

  if [[ -n "$pids" ]]; then
    info_log "检测到运行中的进程 (PID: $pids)，尝试优雅停止..."
    kill "$pids" 2>/dev/null

    local i=0
    while pgrep -f "$bin" > /dev/null 2>&1 && [[ $i -lt 10 ]]; do
      sleep 1
      ((i++))
    done

    if pgrep -f "$bin" > /dev/null 2>&1; then
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
    # 避免重复归档：可选追加或覆盖（此处追加）
    cat "$log_file" >> "$archive"
    rm -f "$log_file"
  else
    info_log "无日志文件可归档 ($log_file 不存在)"
  fi
}

# 启动主程序
run_app() {
  local cli="${BR_INSTALL_PATH}/Application/BililiveRecorder.Cli"

  if [[ ! -f "$cli" ]]; then
    info_log "[ERROR] 可执行文件不存在: $cli"
    info_log "请先运行 ./install.sh 安装程序"
    exit 1
  fi

  if [[ ! -x "$cli" ]]; then
    info_log "[WARN] 文件不可执行，尝试添加执行权限"
    chmod +x "$cli" || { info_log "[ERROR] 权限设置失败"; exit 1; }
  fi

  safe_stop
  log_archive

  info_log "正在启动 BililiveRecorder..."
  nohup "$cli" run \
    --bind "http://*:2233" \
    --http-basic-user "$BR_USERNAME" \
    --http-basic-pass "$BR_PASSWORD" \
    "$BR_INSTALL_PATH/Downloads" \
    >> "${BR_INSTALL_PATH}/Application.log" 2>&1 &

  sleep 2

  # 精确检查进程（避免匹配到 grep 或脚本）
  if pgrep -f "BililiveRecorder.Cli.*run" > /dev/null; then
    info_log "✅ 应用程序启动成功！访问 http://127.0.0.1:2233"
    {
      echo "[$(date '+%Y-%m-%d %T INFO')] 应用程序启动成功！"
      echo "[$(date '+%Y-%m-%d %T INFO')] Web 端口: 2233"
    } >> "${BR_INSTALL_PATH}/Application.log"
  else
    info_log "❌ 启动失败！查看最后 20 行日志："
    tail -n 20 "${BR_INSTALL_PATH}/Application.log" || true
    exit 1
  fi
}

run_app