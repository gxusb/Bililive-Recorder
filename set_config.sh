#!/bin/bash
###
# @Author       : gxusb admin@gxusb.com
# @Date         : 2021-08-07 14:25:21
# @LastEditors  : gxusb admin@gxusb.com
# @LastEditTime : 2022-06-26 08:35:16
# @FilePath     : /Bililive-Recorder/set_config.sh
# @FileEncoding : -*- UTF-8 -*-
# @Description  : set config
# @Copyright (c) 2022 by gxusb, All Rights Reserved. 
###

#获取脚本所在的父目录
ENV_PATH="$(dirname "$0")/config/config.ini"
#以下变量从config.ini文件获取
BR_INSTALL_PATH=""
# 本地模式
if [ -f "${ENV_PATH}" ]; then
  # shellcheck disable=SC1090
  source "$ENV_PATH"
fi
echo "配置文件路径${ENV_PATH}"

info_log() {
  echo -e "\\033[32;1m[$(date '+%Y-%m-%d %T INFO')]\\033[0m ${*}"
}

function menu() {
  cat <<-EOF
######## 设置配置文件 ########
    (1) 交互命令配置 帮助文档
    (2) 交互命令配置
    (3) 退出脚本
EOF
  if ((OptionText == 1)); then
    info_log "输入无效"
  fi
  read -rep "请输入对应选项的数字：" numa

  case $numa in
  1)
    info_log "Show help and usage information"
    "${BR_INSTALL_PATH}"/Application/BililiveRecorder.Cli configure --help
    menu
    ;;
  2)
    "${BR_INSTALL_PATH}"/Application/BililiveRecorder.Cli configure "${BR_INSTALL_PATH}"/Downloads
    menu
    ;;
  3)
    # clear
    exit
    ;;
  *)
    OptionText=1
    menu
    ;;
  esac
}

menu
