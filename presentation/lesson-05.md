---
marp: true
theme: gaia
class: lead
paginate: true
backgroundColor: #0a0e27
color: #e0e0e0
style: |
  @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@300;400;500;700;900&display=swap');
  :root {
    --color-bg: #0a0e27;
    --color-primary: #00d4ff;
    --color-danger: #ff4757;
    --color-success: #2ed573;
    --color-warning: #ffa502;
    --color-text: #e0e0e0;
    --color-muted: #8a8fa8;
  }
  * {
    font-family: 'Noto Sans SC', sans-serif;
  }
  section::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: linear-gradient(90deg, #00d4ff, #7c3aed, #ff4757);
  }
  h1 {
    color: #00d4ff;
    font-size: 2.4em;
    font-weight: 900;
    text-shadow: 0 0 40px rgba(0, 212, 255, 0.3);
  }
  h2 {
    color: #00d4ff;
    font-size: 1.6em;
    font-weight: 700;
    border-left: 4px solid #00d4ff;
    padding-left: 16px;
  }
  h3 {
    color: #7c3aed;
    font-size: 1.2em;
  }
  strong {
    color: #00d4ff;
  }
  .danger { color: #ff4757; font-weight: 700; }
  .success { color: #2ed573; font-weight: 700; }
  .warning { color: #ffa502; font-weight: 700; }
  .muted { color: #8a8fa8; }
  table {
    font-size: 0.75em;
    border-collapse: collapse;
    width: 100%;
  }
  th {
    background: rgba(0, 212, 255, 0.15);
    color: #00d4ff;
    padding: 8px 12px;
    border: 1px solid rgba(0, 212, 255, 0.3);
  }
  td {
    padding: 6px 12px;
    border: 1px solid rgba(255, 255, 255, 0.1);
  }
  code {
    background: rgba(124, 58, 237, 0.2);
    color: #c4b5fd;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 0.85em;
  }
  blockquote {
    border-left: 3px solid #7c3aed;
    padding-left: 16px;
    color: #8a8fa8;
    font-style: italic;
    margin: 20px 0;
  }
---

<!-- _class: lead -->

# 🛡️ Lesson 05

## 暴力破解正在进行——你能把线索拼起来吗？

---

## 回顾：当前安全链路

```
攻击者 → WAF → Juice Shop → Suricata (NIDS)
                          ↓      ↓
                    Wazuh Agent → Wazuh Manager (新课)
                                    ↓
                              Dashboard (下节课)
```

WAF + NIDS + HIDS 都已部署，但日志分散在 4 个地方……

---

## 场景：eBay 1.45 亿用户泄露

> **2014 年，eBay 遭暴力破解攻击。事后发现：单个失败登录正常，但 10 分钟 5000 次就是明确攻击。**
>
> **问题：日志分散在各处，没有人把它们关联起来。**

你有 4 个安全组件，每个都在产生日志：

- WAF → ModSecurity 日志
- NIDS → Suricata 日志
- HIDS → Wazuh Agent 日志
- 应用 → 访问日志

**攻击者同时触发多个告警，但你无法关联它们。**

---

## 新架构：SIEM 上线

```
┌──────────────┐ ──── 日志 ────┐
│  WAF (Nginx) │               │
└──────┬───────┘               ▼
       ▼               ┌──────────────┐
┌──────────────┐       │              │
│ Juice Shop   │ ─ 日志 ─▶│ Wazuh Manager│
└──────────────┘       │   (SIEM)     │  ← 你的大脑
       ▼               │  关联分析    │
┌──────────────┐       │  暴力破解    │
│   Suricata   │ ─ 日志 ─┘│  检测       │
└──────────────┘       │
┌──────────────┐       │
│ Wazuh Agent  │ ─ 日志 ─┘
└──────────────┘
```

---

## 关键概念：暴力破解

> **暴力破解 (Brute Force)** — 通过大量尝试不同用户名/密码组合，猜出有效的登录凭证。

**类型：**
| 类型 | 描述 | 示例 |
|------|------|------|
| 简单暴力 | 尝试所有密码组合 | admin/123456, admin/password... |
| 字典攻击 | 使用常见密码字典 | rockyou.txt |
| 凭证填充 | 用其他站点泄露的凭证 | LinkedIn 泄露的密码试其他站点 |

**本实验的测试：**
```bash
for i in $(seq 1 60); do
  curl -s -X POST "http://localhost:80/api/users/login" \
    -d '{"email":"admin@test.com","password":"wrong'$i'"}' -o /dev/null
  sleep 0.2
done
```

---

## 为什么只有 SIEM 能检测

| 单个请求 | WAF 看法 | NIDS 看法 | 实际性质 |
|----------|---------|----------|---------|
| 1 次失败登录 | 合法 URL | 正常 TCP | 正常 |
| 1 次失败登录 | 合法 URL | 正常 TCP | 正常 |
| …… 重复 50 次/分钟 | 每个都正常 | 每个都正常 | <span class="danger">攻击！</span> |

> **单个事件无害，但组合起来就是攻击。** 只有 SIEM 能把时间窗口内的所有失败登录聚合起来识别模式。

---

## 关键概念：SIEM

> **SIEM (Security Information and Event Management)** — 安全信息与事件管理平台。

**核心功能：**
- 日志聚合（所有组件日志集中到一个平台）
- 解码解析（Decoder：原始日志 → 结构化数据）
- 规则匹配（Rule：模式匹配 → 告警生成）
- 关联分析（时间窗口 + 频率阈值 → 高级别告警）

**处理流水线：**
```
原始日志 → Decoder 解析字段 → Rule 匹配模式 → 生成 Alert
```

---

## 关联分析示例

| 场景 | 没有 SIEM | 有 SIEM |
|------|-----------|---------|
| 单次失败登录 | 正常 | 正常 |
| 50 次/分钟 | 分散，没人知道 | <span class="danger">暴力破解告警！</span> |
| 攻击链分析 | 不可能 | WAF + NIDS + HIDS = 完整路径 |
| 响应时间 | 数天到数周 | <span class="success">数分钟</span> |

**关联规则示例：**
```
规则: 同一源 IP 5 分钟内失败登录 > 20 次
触发: 暴力破解告警 (Severity: High)
```

---

## 关键概念：Decoder + Rule

**Decoder — 把不同格式的原始日志解析成统一的结构化数据：**

```
原始日志: "192.168.1.100 - - [01/Sep] POST /api/users/login 401"
    ↓ [Decoder]
  src_ip = 192.168.1.100
  method = POST
  url = /api/users/login
  status = 401
```

**Rule — 基于解析后的数据匹配攻击模式：**

```
IF status == 401 AND url contains "login" THEN ...
IF count(status==401, src_ip, 5min) > 20 THEN severity = High
```

---

## 动手验证

```bash
cd lesson-05
docker compose up -d

# 运行攻击演示
bash attack.sh

# 查看 SIEM 告警
docker compose exec wazuh-manager cat /var/ossec/logs/alerts/alerts.json | tail -10
```

---

## CISO 观察记录

| 检查项 | 状态 | 备注 |
|--------|------|------|
| WAF | <span class="success">✅</span> | HTTP 层 |
| NIDS | <span class="success">✅</span> | 网络层 |
| HIDS | <span class="success">✅</span> | 主机层 |
| SIEM | <span class="success">✅</span> | 日志集中 + 关联 |
| 暴力破解 | <span class="success">🛡️</span> | 关联规则触发 |
| Dashboard | <span class="danger">❌</span> | 还没有统一展示 |

> **单个事件无害，但组合起来就是攻击。关联分析是关键。**

---

## 下一课

→ SIEM 上线了，所有日志被集中，关联分析在运行。

**但安全团队需要一个直观的方式来理解整个安全态势——他们不想看 JSON 日志，不想 grep 告警文件。**

他们需要一张图——一个仪表盘，**一眼就能看到整个安全态势。**

下一课部署 **Dashboard，完成整个安全链路的最后一环。**
