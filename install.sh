#!/bin/bash
###
# @Author       : gxusb admin@gxusb.com
# @Date         : 2021-08-05 07:58:50
# @LastEditors  : gxusb admin@gxusb.com
# @LastEditTime : 2022-07-03 22:02:44
# @FilePath     : /Bililive-Recorder/install.sh
# @FileEncoding : -*- UTF-8 -*-
# @Description  : install bililiverecorder
# @Copyright (c) 2022 by gxusb, All Rights Reserved.
###

# 获取当前脚本的运行路径
cur_dir=$PWD
# 获取脚本所在的父目录  可以用来获取config.ini文件
ENV_PATH="$cur_dir/config/config.ini"
# 输出日志时间格式化
function info_log() {
  echo -e "\\033[32;1m[$(date '+%Y-%m-%d %T INFO')]\\033[0m ${*}"
  sleep 0.6 # 可优化运行速度 延时X秒显示输出的日志
}

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

info_log "加载的配置文件路径 $ENV_PATH"
# 本地模式
if [ -f "${ENV_PATH}" ]; then
  info_log "从config.ini文件获取配置信息"
  # shellcheck disable=SC1090
  source "$ENV_PATH"
  if [ "$BR_USE_PROXY" -eq 1 ]; then
    info_log "使用代理"
  else
    info_log "不使用代理"
    BR_GITHUB_PROXY=""
  fi
else
  info_log "没有配置文件，采用脚本自带配置"
  BR_INSTALL_PATH="${cur_dir}"
  BR_GITHUB_PROXY="https://git.scisys.top/"
fi

# 配置文件路径
CONFIG_FILE_PATH="${BR_INSTALL_PATH}/Downloads/config.json"
#app版本记录路径
APP_LOCAL_VERSION="${BR_INSTALL_PATH}/config/app_version.txt"

# 检查操作系统信息
check_sys
# 判断SYSTEM_OS_VERSION是否存在
if [ -z "$SYSTEM_OS_VERSION" ]; then
  info_log "您的操作系统不支持"
  exit 1
fi
# 获取运程版本信息
APP_VERSION=$(curl -sL https://api.github.com/repos/Bililive/BililiveRecorder/releases/latest | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
if [ -z "$APP_VERSION" ]; then
  info_log "获取版本信息失败"
  exit 1
fi
APP_URL="${BR_GITHUB_PROXY}https://github.com/Bililive/BililiveRecorder/releases/download/${APP_VERSION}/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}.zip"
# 判断URL文件是否200 循环5次
APP_FILE_FATH="${BR_INSTALL_PATH}/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}-${APP_VERSION}.zip"
# 初始化config.json
function init_the_config_json_file() {
  info_log "初始化配置文件 $CONFIG_FILE_PATH"
  if [ -f "$CONFIG_FILE_PATH" ]; then
    info_log "配置文件 config.json 已存在，无需初始化"
  else
    info_log "配置文件 config.json 不存在，开始初始化"
    cat <<-EFO >"$CONFIG_FILE_PATH"
{"\$schema":"https://raw.githubusercontent.com/Bililive/BililiveRecorder/dev-1.3/configV2.schema.json","version":2,"global":{},"rooms":[]}
EFO
    info_log "配置文件初始化完成"
  fi
}
# 创建安装目录
function create_directory() {
  info_log "创建目录"
  mkdir -pv "$BR_INSTALL_PATH"/{Application,config,Downloads,Logs}
  info_log "安装目录已创建"
}
# 下载安装包
function download_app() {
  info_log "开始下载文件"
  info_log "下载地址 $APP_URL"
  # curl -Lo# "${APP_FILE_FATH}" "$APP_URL"
  # 判断是否下载success
  if wget --no-check-certificate -L -O "${APP_FILE_FATH}" "$APP_URL"; then
    info_log "下载完成"
  else
    info_log "下载失败"
    # 重试5次
    for i in {1..5}; do
      info_log "第${i}次重试"
      sleep 1
      if wget -q --no-check-certificate -L -O "${APP_FILE_FATH}" "$APP_URL"; then
        info_log "下载完成"
        break
      fi
    done
  fi
}
# 解压安装包  并删除安装包
function upzip_file() {
  if [ -f "${APP_FILE_FATH}" ]; then
    info_log "已检测到 ${APP_FILE_FATH} 文件"
    # if unzip -t "${APP_FILE_FATH}"; then
    #   info_log "压缩包完整"
    # else
    #   info_log "压缩包不完整"
    # fi
    info_log "开始解压到Application目录"
    # 判断压缩包是否解压完成
    if unzip -q -o "${APP_FILE_FATH}" -d "${BR_INSTALL_PATH}"; then
      info_log "解压完成"
      info_log "删除安装包"
      info_log "$(rm -fv "${APP_FILE_FATH}")"
      cd "$BR_INSTALL_PATH" || exit
      info_log "删除 Application 目录"
      rm -rf Application/
      info_log "把解压文件移动到 Application 目录"
      if [ -d "$SYSTEM_OS_VERSION/Release" ]; then
        info_log "Release文件夹已存在，开始移动"
        mv "$SYSTEM_OS_VERSION/Release" "${BR_INSTALL_PATH}/Application"
        rm -rf "$SYSTEM_OS_VERSION" # 删除文件夹
        info_log "移动完成"
      else
        info_log "Release文件夹不存在，开始移动"
        mv -v "${SYSTEM_OS_VERSION}" "${BR_INSTALL_PATH}/Application"
        info_log "移动完成"
      fi
      info_log "设置文件可执行权限 Application/BililiveRecorder.Cli"
      chmod +x Application/BililiveRecorder.Cli
    else
      info_log "解压失败"
      rm "${APP_FILE_FATH}"
      exit 1
    fi
  else
    info_log "文件不存在，请检查是否下载成功"
  fi
  info_log "当前目录 $PWD"
}

function set_local_version_info() {
  info_log "记录当前版本信信息"
  info_log "当前版本号 $APP_VERSION"
  info_log "当前安装目录 $BR_INSTALL_PATH"
  info_log "当前系统信息 $release $SYSTEM_OS_VERSION"
  info_log "把版本信息（${APP_VERSION}）写入 $APP_LOCAL_VERSION"
  echo "${APP_VERSION}" >"$APP_LOCAL_VERSION"
  # 判断文件是否存在
  if [ -f "$ENV_PATH" ]; then
    info_log "程序设置文件已存在"
  else
    info_log "程序设置文件不存在, 开始创建"
    : >"$ENV_PATH"
    info_log "是否使用代理  0: 不使用  1: 使用"
    read -rep "请输入对应的数字：" USE_PROXY
    cat <<-EFO >"$ENV_PATH"
# 手动移动目录，要修改安装目录
BR_INSTALL_PATH="$(printf '%s' "$BR_INSTALL_PATH")"
# CDN Proxy address 
BR_GITHUB_PROXY="$BR_GITHUB_PROXY"
# 是否使用代理  0: 不使用  1: 使用
BR_USE_PROXY="$USE_PROXY"
EFO
  fi
}

# 程序运行流程
function main() {
  create_directory
  # 初始化配置文件
  init_the_config_json_file
  # 下载安装包
  download_app
  # 解压安装包
  upzip_file
  # 记录版本信息
  set_local_version_info
}
# 启动程序
main
