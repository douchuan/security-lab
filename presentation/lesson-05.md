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

## 关键问题：SIEM 不会自动读懂你的日志

> **Wazuh 不认识 Juice Shop 的日志，也不认识你的应用日志。** 它必须经过配置才能解析每个日志源。

**我们当前的日志源：**

| 组件 | 日志格式 | Wazuh 内置 Decoder | 需要额外工作 |
|------|---------|-------------------|-------------|
| WAF (ModSecurity) | syslog | ✅ 内置 | 配置传输 |
| NIDS (Suricata) | JSON (eve.json) | ✅ 内置 | 配置传输 |
| HIDS (Wazuh Agent) | 内部格式 | ✅ 内置 | 无 |
| **Juice Shop** | 自定义 JSON | ❌ **无** | **写 decoder + 写 rule + 配传输** |

**三步缺一不可：**

```
传输 (Transport) → 解码 (Decoder) → 告警 (Rule)
      ↓                  ↓                ↓
  日志到达 Manager   解析成结构化字段   定义什么算攻击
```

**没有 Decoder = 日志进了 SIEM 也只是"存在那里"，不会被分析、不会被关联、不会产生告警。**

**这就是 SIEM 和简单日志收集器的区别：**
- 日志收集器（如 Filebeat）：只管搬运，把日志从 A 送到 B
- SIEM（Wazuh Manager）：搬过来之后，你必须告诉它**怎么读**、**什么是异常**

---

## 深度思考：日志格式变了怎么办？

一个自然的担忧：如果 ModSecurity 改了日志格式、Juice Shop 换了输出方式，Wazuh 的 Decoder 不就失效了吗？

**答案是：会失效。但生态通过以下机制保持稳定：**

### 1. 标准化格式是行业共识

- Apache/Nginx **combined log format** 是 20 多年前的标准，几乎所有 Web 服务器都遵循
- ModSecurity JSON audit log、Suricata eve.json 由项目定义，版本迭代时保持向后兼容
- CEF、LEEF、Syslog RFC 5424 是安全设备通用的交换格式

这些格式之所以稳定，是因为**下游生态（SIEM、日志分析、审计工具）都依赖它们**。一旦改了，下游全断——所以上游软件项目会极力避免 Breaking Change。

### 2. Decoder 层做解耦——格式变了只改 Decoder

```
原始日志 → Decoder（解析为结构化字段） → Rule Engine（基于字段匹配） → Alert
```

如果上游改了日志格式：
- **只需要更新对应的 Decoder**（正则或 JSON 字段映射）
- **Rule 层不需要改**（因为规则基于的是结构化后的字段名，不是原始文本）
- 这就是解耦的价值

### 3. 自定义日志的处理方式

如果你的应用输出了完全自定义的日志格式：
- 写一个**自定义 decoder**（就像我们对 ModSecurity 做的那样）
- 在应用层改用标准格式输出（改配置）
- 用 Fluentd/Logstash 做中间转换，把非标日志转为标准格式再喂给 SIEM

### 4. 真实企业的做法

大厂有专门的 **Log Engineering 团队**，维护内部日志规范 + Fluentd/Vector 统一转发。中小公司用社区现成的 Decoder，上游升级时跟着改配置文件。

**核心就是：SIEM 不假设日志格式永远不变，而是通过 Decoder 这一层做抽象隔离。格式变了就换 Decoder，Rule 不变。**

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
