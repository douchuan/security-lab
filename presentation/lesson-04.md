# 🛡️ Lesson 04

## 你的服务器文件被篡改了——谁干的？

---

## 回顾：当前安全链路

```
攻击者 → WAF → Juice Shop → Suricata (NIDS)
                          ↓
                    Wazuh Agent (新课) → SIEM → Dashboard
```

WAF + NIDS 都已部署。但如果攻击者已经进了主机呢？

---

## 场景：Uber 文件篡改事件

> **2016 年，攻击者获得 AWS 凭证后修改内部系统文件，窃取 5700 万用户信息。Uber 支付赎金试图掩盖——最终被罚 1.48 亿美元。**

你仍然担心：

- **如果攻击者已经进来了呢？**
- 他们在服务器上修改文件：植入后门、修改配置、删除日志
- **网络层检测看不到主机内部发生了什么**

你需要一双**在主机内部的眼睛**。

---

## 新架构：HIDS 上线

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐
│ Juice Shop   │     │   Suricata   │     │  Wazuh Agent     │
│              │────▶│   (NIDS)     │     │  (HIDS)  ← 新防线│
└──────────────┘     └──────────────┘     │  监控文件变化     │
                                          │  监控进程         │
                                          │  FIM 实时告警    │
                                          └──────────────────┘
```

---

## 关键概念：文件篡改

> **文件篡改 (File Tampering)** — 攻击者获得主机权限后，修改系统文件、创建后门、植入恶意代码。

**常见篡改行为：**
| 行为 | 目的 |
|------|------|
| 修改 `/etc/passwd` | 创建后门账户 |
| 修改 Web 文件 | 植入 WebShell |
| 删除日志文件 | 销毁攻击痕迹 |
| 修改 cron 任务 | 持久化恶意代码 |
| 安装 Rootkit | 隐藏恶意进程 |

**本实验模拟：**
```bash
docker exec juice-shop touch /tmp/.hidden_backdoor
```

---

## 三层防御对比

| 威胁类型 | WAF | NIDS | HIDS |
|----------|-----|------|------|
| SQL 注入 | ✅ | ❌ | ❌ |
| 端口扫描 | ❌ | ✅ | ❌ |
| <span class="danger">文件篡改</span> | ❌ | ❌ | <span class="success">✅ 只有 HIDS</span> |
| <span class="danger">可疑进程</span> | ❌ | ❌ | <span class="success">✅ 只有 HIDS</span> |
| <span class="danger">Rootkit</span> | ❌ | ❌ | <span class="success">✅ 只有 HIDS</span> |

---

## 关键概念：Wazuh Agent

**Wazuh Agent** — 部署在受监控主机上的轻量级代理。

**核心功能：**
- **文件完整性监控 (FIM)** — 监控关键文件的创建、修改、删除
- **日志监控** — 收集和分析系统日志
- **进程监控** — 检测可疑进程
- **Rootkit 检测** — 扫描系统中可能存在的 Rootkit

> 它是你在主机层的"眼睛"——从内部监控系统状态。

---

## 关键概念：FIM

> **文件完整性监控 (File Integrity Monitoring)** — 持续监控关键文件和目录的变化。

**工作原理：**
```
基线快照 → 持续对比 → 发现变化 → 生成告警
  (初始)     (运行时)     (差异)      (通知)
```

**典型监控目标：**
- `/etc/passwd`, `/etc/shadow` — 用户账户
- `/etc/crontab` — 定时任务
- Web 根目录 — WebShell 植入
- 系统二进制文件 — Rootkit 替换

> FIM 只检测和告警，不阻止。阻止需要访问控制或不可变文件系统。

---

## NIDS vs HIDS

| 维度 | NIDS (Suricata) | HIDS (Wazuh Agent) |
|------|----------------|-------------------|
| 监控位置 | 网络接口 | 主机系统 |
| 数据来源 | 网络流量包 | 系统日志、文件、进程 |
| 擅长检测 | 端口扫描、协议攻击 | 文件篡改、Rootkit |
| 盲区 | 主机内部活动 | 未安装 Agent 的主机 |
| 比喻 | 摄像头看大楼入口 | 监控看每个房间 |

> **最佳实践：同时部署 NIDS + HIDS，互补而非替代。**

---

## 动手验证

```bash
cd lesson-04
docker compose up -d

# 运行攻击演示
bash attack.sh

# 手动文件篡改
docker exec juice-shop touch /tmp/.hidden_backdoor

# 查看检测
docker compose logs --tail=30 wazuh-agent
```

---

## CISO 观察记录

| 检查项 | 状态 | 备注 |
|--------|------|------|
| WAF | <span class="success">✅</span> | HTTP 层防护 |
| NIDS | <span class="success">✅</span> | 网络流量监控 |
| HIDS | <span class="success">✅</span> | 主机层监控 |
| 文件篡改 | <span class="success">🛡️</span> | FIM 告警 |
| 日志集中 | <span class="danger">❌</span> | 日志分散在各处 |
| 关联分析 | <span class="danger">❌</span> | 无法跨组件关联 |

> **NIDS 像大楼摄像头，HIDS 像房间里的监控。两者结合 = 完整威胁可见性。**

---

## 下一课

→ HIDS 上线了，但你遇到了一个新问题：**你有 4 个安全组件，每个都在产生日志。**

WAF 日志、Suricata 日志、Wazuh Agent 日志、应用访问日志……

**攻击者同时触发了多个组件的告警，但你无法把它们关联起来。**

下一课部署 **SIEM，将所有日志集中到一个平台进行关联分析。**
