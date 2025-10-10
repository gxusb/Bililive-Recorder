#!/bin/bash
###
# @Author       : Gxusb
# @Date         : 2021-08-06 10:13:36
# @LastEditTime : 2025-10-10 20:18:05
# @FileEncoding : -*- UTF-8 -*-
# @Description  : 启动 BililiveRecorder 应用程序
# @Copyright (c) 2025 by Gxusb, All Rights Reserved.
###

set -euo pipefail

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

safe_stop() {
  local bin="BililiveRecorder.Cli"
  local pids
  # 排除当前 shell 进程（$$）
  pids=$(pgrep -f "$bin" | grep -v "$$" || true)

  if [[ -n "$pids" ]]; then
    info_log "检测到运行中的进程 (PID: $pids)，尝试优雅停止..."
    kill "$pids" 2>/dev/null

    for _ in {1..10}; do
      pgrep -f "$bin" >/dev/null 2>&1 || return 0
      sleep 1
    done

    if pgrep -f "$bin" >/dev/null 2>&1; then
      info_log "进程未退出，强制终止..."
      kill -9 "$pids" 2>/dev/null
    fi

    echo "[$(date '+%Y-%m-%d %T INFO')] 应用程序已停止。" >> "${BR_INSTALL_PATH}/Application.log"
  else
    info_log "未检测到运行中的进程。"
  fi
}

log_archive() {
  local log_dir log_file archive
  log_dir="${BR_INSTALL_PATH}/Logs"
  log_file="${BR_INSTALL_PATH}/Application.log"
  archive="${log_dir}/$(date +%Y-%m-%d)-Application.log"
  mkdir -p "$log_dir"

  if [[ -f "$log_file" ]]; then
    info_log "归档日志到: $archive"
    cat "$log_file" >> "$archive"
    rm -f "$log_file"
  else
    info_log "无日志文件可归档 ($log_file 不存在)"
  fi
}

run_app() {
  local cli="${BR_INSTALL_PATH}/Application/BililiveRecorder.Cli"
  local download_dir="${BR_INSTALL_PATH}/Downloads"

  # 校验 CLI
  [[ -f "$cli" ]] || { info_log "[ERROR] 可执行文件不存在: $cli"; exit 1; }
  [[ -x "$cli" ]] || { info_log "[WARN] 添加执行权限"; chmod +x "$cli" || exit 1; }
  [[ -d "$download_dir" ]] || mkdir -p "$download_dir"

  safe_stop
  log_archive

  # 构建启动参数
  local args=(run --bind "http://*:2233" "$download_dir")
  if [[ -n "${BR_PASSWORD:-}" ]]; then
    args+=(--http-basic-user "$BR_USERNAME" --http-basic-pass "$BR_PASSWORD")
    info_log "启用 HTTP Basic 认证（用户名: $BR_USERNAME）"
  else
    info_log "未设置密码，以无认证模式启动"
  fi

  info_log "正在启动 BililiveRecorder..."
  nohup "$cli" "${args[@]}" >> "${BR_INSTALL_PATH}/Application.log" 2>&1 &

  sleep 2

  # 精确检测：匹配完整命令特征
  if pgrep -f "BililiveRecorder.Cli.*run.*${download_dir}" >/dev/null; then
    info_log "✅ 启动成功！访问 http://127.0.0.1:2233"

    {
      echo "[$(date '+%Y-%m-%d %T INFO')] 应用程序启动成功！"
      echo "[$(date '+%Y-%m-%d %T INFO')] Web 端口: 2233"
      echo "[$(date '+%Y-%m-%d %T INFO')] 访问地址: http://127.0.0.1:2233"
      [[ -n "${BR_PASSWORD:-}" ]] && echo "[$(date '+%Y-%m-%d %T INFO')] 用户名: $BR_USERNAME"
    } >> "${BR_INSTALL_PATH}/Application.log"
  else
    info_log "❌ 启动失败！查看最后 20 行日志："
    tail -n 20 "${BR_INSTALL_PATH}/Application.log" || true
    exit 1
  fi
}

run_app