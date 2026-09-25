#!/usr/bin/env bash
# Lesson 03: NIDS (Suricata) Demo
#
# VM1 (目标服务器): docker compose up -d
# VM2 (攻击者):     bash attack.sh <VM1的IP>

set -euo pipefail

usage() {
  echo "用法: bash attack.sh <目标IP>"
  echo ""
  echo "在攻击者 VM 上运行，对目标 VM 发起端口扫描，触发 Suricata 告警。"
  echo ""
  echo "示例:"
  echo "  bash attack.sh 10.0.2.10"
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

echo "[Step 1] nmap 扫描 → $TARGET"
nmap -sT -p 3000-3005,8080,8443 "$TARGET" 2>&1 | grep -E "PORT|open|closed|filtered"

echo ""
echo "[Step 2] 在 VM1 上查看告警："
echo "  docker compose exec suricata cat /var/log/suricata/eve.json | jq 'select(.event_type==\"alert\")'"
