#!/bin/bash
###
# @Author       : Gxusb
# @Date         : 2021-08-07 14:25:21
# @LastEditTime : 2025-10-19 14:22:55
# @FileEncoding : UTF-8
# @Description  : BililiveRecorder CLI 安装与自动更新脚本
#                 支持首次安装、版本检测、自动下载、安全部署与配置管理
# @Copyright (c) 2025 by Gxusb, All Rights Reserved.
###

# set -euo pipefail

# ========== 全局常量定义 ==========
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly ENV_PATH="$SCRIPT_DIR/config/config.ini"
readonly CONFIG_DIR="$SCRIPT_DIR/config"
readonly APP_DIR="$SCRIPT_DIR/Application"
readonly DOWNLOAD_DIR="$SCRIPT_DIR/Downloads"
readonly LOG_DIR="$SCRIPT_DIR/Logs"
readonly LOCAL_VERSION_FILE="$CONFIG_DIR/app_version.txt"

# 默认配置（符合用户偏好：信任默认、自动化、简化操作）
readonly BR_INSTALL_PATH_DEFAULT="$SCRIPT_DIR"
readonly BR_GITHUB_PROXY_DEFAULT="https://git-proxy.gxusb.com/"
readonly BR_USERNAME_DEFAULT="admin"
readonly BR_PASSWORD_LENGTH=8
readonly BR_CONFIG_SCHEMA_URL="https://raw.githubusercontent.com/Bililive/BililiveRecorder/dev-1.3/configV2.schema.json"

# ========== 日志函数 ==========
# 使用 ISO 8601 格式，精确到微秒（符合用户对时间戳精度的要求）
log_info() {
  local msg="${1:-}"
  local delay="${2:-0}"
  printf "[%s INFO] %s\n" "$(date '+%Y-%m-%dT%H:%M:%S.%6N')" "$msg" >&2
  [[ $delay != "0" ]] && sleep "$delay"
}

log_error() {
  local msg="${1:-}"
  printf "[%s ERROR] %s\n" "$(date '+%Y-%m-%dT%H:%M:%S.%6N')" "$msg" >&2
  exit 1
}

# ========== 系统检测 ==========
detect_os_arch() {
  case "$(uname -s)" in
  Darwin*)
    case "$(uname -m)" in
    x86_64) SYSTEM_OS_VERSION="osx-x64" ;;
    arm64 | arm) SYSTEM_OS_VERSION="osx-arm64" ;;
    *) log_error "不支持的 macOS 架构: $(uname -m)" ;;
    esac
    ;;
  Linux*)
    case "$(uname -m)" in
    x86_64) SYSTEM_OS_VERSION="linux-x64" ;;
    aarch64) SYSTEM_OS_VERSION="linux-arm64" ;;
    armv7l) SYSTEM_OS_VERSION="linux-arm" ;;
    *) log_error "不支持的 Linux 架构: $(uname -m)" ;;
    esac
    ;;
  *)
    log_error "不支持的操作系统: $(uname -s)"
    ;;
  esac
  log_info "系统环境: $(uname -s) ($SYSTEM_OS_VERSION)" 0.1
}

