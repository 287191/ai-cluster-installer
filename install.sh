#!/bin/bash
set -e

USER_HOME=$(eval echo "~${SUDO_USER:-$USER}")
INSTALL_PATH="$USER_HOME/ai-cluster-installer.sh"

echo "当前用户目录: $USER_HOME"
echo "正在下载最新版本..."

curl -fsSL -o "$INSTALL_PATH" \
https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/ai-cluster-installer/main/ai-cluster-installer.sh

chmod +x "$INSTALL_PATH"

echo
echo "安装完成。"
echo "运行命令："
echo "sudo $INSTALL_PATH"
