#!/bin/bash

# 获取当前脚本的绝对路径
cur_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$cur_dir/tool.sh"

info_log "当前脚本所在目录 $cur_dir" && sleep 1

# 版本信息
APP_VERSION=$(curl -sL https://api.github.com/repos/Bililive/BililiveRecorder/releases/latest | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
# 判断APP_VERSION是否存在
if [ -z "$APP_VERSION" ]; then
  info_log "获取版本信息失败，请检查网络"
  exit 1
fi
APP_LOCAL_VERSION=$(grep "v" "${BR_INSTALL_PATH}/config/app_version.txt")
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
    info_log "开始解压"
    # 判断压缩包是否解压完成
    if unzip -q -o "${APP_FILE_FATH}" -d "${BR_INSTALL_PATH}/unzip"; then
      info_log "解压完成 删除安装包"
      info_log "$(rm -fv "${APP_FILE_FATH}")"
      cd "$BR_INSTALL_PATH" || exit
      info_log "删除 Application 目录"
      rm -rf Application/
      info_log "把解压文件移动到 Application 目录"
      if [ -d "${BR_INSTALL_PATH}/unzip/Release" ]; then
        info_log "Release文件夹已存在，开始移动"
        mv -v "${BR_INSTALL_PATH}/unzip/Release" "${BR_INSTALL_PATH}/Application"
        info_log "移动完成"
      else
        info_log "Release文件夹不存在，开始移动"
        info_log "$(mv -v "${BR_INSTALL_PATH}/unzip" "${BR_INSTALL_PATH}/Application")"
        info_log "移动完成"
      fi
      info_log "删除解压文件"
      rm -rfv "${BR_INSTALL_PATH}"/unzip # 删除文件夹
      info_log "设置文件可执行权限 Application/BililiveRecorder.Cli"
      chmod +x Application/BililiveRecorder.Cli
      # 记录当前版本信信息
      set_local_version_info
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
  info_log "把版本信息（""${APP_VERSION}""）写入 ${BR_INSTALL_PATH}/config/app_version.txt"
  echo "${APP_VERSION}" >"${BR_INSTALL_PATH}/config/app_version.txt"
}

function check_app_version() {
  if version_lt "$APP_LOCAL_VERSION" "$APP_REMOTELY_VERSION"; then
    info_log "本地版本 $APP_LOCAL_VERSION 小于 远程版本 $APP_REMOTELY_VERSION ，可以更新。"
    download_app
    upzip_file
  else
    info_log "本地版本 $APP_LOCAL_VERSION 与 远程版本 $APP_REMOTELY_VERSION 相同，已是最新版本，无需更新！"
  fi
}

check_app_version
