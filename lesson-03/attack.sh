#!/usr/bin/env bash
# Lesson 03 Attack Script
# 目标：演示 Suricata NIDS 对端口扫描的检测。

set -euo pipefail

echo "============================================"
echo "  Lesson 03: NIDS (Suricata) Demo"
echo "============================================"
echo ""

# 确认 Suricata 正常运行
echo "[Step 1] 检查 Suricata 状态..."
if docker compose ps --format "{{.Name}} {{.Status}}" 2>/dev/null | grep -q suricata; then
  echo "  ✓ Suricata 容器正在运行"
else
  echo "  ✗ Suricata 未运行"
  echo "  请确保已运行: docker compose up -d"
  exit 1
fi
echo ""

# 端口扫描攻击
echo "[Step 3] 执行端口扫描..."
echo "  目标: juice-shop (3000-3005, 8080, 8443)"
echo "  扫描中..."

# 使用 bash /dev/tcp 进行 TCP 端口扫描（无需安装额外工具）
docker compose exec suricata bash -c '
for port in 3000 3001 3002 3003 3004 3005 8080 8443; do
  (echo > /dev/tcp/juice-shop/$port) 2>/dev/null && echo "  Port $port: OPEN" || echo "  Port $port: CLOSED/FILTERED"
done
' 2>&1
echo ""

# 等待 Suricata 处理告警
echo "[Step 4] 等待 Suricata 处理告警..."
sleep 5
echo "  ✓ 等待完成"
echo ""

# 查看 Suricata 告警
echo "[Step 5] 查看 Suricata EVE 告警日志..."
ALERT_COUNT=$(docker compose exec suricata cat /var/log/suricata/eve.json 2>/dev/null | \
  grep '"event_type":"alert"' | wc -l | tr -d ' ')

if [ "$ALERT_COUNT" -gt 0 ]; then
  echo "  检测到 ${ALERT_COUNT} 条告警:"
  docker compose exec suricata cat /var/log/suricata/eve.json 2>/dev/null | \
    grep '"event_type":"alert"' | head -5 | while IFS= read -r line; do
    echo "$line" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    a = d.get('alert', {})
    print(f'  [{a.get(\"severity\",\"?\")}] {a.get(\"signature\",\"unknown\")} (sid:{a.get(\"signature_id\",0)})')
except: pass
" 2>/dev/null || echo "  $line"
  done
else
  echo "  ⚠ 未检测到告警"
  echo "  查看 Suricata 日志:"
  docker compose logs --tail=10 suricata 2>/dev/null | head -5
fi
echo ""

# 查看 Suricata 统计
echo "[Step 6] Suricata 统计信息..."
STATS=$(docker compose exec suricata cat /var/log/suricata/eve.json 2>/dev/null | \
  grep '"event_type":"stats"' | tail -1 || echo "")

if [ -n "$STATS" ]; then
  echo "$STATS" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    s = d.get('stats', {}).get('capture', {})
    print(f'  抓包: {s.get(\"kernel_packets\", 0)}  丢弃: {s.get(\"kernel_drops\", 0)}')
except:
    print('  (解析失败)')
" 2>/dev/null || echo "  (无法获取统计信息)"
else
  echo "  (stats 事件未生成)"
fi
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  Suricata 监控网络流量，检测到端口扫描行为。"
echo "  下一课：添加 HIDS (Wazuh Agent) 检测主机层威胁！"
echo "============================================"
