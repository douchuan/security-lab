#!/usr/bin/env bash
# Lesson 03: NIDS (Suricata) Demo
#
# VM1 (目标服务器): docker compose up -d
# VM2 (攻击者):     bash attack.sh <VM1的IP>

set -euo pipefail

TARGET="${1:?用法: bash attack.sh <VM1的IP>}"

echo "[Step 1] nmap 扫描 → $TARGET"
nmap -sT -p 3000-3005,8080,8443 "$TARGET" 2>&1 | grep -E "PORT|open|closed|filtered"

echo ""
echo "[Step 2] 在 VM1 上查看告警："
echo "  docker compose exec suricata cat /var/log/suricata/eve.json | jq 'select(.event_type==\"alert\")'"
