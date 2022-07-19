#!/bin/bash
###
# @Author       : gxusb admin@gxusb.com
# @Date         : 2022-04-08 10:21:33
# @LastEditors  : gxusb admin@gxusb.com
# @LastEditTime : 2022-07-15 16:11:41
# @FilePath     : /Bililive-Recorder/tool.sh
# @FileEncoding : -*- UTF-8 -*-
# @Description  : 工具脚本
# @Copyright (c) 2022 by gxusb, All Rights Reserved.
###

##
# @description: 输出日志时间格式化
# @param {$1} : 日志内容
# @param {$2} : 日志打印间隔时间 单位：秒
# @return {*}
##
function info_log() {
  local content=$1 # 日志内容
  if [ -n "$2" ]; then
    local interval=$2
  else
    local interval=0.3 # 日志打印间隔时间 单位：秒
  fi
  local interval
  time_interval=$(date '+%Y-%m-%d %T INFO')
  echo -e "\033[32;1m[${time_interval}]\033[0m ${content}"
  sleep $interval
}

# 获取脚本所在的目录
ENV_PATH="$(dirname "$0")/config/config.ini"
info_log "配置文件路径${ENV_PATH}" 0
# 获取配置文件
if [ -f "${ENV_PATH}" ]; then
  info_log "从${ENV_PATH}文件获取配置信息" 0.1
  # shellcheck disable=SC1090
  source "$ENV_PATH"
  #判断$BR_USE_PROXY是否存在
  if [ -n "$BR_USE_PROXY" ]; then
    info_log "BR_USE_PROXY 变量 存在"
    if [ "$BR_USE_PROXY" -eq 1 ]; then
      info_log "使用代理"
    else
      info_log "不使用代理"
      BR_GITHUB_PROXY=""
    fi
  else
    info_log "BR_USE_PROXY 变量 不存在"
  fi
  env_list=$(cat <"$ENV_PATH" | grep -Ev "^#" | awk '{print $1}')
  for i in $env_list; do
    info_log "配置环境变量 export $i" 0
  done
else
  info_log "没有配置文件，采用脚本自带配置"
  if [ "$BR_USE_PROXY" -eq 1 ]; then
    info_log "使用代理"
    BR_GITHUB_PROXY="https://git.scisys.top/"
  else
    info_log "不使用代理"
    BR_GITHUB_PROXY=""
  fi
fi

# 检查系统
function check_sys() {
  release=$(uname -a)
  if [[ $release =~ "Darwin" ]]; then
    # 判断处理器x86_64或者arm
    if [[ $release =~ "x86_64" ]]; then
      SYSTEM_OS_VERSION="osx-x64"
    else
      SYSTEM_OS_VERSION="osx-arm64"
    fi
    release="macos"
  elif [[ $release =~ "centos" ]]; then
    if [[ $release =~ "x86_64" ]]; then
      SYSTEM_OS_VERSION="linux-x64"
    elif [[ $release =~ "aarch64" ]]; then
      SYSTEM_OS_VERSION="linux-arm64"
    else
      SYSTEM_OS_VERSION="linux-arm"
    fi
    release="centos"
  elif [[ $release =~ "ubuntu" ]]; then
    if [[ $release =~ "x86_64" ]]; then
      SYSTEM_OS_VERSION="linux-x64"
    elif [[ $release =~ "aarch64" ]]; then
      SYSTEM_OS_VERSION="linux-arm64"
    else
      SYSTEM_OS_VERSION="linux-arm"
    fi
    release="ubuntu"
  elif [[ $release =~ "debian" ]]; then
    if [[ $release =~ "x86_64" ]]; then
      SYSTEM_OS_VERSION="linux-x64"
    elif [[ $release =~ "aarch64" ]]; then
      SYSTEM_OS_VERSION="linux-arm64"
    else
      SYSTEM_OS_VERSION="linux-arm"
    fi
    release="debian"
  else
    echo "uname -a :$release"
  fi
  info_log "您当前的操作系统是: ${release} ${SYSTEM_OS_VERSION}"
  if [ -z "${SYSTEM_OS_VERSION}" ]; then
    info_log "没有获取到操作系统版本信息"
    exit 1
  fi
}

check_sys
