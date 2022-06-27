#!/bin/bash
###
# @Author       : gxusb admin@gxusb.com
# @Date         : 2021-08-06 10:28:46
# @LastEditors  : gxusb admin@gxusb.com
# @LastEditTime : 2022-06-27 09:57:56
# @FilePath     : /Bililive-Recorder/stop_app.sh
# @FileEncoding : -*- UTF-8 -*-
# @Description  : stop app
# @Copyright (c) 2022 by gxusb, All Rights Reserved. 
###

#获取脚本所在的父目录
ENV_PATH="$(dirname "$0")/config/config.ini"
# 本地模式
if [ -f "${ENV_PATH}" ]; then
  # shellcheck disable=SC1090
  source "$ENV_PATH"
fi
echo "配置文件路径${ENV_PATH}"

info_log() {
  echo -e "\\033[32;1m[$(date '+%Y-%m-%d %T INFO')]\\033[0m ${*}"
  sleep 0.3 # 可优化运行速度 延时X秒显示输出的日志
}
# 停止APP
function stop_BililiveRecorder() {
  info_log "停止BililiveRecorder"
  # ps -ef | grep BililiveRecorder | grep -v grep | awk '{print $2" "$3}' | xargs kill -9
  # 查找进程 BililiveRecorder 根据进程名称  杀死进程
  if [[ -n $(pgrep -f BililiveRecorder) ]]; then
    info_log "提示: 程序正在运行，即将终止应用程序。"
    pgrep -f "BililiveRecorder" | xargs kill -9
    echo "[$(date '+%T IFN')] $(date '+%Y-%m-%d') 应用程序已停止。" >>"${BR_INSTALL_PATH}"/Application.log
  else
    info_log "提示: 程序不在运行。"
  fi
}

stop_BililiveRecorder
