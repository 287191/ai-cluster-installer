#!/bin/bash
set -e
USER_HOME=$(eval echo "~${SUDO_USER:-$USER}")
INSTALL_PATH="$USER_HOME/ai-cluster-installer.sh"

curl -fsSL -o "$INSTALL_PATH" \
https://raw.githubusercontent.com/287191/ai-cluster-installer/main/ai-cluster-installer.sh

chmod +x "$INSTALL_PATH"
echo "安装完成。运行：sudo $INSTALL_PATH"
