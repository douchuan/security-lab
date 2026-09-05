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

# 🛡️ Security Lab

## 你是 CISO，你会怎么做？

> 一套基于真实安全事件的沉浸式网络安全实践课程

---

## 课程概览

> **攻击 → 防火墙 → WAF → NIDS/HIDS → SIEM → 安全告警 → 态势感知**

| 课程 | 安全事件 | 防御能力 |
|------|----------|----------|
| **Lesson 01** | 应用裸奔在公网 | 理解攻击面 |
| Lesson 02 | SQL 注入攻击 | WAF 拦截 |
| Lesson 03 | 网络端口扫描 | NIDS 检测 |
| Lesson 04 | 文件被篡改 | HIDS 监控 |
| Lesson 05 | 暴力破解撞库 | SIEM 关联分析 |
| Lesson 06 | 缺乏全局可见性 | Dashboard 可视化 |

---

## 技术架构

```
                         攻击者
                            │
                            ▼
                     ┌─────────────┐
                     │  Firewall   │
                     └──────┬──────┘
                            │
                            ▼
                     ┌─────────────┐
                     │     WAF     │  ← 应用层
                     └──────┬──────┘
                            │
                            ▼
                     ┌─────────────┐
                     │ Juice Shop  │  ← 业务应用
                     └──────┬──────┘
              ┌─────────────┴─────────────┐
              ▼                           ▼
       ┌─────────────┐             ┌─────────────┐
       │  Suricata   │             │   Wazuh     │
       │    NIDS     │             │    HIDS     │
       └──────┬──────┘             └──────┬──────┘
              └─────────────┬─────────────┘
                            ▼
                     ┌─────────────┐
                     │    SIEM     │  ← 关联分析
                     │   Wazuh     │
                     └──────┬──────┘
                            ▼
                     ┌─────────────┐
                     │  Dashboard  │  ← 作战大屏
                     └─────────────┘
```

---

<!-- _class: lead -->

# 🛡️ Lesson 01

## 你的应用正在裸奔

---

## 场景：Equifax 的教训

> **2017 年，Equifax 因未修补的 Apache Struts 漏洞导致 1.47 亿人数据泄露，罚款 7 亿美元。**

作为新任 CISO，你在第一次安全审计中发现：

- 公司 Web 应用直接暴露在公网
- 没有任何防护层
- 任何人都能访问、攻击、注入
- 被攻击了你也不会知道

---

## 当前架构（裸奔状态）

```
  ☁️ 互联网（任何人）
       │
       ▼  ← 没有任何防护！
┌──────────────┐
│ Juice Shop   │  ← 已知包含多种漏洞
│  端口 3000    │
└──────────────┘
```

**风险：你的应用完全暴露，没有防火墙、WAF、监控、日志分析。**

---

## 动手验证

```bash
# 启动应用
cd lesson-01
docker compose up -d

# 验证运行
curl http://localhost:3000/rest/products

# 运行攻击演示 — 展示脆弱性
bash attack.sh
```

攻击脚本展示：
1. ✅ 应用正常响应
2. 🔓 公开 API 无访问控制
3. 💉 SQL 注入**直达后端**，无任何拦截

---

## CISO 观察记录

| 检查项 | 状态 | 风险 |
|--------|------|------|
| 应用可访问 | ✅ | 正常 |
| 有 WAF 保护 | <span class="danger">❌</span> | 恶意请求直达后端 |
| 有日志监控 | <span class="danger">❌</span> | 被攻击了不知道 |
| 有入侵检测 | <span class="danger">❌</span> | 端口扫描毫无感知 |

---

## 关键概念：攻击面

> **攻击面 (Attack Surface)** — 系统暴露给潜在攻击者的所有入口点的总和。

**Juice Shop 内置漏洞：**
- SQL 注入（搜索框、登录表单）
- 跨站脚本 XSS（评论、用户输入）
- 不安全的直接对象引用（IDOR）
- JWT 令牌操纵
- 敏感信息泄露

> **暴露越多 = 风险越大。发现问题只是第一步，下一步是解决问题。**

---

## 下一课

→ 在下一课中，你将在应用前面部署 **WAF（Web 应用防火墙）**，拦截 SQL 注入、XSS 等 Web 攻击。

**Equifax 的教训：** 如果及时部署了 WAF 并修补了已知漏洞，7 亿美元的罚款本来可以避免。
