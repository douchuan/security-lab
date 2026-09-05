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

# 🛡️ Lesson 06

## 你的作战指挥中心——端到端全链路

---

## 回顾：当前安全链路

```
攻击者 → WAF → NIDS → HIDS → SIEM → Dashboard (新课)
          ↓      ↓       ↓       ↓
        应用层  网络层   主机层   聚合层   展示层
```

前五层都已在工作，但缺少最后一块拼图——**可视化**。

---

## 场景：SolarWinds 供应链攻击

> **2020 年，SolarWinds 攻击影响 18000+ 组织。攻击者潜伏数月才被检测到。**
>
> **如果有一个全景态势感知系统，每个阶段都能被看到。**

你的团队需要一个**作战指挥中心**：

- 今天有多少攻击？什么类型？
- 攻击从哪里来？
- 每个安全组件还在线吗？
- 哪些告警最紧急？

**如果没有可视化，团队是在黑暗中操作。**

---

## 完整架构：全链路

```
  攻击者
     ▼
┌──────────────┐ ──── 日志 ────┐
│  WAF (Nginx) │               │  ← 应用层防御
└──────┬───────┘               │
       │                       ▼
       ▼               ┌──────────────┐
┌──────────────┐       │              │
│ Juice Shop   │ ─ 日志 ─▶│  Wazuh       │
└──────────────┘       │   Manager    │  ← 你的大脑 (SIEM)
       │               │   (SIEM)     │
       ▼               │  关联分析    │
┌──────────────┐       │  告警生成    │
│   Suricata   │ ─ 日志 ─┘
│   (NIDS)     │
└──────────────┘       ┌──────────────┐
┌──────────────┐       │  OpenSearch  │  ← 你的存储
│ Wazuh Agent  │ ────▶ │  (索引引擎)   │
│   (HIDS)     │       └──────┬───────┘
└──────────────┘              │
                              ▼
                       ┌──────────────┐
                       │   Wazuh      │  ← 你的指挥中心
                       │  Dashboard   │     https://localhost:443
                       └──────────────┘
```

---

## 完整防御矩阵

| 攻击类型 | WAF | NIDS | HIDS | SIEM | Dashboard |
|----------|:---:|:----:|:----:|:----:|:---------:|
| SQL 注入 | 🛡️ | | | 📋 | 📊 |
| XSS | 🛡️ | | | 📋 | 📊 |
| 端口扫描 | | 🛡️ | | 📋 | 📊 |
| 文件篡改 | | | 🛡️ | 📋 | 📊 |
| 暴力破解 | | | | 🛡️ | 📊 |

> 🛡️ = 直接检测/拦截 &nbsp;&nbsp; 📋 = 记录并聚合 &nbsp;&nbsp; 📊 = 可视化展示

---

## Dashboard 面板

| 面板 | CISO 看到的问题 |
|------|----------------|
| Security Overview | 我的安全状态有多糟？ |
| Attack Types | 我们主要面临哪些威胁？ |
| Event Timeline | 攻击在什么时候最密集？ |
| Source IPs | 攻击者从哪里来？ |
| Component Health | 我的防御体系完整吗？ |
| Alert Table | 我现在需要处理哪些告警？ |

**访问：https://localhost:443（admin / admin）**

---

## 关键概念：OpenSearch

**OpenSearch (Wazuh Indexer)** — 分布式搜索与分析引擎。

- Elasticsearch 的开源分支
- 存储和索引所有安全事件数据
- 为 Dashboard 提供查询和聚合能力

**数据流：**
```
Wazuh Manager → OpenSearch → Wazuh Dashboard
    (处理)         (存储)        (展示)
```

---

## 纵深防御总结

```
Layer 1 — WAF (应用层)    → 拦截 SQL 注入、XSS、目录遍历
Layer 2 — NIDS (网络层)   → 检测端口扫描、网络攻击
Layer 3 — HIDS (主机层)   → 监控文件篡改、可疑进程
Layer 4 — SIEM (分析层)   → 关联分析、暴力破解检测
Layer 5 — Dashboard (展示) → 全局态势感知
```

> **每一层都有自己的盲区，但也有自己独到的视角。多层组合 = 完整的威胁可见性。**

---

## 六课通关总结

| 课 | 安全事件 | 行动 | 能力 |
|----|----------|------|------|
| 01 | 应用裸奔 | 部署并理解危险性 | 攻击面 |
| 02 | SQL 注入 | 部署 WAF | Web 防火墙 |
| 03 | 网络扫描 | 部署 NIDS | 网络检测 |
| 04 | 文件篡改 | 部署 HIDS | 主机检测 |
| 05 | 暴力破解 | 部署 SIEM | 关联分析 |
| 06 | 缺乏可见性 | 部署 Dashboard | 端到端可视化 |

> **攻击发生 → WAF 拦截 → NIDS 检测 → HIDS 监控 → SIEM 聚合 → Dashboard 展示**

---

## 动手验证：端到端攻击

```bash
cd lesson-06
docker compose up -d       # 首次启动需要 2-3 分钟

# 验证所有组件
docker compose ps

# 运行端到端攻击演示
bash attack.sh
```

脚本依次执行：
1. 💉 SQL 注入 → WAF 检测
2. 🔍 端口扫描 → Suricata 检测
3. ☠️ 暴力破解 → Wazuh 关联检测
4. ⏳ 等待告警聚合
5. 📋 打印 Dashboard 访问指引

---

## 继续探索

课程完成了，但安全之路才刚开始。

建议继续探索：
- 编写 ModSecurity 自定义规则
- 尝试 Suricata 的 IPS 模式（从被动检测到主动拦截）
- 扩展 Wazuh 规则，检测更多类型的威胁
- 研究真实企业安全架构（SOC、SOAR、威胁情报集成）

> **SolarWinds 的教训：没有 100% 的安全。纵深防御意味着即使一层被突破，其他层仍然在保护你。**

---

<!-- _class: lead -->

# 🛡️ 安全之路才刚开始

## 没有 100% 的安全——纵深防御是唯一的出路

---

## 快速开始

```bash
# 选择你的战场
cd lesson-01

# 启动防御环境
docker compose up -d

# 运行攻击，观察效果
bash attack.sh

# 查看日志
docker compose logs -f

# 清理
docker compose down
```

## 系统要求

| 课程 | 内存 | CPU |
|------|------|-----|
| Lesson 01-03 | 2 GB | 2 核 |
| Lesson 04-06 | 8 GB | 4 核 |

---

<!-- _class: lead -->

# 🙏 感谢参与

> **保持好奇，保持警惕。**

<div class="muted" style="margin-top: 40px;">

Security Lab — CISO 安全事件响应实践课程

</div>
