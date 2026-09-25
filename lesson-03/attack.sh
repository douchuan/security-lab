#!/usr/bin/env bash
# Lesson 03 Attack Script — Linux 环境
# 目标：演示 Suricata NIDS 对端口扫描的检测。
#
# 使用方式：
#   bash attack.sh                        # 单机模式：从本机扫描
#   bash attack.sh <目标IP>               # 双 VM 模式：从攻击者 VM 扫描 Suricata VM

set -euo pipefail

TARGET="${1:-}"

if [ -n "$TARGET" ]; then
  SCAN_TARGET="$TARGET"
  echo "[Step 1] 远程扫描模式"
  echo "  目标: $SCAN_TARGET"
else
  echo "[Step 1] 检查 Suricata 状态..."
  EVE="docker compose exec suricata cat /var/log/suricata/eve.json"
  if docker compose ps --format "{{.Name}} {{.Status}}" 2>/dev/null | grep -q suricata; then
    echo "  ✓ Suricata 容器正在运行"
  else
    echo "  ✗ Suricata 未运行，请执行: docker compose up -d"
    exit 1
  fi
  echo ""

  # 获取物理网卡 IP
  SCAN_TARGET=$(docker exec suricata sh -c "ip -4 addr show | grep -E 'inet ' | grep -v '127.0.0.1' | grep -v '172\.' | head -1 | awk '{print \$2}' | cut -d/ -f1" 2>/dev/null)
  if [ -z "$SCAN_TARGET" ]; then
    SCAN_TARGET=$(ip route get 1 | awk '{print $7; exit}' 2>/dev/null || hostname -I | awk '{print $1}')
  fi
  EVE="docker compose exec suricata cat /var/log/suricata/eve.json"
fi

# nmap 端口扫描
echo "[Step 2] 执行端口扫描（nmap -sT）..."
echo "  目标: $SCAN_TARGET (3000-3005,8080,8443)"
nmap -sT -p 3000-3005,8080,8443 --open "$SCAN_TARGET" 2>&1 | grep -E "PORT|open|closed|filtered"
echo ""

# 等待处理（仅本机模式有 stats）
if [ -z "${1:-}" ]; then
  BEFORE_PKTS=$($EVE 2>/dev/null | jq -r 'select(.event_type=="stats") | .stats.capture.kernel_packets' 2>/dev/null | tail -1)
  BEFORE_PKTS=${BEFORE_PKTS:-0}
fi

echo "[Step 3] 等待 Suricata 处理..."
sleep 3

# 查看包数变化（仅本机模式）
if [ -z "${1:-}" ]; then
  AFTER_PKTS=$($EVE 2>/dev/null | jq -r 'select(.event_type=="stats") | .stats.capture.kernel_packets' 2>/dev/null | tail -1)
  AFTER_PKTS=${AFTER_PKTS:-0}
  echo "  抓包: $BEFORE_PKTS → $AFTER_PKTS (+$((AFTER_PKTS - BEFORE_PKTS)))"
  echo ""

  # 查看告警
  echo "[Step 4] Suricata 告警..."
  ALERT_COUNT=$($EVE 2>/dev/null | jq -r 'select(.event_type=="alert") | .alert.signature' 2>/dev/null | wc -l | tr -d ' ')

  if [ "$ALERT_COUNT" -gt 0 ]; then
    echo "  检测到 $ALERT_COUNT 条告警:"
    $EVE 2>/dev/null | jq -r 'select(.event_type=="alert") | "  [\(.alert.severity)] \(.alert.signature) (sid:\(.alert.signature_id))"' 2>/dev/null | head -10
  else
    echo "  ⚠ 未检测到告警"
  fi
  echo ""

  # 统计信息
  echo "[Step 5] 抓包统计..."
  $EVE 2>/dev/null | jq -r 'select(.event_type=="stats") |
    "  包: \(.stats.capture.kernel_packets)  丢弃: \(.stats.capture.kernel_drops)  TCP: \(.stats.decoder.tcp)  UDP: \(.stats.decoder.udp)"' 2>/dev/null | tail -1 || echo "  (无数据)"
else
  echo "[Step 3] 扫描完成。请在 Suricata VM 上查看告警："
  echo "  docker compose exec suricata cat /var/log/suricata/eve.json | jq 'select(.event_type==\"alert\")'"
fi
echo ""

echo "============================================"
echo "  Suricata 检测到端口扫描行为。"
echo "  下一课：HIDS (Wazuh Agent) 检测主机层威胁！"
echo "============================================"
