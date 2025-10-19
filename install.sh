#!/bin/bash
###
# @Author       : Gxusb
# @Date         : 2021-08-07 14:25:21
# @LastEditTime : 2025-10-19 13:29:49
# @FileEncoding : -*- UTF-8 -*-
# @Description  : BililiveRecorder CLI 安装与更新脚本 支持首次安装 + 自动检测更新
# @Copyright (c) 2025 by Gxusb, All Rights Reserved.
###

set -euo pipefail

# ========== 全局变量定义区 ==========
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ENV_PATH="$SCRIPT_DIR/config/config.ini"
BR_GITHUB_PROXY_DEFAULT="https://git-proxy.gxusb.com/"
BR_INSTALL_PATH_DEFAULT="$SCRIPT_DIR"

# ========== 核心函数定义区 ==========

# 日志函数
info_log() {
  local msg=${1:-}
  local delay=${2:-0}
  echo -e "\033[32;1m[$(date '+%Y-%m-%d %T INFO')]\033[0m $msg"
  [[ $delay != "0" ]] && sleep "$delay"
}

# 检测操作系统与架构
detect_os() {
  case "$(uname -s)" in
  Darwin*) SYSTEM_OS_VERSION=$([[ "$(uname -m)" == "x86_64" ]] && echo "osx-x64" || echo "osx-arm64") ;;
  Linux*)
    case "$(uname -m)" in
    x86_64) SYSTEM_OS_VERSION="linux-x64" ;;
    aarch64) SYSTEM_OS_VERSION="linux-arm64" ;;
    armv7l) SYSTEM_OS_VERSION="linux-arm" ;;
    *)
      info_log "不支持的架构: $(uname -m)" 0
      exit 1
      ;;
    esac
    ;;
  *)
    info_log "不支持的操作系统: $(uname -s)" 0
    exit 1
    ;;
  esac
  info_log "系统: $(uname -s) ($SYSTEM_OS_VERSION)" 0.1
}

# 版本比较
version_lt() { [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" != "$1" ]]; }

# 下载应用
download_app() {
  info_log "正在下载: $APP_URL" 0
  for i in {1..5}; do
    if curl -#L --connect-timeout 10 --retry 2 -o "$APP_FILE_PATH" "$APP_URL"; then
      info_log "下载成功" 0.3
      return 0
    fi
    info_log "第 $i 次下载失败，重试..." 1
  done
  info_log "下载失败，请检查网络或代理设置" 0
  exit 1
}

# 解压并部署
deploy_app() {
  info_log "解压安装包..." 0
  mkdir -p "$BR_INSTALL_PATH/unzip"
  if ! unzip -q -o "$APP_FILE_PATH" -d "$BR_INSTALL_PATH/unzip"; then
    info_log "解压失败" 0
    rm -f "$APP_FILE_PATH"
    exit 1
  fi

  rm -rf "$BR_INSTALL_PATH/Application"
  mv "$BR_INSTALL_PATH/unzip/$([ -d "$BR_INSTALL_PATH/unzip/Release" ] && echo "Release" || echo ".")" "$BR_INSTALL_PATH/Application"
  rm -rf "$BR_INSTALL_PATH/unzip"
  rm -f "$APP_FILE_PATH"

  chmod +x "$BR_INSTALL_PATH/Application/BililiveRecorder.Cli"
  info_log "部署完成" 0.3
}

# 首次配置
first_time_setup() {
  info_log "首次运行，请配置基本信息" 0.3

  # === 关键修复点：提前设置路径和代理 ===
  # 初始化全局变量，确保后续所有操作都有正确的路径
  BR_INSTALL_PATH="$BR_INSTALL_PATH_DEFAULT"
  BR_GITHUB_PROXY="$BR_GITHUB_PROXY_DEFAULT"

  info_log "默认安装路径: $BR_INSTALL_PATH" 0.1

  # 设置其他默认值
  BR_USE_PROXY=0
  BR_USERNAME="admin"

  read -rp "是否使用代理？(0=否, 1=是) [0]: " use_proxy
  BR_USE_PROXY=${use_proxy:-0}

  read -rp "HTTP Basic 用户名 [admin]: " username
  BR_USERNAME=${username:-admin}

  local password_input
  read -rsp "HTTP Basic 密码 [留空以自动生成]: " password_input
  echo

  if [[ -z "$password_input" ]]; then
    # 生成一个包含小写字母和数字的8位随机密码
    BR_PASSWORD=$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 8)
    info_log "已为您生成一个安全且易记的密码: ${BR_PASSWORD:0:4}****"
  else
    # 使用用户输入的密码
    BR_PASSWORD="$password_input"
    info_log "已使用您输入的密码: ${BR_PASSWORD:0:4}****"
  fi

  # 打印最终确认信息
  info_log "安装路径: $BR_INSTALL_PATH" 0.1
  info_log "GitHub 代理: $BR_GITHUB_PROXY" 0.1
  info_log "HTTP Basic 用户名: $BR_USERNAME" 0.1
  info_log "HTTP Basic 密码: ${BR_PASSWORD:0:4}****" 0.1

  info_log "正在创建必要的目录结构..." 0.1
  mkdir -p "$BR_INSTALL_PATH"/{Application,config,Downloads,Logs}

  # 初始化 config.json (修复：使用正确的初始结构)
  local cfg="$BR_INSTALL_PATH/Downloads/config.json"
  if [[ ! -f "$cfg" ]]; then
    info_log "初始化 config.json" 0
    cat >"$cfg" <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/Bililive/BililiveRecorder/dev-1.3/configV2.schema.json",
  "version": 2,
  "global": {},
  "rooms": []
}
EOF
  fi

  # 写入配置文件 (修复：用单引号包裹值，防止特殊字符破坏脚本)
  mkdir -p "$(dirname "$ENV_PATH")"
  cat >"$ENV_PATH" <<EOF
BR_INSTALL_PATH='$BR_INSTALL_PATH'
BR_GITHUB_PROXY='$BR_GITHUB_PROXY'
BR_USE_PROXY='$BR_USE_PROXY'
BR_USERNAME='$BR_USERNAME'
BR_PASSWORD='$BR_PASSWORD'
EOF
  info_log "配置已保存: $ENV_PATH" 0.3
}

