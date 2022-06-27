#!/bin/bash
###
# @Author       : gxusb admin@gxusb.com
# @Date         : 2021-08-06 10:13:36
# @LastEditors  : gxusb admin@gxusb.com
# @LastEditTime : 2022-06-27 09:56:07
# @FilePath     : /Bililive-Recorder/run_app.sh
# @FileEncoding : -*- UTF-8 -*-
# @Description  : run app
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
  sleep 0.5 # 可优化运行速度 延时X秒显示输出的日志
}

function Log_archive() {
  info_log "提示: 启动应用程序前，对旧日志进行归档"
  cur_day=$(date +%Y-%m-%d)
  if [ -f "${BR_INSTALL_PATH}/Application.log" ]; then
    cat "${BR_INSTALL_PATH}"/Application.log >>"${BR_INSTALL_PATH}"/Logs/"${cur_day}"-Application.log
    rm "${BR_INSTALL_PATH}"/Application.log
  else
    info_log "${BR_INSTALL_PATH} 目录下，没有日志文件(Application.log)"
  fi
}

function stop_BililiveRecorder() {
  if [[ -n $(pgrep -f BililiveRecorder) ]]; then
    info_log "提示: 程序正在运行，即将终止应用程序"
    pgrep -f "BililiveRecorder" | xargs kill -9
    echo "[$(date '+%T %Y-%m-%d IFN')] 应用程序已停止。" >>"${BR_INSTALL_PATH}"/Application.log
  else
    info_log "提示: 程序不在运行。"
  fi
}

function run_app() {
  stop_BililiveRecorder
  Log_archive # 日志归档
  nohup "${BR_INSTALL_PATH}"/Application/BililiveRecorder.Cli run --bind "http://*:2233" "$BR_INSTALL_PATH/Downloads" >>"${BR_INSTALL_PATH}"/Application.log 2>&1 &
  sleep 2
  if [[ -n $(pgrep -f BililiveRecorder) ]]; then
    info_log "提示: 应用程序启动成功！"
    echo "[$(date '+%T IFN')] $(date '+%Y-%m-%d') 应用程序启动成功！" >>"${BR_INSTALL_PATH}"/Application.log
    sleep 1
    cat "$BR_INSTALL_PATH"/Application.log
  else
    info_log "提示: 应用程序启动失败！"
  fi
}

run_app
