#!/usr/bin/env bash
# Lesson 05 Attack Script
# 目标：演示 Wazuh Manager (SIEM) 两层攻击检测
# 数据流：WAF + 应用日志 → Docker Volume → Wazuh Agent → Wazuh Manager → Decoder → Rule → Alert

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

# ============================================================
# 第一阶段：SQL 注入攻击（触发 WAF / ModSecurity）
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[Phase 1] SQL 注入攻击 → 触发 WAF (ModSecurity)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SQL_PAYLOADS=(
  "' OR '1'='1"                    # 布尔注入：构造永真条件，绕过认证
  "' UNION SELECT NULL--"          # UNION 注入：联合查询探测数据库结构
  "admin'--"                       # 注释截断：-- 后面内容被忽略，直接以 admin 身份登录
  "'; DROP TABLE users--"          # 破坏性注入：删除 users 表（实际被 ModSecurity 拦截）
  "' OR 1=1; SELECT * FROM users--" # 复合注入：永真条件 + 数据窃取
)

for i in "${!SQL_PAYLOADS[@]}"; do
  PAYLOAD="${SQL_PAYLOADS[$i]}"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "$JUICE_SHOP_URL/rest/user/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${PAYLOAD}\",\"password\":\"test\"}" 2>/dev/null || echo "000")
  echo "  [$((i+1))/5] SQL 注入尝试 → HTTP $HTTP_CODE"
  sleep 0.5
done

echo "  ✓ SQL 注入攻击完成（应被 ModSecurity 拦截并记录审计日志）"
echo ""

# ============================================================
# 第二阶段：暴力破解（触发 SIEM 关联规则）
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[Phase 2] 暴力破解 → 触发 SIEM 关联分析"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "  执行暴力破解攻击（发送 60 次失败登录请求）..."
ATTEMPTS=0
SUCCESS=0
FAILED=0

for i in $(seq 1 60); do
  HTTP_CODE=$(curl -s -X POST "$JUICE_SHOP_URL/rest/user/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@test.com\",\"password\":\"wrong_password_$i\"}" \
    -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$HTTP_CODE" = "200" ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAILED=$((FAILED + 1))
  fi

  if [ $((i % 10)) -eq 0 ]; then
    echo "  进度: $i/60 请求已发送"
  fi

  sleep 0.2
done

echo "  攻击完成: 总 $ATTEMPTS 次, 成功 $SUCCESS 次, 失败 $FAILED 次"
echo ""

# 3. 确认日志已写入 volume
echo "[Step 3] 验证各组件日志已写入 volume..."
echo ""
echo "  Juice Shop access log:"
if docker compose exec wazuh-agent ls /monitored/juice-shop/logs/ 2>/dev/null | grep -q "access.log"; then
  docker compose exec wazuh-agent ls -la /monitored/juice-shop/logs/ 2>/dev/null | head -3
  echo "  最近 2 行:"
  docker compose exec wazuh-agent tail -2 /monitored/juice-shop/logs/access.log.* 2>/dev/null | head -2 || echo "  (无)"
else
  echo "  (日志尚未写入)"
fi
echo ""
echo "  ModSecurity audit log:"
docker compose exec nginx-modsecurity ls -la /var/log/modsecurity/ 2>/dev/null || echo "  (无法查看)"
docker compose exec nginx-modsecurity tail -1 /var/log/modsecurity/audit.log 2>/dev/null | head -c 200 || echo "  (无)"
echo ""

# 4. 等待 SIEM 关联分析
echo "[Step 4] 等待 Wazuh Manager 关联分析 (30 秒)..."
sleep 30
echo "  ✓ 等待完成"
echo ""

# 5. 查看两层告警
echo "============================================"
echo "  SIEM 两层告警汇总"
echo "============================================"
echo ""

ALERTS_JSON=$(docker compose exec wazuh-manager cat /var/ossec/logs/alerts/alerts.json 2>/dev/null || echo "")

if [ -n "$ALERTS_JSON" ]; then
  # 暴力破解告警 (优先展示关联告警 100002，其次展示单次失败 100001)
  echo "🔴 [Layer 1] 暴力破解 (Juice Shop → Wazuh):"
  BRUTE=$(echo "$ALERTS_JSON" | grep '"id":"100002"' | head -2 || echo "")
  if [ -z "$BRUTE" ]; then
    BRUTE=$(echo "$ALERTS_JSON" | grep '"id":"100001"' | head -2 || echo "")
  fi
  [ -n "$BRUTE" ] && echo "$BRUTE" | while IFS= read -r line; do echo "    $line"; done || echo "    (未触发)"
  echo ""

  # ModSecurity 告警
  echo "🟠 [Layer 2] WAF 拦截 (ModSecurity → Wazuh):"
  MODSEC=$(echo "$ALERTS_JSON" | grep '"id":"10002[012]"' | head -2 || echo "")
  [ -n "$MODSEC" ] && echo "$MODSEC" | while IFS= read -r line; do echo "    $line"; done || echo "    (未触发)"
  echo ""
else
  echo "  ⚠ 告警文件为空"
  echo "  查看 ossec.log 最近条目:"
  docker compose exec wazuh-manager tail -10 /var/ossec/logs/ossec.log 2>/dev/null || echo "  (无)"
fi

# 6. 统计
echo "============================================"
echo "  告警统计"
echo "============================================"
if [ -n "$ALERTS_JSON" ]; then
  TOTAL=$(echo "$ALERTS_JSON" | wc -l | tr -d ' ')
  echo "  总告警数: $TOTAL"
else
  echo "  总告警数: 0"
fi
echo ""

# 7. SIEM 处理流水线验证
echo "[Step 5] SIEM 处理流水线验证:"
echo "  应用层: ModSecurity → audit.log (审计格式) → 内置 decoder → rule 100020/100021 → Alert"
echo "  业务层: Juice Shop → access.log (Morgan) → 自定义 decoder → rule 100001/100002 → Alert"
echo "  汇聚点: Wazuh Manager 集中存储 + 关联分析"
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  SIEM 聚合了来自 WAF 层和应用层的所有日志。"
echo "  两种不同格式的日志经过 Decoder 统一解析后，"
echo "  关联规则将低级别事件聚合为高级别告警。"
echo "  下一课：添加 Dashboard，将所有安全事件可视化！"
echo "============================================"
