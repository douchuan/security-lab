#!/usr/bin/env bash
# Lesson 03: NIDS (Suricata) Demo
# macvlan 架构 — 所有容器在同一 Layer2 网络

set -euo pipefail

echo "[Step 1] 检查服务..."
docker compose ps --format "{{.Name}} {{.Status}}" | grep -q suricata || { echo "Suricata 未运行"; exit 1; }
echo "  ✓ Suricata 运行中"

echo "[Step 2] 端口扫描 (从 attacker 容器)..."
docker exec attacker nmap -sT -p 3000-3005,8080,8443 juice-shop 2>&1 | grep -E "PORT|open|closed|filtered"

echo "[Step 3] 等待告警..."
sleep 3

echo "[Step 4] 告警:"
ALERTS=$(docker compose exec suricata cat /var/log/suricata/eve.json 2>/dev/null | \
  jq -r 'select(.event_type=="alert") | "  [\(.alert.severity)] \(.alert.signature) (sid:\(.alert.signature_id))"' 2>/dev/null | head -5)
if [ -n "$ALERTS" ]; then
  echo "$ALERTS"
else
  echo "  无告警"
fi

echo "[Step 5] 统计:"
docker compose exec suricata cat /var/log/suricata/eve.json 2>/dev/null | \
  jq -r 'select(.event_type=="stats") | "  包: \(.stats.capture.kernel_packets)  TCP: \(.stats.decoder.tcp)"' 2>/dev/null | \
  tail -1 || echo "  无数据"
