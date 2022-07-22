# Bililive-Recorder for MacOS/Linux

上游项目 [BililiveRecorder](https://github.com/Bililive/BililiveRecorder) 地址

>录播姬命令行版与桌面版的功能完全一致，两个版本共用同一套核心代码，只在与用户交互的外壳代码上不同。
录播姬命令行版与桌面版的配置文件也是通用的，可以在桌面版配置好相关参数后用命令行版加载运行。

>录播姬命令行版也提供了与桌面版一样的完整的录播姬工具箱功能，便于有能人士编写脚本实现自动化。

标准模式运行（[使用配置文件](https://github.com/Bililive/BililiveRecorder/issues/207)）

## 程序说明
简化使用流程

### 安装
```bash
git clone https://github.com/gxusb/Bililive-Recorder.git && cd Bililive-Recorder
bash install.sh
```

<!--
```bash
bash <(curl -sL --proto-redir -all,https https://raw.githubusercontent.com/gxusb/Bililive-Recorder/master/install.sh)
```
-->

### 启动程序

请运行`run_app`
默认启用 Web UI (http://localhost:2233)

### 停止程序

请运行`stop_app`

### 编辑配置文件

请运行`set_config`

## 如何食用

1. 交互命令说明

| 选项                         | 描述               |
| ---------------------------- | ------------------ |
| List rooms                   | （列出房间）       |
| Add room                     | （添加房间）       |
| Delete room                  | （删除房间）       |
| Update room config           | （更新房间配置）   |
| Update global config         | （更新全局配置）   |
| Update JSON Schema           | （更新 JSON 架构） |
| Exit and discard all changes | （退出并放弃）     |
| Save and Exit                | （保存并退出）     |

2. 添加房间号使用说明


```markdown
# 在后面输入房间号（live.bilibili.com/后面的数字就是房间号），输入 0 取消
# https://live.bilibili.com/9196015?broadcast_type=0&spm_id_from=444.41.0.0
(type 0 to cancel) Roomid: 9196015

# 开播时自动录制，输入 y 开启
Enable auto record? [y/n] (y): 

# 添加完成
Room 22333522 added to config
(type 0 to cancel) Roomid: 
# 输入 0 返回主界面
```

-----------------

## 以命令行的方式运行

- 比如 MacOS 命令

```bash
./BililiveRecorder.Cli run "/Users/${USER}/Desktop/BilibiliLive"
```

- 比如 MacOS 后台运行命令

```bash
nohup ./BililiveRecorder.Cli run "/Users/${USER}/Desktop/BilibiliLive" >>/Users/${USER}/Desktop/BilibiliLive/Application.log 2>&1 &
```

- 比如 Linux 后台运行命令

```bash
nohup ./BililiveRecorder.Cli run "/root/BilibiliLive" >>/root/BilibiliLive/Application.log 2>&1 &
```

-----------
> [使用教程](https://lxnchan.cn/bilibili-Rec.html)

## 创建系统服务

创建系统服务：vim /etc/systemd/system/brec.service

```service
[Unit]
Description=BililiveRecorder
After=network.target
[Service]
ExecStart=/opt/Bililive-Recorder/Application/BililiveRecorder.Cli run --bind "http://*:2233" --http-basic-user "用户名" --http-basic-pass "密码" "/opt/Bililive-Recorder/Downloads"
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
[Install]
WantedBy=multi-user.target
```
然后可以用 systemctl 控制该服务。

然后重载服务：
```bash
systemctl daemon-reload
```
每次修改了 brec.service 文件后都需要运行这个命令重载一次。

设置开机启动
`systemctl enable brec`

禁用开机启动
`systemctl disable brec`

查看运行状态：
`systemctl status brec`

```shell
# 开启服务
systemctl start brec.service
# 停止服务
systemctl stopbrec.service
# 查看状态和部分日志
systemctl status brec.service
```