# ========== 版本比较函数 ==========
version_lt() {
  [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" != "$1" ]]
}

# ========== 下载工具函数 ==========
download_with_retry() {
  local url="$1"
  local output_file="$2"
  local max_retries=5
  local retry_delay=1

  for attempt in $(seq 1 "$max_retries"); do
    log_info "正在下载: $url (尝试 $attempt/$max_retries)" 0
    if curl -#L --connect-timeout 10 --retry 2 --retry-delay "$retry_delay" -o "$output_file" "$url"; then
      log_info "下载成功: $output_file" 0.3
      return 0
    fi
    log_info "第 $attempt 次下载失败，$retry_delay 秒后重试..." 1
  done
  log_error "下载失败：$url，已达到最大重试次数。请检查网络或代理设置。"
}

# ========== 部署函数 ==========
deploy_application() {
  local zip_file="$1"
  local dest_dir="$2"

  log_info "正在解压安装包: $zip_file" 0
  mkdir -p "$dest_dir/unzip"
  if ! unzip -q -o "$zip_file" -d "$dest_dir/unzip"; then
    log_error "解压失败: $zip_file"
  fi

  # 移除旧应用目录
  rm -rf "$dest_dir/Application"
  # 移动有效内容（兼容 Release 或根目录结构）
  local app_root="$dest_dir/unzip"
  [[ -d "$app_root/Release" ]] && app_root="$app_root/Release"
  mv "$app_root" "$dest_dir/Application"
  rm -rf "$dest_dir/unzip"
  rm -f "$zip_file"

  # 设置可执行权限
  chmod +x "$dest_dir/Application/BililiveRecorder.Cli"
  log_info "应用部署完成: $dest_dir/Application/BililiveRecorder.Cli" 0.3
}

# ========== 首次配置函数 ==========
first_time_setup() {
  log_info "首次运行，初始化配置..." 0.5

  # 初始化路径（使用默认值，符合用户偏好）
  BR_INSTALL_PATH="$BR_INSTALL_PATH_DEFAULT"
  BR_GITHUB_PROXY="$BR_GITHUB_PROXY_DEFAULT"
  BR_USERNAME="$BR_USERNAME_DEFAULT"

  log_info "默认安装路径: $BR_INSTALL_PATH" 0.1
  log_info "GitHub 代理: $BR_GITHUB_PROXY" 0.1

  # 用户交互（提供默认值，减少输入负担）
  read -rp "是否使用代理？(0=否, 1=是) [0]: " use_proxy_input
  BR_USE_PROXY=${use_proxy_input:-0}

  # 代理使用说明提示（基于用户知识库）
  if [[ "$BR_USE_PROXY" -eq 1 ]]; then
    log_info "⚠️ 注意：代理仅支持 release 文件下载格式，如：" 0
    log_info "   https://github.com/hunshcn/project/releases/download/v0.1.0/example.zip" 0
    log_info "   将被代理为：https://git-proxy.gxusb.com/https://github.com/..." 0
  fi

  read -rp "HTTP Basic 用户名 [$BR_USERNAME_DEFAULT]: " username_input
  BR_USERNAME=${username_input:-$BR_USERNAME_DEFAULT}

  read -rp "HTTP Basic 密码 [留空以自动生成]: " password_input
  if [[ -z "$password_input" ]]; then
    BR_PASSWORD=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$BR_PASSWORD_LENGTH")
    log_info "已自动生成安全密码: ${BR_PASSWORD:0:4}****" 0.1
  else
    BR_PASSWORD="$password_input"
  fi

  # 创建必要目录结构
  mkdir -p "$CONFIG_DIR" "$APP_DIR" "$DOWNLOAD_DIR" "$LOG_DIR"
  log_info "目录结构已创建: $CONFIG_DIR, $APP_DIR, $DOWNLOAD_DIR, $LOG_DIR" 0.1

  # 初始化 config.json（严格遵循 schema 结构）
  local config_file="$DOWNLOAD_DIR/config.json"
  if [[ ! -f "$config_file" ]]; then
    log_info "初始化 config.json 配置文件..." 0
    cat >"$config_file" <<EOF
{
  "\$schema": "$BR_CONFIG_SCHEMA_URL",
  "version": 2,
  "global": {},
  "rooms": []
}
EOF
    log_info "config.json 已生成: $config_file" 0.1
  fi

  # 写入环境配置文件（使用单引号，避免特殊字符污染）
  mkdir -p "$(dirname "$ENV_PATH")"
  cat >"$ENV_PATH" <<EOF
BR_INSTALL_PATH='$BR_INSTALL_PATH'
BR_GITHUB_PROXY='$BR_GITHUB_PROXY'
BR_USE_PROXY='$BR_USE_PROXY'
BR_USERNAME='$BR_USERNAME'
BR_PASSWORD='$BR_PASSWORD'
EOF
  log_info "配置已持久化: $ENV_PATH" 0.3
}

# ========== 主程序入口 ==========
main() {
  log_info "=== BililiveRecorder CLI 安装/更新脚本启动 ===" 0.5

  # 1. 加载或初始化配置
  if [[ -f "$ENV_PATH" ]]; then
    log_info "加载现有配置: $ENV_PATH" 0.1
    # shellcheck disable=SC1090
    source "$ENV_PATH"
    [[ "$BR_USE_PROXY" -eq 1 ]] || BR_GITHUB_PROXY=""
  else
    log_info "未检测到配置文件，进入首次安装流程..." 0.5
    first_time_setup
  fi

  # 2. 检测系统架构
  detect_os_arch

  # 3. 获取远程最新版本（增强健壮性）
  log_info "获取最新版本信息..." 0.1
  local api_url="https://api.github.com/repos/Bililive/BililiveRecorder/releases/latest"
  local tag_name=""
  local max_retries=3
  local retry_delay=2

  for attempt in $(seq 1 "$max_retries"); do
    log_info "正在获取版本信息（尝试 $attempt / $max_retries ）..." 0
    tag_name=$(curl -sL --connect-timeout 10 --retry 2 --retry-delay "$retry_delay" "$api_url" | grep '"tag_name"' | head -n1 | cut -d'"' -f4)

    if [[ -n "$tag_name" ]]; then
      log_info "成功获取版本: $tag_name" 0.1
      break
    fi

    log_info "第 $attempt 次获取失败，$retry_delay 秒后重试..." 1
    sleep "$retry_delay"
  done

  if [[ -z "$tag_name" ]]; then
    log_error "无法获取远程版本信息。请检查：\n  1. 网络连接是否正常\n  2. GitHub API 是否被限流（尝试访问 https://github.com/Bililive/BililiveRecorder/releases）\n  3. 代理配置是否正确：BR_GITHUB_PROXY='$BR_GITHUB_PROXY'\n  4. 尝试临时关闭代理：编辑 config/config.ini，将 BR_USE_PROXY=0"
  fi

  # 4. 构建下载 URL（严格匹配 git-proxy.gxusb.com 支持的格式）
  local app_version="$tag_name"
  if [[ "$BR_USE_PROXY" -eq 1 ]]; then
    # 代理仅支持：https://git-proxy.gxusb.com/https://github.com/.../releases/download/...
    app_url="${BR_GITHUB_PROXY}https://github.com/Bililive/BililiveRecorder/releases/download/${app_version}/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}.zip"
    log_info "使用代理下载: $app_url" 0.1
  else
    # 直连，更稳定
    app_url="https://github.com/Bililive/BililiveRecorder/releases/download/${app_version}/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}.zip"
    log_info "直连 GitHub 下载: $app_url" 0.1
  fi

  local app_zip_path="$DOWNLOAD_DIR/BililiveRecorder-CLI-${SYSTEM_OS_VERSION}-${app_version}.zip"

  # 5. 检查本地版本
  local local_version=""
  if [[ -f "$LOCAL_VERSION_FILE" ]]; then
    local_version=$(cat "$LOCAL_VERSION_FILE" 2>/dev/null | tr -d '\r\n')
  fi

  # 6. 执行安装或更新
  if [[ -z "$local_version" ]]; then
    log_info "首次安装: $app_version" 0.5
    download_with_retry "$app_url" "$app_zip_path"
    deploy_application "$app_zip_path" "$SCRIPT_DIR"
    echo "$app_version" >"$LOCAL_VERSION_FILE"
    log_info "✅ 首次安装完成！运行 ./start.sh 启动服务。" 0
  elif version_lt "$local_version" "$app_version"; then
    log_info "检测到版本更新: $local_version → $app_version" 0.5
    download_with_retry "$app_url" "$app_zip_path"
    deploy_application "$app_zip_path" "$SCRIPT_DIR"
    echo "$app_version" >"$LOCAL_VERSION_FILE"
    log_info "✅ 更新完成！" 0
  else
    log_info "当前版本已是最新: $app_version ，无需更新。" 0
  fi

  log_info "=== 脚本执行完成 ===" 0.5
}

# ========== 启动主程序 ==========
main
