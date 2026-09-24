#!/usr/bin/env bash
# Lesson 03 Attack Script
# 目标：演示 Suricata NIDS 对端口扫描的检测。

set -euo pipefail

echo "============================================"
echo "  Lesson 03: NIDS (Suricata) Demo"
echo "============================================"
echo ""

# 1. 确认 Suricata 正常运行
echo "[Step 1] 检查 Suricata 状态..."
if docker compose ps --format "{{.Name}} {{.Status}}" 2>/dev/null | grep -q suricata; then
  echo "  ✓ Suricata 容器正在运行"
else
  echo "  ✗ Suricata 未运行"
  echo "  请确保已运行: docker compose up -d"
  exit 1
fi
echo ""

# 2. 等待 Suricata 完成初始化
echo "[Step 2] 等待 Suricata 初始化完成..."
sleep 5
echo "  ✓ 等待完成"
echo ""

# 3. 端口扫描攻击
echo "[Step 3] 执行端口扫描（从临时攻击容器）..."

  docker run --rm --network lesson-03_app-net \
    instrumentisto/nmap -sT -p 3000,3001,3002,3003,3004,3005,8080,8443 juice-shop \
    --host-timeout 10s 2>/dev/null || echo "  (nmap 扫描完成)"
echo ""

# 4. 等待 Suricata 处理告警
echo "[Step 4] 等待 Suricata 处理告警..."
sleep 5
echo "  ✓ 等待完成"
echo ""

# 5. 查看 Suricata 告警
echo "[Step 5] 查看 Suricata EVE 告警日志..."
EVE_OUTPUT=$(docker compose exec suricata cat /var/log/suricata/eve.json 2>/dev/null | \
  grep -i "alert\|scan\|port" | head -10 || echo "")

if [ -n "$EVE_OUTPUT" ]; then
  echo "  检测到的告警:"
  echo "$EVE_OUTPUT" | head -5 | while IFS= read -r line; do
    echo "  $line"
  done
else
  echo "  ⚠ 未检测到告警日志"
  echo "  查看 Suricata 完整日志:"
  docker compose logs --tail=20 suricata 2>/dev/null | head -10
fi
echo ""

# 6. 查看 Suricata 统计
echo "[Step 6] Suricata 统计信息..."
docker compose exec suricata cat /var/log/suricata/stats.log 2>/dev/null | head -10 || echo "  (无法获取统计信息)"
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  Suricata 监控网络流量，检测到端口扫描行为。"
echo "  下一课：添加 HIDS (Wazuh Agent) 检测主机层威胁！"
echo "============================================"
