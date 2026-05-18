#!/bin/bash
set -e

USER_HOME=$(eval echo "~${SUDO_USER:-$USER}")
BACKUP_DIR="$USER_HOME/netplan_backup"

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
  done < <(ip -o link show | awk -F': ' '{print $2}' | grep -vE '^(lo)$')
}

show_gpus() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "检测到 NVIDIA GPU："
    nvidia-smi --query-gpu=name --format=csv,noheader | nl
  else
    count=$(lspci | grep -ci 'NVIDIA' || true)
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
  echo "ClamAV 安装完成。"
}

uninstall_tool() {
  echo "即将删除本工具及相关文件。"
  read -p "确认继续？(y/n): " c
  [[ "$c" =~ ^[Yy]$ ]] || exit 0
  sudo rm -f "$USER_HOME/ai-cluster-installer.sh"
  sudo rm -rf "$BACKUP_DIR"
  sudo rm -f /etc/netplan/99-temporary-network.yaml
  sudo netplan apply || true
  echo "卸载完成。"
  exit 0
}

backup_netplan() {
  mkdir -p "$BACKUP_DIR"
  if [ ! -f "$BACKUP_DIR/.done" ]; then
    sudo cp /etc/netplan/*.yaml "$BACKUP_DIR"/ 2>/dev/null || true
    touch "$BACKUP_DIR/.done"
  fi
}

restore_netplan() {
  if [ -d "$BACKUP_DIR" ]; then
    sudo cp "$BACKUP_DIR"/*.yaml /etc/netplan/ 2>/dev/null || true
    sudo rm -f /etc/netplan/99-temporary-network.yaml
    sudo netplan apply
    echo "生产网络配置已恢复。"
  else
    echo "未找到备份。"
  fi
}

config_dhcp() {
  show_ifaces
  read -p "输入网卡名称: " IFACE
  backup_netplan
  sudo tee /etc/netplan/99-temporary-network.yaml >/dev/null <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: true
EOF
  sudo netplan apply
}

config_static() {
  show_ifaces
  read -p "输入网卡名称: " IFACE
  read -p "IP 地址: " IP
  read -p "CIDR 前缀(如24): " CIDR
  read -p "网关: " GW
  read -p "DNS(如8.8.8.8,1.1.1.1): " DNS
  backup_netplan
  sudo tee /etc/netplan/99-temporary-network.yaml >/dev/null <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: false
      addresses:
        - $IP/$CIDR
      routes:
        - to: default
          via: $GW
      nameservers:
        addresses: [$DNS]
EOF
  sudo netplan apply
}

config_bond() {
  read -p "Bond 接口名称（默认 bond0）: " BOND
  BOND=${BOND:-bond0}
  show_ifaces
  read -p "输入成员网卡（空格分隔，如 eno1 eno2）: " SLAVES
  read -p "Bond 使用 DHCP？(y/n): " USE_DHCP
  backup_netplan

  TMP=$(mktemp)
  {
    echo "network:"
    echo "  version: 2"
    echo "  ethernets:"
    for i in $SLAVES; do
      echo "    $i:"
      echo "      dhcp4: false"
    done
    echo "  bonds:"
    echo "    $BOND:"
    echo "      interfaces: [$(echo $SLAVES | sed 's/ /, /g')]"
    echo "      parameters:"
    echo "        mode: 802.3ad"
    echo "        mii-monitor-interval: 100"
    echo "        lacp-rate: fast"
    echo "        transmit-hash-policy: layer3+4"
    if [[ "$USE_DHCP" =~ ^[Yy]$ ]]; then
      echo "      dhcp4: true"
    else
      read -p "Bond IP 地址: " IP
      read -p "CIDR 前缀: " CIDR
      read -p "网关: " GW
      read -p "DNS: " DNS
      echo "      dhcp4: false"
      echo "      addresses:"
      echo "        - $IP/$CIDR"
      echo "      routes:"
      echo "        - to: default"
      echo "          via: $GW"
      echo "      nameservers:"
      echo "        addresses: [$DNS]"
    fi
  } > "$TMP"

  sudo cp "$TMP" /etc/netplan/99-temporary-network.yaml
  rm -f "$TMP"
  sudo netplan apply
}

network_menu() {
  echo "1) DHCP 临时上网"
  echo "2) 静态 IP"
  echo "3) 端口聚合 Bond/LACP (802.3ad)"
  echo "4) 恢复生产网络配置"
  read -p "选择 [1-4]: " N
  case "$N" in
    1) config_dhcp ;;
    2) config_static ;;
    3) config_bond ;;
    4) restore_netplan ;;
  esac
}

echo "当前用户目录: $USER_HOME"
echo "1) 集群部署入口"
echo "2) 卸载并删除本工具"
read -p "选择 [1-2]: " ACTION
[ "$ACTION" = "2" ] && uninstall_tool

echo "请选择服务器类型："
echo "1) 主控服务器（主）"
echo "2) 主控服务器（备）"
echo "3) AI 推理服务器"
echo "4) AI 训练服务器"
echo "5) NAS 服务器"
read -p "选择 [1-5]: " ROLE

network_menu

case "$ROLE" in
  3|4)
    show_gpus
    read -p "安装最新 NVIDIA 驱动？(y/n): " yn
    [[ "$yn" =~ ^[Yy]$ ]] && install_nvidia
    ;;
esac

read -p "安装 ClamAV？(y/n): " cv
[[ "$cv" =~ ^[Yy]$ ]] && install_clamav

echo "所有操作完成。"
