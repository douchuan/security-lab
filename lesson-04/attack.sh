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
WAZUH_RUNNING=$(docker compose ps --format "{{.Name}} {{.Status}}" 2>/dev/null | grep -c wazuh-agent || echo "0")
if [ "$WAZUH_RUNNING" -gt 0 ]; then
  echo "  ✓ Wazuh Agent 正在运行"
else
  echo "  ✗ Wazuh Agent 未运行"
  echo "  请确保已运行: docker compose up -d"
  exit 1
fi
echo ""

# 2. 模拟文件篡改（在 Juice Shop 容器中创建可疑文件）
echo "[Step 2] 模拟文件篡改攻击..."
echo "  创建可疑文件（模拟后门）..."
docker exec juice-shop mkdir -p /tmp/.hidden 2>/dev/null || true
docker exec juice-shop sh -c 'echo "#!/bin/bash" > /tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec juice-shop chmod +x /tmp/.hidden/backdoor.sh 2>/dev/null || true
echo "  ✓ 可疑文件已创建: /tmp/.hidden/backdoor.sh"
echo ""

# 3. 模拟权限提升尝试
echo "[Step 3] 模拟可疑进程执行..."
docker exec juice-shop sh -c 'nohup sleep 3600 &>/dev/null &' 2>/dev/null || true
echo "  ✓ 可疑后台进程已启动"
echo ""

# 4. 等待 HIDS 检测
echo "[Step 4] 等待 Wazuh Agent 检测变化..."
sleep 15
echo "  ✓ 等待完成"
echo ""

# 5. 查看 Wazuh Agent 日志
echo "[Step 5] 查看 Wazuh Agent 日志..."
echo "  最近的检测日志:"
docker compose logs --tail=20 wazuh-agent 2>/dev/null | grep -i "file\|added\|modified\|alert\|warn\|error\|syscheck" | tail -10 || echo "  (无匹配日志)"
echo ""

# 6. 验证文件监控
echo "[Step 6] 验证文件完整性监控..."
docker exec juice-shop ls -la /tmp/.hidden/ 2>/dev/null || echo "  (目录不存在)"
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  Wazuh Agent 监控主机文件系统，检测文件变化和可疑进程。"
echo "  HIDS 从内部视角发现威胁，与 NIDS 形成互补。"
echo "  下一课：添加 SIEM (Wazuh Manager) 聚合所有安全日志！"
echo "============================================"
