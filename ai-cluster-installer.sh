#!/bin/bash
set -e
GREEN='\033[1;92m'
NC='\033[0m'

show_ifaces() {
  echo "可用网卡（绿色表示已连接）:"
  while read -r iface; do
    state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo unknown)
    if [ "$state" = "up" ]; then
      printf "  ${GREEN}%s (已连接)${NC}\n" "$iface"
    else
      printf "  %s (%s)\n" "$iface" "$state"
    fi
  done < <(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$')
}

show_gpus() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "检测到 NVIDIA GPU："
    nvidia-smi --query-gpu=name --format=csv,noheader | nl
  else
    count=$(lspci | grep -ci 'NVIDIA')
    echo "检测到 NVIDIA 设备数量: $count"
  fi
}

install_nvidia() {
  sudo apt update
  sudo apt install -y build-essential dkms linux-headers-$(uname -r)
  sudo ubuntu-drivers autoinstall
  echo "驱动安装完成，请重启后运行 nvidia-smi 验证。"
}

install_clamav() {
  sudo apt update
  sudo apt install -y clamav clamav-daemon clamav-freshclam
  sudo systemctl stop clamav-freshclam || true
  sudo freshclam || true
  sudo systemctl enable --now clamav-freshclam clamav-daemon || true
}

echo "请选择服务器类型:"
echo "1) 主控服务器（主）"
echo "2) 主控服务器（备）"
echo "3) AI 推理服务器"
echo "4) AI 训练服务器"
echo "5) NAS 服务器（信息查看）"
read -p "输入选项: " ROLE

show_ifaces

case "$ROLE" in
  3|4)
    show_gpus
    read -p "是否安装最新 NVIDIA 驱动？(y/n): " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      install_nvidia
    fi
    ;;
esac

read -p "是否安装 ClamAV？(y/n): " cv
if [[ "$cv" =~ ^[Yy]$ ]]; then
  install_clamav
fi

echo "部署入口执行完成。"
