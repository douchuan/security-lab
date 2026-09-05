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
  section {
    background: var(--color-bg);
    font-size: 28px;
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
  .footer-text {
    position: absolute;
    bottom: 16px;
    left: 24px;
    font-size: 0.5em;
    color: #8a8fa8;
  }
  .page-number {
    position: absolute;
    bottom: 16px;
    right: 24px;
    font-size: 0.5em;
    color: #8a8fa8;
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
| Lesson 01 | 应用裸奔在公网 | 理解攻击面 |
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

# 🚨 Lesson 01

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

> **结论：发现问题只是第一步，下一步是解决问题。**

---

<!-- _class: lead -->

# 🚨 Lesson 02

## SQL 注入正在发生——部署第一道防线

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

## 攻击 vs 防御对比

| 攻击类型 | 无 WAF | 有 WAF |
|----------|--------|--------|
| SQL 注入 | <span class="danger">💀 直达后端</span> | <span class="success">🛡️ 403 拦截</span> |
| XSS | <span class="danger">💀 直达后端</span> | <span class="success">🛡️ 403 拦截</span> |
| 目录遍历 | <span class="danger">💀 直达后端</span> | <span class="success">🛡️ 403 拦截</span> |

```bash
# 正常请求 — 应通过
curl http://localhost:80

# SQL 注入 — 应被拦截
curl "http://localhost:80/rest/products/search?q=%27%20OR%201%3D1%20--"
# → 403 Forbidden
```

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

<!-- _class: lead -->

# 🚨 Lesson 03

## 有人在扫描你的网络——你能看见吗？

---

## 场景：Target 4000 万信用卡被盗

> **2013 年，攻击者通过端口扫描发现 HVAC 供应商的薄弱入口，横向移动进入 Target 核心网络。**
>
> 如果有 NIDS 监控流量，端口扫描会被立刻检测到。

WAF 已部署，但 SOC 团队报告：

- 有未知 IP 正在对服务器进行**端口扫描**
- 他们在探测开放端口和运行服务
- **这是攻击前的侦察**

---

## 新架构：NIDS 上线

```
  ☠️ 攻击者
       ▼
┌──────────────┐
│  WAF (Nginx) │  ← 应用层防护
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

## NIDS vs WAF 互补

| 攻击类型 | WAF 能看到？ | NIDS 能看到？ |
|----------|-------------|--------------|
| SQL 注入 | ✅ 能 | ❌ |
| XSS | ✅ 能 | ❌ |
| <span class="danger">端口扫描</span> | <span class="danger">❌ 看不到</span> | <span class="success">✅ 能！</span> |
| 网络协议攻击 | <span class="danger">❌ 看不到</span> | <span class="success">✅ 能！</span> |

```bash
# 运行攻击演示
bash attack.sh

# 查看 Suricata 告警
docker compose exec suricata cat /var/log/suricata/eve.json
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

<!-- _class: lead -->

# 🚨 Lesson 04

## 你的服务器文件被篡改了——谁干的？

---

## 场景：Uber 文件篡改事件

> **2016 年，攻击者获得 AWS 凭证后修改内部系统文件，窃取 5700 万用户信息。Uber 支付赎金试图掩盖——最终被罚 1.48 亿美元。**

WAF + NIDS 都已部署，但你仍然担心：

- **如果攻击者已经进来了呢？**
- 他们正在服务器上修改文件：植入后门、修改配置、删除日志
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

## 三层防御对比

| 威胁类型 | WAF | NIDS | HIDS |
|----------|-----|------|------|
| SQL 注入 | ✅ | ❌ | ❌ |
| 端口扫描 | ❌ | ✅ | ❌ |
| <span class="danger">文件篡改</span> | ❌ | ❌ | <span class="success">✅ 只有 HIDS</span> |
| <span class="danger">可疑进程</span> | ❌ | ❌ | <span class="success">✅ 只有 HIDS</span> |
| <span class="danger">Rootkit</span> | ❌ | ❌ | <span class="success">✅ 只有 HIDS</span> |

```bash
# 模拟文件篡改
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

<!-- _class: lead -->

# 🚨 Lesson 05

## 暴力破解正在进行——你能把线索拼起来吗？

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

## SIEM 的核心价值

| 问题 | 没有 SIEM | 有 SIEM |
|------|-----------|---------|
| 单次失败登录 | 正常 | 正常 |
| 50 次/分钟 | 分散，没人知道 | <span class="danger">暴力破解告警！</span> |
| 攻击链分析 | 不可能 | WAF + NIDS + HIDS = 完整路径 |
| 响应时间 | 数天到数周 | <span class="success">数分钟</span> |

```bash
# 手动暴力破解测试
for i in $(seq 1 60); do
  curl -s -X POST "http://localhost:80/api/users/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@test.com","password":"wrong'$i'"}' -o /dev/null
  sleep 0.2
done
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

<!-- _class: lead -->

# 🚨 Lesson 06

## 你的作战指挥中心——端到端全链路

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
  攻击者 → WAF → NIDS → HIDS → SIEM → Dashboard
                    应用层    网络层   主机层   聚合层   展示层
```

**六层防御，一气呵成。**

---

## 完整防御矩阵

| 攻击类型 | WAF | NIDS | HIDS | SIEM | Dashboard |
|----------|:---:|:----:|:----:|:----:|:---------:|
| SQL 注入 | 🛡️ | | | 📋 | 📊 |
| XSS | 🛡️ | | | 📋 | 📊 |
| 端口扫描 | | 🛡️ | | 📋 | 📊 |
| 文件篡改 | | | 🛡️ | 📋 | 📊 |
| 暴力破解 | | | | 🛡️ | 📊 |

---

## Dashboard 面板

| 面板 | CISO 看到的问题 |
|------|-----------------|
| Security Overview | 我的安全状态有多糟？ |
| Attack Types | 我们主要面临哪些威胁？ |
| Event Timeline | 攻击在什么时候最密集？ |
| Source IPs | 攻击者从哪里来？ |
| Component Health | 我的防御体系完整吗？ |
| Alert Table | 我现在需要处理哪些告警？ |

**访问：https://localhost:443 （admin / admin）**

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

## 课程要求

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
