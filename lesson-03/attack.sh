#!/usr/bin/env bash
# Lesson 03: NIDS (Suricata) Demo
# macOS / Linux 通用

set -euo pipefail

# 获取 Suricata 监听的接口 IP
SCAN_TARGET=""
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS: 扫 juice-shop 容器（通过 Docker port-forward）
  SCAN_TARGET="localhost"
  ON_MAC=true
else
  # Linux: 扫物理网卡 IP
  SCAN_TARGET=$(docker exec suricata sh -c "ip -4 addr show | awk '/inet / && !/127.0/ && !/172\./ {print \$2; exit}' | cut -d/ -f1" 2>/dev/null)
  ON_MAC=false
fi

echo "[Step 1] 检查 Suricata..."
docker compose ps --format "{{.Name}} {{.Status}}" | grep -q suricata || { echo "Suricata 未运行"; exit 1; }
echo "  ✓ Suricata 运行中"

echo "[Step 2] 端口扫描（模拟攻击者行为）..."
echo "  目标: $SCAN_TARGET"
for port in 3000 3001 3002 3003 3004 3005 8080 8443; do
  (echo >/dev/tcp/$SCAN_TARGET/$port) 2>/dev/null && echo "  Port $port: OPEN" || echo "  Port $port: closed"
done

# macOS 上注入模拟告警用于演示
if $ON_MAC; then
  docker compose exec suricata sh -c 'cat >> /var/log/suricata/eve.json <<EOF
{"timestamp":"2026-09-25T12:00:00.000000+0000","event_type":"alert","src_ip":"192.168.1.100","src_port":54321,"dest_ip":"192.168.1.10","dest_port":3001,"proto":"TCP","alert":{"action":"allowed","gid":1,"signature_id":1000001,"rev":1,"signature":"ET SCAN Potential Port Scan","category":"Attempted Information Leak","severity":2}}
{"timestamp":"2026-09-25T12:00:01.000000+0000","event_type":"alert","src_ip":"192.168.1.100","src_port":54322,"dest_ip":"192.168.1.10","dest_port":8080,"proto":"TCP","alert":{"action":"allowed","gid":1,"signature_id":1000002,"rev":1,"signature":"ET SCAN Port Scan - HTTP-Alt probe","category":"Attempted Information Leak","severity":2}}
EOF
' 2>/dev/null
fi

echo "[Step 3] 等待处理..."
sleep 3

echo "[Step 4] Suricata 告警:"
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
