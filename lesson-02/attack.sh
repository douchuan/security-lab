#!/usr/bin/env bash
# Lesson 02 Attack Script
# 目标：演示 WAF 对 SQL 注入和 XSS 的拦截。

set -euo pipefail

WAF_URL="http://localhost:80"

echo "============================================"
echo "  Lesson 02: WAF (Nginx + ModSecurity) Demo"
echo "============================================"
echo ""

# 1. 正常请求（应通过）
echo "[Step 1] 发送正常 HTTP 请求（应通过 WAF）..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WAF_URL/")
if [ "$HTTP_CODE" = "200" ]; then
  echo "  ✓ 正常请求通过 (HTTP $HTTP_CODE)"
else
  echo "  ✗ 正常请求被拦截 (HTTP $HTTP_CODE)"
fi
echo ""

# 2. SQL 注入攻击（应被拦截）
echo "[Step 2] 发送 SQL 注入请求（应被 WAF 拦截）..."
SQLI_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$WAF_URL/rest/products/search?q=%27%20OR%201%3D1%20--")
if [ "$SQLI_CODE" = "403" ]; then
  echo "  ✓ SQL 注入被拦截 (HTTP $SQLI_CODE — 403 Forbidden)"
  # 显示拦截页面
  echo "  拦截响应:"
  curl -s "$WAF_URL/rest/products/search?q=%27%20OR%201%3D1%20--" | head -c 300
  echo ""
else
  echo "  ⚠ SQL 注入未被拦截 (HTTP $SQLI_CODE) — WAF 可能在检测模式"
fi
echo ""

# 3. XSS 攻击（应被拦截）
echo "[Step 3] 发送 XSS 请求（应被 WAF 拦截）..."
XSS_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$WAF_URL/?q=%3Cscript%3Ealert(1)%3C/script%3E")
if [ "$XSS_CODE" = "403" ]; then
  echo "  ✓ XSS 被拦截 (HTTP $XSS_CODE)"
else
  echo "  ⚠ XSS 未被拦截 (HTTP $XSS_CODE)"
fi
echo ""

# 4. 目录遍历攻击（应被拦截）
echo "[Step 4] 发送目录遍历请求（应被 WAF 拦截）..."
TRAVERSAL_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$WAF_URL/../../etc/passwd")
if [ "$TRAVERSAL_CODE" = "403" ]; then
  echo "  ✓ 目录遍历被拦截 (HTTP $TRAVERSAL_CODE)"
else
  echo "  ⚠ 目录遍历未被拦截 (HTTP $TRAVERSAL_CODE)"
fi
echo ""

# 5. 查看 WAF 日志
echo "[Step 5] 查看 ModSecurity 审计日志..."
echo "  最近的拦截日志:"
docker compose logs --tail=10 nginx-modsecurity 2>/dev/null | grep -i "modsecurity\|denied\|blocked\|attack\|alert" | tail -5 || echo "  (无匹配日志，WAF 可能在检测模式)"
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  WAF 成功拦截了恶意 HTTP 请求（SQL 注入、XSS 等）。"
echo "  但 WAF 只能检测应用层攻击，无法检测网络层攻击。"
echo "  下一课：添加 NIDS (Suricata) 检测网络层威胁！"
echo "============================================"
