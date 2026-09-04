# Lesson 04: HIDS — 主机入侵检测系统

## 实验目标

1. 部署 Wazuh Agent 作为主机入侵检测系统（HIDS）
2. 理解 HIDS 与 NIDS 的区别（主机层 vs 网络层）
3. 观察文件完整性监控（FIM）和进程监控

## 架构

```
  攻击者
    │
    ▼
┌──────────────┐
│  WAF (Nginx) │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐
│ Juice Shop   │     │   Suricata   │     │  Wazuh Agent     │
│              │────▶│   (NIDS)     │     │  (HIDS)           │
└──────────────┘     └──────────────┘     │  监控文件变化     │
                                          │  监控进程         │
                                          │  监控日志         │
                                          └──────────────────┘
```

## 快速开始

```bash
# 启动应用
docker compose up -d

# 查看容器状态
docker compose ps

# 查看 Wazuh Agent 日志
docker compose logs -f wazuh-agent

# 停止并清理
docker compose down
```

## 验证 HIDS

### 运行攻击脚本

```bash
bash attack.sh
```

脚本会：
1. 在 Juice Shop 容器中模拟文件篡改
2. 查看 Wazuh Agent 的检测结果
3. 查看 Wazuh Agent 日志

### 手动测试

```bash
# 在 Juice Shop 容器中创建一个可疑文件
docker exec juice-shop touch /tmp/.hidden_backdoor

# 查看 Wazuh Agent 日志
docker compose logs --tail=30 wazuh-agent
```

## 思考题

1. HIDS（Wazuh Agent）和 NIDS（Suricata）的监控层次有什么不同？
2. 文件完整性监控（FIM）如何检测恶意文件？
3. HIDS 能检测哪些 NIDS 无法检测的威胁？

## 知识点

- **Wazuh Agent**：部署在受监控主机上的代理，收集日志、文件变化、进程信息等
- **FIM (File Integrity Monitoring)**：监控关键文件的创建、修改、删除
- **Rootkit 检测**：Wazuh 可以检测系统中可能存在的 rootkit
- **HIDS vs NIDS**：
  - NIDS 监控网络流量（外部视角）
  - HIDS 监控主机内部状态（内部视角）

## 下一步

完成本课后，继续学习 Lesson 05 —— 添加 Wazuh Manager (SIEM) 来聚合和分析所有安全日志。
