#!/usr/bin/env bash
# Lesson 03 Attack Script — Linux 环境
# 目标：演示 Suricata NIDS 对端口扫描的检测。

set -euo pipefail

EVE="docker compose exec suricata cat /var/log/suricata/eve.json"

# Step 1: 检查状态
echo "[Step 1] 检查 Suricata 状态..."
if docker compose ps --format "{{.Name}} {{.Status}}" 2>/dev/null | grep -q suricata; then
  echo "  ✓ Suricata 容器正在运行"
else
  echo "  ✗ Suricata 未运行，请执行: docker compose up -d"
  exit 1
fi
echo ""

# Step 2: 记录扫描前包数
BEFORE_PKTS=$($EVE 2>/dev/null | jq -r 'select(.event_type=="stats") | .stats.capture.kernel_packets' 2>/dev/null | tail -1)
BEFORE_PKTS=${BEFORE_PKTS:-0}

# Step 3: nmap 端口扫描
echo "[Step 2] 执行端口扫描（nmap -sT）..."
echo "  目标: localhost:3000-3005,8080,8443"
nmap -sT -p 3000-3005,8080,8443 --open localhost 2>&1 | grep -E "PORT|open|closed|filtered"
echo ""

# Step 4: 等待处理
echo "[Step 3] 等待 Suricata 处理..."
sleep 3

# Step 5: 查看包数变化
AFTER_PKTS=$($EVE 2>/dev/null | jq -r 'select(.event_type=="stats") | .stats.capture.kernel_packets' 2>/dev/null | tail -1)
AFTER_PKTS=${AFTER_PKTS:-0}
echo "  抓包: $BEFORE_PKTS → $AFTER_PKTS (+$((AFTER_PKTS - BEFORE_PKTS)))"
echo ""

# Step 6: 查看告警
echo "[Step 4] Suricata 告警..."
ALERT_COUNT=$($EVE 2>/dev/null | jq -r 'select(.event_type=="alert") | .alert.signature' 2>/dev/null | wc -l | tr -d ' ')

if [ "$ALERT_COUNT" -gt 0 ]; then
  echo "  检测到 $ALERT_COUNT 条告警:"
  $EVE 2>/dev/null | jq -r 'select(.event_type=="alert") | "  [\(.alert.severity)] \(.alert.signature) (sid:\(.alert.signature_id))"' 2>/dev/null | head -10
else
  echo "  ⚠ 未检测到告警"
fi
echo ""

# Step 7: 统计信息
echo "[Step 5] 抓包统计..."
$EVE 2>/dev/null | jq -r 'select(.event_type=="stats") |
  "  包: \(.stats.capture.kernel_packets)  丢弃: \(.stats.capture.kernel_drops)  TCP: \(.stats.decoder.tcp)  UDP: \(.stats.decoder.udp)"' 2>/dev/null | tail -1 || echo "  (无数据)"
echo ""