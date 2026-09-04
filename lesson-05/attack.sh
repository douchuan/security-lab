#!/usr/bin/env bash
# Lesson 05 Attack Script
# 目标：演示 Wazuh Manager (SIEM) 对暴力破解攻击的关联检测。

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

# 3. 等待 SIEM 关联分析
echo "[Step 3] 等待 Wazuh Manager 关联分析..."
sleep 30
echo "  ✓ 等待完成"
echo ""

# 4. 查看 SIEM 告警
echo "[Step 4] 查看 Wazuh Manager 告警..."
ALERTS=$(docker compose exec wazuh-manager cat /var/ossec/logs/alerts/alerts.json 2>/dev/null | \
  grep -i "brute\|login\|authentication" | tail -5 || echo "")

if [ -n "$ALERTS" ]; then
  echo "  检测到的暴力破解告警:"
  echo "$ALERTS" | head -5 | while IFS= read -r line; do
    echo "  $line"
  done
else
  echo "  ⚠ 未检测到暴力破解告警"
  echo "  查看最近的一般告警:"
  docker compose exec wazuh-manager tail -20 /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "  (无告警日志)"
fi
echo ""

# 5. 查看 Wazuh Manager 统计
echo "[Step 5] Wazuh Manager 统计..."
docker compose exec wazuh-manager cat /var/ossec/logs/ossec.log 2>/dev/null | \
  grep -i "started\|info\|warn" | tail -5 || echo "  (无法获取统计信息)"
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  SIEM 聚合了来自 WAF、NIDS、HIDS 和应用的所有日志。"
echo "  关联规则将大量失败登录事件聚合为一个暴力破解告警。"
echo "  下一课：添加 Dashboard，将所有安全事件可视化！"
echo "============================================"
