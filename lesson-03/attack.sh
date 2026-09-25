#!/usr/bin/env bash
# Lesson 03: NIDS (Suricata) Demo
#
# VM1 (目标服务器): docker compose up -d
# VM2 (攻击者):     bash attack.sh <VM1的IP>

set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "用法: bash attack.sh <VM1的IP>"
  echo "  在 VM2（攻击者）上运行，扫描 VM1"
  exit 1
fi

echo "[Step 1] 端口扫描 → $TARGET"
for port in 3000 3001 3002 3003 3004 3005 8080 8443; do
  if (echo >/dev/tcp/$TARGET/$port) 2>/dev/null; then
    echo "  Port $port: OPEN"
  else
    echo "  Port $port: closed"
  fi
done

echo ""
echo "[Step 2] 请在 VM1 上查看 Suricata 告警："
echo "  docker compose exec suricata cat /var/log/suricata/eve.json | jq 'select(.event_type==\"alert\")'"
