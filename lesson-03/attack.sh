#!/usr/bin/env bash
# Lesson 03: NIDS (Suricata) — 端口扫描检测
#
# 部署架构（VirtualBox + Host-Only 网络）：
#   目标 VM  : docker compose up -d    → Juice Shop + Suricata
#   攻击者 VM: bash attack.sh <目标IP>  → nmap 扫描触发告警
#
# 两台 VM 通过 VirtualBox Host-Only 网卡互联（如 192.168.56.0/24）

set -euo pipefail

usage() {
  echo "用法: bash attack.sh <目标VM的IP>"
  echo ""
  echo "在攻击者 VM 上运行，对目标 VM 发起端口扫描，触发 Suricata 告警。"
  echo ""
  echo "示例:"
  echo "  bash attack.sh 192.168.56.10"
  exit 1
}

# 检查参数
if [ $# -ne 1 ]; then
  usage
fi

TARGET="$1"

# 验证 IP 格式
if ! echo "$TARGET" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
  echo "错误: 无效的 IP 地址: $TARGET"
  usage
fi

echo "[Step 1] nmap 端口扫描 → $TARGET"
nmap -sT -p 3000-3005,8080,8443 "$TARGET" 2>&1 | grep -E "PORT|open|closed|filtered"

echo ""
echo "[Step 2] 在目标 VM 上查看告警（ssh 登录后执行）："
echo "  cd lesson-03"
echo "  docker compose exec suricata cat /var/log/suricata/eve.json | jq 'select(.event_type==\"alert\")'"
