# Caddy 反代 EMBY 一键脚本

![Language](https://img.shields.io/badge/Language-Bash-green.svg) ![License](https://img.shields.io/badge/License-MIT-blue.svg) ![Version](https://img.shields.io/badge/Version-V15.3-orange.svg)

这是一个专为 Emby / Jellyfin 设计的 Caddy 反向代理一键配置脚本。支持自动申请 HTTPS 证书、全交互式推流节点管理（前后端分离）、自动重写跨域链接，并内置了端口冲突自动清理功能。

## 🚀 快速开始 (一键安装)

**使用 `root` 用户在终端运行以下命令即可：**

```bash
bash <(curl -sL [https://raw.githubusercontent.com/suntai-sh/caddy-EMBY/main/caddy-emby-proxy.sh](https://raw.githubusercontent.com/suntai-sh/caddy-EMBY/main/caddy-emby-proxy.sh))
