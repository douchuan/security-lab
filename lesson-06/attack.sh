#!/usr/bin/env bash
# Lesson 06 Attack Script — 完整安全链路端到端演示
# 依次执行三种攻击场景，观察全链路检测效果。

set -euo pipefail

WAF_URL="http://localhost:80"
DASHBOARD_URL="https://localhost:443"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     安全实验室 — 完整演示                                ║"
echo "║     攻击 → WAF → NIDS → HIDS → SIEM → Dashboard        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Step 0: 验证环境
echo "[Step 0] 验证所有组件运行状态..."
SERVICES=("nginx-modsecurity" "juice-shop" "suricata" "wazuh-agent" "wazuh-manager" "wazuh-indexer" "wazuh-dashboard")
ALL_OK=true

for svc in "${SERVICES[@]}"; do
  STATUS=$(docker compose ps --format "{{.Name}} {{.Status}}" 2>/dev/null | grep "$svc" | grep -c "running" || echo "0")
  if [ "$STATUS" -gt 0 ]; then
    echo "  ✓ $svc 正在运行"
  else
    echo "  ✗ $svc 未运行"
    ALL_OK=false
  fi
done

if [ "$ALL_OK" = false ]; then
  echo ""
  echo "  ⚠ 部分服务未运行，请执行: docker compose up -d"
  echo "  注意：Wazuh 组件首次启动需要 60-90 秒初始化。"
  echo ""
fi
echo ""

# Step 1: SQL 注入攻击
echo "============================================"
echo "  [攻击 1] SQL 注入 — WAF 检测"
echo "============================================"
echo ""

echo "  1a) SQL 注入搜索请求..."
SQLI_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$WAF_URL/rest/products/search?q=%27%20OR%201%3D1%20--")
echo "  结果: HTTP $SQLI_CODE"
if [ "$SQLI_CODE" = "403" ]; then
  echo "  ✓ WAF 成功拦截 SQL 注入"
else
  echo "  ⚠ WAF 可能处于检测模式（仍会记录告警）"
  if [ "$SQLI_CODE" = "200" ] || [ "$SQLI_CODE" = "500" ]; then
    echo "  返回 $SQLI_CODE 说明注入已影响应用（200=正常响应 / 500=后端异常）"
  fi
fi
echo ""

echo "  1b) UNION SELECT 注入..."
UNION_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$WAF_URL/rest/products/search?q=1%20UNION%20SELECT%20null,null,null--")
echo "  结果: HTTP $UNION_CODE"
echo ""

echo "  1c) XSS 攻击..."
XSS_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$WAF_URL/?q=%3Cscript%3Ealert(1)%3C/script%3E")
echo "  结果: HTTP $XSS_CODE"
echo ""

# Step 2: 端口扫描
echo "============================================"
echo "  [攻击 2] 端口扫描 — Suricata NIDS 检测"
echo "============================================"
echo ""

ATTACKER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' juice-shop 2>/dev/null | head -1)

if [ -n "$ATTACKER_IP" ]; then
  echo "  扫描目标: $ATTACKER_IP"
  docker run --rm --network lesson-06_monitor-net \
    instrumentisto/nmap -sT -p 80,3000,3306,5432,8080,8443 "$ATTACKER_IP" \
    --host-timeout 10s 2>/dev/null || echo "  (nmap 扫描完成)"
else
  echo "  ⚠ 无法获取目标 IP，尝试 localhost 扫描..."
  nmap -sT localhost -p 80,3000 --host-timeout 10s 2>/dev/null || echo "  (nmap 可能未安装)"
fi
echo ""

# Step 3: 暴力破解
echo "============================================"
echo "  [攻击 3] 暴力破解 — Wazuh SIEM 关联检测"
echo "============================================"
echo ""

echo "  发送 50 次失败登录请求..."
FAILED=0
for i in $(seq 1 50); do
  HTTP_CODE=$(curl -s -X POST "$WAF_URL/api/users/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@test.com\",\"password\":\"wrong_password_$i\"}" \
    -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" != "200" ]; then
    FAILED=$((FAILED + 1))
  fi

  if [ $((i % 10)) -eq 0 ]; then
    echo "  进度: $i/50 (失败 $FAILED 次)"
  fi

  sleep 0.2
done
echo "  攻击完成: 总 50 次, 失败 $FAILED 次"
echo ""

# Step 4: 等待 SIEM 关联分析
echo "============================================"
echo "  [等待] SIEM 关联分析中..."
echo "============================================"
echo ""
echo "  等待 30 秒让 Wazuh 完成关联规则触发..."
sleep 30
echo "  ✓ 等待完成"
echo ""

# Step 5: 查看告警
echo "============================================"
echo "  [告警] 查看检测到的安全事件"
echo "============================================"
echo ""

echo "  WAF (ModSecurity) 日志:"
docker compose logs --tail=5 nginx-modsecurity 2>/dev/null | grep -i "denied\|blocked\|attack\|alert" | tail -3 || echo "  (无匹配)"
echo ""

echo "  Suricata 告警:"
docker compose exec suricata cat /var/log/suricata/eve.json 2>/dev/null | \
  grep -i "alert\|scan" | head -3 || echo "  (无匹配)"
echo ""

echo "  Wazuh Manager 告警:"
docker compose exec wazuh-manager cat /var/ossec/logs/alerts/alerts.json 2>/dev/null | \
  grep -i "brute\|login\|auth" | head -3 || echo "  (无匹配)"
echo ""

# Step 6: Dashboard 指引
echo "============================================"
echo "  [Dashboard] 安全态势可视化"
echo "============================================"
echo ""
echo "  访问 Wazuh Dashboard:"
echo "    URL: $DASHBOARD_URL"
echo "    账号: admin / SecretPassword"
echo ""
echo "  在 Dashboard 中查看:"
echo "    1. Security Events — 查看所有安全事件"
echo "    2. 按严重级别筛选 (Critical/High/Medium/Low)"
echo "    3. 按来源筛选 (WAF/NIDS/HIDS)"
echo "    4. 查看攻击来源 IP"
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  完整安全链路演示完成                                    ║"
echo "║                                                        ║"
echo "║  检测链路: 攻击 → WAF → NIDS → HIDS → SIEM → Dashboard ║"
echo "║                                                        ║"
echo "║  本次演示的三种攻击场景:                                 ║"
echo "║    1. SQL 注入  → WAF (ModSecurity) 拦截                ║"
echo "║    2. 端口扫描  → NIDS (Suricata) 检测                  ║"
echo "║    3. 暴力破解  → SIEM (Wazuh) 关联告警                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
