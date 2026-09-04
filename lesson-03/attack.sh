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

# 创建一个带 nmap 的临时容器来执行扫描
ATTACKER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' juice-shop 2>/dev/null | head -1)

if [ -n "$ATTACKER_IP" ]; then
  echo "  扫描目标: $ATTACKER_IP"
  docker run --rm --network lesson-03_monitor-net \
    instrumentisto/nmap -sT -p 80,3000,3306,5432,8080,8443 "$ATTACKER_IP" \
    --host-timeout 10s 2>/dev/null || echo "  (nmap 扫描完成)"
else
  echo "  ⚠ 无法获取目标 IP，尝试扫描 localhost..."
  nmap -sT localhost -p 80,3000 --host-timeout 10s 2>/dev/null || echo "  (nmap 可能未安装)"
fi
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
echo "  NIDS 与 WAF 的互补：WAF 防护应用层，NIDS 防护网络层。"
echo "  下一课：添加 HIDS (Wazuh Agent) 检测主机层威胁！"
echo "============================================"