# ========== 主程序逻辑 ==========

main() {
  # 1. 加载或初始化配置
  if [[ -f "$ENV_PATH" ]]; then
    info_log "加载配置: $ENV_PATH" 0.1
    # shellcheck disable=SC1090
    source "$ENV_PATH"
    [[ "$BR_USE_PROXY" -eq 1 ]] || BR_GITHUB_PROXY=""
  else
    info_log "未检测到配置文件，进入首次安装模式" 0.3
    first_time_setup
  fi

  # 2. 检测系统
  detect_os

  # 3. 获取远程版本
  info_log "获取最新版本信息..." 0.1
  APP_VERSION=$(curl -sL "https://api.github.com/repos/Bililive/BililiveRecorder/releases/latest" | grep '"tag_name"' | head -n1 | cut -d'"' -f4)
  [[ -z "$APP_VERSION" ]] && {
    info_log "获取远程版本失败" 0
    exit 1
  }

  APP_URL="${BR_GITHUB_PROXY}https://github.com/Bililive/BililiveRecorder/releases/download/${APP_VERSION}/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}.zip"
  APP_FILE_PATH="${BR_INSTALL_PATH}/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}-${APP_VERSION}.zip"

  # 4. 检查本地版本
  LOCAL_VERSION_FILE="$BR_INSTALL_PATH/config/app_version.txt"
  APP_LOCAL_VERSION=$(grep -oE 'v[0-9].*' "$LOCAL_VERSION_FILE" | head -n1)

  # 5. 执行安装或更新
  if [[ -z "$APP_LOCAL_VERSION" ]]; then
    info_log "首次安装 BililiveRecorder $APP_VERSION" 0.3
    download_app
    deploy_app
    echo "$APP_VERSION" >"$LOCAL_VERSION_FILE"
    info_log "✅ 首次安装完成！运行 ./start.sh 启动服务。" 0
  elif version_lt "$APP_LOCAL_VERSION" "$APP_VERSION"; then
    info_log "发现新版本：$APP_LOCAL_VERSION → $APP_VERSION" 0.3
    download_app
    deploy_app
    echo "$APP_VERSION" >"$LOCAL_VERSION_FILE"
    info_log "✅ 更新完成！" 0
  else
    info_log "已是最新版本：$APP_VERSION ，无需更新。" 0
  fi
}

main
