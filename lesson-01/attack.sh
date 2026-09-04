#!/usr/bin/env bash
# Lesson 01 Attack Script
# 目标：验证 Juice Shop 应用可访问，展示没有安全防护时的脆弱性。

set -euo pipefail

JUICE_SHOP_URL="http://localhost:3000"

echo "============================================"
echo "  Lesson 01: Vulnerable Web App Demo"
echo "============================================"
echo ""

# 1. 检查应用是否可访问
echo "[Step 1] 检查 Juice Shop 是否可访问..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$JUICE_SHOP_URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  echo "  ✓ Juice Shop 正常运行 (HTTP $HTTP_CODE)"
else
  echo "  ✗ Juice Shop 不可访问 (HTTP $HTTP_CODE)"
  echo "  请确保已运行: docker compose up -d"
  exit 1
fi
echo ""

# 2. 获取 API 数据（无认证的公开 API）
echo "[Step 2] 获取公开 API 数据（无防护的 API 接口）..."
RESPONSE=$(curl -s "$JUICE_SHOP_URL/rest/products" | head -c 200)
echo "  API 返回数据（前200字符）: $RESPONSE"
echo ""

# 3. 尝试简单的 SQL 注入（展示没有 WAF 时的脆弱性）
echo "[Step 3] 尝试 SQL 注入（无 WAF 防护，请求应正常到达后端）..."
SQLI_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$JUICE_SHOP_URL/rest/products/search?q=' OR 1=1 --")
echo "  注入请求返回 HTTP $SQLI_RESPONSE（应非 403，因为没有 WAF 拦截）"
echo ""

# 4. 查看网络配置
echo "[Step 4] Docker 网络信息..."
echo "  运行的容器:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker ps --filter "name=juice-shop" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  Juice Shop 暴露在公网，没有任何安全防护。"
echo "  API 接口可直接访问，SQL 注入请求未被拦截。"
echo "  下一课：部署 WAF (Nginx + ModSecurity) 来保护它！"
echo "============================================"
