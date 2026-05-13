#!/bin/bash
set -e

curl -fsSL -o /home/yw/ai-cluster-installer.sh \
https://raw.githubusercontent.com/287191/ai-cluster-installer/main/ai-cluster-installer.sh

chmod +x /home/yw/ai-cluster-installer.sh

echo "安装完成。"
echo "运行命令：sudo /home/yw/ai-cluster-installer.sh"
