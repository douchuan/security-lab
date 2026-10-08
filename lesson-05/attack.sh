#!/usr/bin/env bash
# Lesson 05 Attack Script
# 目标：演示 Wazuh Manager (SIEM) 对暴力破解攻击的关联检测。
# 数据流：Juice Shop 日志 → Docker Volume → Wazuh Agent → Wazuh Manager → Decoder → Rule → Alert

set -euo pipefail

JUICE_SHOP_URL="http://localhost:80"

echo "============================================"
echo "  Lesson 05: SIEM (Wazuh Manager) Demo"
echo "============================================"
echo ""

# 1. 确认 Wazuh Manager 正常运行
echo "[Step 1] 检查 Wazuh Manager 状态..."
HTTP_CODE=$(curl -sf http://localhost:55000 -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
  echo "  ✓ Wazuh Manager API 可访问 (HTTP $HTTP_CODE)"
else
  echo "  ⚠ Wazuh Manager API 可能仍在启动中，继续..."
fi
echo ""

# 2. 执行暴力破解攻击
echo "[Step 2] 执行暴力破解攻击（发送 60 次失败登录请求）..."
ATTEMPTS=0
SUCCESS=0
FAILED=0

for i in $(seq 1 60); do
  HTTP_CODE=$(curl -s -X POST "$JUICE_SHOP_URL/api/users/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@test.com\",\"password\":\"wrong_password_$i\"}" \
    -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$HTTP_CODE" = "200" ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAILED=$((FAILED + 1))
  fi

  # 每 10 次显示进度
  if [ $((i % 10)) -eq 0 ]; then
    echo "  进度: $i/60 请求已发送"
  fi

  sleep 0.2
done

echo "  攻击完成: 总 $ATTEMPTS 次, 成功 $SUCCESS 次, 失败 $FAILED 次"
echo ""

# 3. 确认日志已写入 volume
echo "[Step 3] 验证日志已写入 volume..."
echo "  Juice Shop access log:"
docker compose exec juice-shop ls -la /app/logs/ 2>/dev/null | head -3 || echo "  (无法查看)"
echo "  最近 2 行 access log:"
docker compose exec juice-shop tail -2 /app/logs/access.log 2>/dev/null || echo "  (无日志文件)"
echo ""

# 4. 等待 SIEM 关联分析
echo "[Step 4] 等待 Wazuh Manager 关联分析 (30 秒)..."
sleep 30
echo "  ✓ 等待完成"
echo ""

# 5. 查看 SIEM 告警
echo "[Step 5] 查看 Wazuh Manager 暴力破解告警..."
ALERTS_JSON=$(docker compose exec wazuh-manager cat /var/ossec/logs/alerts/alerts.json 2>/dev/null || echo "")

if [ -n "$ALERTS_JSON" ]; then
  BRUTE_ALERTS=$(echo "$ALERTS_JSON" | grep -i "brute\|100002\|100003" | head -3 || echo "")
  if [ -n "$BRUTE_ALERTS" ]; then
    echo "  ✓ 检测到暴力破解告警:"
    echo "$BRUTE_ALERTS" | while IFS= read -r line; do
      echo "    $line"
    done
  else
    echo "  ⚠ 未找到暴力破解告警 (rule 100002/100003)"
    echo "  查看最近的一般告警:"
    echo "$ALERTS_JSON" | tail -3 | while IFS= read -r line; do
      echo "    $line"
    done
  fi
else
  echo "  ⚠ 告警文件为空"
  echo "  查看 ossec.log 最近条目:"
  docker compose exec wazuh-manager tail -10 /var/ossec/logs/ossec.log 2>/dev/null || echo "  (无日志)"
fi
echo ""

# 6. 查看 Wazuh Agent 状态
echo "[Step 6] 检查 Wazuh Agent 连接状态..."
AGENT_LOGS=$(docker compose logs wazuh-agent 2>/dev/null | tail -10 || echo "")
if echo "$AGENT_LOGS" | grep -qi "connected\|enrolled"; then
  echo "  ✓ Wazuh Agent 已连接"
else
  echo "  ⚠ Agent 连接状态不确定"
  echo "  最近 Agent 日志:"
  echo "$AGENT_LOGS" | tail -5
fi
echo ""

# 7. 验证 SIEM 处理流水线
echo "[Step 7] SIEM 处理流水线验证:"
echo "  1. 日志生成: Juice Shop access.log ✓"
echo "  2. 日志传输: Docker Volume → Wazuh Agent → Manager"
echo "  3. 日志解码: juice-shop decoder 解析 HTTP 字段"
echo "  4. 规则匹配: rule 100001 (401) → rule 100002 (关联)"
echo "  5. 告警输出: alerts.json"
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  SIEM 聚合了来自 WAF、NIDS、HIDS 和应用的所有日志。"
echo "  关联规则将大量失败登录事件聚合为一个暴力破解告警。"
echo "  下一课：添加 Dashboard，将所有安全事件可视化！"
echo "============================================"
