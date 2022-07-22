#!/bin/bash
###
# @Author       : gxusb admin@gxusb.com
# @Date         : 2022-07-15 15:04:45
# @LastEditors  : gxusb admin@gxusb.com
# @LastEditTime : 2022-07-22 09:57:03
# @FilePath     : /Bililive-Recorder/servce.sh
# @FileEncoding : -*- UTF-8 -*-
# @Description  : 创建系统服务
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

if [[ $release == "macos" ]]; then
    echo "系统不支持"
    exit 1
fi

function Create_service() {
    cat <<EOF >/etc/systemd/system/brec.service
[Unit]
Description=BililiveRecorder
After=network.target
[Service]
ExecStart="$BRBR_INSTALL_PATH"/Application/BililiveRecorder.Cli run --bind "http://*:2233" --http-basic-user "$BR_USERNAME" --http-basic-pass "$BR_PASSWORD" "$BR_INSTALL_PATH/Downloads"
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
    if [ -f /etc/systemd/system/brec.service ]; then
        info_log "创建系统服务成功"
        cat /etc/systemd/system/brec.service
    else
        info_log "创建系统服务失败"
    fi
    # 每次修改了 brec.service 文件后都需要运行这个命令重载一次
    systemctl daemon-reload

}

function Delete_service() {
    if [ -f /etc/systemd/system/brec.service ]; then
        rm /etc/systemd/system/brec.service
    else
        info_log "系统服务文件不存在"
    fi
    systemctl daemon-reload
}

function menu() {
    cat <<-EOF
######## 管理系统服务 ########
    (1) 创建系统服务
    (2) 删除系统服务
    (3) 退出脚本
EOF
    if ((OptionText == 1)); then
        info_log "输入无效"
    fi
    read -rep "请输入对应选项的数字：" Option_number
    case $Option_number in
    1)
        Create_service
        ;;
    2)
        Delete_service
        ;;
    3)
        exit
        ;;
    *)
        OptionText=1
        menu
        ;;
    esac
}

menu
