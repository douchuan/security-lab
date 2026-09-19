# 🛡️ Lesson 03

## 有人在扫描你的网络——你能看见吗？

---

## 回顾：当前安全链路

```
攻击者 → WAF → Juice Shop → Suricata (新课)
                          ↓
                    HIDS → SIEM → Dashboard
```

上节课 WAF 已部署，Web 攻击被有效拦截。但攻击者换了方向……

---

## 场景：Target 4000 万信用卡被盗

> **2013 年，攻击者通过端口扫描发现 HVAC 供应商的薄弱入口，横向移动进入 Target 核心网络。**

WAF 已部署，但 SOC 团队报告：

- 有未知 IP 正在对服务器进行**端口扫描**
- 他们在探测开放端口和运行服务
- **这不是攻击——这是攻击前的侦察**

**决定：部署 NIDS，让网络层的每一次异常探测都被看见。**

---

## 新架构：NIDS 上线

```
  ☠️ 攻击者
       ▼
┌──────────────┐
│  WAF (Nginx) │  ← 应用层防护（已有）
└──────┬───────┘
       ▼
┌──────────────┐     ┌──────────────────┐
│ Juice Shop   │     │   Suricata (NIDS)│  ← 新防线
│              │────▶│  监控网络流量     │
└──────────────┘     │  检测端口扫描     │
                     │  生成 EVE 告警    │
                     └──────────────────┘
```

---

## 关键概念：端口扫描

> **端口扫描 (Port Scanning)** — 向目标多个端口发送连接请求，探测哪些服务正在运行。

**每个端口 = 一个潜在入口：**
| 端口 | 常见服务 | 风险 |
|------|---------|------|
| 22 | SSH | 远程管理入口 |
| 80 | HTTP | Web 服务 |
| 3306 | MySQL | 数据库（不应暴露） |
| 3000 | Node.js | 应用服务 |

**常见工具：** `nmap`

```bash
# 本实验的扫描方式
nmap -sT localhost -p 80,3000
```

> 端口扫描本身不造成破坏，但它是攻击的**侦察阶段**。

---

## NIDS vs WAF 互补

| 攻击类型 | WAF 能看到？ | NIDS 能看到？ |
|----------|-------------|--------------|
| SQL 注入 | ✅ 能 | ❌ |
| XSS | ✅ 能 | ❌ |
| 端口扫描 | ❌ 看不到 | ✅ 能！ |
| 网络协议攻击 | ❌ 看不到 | ✅ 能！|
| DDoS | ❌ 看不到 | ⚠️ 部分能 |

> **WAF 工作在应用层（HTTP），NIDS 工作在网络层（TCP/IP）。它们互补，不替代。**

---

## 关键概念：Suricata

**Suricata** — 高性能开源 IDS/IPS，支持多线程处理。

**核心能力：**
- 端口扫描检测（行为分析）
- 网络攻击特征匹配（ET 规则集）
- 协议异常检测
- 流量分析

**EVE JSON 日志输出：**
```json
{
  "timestamp": "2024-09-01T10:00:00",
  "src_ip": "172.18.0.1",
  "dest_ip": "172.18.0.2",
  "alert": {
    "signature": "ET SCAN Potential SSH Scan",
    "severity": 2,
    "category": "Attempted Information Leak"
  }
}
```

---

## 关键概念：NIDS 是什么

**NIDS (Network Intrusion Detection System)** — 网络入侵检测系统。

**工作原理：**
```
网络流量 → Suricata 抓包 → 规则/行为匹配 → 生成告警
```

**NIDS 如何检测端口扫描：**
> 短时间内对同一主机的多个端口发起连接 → 行为模式识别 → 生成端口扫描告警

**不是基于规则匹配，而是基于行为分析。**

---

## 动手验证

```bash
cd lesson-03
docker compose up -d

# 运行攻击演示
bash attack.sh

# 手动扫描
nmap -sT localhost -p 80,3000

# 查看 Suricata 告警
docker compose exec suricata cat /var/log/suricata/eve.json | grep "alert"
```

---

## CISO 观察记录

| 检查项 | 状态 | 备注 |
|--------|------|------|
| WAF | <span class="success">✅</span> | 保护 HTTP 层 |
| NIDS | <span class="success">✅</span> | Suricata 监控流量 |
| 端口扫描 | <span class="success">🛡️</span> | 告警触发 |
| 主机威胁 | <span class="danger">❌</span> | 文件篡改不知道 |
| 日志集中 | <span class="danger">❌</span> | 日志分散在各处 |

> **NIDS 看网络层，WAF 看应用层。两者结合，才能看到更多威胁。**

---

## 下一课

→ NIDS 上线了，但**如果攻击者已经进来了怎么办？**

端口扫描只是侦察。如果攻击者已获得主机访问权限，开始篡改文件、植入后门……

**NIDS 看不到主机内部发生了什么。** 下一课部署 **HIDS（主机入侵检测系统）**。
