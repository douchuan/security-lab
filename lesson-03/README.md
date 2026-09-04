# Lesson 03: NIDS — 网络入侵检测系统

## 实验目标

1. 部署 Suricata 作为网络入侵检测系统（NIDS）
2. 理解 NIDS 和 WAF 的防护层次区别
3. 观察 Suricata 对端口扫描的检测

## 架构

```
  攻击者
    │
    ▼ (http://localhost:80)
┌──────────────┐
│  WAF (Nginx) │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────────┐
│ Juice Shop   │     │   Suricata (NIDS)│
│              │────▶│  监控网络流量     │
└──────────────┘     │  检测端口扫描     │
                     │  生成 EVE 告警    │
                     └──────────────────┘
```

## 网络设计

- **dmz-net**：WAF 所在网络
- **app-net**：Juice Shop 所在内部网络
- **monitor-net**：Suricata 监控网络

## 快速开始

```bash
# 启动应用
docker compose up -d

# 查看容器状态
docker compose ps

# 查看 Suricata 实时告警
docker compose logs -f suricata

# 查看 EVE JSON 告警文件
docker compose exec suricata cat /var/log/suricata/eve.json

# 停止并清理
docker compose down
```

## 验证 NIDS

### 运行攻击脚本

```bash
bash attack.sh
```

脚本会：
1. 启动一个临时攻击容器（带 nmap）
2. 对目标执行端口扫描
3. 查看 Suricata 的告警日志，展示检测结果

### 手动端口扫描

```bash
# 从宿主机扫描
nmap -sT localhost -p 80,3000

# 查看 Suricata 告警
docker compose exec suricata cat /var/log/suricata/eve.json | grep -i "scan\|alert" | tail -5
```

## 思考题

1. NIDS（Suricata）和 WAF（ModSecurity）的防护层次有什么不同？
2. Suricata 是如何检测端口扫描的？（连接频率、目标端口数量）
3. 为什么 NIDS 需要看到原始网络流量？

## 知识点

- **Suricata**：高性能开源 IDS/IPS，支持多线程处理和规则匹配
- **EVE JSON**：Suricata 的结构化日志输出格式，每条记录包含告警元数据
- **端口扫描检测**：Suricata 通过检测短时间内对多个端口的连接尝试来识别扫描行为
- **ET (Emerging Threats) 规则集**：Suricata 的默认检测规则集

## 下一步

完成本课后，继续学习 Lesson 04 —— 添加 HIDS（Wazuh Agent）检测主机层威胁。
