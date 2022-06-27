#!/bin/bash
###
# @Author       : gxusb admin@gxusb.com
# @Date         : 2021-08-06 14:58:19
# @LastEditors  : gxusb admin@gxusb.com
# @LastEditTime : 2022-06-26 08:36:52
# @FilePath     : /Bililive-Recorder/update_app.sh
# @FileEncoding : -*- UTF-8 -*-
# @Description  : update application
# @Copyright (c) 2022 by gxusb, All Rights Reserved.
###

# 获取当前脚本的绝对路径
cur_dir=$(
  cd "$(dirname "$0")" || exit
  pwd
)
# 本地模式 加载变量
if [ -f "$cur_dir/tool.sh" ]; then
  # shellcheck source=/dev/null
  source "$cur_dir/tool.sh"
else
  info_log "tool.sh not found"
fi
info_log "当前脚本所在目录 $cur_dir" && sleep 1

# 版本信息
APP_VERSION=$(curl -sL https://api.github.com/repos/Bililive/BililiveRecorder/releases/latest | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
# 判断APP_VERSION是否存在
if [ -z "$APP_VERSION" ]; then
  info_log "获取版本信息失败，请检查网络"
  exit 1
fi
APP_LOCAL_VERSION=$(cat <"${BR_INSTALL_PATH}/config/app_version.txt" | grep "v")
APP_REMOTELY_VERSION=${APP_VERSION}
# https://sobaigu.com/shell-get-lastest-version-from-github.html
APP_URL="${BR_GITHUB_PROXY}https://github.com/Bililive/BililiveRecorder/releases/download/${APP_VERSION}/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}.zip"
APP_FILE_FATH="${BR_INSTALL_PATH}/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}-${APP_VERSION}.zip"

function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

function download_app() {
  info_log "开始下载文件 $APP_URL"
  if curl -#Lo "${APP_FILE_FATH}" "$APP_URL"; then
    info_log "下载完成"
  else
    info_log "下载失败"
    for i in {1..5}; do
      info_log "第${i}次重试"

      if curl -#Lo "${APP_FILE_FATH}" "$APP_URL"; then
        info_log "下载完成"
        break
      fi
    done
  fi
  info_log "理论下载完成，请自行检查！"
}
# 解压安装包  并删除安装包
function upzip_file() {
  if [ -f "${APP_FILE_FATH}" ]; then
    info_log "已检测到 ${APP_FILE_FATH} 文件"
    info_log "开始解压到Application目录"
    unzip -o "${APP_FILE_FATH}" -d "${BR_INSTALL_PATH}"
    # 判断压缩包是否可解压
    if [ $? -eq 0 ]; then
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
  info_log "📝记录当前版本信信息"
  info_log "把版本信息（""${APP_VERSION}""）写入 ${BR_INSTALL_PATH}/config/app_version.txt"
  echo "${APP_VERSION}" >"${BR_INSTALL_PATH}/config/app_version.txt"
}

function check_app_version() {
  if version_lt "$APP_LOCAL_VERSION" "$APP_REMOTELY_VERSION"; then
    info_log "本地版本 $APP_LOCAL_VERSION is less than ( 小于 ) 远程版本 $APP_REMOTELY_VERSION ，可以更新。"
    download_app
    upzip_file
    set_local_version_info
  else
    info_log "本地版本 $APP_LOCAL_VERSION 与 远程版本 $APP_REMOTELY_VERSION 相同，已是最新版本，无需更新！"
  fi
}

check_app_version
