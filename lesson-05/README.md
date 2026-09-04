# Lesson 05: SIEM — 安全信息与事件管理

## 实验目标

1. 部署 Wazuh Manager 作为 SIEM，聚合所有安全组件的日志
2. 理解 SIEM 的核心功能：日志收集、关联分析、告警生成
3. 观察暴力破解攻击的关联检测

## 架构

```
  攻击者
    │
    ▼
┌──────────────┐
│  WAF (Nginx) │ ──── 日志 ───┐
└──────┬───────┘              │
       │                      ▼
       ▼              ┌──────────────┐
┌──────────────┐      │              │
│ Juice Shop   │ ──── 日志 ──▶ Wazuh  │
│              │      │   Manager    │
└──────────────┘      │   (SIEM)     │
       │              │              │
       ▼              │  关联分析    │
┌──────────────┐      │  告警生成    │
│   Suricata   │ ──── 日志 ───┐     │
│   (NIDS)     │              │     │
└──────────────┘              │     │
                              │     │
┌──────────────┐              │     │
│ Wazuh Agent  │ ──── 日志 ───┘     │
│   (HIDS)     │                    │
└──────────────┘                    │
                           ┌────────┴───────┐
                           │  安全告警存储   │
                           └────────────────┘
```

## 快速开始

```bash
# 启动应用
docker compose up -d

# 查看容器状态
docker compose ps

# 查看 SIEM 日志
docker compose logs -f wazuh-manager

# 查看告警
docker compose exec wazuh-manager cat /var/ossec/logs/alerts/alerts.json | tail -10

# 停止并清理
docker compose down
```

## 验证 SIEM

### 运行攻击脚本

```bash
bash attack.sh
```

脚本会：
1. 对 Juice Shop 发送大量失败登录请求（暴力破解）
2. 等待 Wazuh Manager 的关联规则触发
3. 查看暴力破解告警

### 手动暴力破解

```bash
# 快速发送 50+ 次失败登录请求
for i in $(seq 1 60); do
  curl -s -X POST "http://localhost:80/api/users/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@test.com","password":"wrong'$i'"}' \
    -o /dev/null -w "Attempt $i: HTTP %{http_code}\n"
  sleep 0.2
done

# 查看 SIEM 告警
docker compose exec wazuh-manager cat /var/ossec/logs/alerts/alerts.json | \
  grep -i "brute\|login\|auth" | tail -5
```

## 思考题

1. SIEM 的"关联分析"是什么意思？（单个事件正常，多个事件组合成告警）
2. 暴力破解检测的核心逻辑是什么？（短时间内大量失败登录）
3. SIEM 如何整合不同来源的日志？（统一格式、时间戳对齐、规则匹配）

## 知识点

- **SIEM (Security Information and Event Management)**：收集、存储、分析安全事件的平台
- **日志聚合**：将不同来源的日志（WAF、NIDS、HIDS、应用）统一收集到一个地方
- **关联规则**：基于时间、频率、模式等条件，将多个低级别事件关联为高级别告警
- **Wazuh Manager**：Wazuh 的核心组件，负责接收 Agent 日志、执行规则匹配、生成告警
- **Decoder + Rule**：Wazuh 的处理流程：原始日志 → Decoder 解析 → Rule 匹配 → 告警

## 下一步

完成本课后，继续学习 Lesson 06 —— 添加 Dashboard，将安全事件可视化。
