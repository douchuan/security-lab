# 第五章 如何从大量日志中识别有意义的安全事件？

## 5.1 本章要解决的问题

前四章，我们逐步建立了四道防线：

1. **第一章**：我们发现应用暴露在互联网上，存在可被利用的风险。
2. **第二章**：我们在攻击者和应用之间部署了 WAF，可以在 HTTP 层面拦截部分攻击。
3. **第三章**：我们在网络侧部署了 NIDS，可以观察到端口扫描等侦察行为。
4. **第四章**：我们在主机侧部署了 FIM，可以检测到关键文件的变化。

每一道防线都在产生日志和告警。但此时，作为 CISO，你面临一个新的问题：

> **"WAF 有自己的日志，Suricata 有自己的告警，Wazuh Agent 也在发事件。如果攻击者同时触发了多个告警，我怎样才能把这些分散的线索拼成一张完整的图？"**

这个问题触及了安全运营的核心挑战：**日志分散、格式各异、缺乏关联。**

想象一个场景：攻击者先对 Juice Shop 发起 SQL 注入，被 WAF 拦截；接着尝试暴力破解登录，被应用拒绝；最后在服务器上修改了一个配置文件，被 FIM 捕获。三个独立的安全设备各自产生了一条记录，但没有任何一个设备告诉你："**同一个攻击者，在三分钟内，对你的系统发起了多阶段攻击。**"

这就是 **SIEM（Security Information and Event Management）** 要解决的问题。

本章结束后，你应该能够：

- 理解 SIEM 的核心能力：多源日志采集、归一化、关联分析和告警。
- 区分 **日志采集**、**日志解析**、**规则匹配** 和 **告警生成** 四个不同阶段。
- 解释 Wazuh 中 **Decoder** 和 **Rule** 的职责差异。
- 理解 Juice Shop 的 Morgan 格式日志和 ModSecurity 的 JSON 审计日志如何被统一处理。
- 通过暴力破解实验，验证 Wazuh Manager 的关联规则如何将多次低级别事件聚合为高级别告警。
- 理解"日志被采集 ≠ 日志被正确解析 ≠ 一定会生成告警"这条关键链路的含义。
- 理解 SIEM 的能力边界，以及规则驱动检测的局限。

## 5.2 SIEM 的理论基础

### 5.2.1 什么是 SIEM

SIEM 的全称是 **Security Information and Event Management**（安全信息与事件管理）。它是一套集中采集、归一化、存储、关联分析全网设备和应用日志，生成安全告警，支持审计取证的安全平台。

SIEM 的核心价值可以用一句话概括：**把分散在各处的安全日志汇总起来，做统一分析。**

在没有 SIEM 的环境中，安全人员需要分别登录 WAF 控制台、NIDS 管理界面、主机日志系统，逐一查看各自的事件。这不仅效率低，更重要的是——**攻击不会按照安全设备的边界来组织自己。**

一个典型的攻击链可能同时涉及：

- 网络层的端口扫描（Suricata 检测到）。
- 应用层的 SQL 注入（ModSecurity 拦截）。
- 认证层的暴力破解（Juice Shop 日志记录）。
- 主机层的文件篡改（Wazuh Agent FIM 捕获）。

如果每个设备只看到自己那一小部分，安全人员就需要手动拼凑全貌。SIEM 的目标是：**让所有日志到达同一个分析平台，通过规则关联，自动识别跨设备的安全事件。**

### 5.2.2 SIEM 的核心能力

| 能力 | 说明 |
|---|---|
| **多源日志采集** | 从网络设备、服务器、操作系统、中间件、数据库、云资源、应用系统采集日志 |
| **日志归一化** | 将不同厂商、不同格式的日志统一为结构化字段，方便检索和关联 |
| **日志长期存储** | 满足合规留存要求，用于事后溯源取证 |
| **关联规则引擎** | 基于规则识别已知攻击场景，例如短时间内同一 IP 的多次登录失败 |
| **告警管理** | 告警聚合、去重、分级和工单流转 |
| **合规报表** | 等保、PCI-DSS、行业审计报表 |
| **日志检索** | 事件发生后，快速检索原始日志进行排查 |

### 5.2.3 SIEM 的典型局限

理解 SIEM 的能力边界和理解它能做什么同样重要：

- **数据源以日志为主，缺少深度行为上下文。** SIEM 看到的是设备上报的事件，不是终端进程的行为、网络连接的状态或攻击者的意图。
- **以规则驱动为主。** 已知攻击模式可以被检测，但零日攻击和 APT（高级持续威胁）的检出能力较弱。
- **存在误报。** 规则无法完美区分正常行为和恶意行为，尤其在业务流量复杂的场景下。
- **原生没有响应能力。** SIEM 输出告警，但不会直接隔离主机、封禁 IP 或阻断账号。

### 5.2.4 补齐 SIEM 短板

实际的安全运营体系中，SIEM 通常与其他系统配合：

- **EDR（Endpoint Detection and Response）**：提供终端进程、注册表、内存等深度行为可见性。
- **SOAR（Security Orchestration, Automation and Response）**：SIEM 产生告警后，推送到 SOAR 平台，由 SOAR 调用各安全设备的 API 执行自动处置（封禁 IP、隔离主机、重置密码等）。
- **UEBA（User and Entity Behavior Analytics）**：基于行为基线和机器学习，识别偏离正常模式的异常行为，辅助发现未知威胁。

**教学说明**：本课程实验中的 Wazuh Manager 主要展示 SIEM 的日志采集、解析、规则匹配和告警能力。EDR、SOAR 和 UEBA 属于扩展能力，不在本次实验范围内。

### 5.2.5 日志收集器 vs SIEM

一个常见的混淆是：日志收集器和 SIEM 有什么区别？

| 维度 | 日志收集器 | SIEM（以 Wazuh 为例） |
|---|---|---|
| **核心职责** | 采集、传输日志 | 分析安全事件、识别威胁 |
| **输入** | 日志文件、事件流等 | 原始日志、结构化事件等 |
| **主要处理** | 读取、转发、必要的格式转换 | 解析、规则匹配、事件关联 |
| **输出** | 转发后的日志 | 安全告警，以及按配置保存的事件 |
| **核心价值** | 让日志到达目的地 | 帮助安全人员判断哪些事件值得调查 |

两者不是互斥的。实际上，Wazuh Agent 自身就包含 Logcollector（日志收集器），而 Wazuh Manager 进一步负责事件分析与告警。

## 5.3 Wazuh 作为 SIEM

### 5.3.1 Wazuh 简介

Wazuh 是一个开源的安全监控与威胁检测平台，用于集中分析主机、应用和其他安全设备产生的日志与事件，帮助安全团队发现威胁、调查事件并满足合规要求。

可以把它理解为一个轻量级的安全运营平台，集成了主机安全监控、日志分析、入侵检测和安全事件告警等能力。

在本课程的实验架构中，Wazuh 承担了两个角色：

- **Wazuh Agent**：部署在受监控的节点上，负责文件完整性监控（FIM，第四章）和日志采集（Logcollector，本章）。
- **Wazuh Manager**：接收来自 Agent 的日志和事件，进行解析、规则匹配、关联分析和告警生成。

### 5.3.2 实验架构

本章的实验环境与之前章节共享同一套 Docker Compose 基础设施：

```text
攻击者（宿主机）
   │
   ▼ http://localhost:80
Nginx + ModSecurity (WAF)
   │
   ▼ http://juice-shop:3000
Juice Shop (后端应用)
   │
   │ Docker Volumes
   │ ├── juice-shop-logs → access.log (Morgan 格式)
   │ └── modsec-log → audit.log (JSON 格式)
   │
   ▼
Wazuh Agent (logcollector + FIM)
   │ TCP :1514
   ▼
Wazuh Manager (Decoder → Rule → Alert)
```

数据流：

1. **Juice Shop** 产生 access log（Morgan combined 格式），写入 `juice-shop-logs` volume。
2. **ModSecurity** 产生审计日志（JSON 格式），写入 `modsec-log` volume。
3. **Wazuh Agent** 通过 `<localfile>` 配置读取这两个 volume 中的日志文件。
4. **Wazuh Agent** 将采集到的日志通过 TCP 协议（端口 1514）发送给 **Wazuh Manager**。
5. **Wazuh Manager** 对接收到的日志进行 Decoder 解析和 Rule 匹配。
6. 符合告警条件的事件被写入告警文件（`alerts.json`）。

### 5.3.3 启动实验环境

```bash
cd lesson-05
docker compose up -d
```

等待所有服务启动完成后，可以检查 Wazuh Manager 的 API 是否就绪：

```bash
curl -sf http://localhost:55000 -o /dev/null -w "%{http_code}"
# 预期返回 401（未认证），说明 API 已经运行
```

## 5.4 Wazuh 的日志处理流水线

这是本章最需要理解的核心机制。

**日志从产生到告警，需要经过四个不同的阶段：**

```text
原始日志 → 采集 → 解析（Decoder） → 检测（Rule） → 告警（Alert）
```

每个阶段都有独立的职责，任何一个阶段失败，都会导致最终无法产生预期的告警。

### 5.4.1 阶段一：日志产生

这是安全事件的起点。不同的组件产生不同格式的日志：

- **Juice Shop** 使用 Morgan 中间件记录 access log，格式类似于 Apache/Nginx 的 combined 格式：

  ```
  ::ffff:172.20.0.4 - - [11/Oct/2026:10:15:32 +0000] "POST /rest/user/login HTTP/1.1" 401 35 "http://localhost:80/" "curl/8.1.2"
  ```

- **ModSecurity** 的审计日志是 JSON 格式（由 `MODSEC_AUDIT_LOG_TYPE=Serial` 配置，所有审计日志写入单个文件）：

  ```json
  {
    "transaction": {
      "client_ip": "172.20.0.1",
      "request": {
        "uri": "/rest/user/login",
        "method": "POST"
      },
      "response": {
        "http_code": 403
      },
      "is_interrupted": true,
      "messages": [
        {
          "details": {
            "ruleId": "949110"
          }
        }
      ],
      "producer": {
        "modsecurity": "ModSecurity v3.x"
      }
    }
  }
  ```

### 5.4.2 阶段二：日志采集

Wazuh Agent 的 `ossec.conf` 中通过 `<localfile>` 配置指定要采集的日志文件：

```xml
<!-- Juice Shop Access Log -->
<localfile>
  <log_format>syslog</log_format>
  <location>/monitored/juice-shop/logs/access.log.*</location>
</localfile>

<!-- ModSecurity WAF 审计日志 -->
<localfile>
  <log_format>json</log_format>
  <location>/monitored/modsecurity/audit.log</location>
</localfile>
```

Agent 的 Logcollector 组件持续监控这些文件，当有新内容追加时，将其读取并发送给 Wazuh Manager。

**关键点**：`log_format` 告诉 Agent 使用什么方式读取文件，但它不决定如何解析内容。解析工作在 Manager 侧由 Decoder 完成。

### 5.4.3 阶段三：日志解析（Decoder）

**Decoder 的核心问题：这条日志包含什么信息？**

Wazuh Manager 接收到原始日志后，第一步是将其解析为结构化字段。

#### Decoder 的工作原理

假设 Linux SSH 服务产生了一条日志：

```
Feb 14 12:19:04 server sshd[25474]: Accepted password for alice from 192.168.1.133 port 49765 ssh2
```

Decoder 处理后，可以得到类似这样的结构化数据：

```json
{
  "program_name": "sshd",
  "dstuser": "alice",
  "srcip": "192.168.1.133",
  "srcport": "49765"
}
```

Wazuh 支持多种解析方式：

- **预置 Decoder**：Wazuh 已经提供常见日志格式（SSH、Apache、Nginx 等）的解析定义。
- **正则表达式**：使用匹配规则从非结构化文本中提取字段。
- **JSON Decoder**：解析 JSON 格式的日志。
- **自定义 Decoder**：针对尚未支持的应用日志编写解析规则。

#### Decoder 不是安全判断

**重要区分**：Decoder 只负责解析和提取字段，它不判断"这条日志是否意味着攻击"。它帮助安全分析人员识别事件，但不做安全结论。安全判断主要由 Rule 完成。

#### 本实验中的两个 Decoder

**1. Juice Shop 日志：内置 `web-accesslog` Decoder**

Juice Shop 的 access log 采用 Morgan combined 格式，与 Apache/Nginx 标准访问日志格式一致。Wazuh 内置的 `web-accesslog` Decoder 会自动解析这类日志，提取以下关键字段：

- `srcip`：客户端 IP 地址。
- `url`：请求的 URL 路径。
- `status`：HTTP 响应状态码。

不需要编写自定义 Decoder。

**2. ModSecurity 日志：自定义 `modsec-json` Decoder**

ModSecurity 的审计日志是 JSON 格式。Wazuh 内置的 JSON Decoder 可以解析所有 JSON 日志，但我们还需要一个更精确的识别机制——通过 `prematch` 确认这条 JSON 日志确实来自 ModSecurity：

```xml
<!-- configs/decoders/modsec-decoder.xml -->
<decoder name="modsec-json">
  <prematch>"transaction"</prematch>
  <plugin_decoder>JSON_Decoder</plugin_decoder>
</decoder>
```

`prematch` 的作用是：当原始日志中包含 `"transaction"` 字符串时，激活 `modsec-json` Decoder。然后 `JSON_Decoder` 插件会解析整个 JSON 对象，使 Rule 可以通过 `data.transaction.*` 路径访问嵌套字段。

**注意**：Wazuh 内置的 JSON Decoder 本身已经能够解析所有 JSON 日志。这里的自定义 Decoder 提供了更精确的来源识别（prematch），确保后续 Rule 可以准确区分 ModSecurity 日志和其他 JSON 日志。

### 5.4.4 阶段四：检测与告警（Rule）

**Rule 的核心问题：这条日志意味着什么？**

解析后的结构化事件进入规则引擎。Rule 根据条件判断事件是否匹配安全规则，必要时生成告警。

#### 本实验中的规则体系

规则定义在 `configs/local_rules.xml` 中。Wazuh 的自定义规则 ID 建议使用 `100000–120000` 范围，避免与内置规则（1–99999）冲突。

**第一部分：Juice Shop 暴力破解检测**

```xml
<!-- 规则 100001：检测到失败的登录尝试 -->
<rule id="100001" level="5">
  <if_sid>31101</if_sid>
  <match>/rest/user/login</match>
  <description>Failed login attempt on Juice Shop from $(srcip)</description>
</rule>
```

- `<if_sid>31101</if_sid>`：这条规则的前提是事件已经命中了内置规则 31101（Wazuh 对 Web 访问日志中 HTTP 4xx 状态码的基础分类规则）。这意味着日志必须首先被 `web-accesslog` Decoder 正确解析，提取出 `status` 字段为 4xx，才会进入 31101 的分类，然后本规则在此基础上进一步过滤。
- `<match>/rest/user/login</match>`：URL 必须包含 `/rest/user/login`，排除其他 4xx 响应（如 404 页面不存在）。
- `level="5"`：告警等级 5，表示中等严重程度的单次事件。

```xml
<!-- 规则 100002：暴力破解 — 频率关联分析 -->
<rule id="100002" level="10" frequency="8" timeframe="120">
  <if_matched_sid>100001</if_matched_sid>
  <same_source_ip />
  <description>Brute force attack detected — multiple failed logins from $(srcip)</description>
  <group>bruteforce,authentication,</group>
</rule>
```

这是本章最关键的关联规则。它的工作机制如下：

- Wazuh 维护一个计数器，跟踪每个源 IP 触发 rule 100001 的次数。
- `frequency="8"`：2 分钟内累计 8 次失败登录才触发此规则。
- `timeframe="120"`：时间窗口为 120 秒。
- `<same_source_ip />`：只统计同一源 IP 的事件，不同 IP 分别计数。
- `<if_matched_sid>100001</if_matched_sid>`：关联 rule 100001 的触发事件。
- `level="10"`：告警等级 10，表示高严重程度的聚合事件。

**重要教学说明**：`8/120` 的阈值适合实验环境快速验证。生产环境建议提高到 `frequency=20 timeframe=300`，以降低误报。具体的阈值需要根据业务流量和正常用户行为模式进行调整。

```xml
<!-- 规则 100003：暴力破解成功（失败后突然 200） -->
<rule id="100003" level="12">
  <if_sid>31150</if_sid>
  <match>/rest/user/login</match>
  <description>Possible successful brute force attack on Juice Shop from $(srcip)</description>
  <group>bruteforce,authentication,high_severity,</group>
</rule>
```

这条规则检测"多次失败后突然登录成功"的模式，`level="12"` 为最高严重等级之一。

**注**：rule 31150 可能在某些 Wazuh 版本中不存在。这条规则的实际效果取决于内置规则的具体定义。

**第二部分：ModSecurity WAF 告警**

```xml
<!-- 规则 100020：ModSecurity 父规则 -->
<rule id="100020" level="5">
  <match>"producer":{"modsecurity":"ModSecurity</match>
  <description>ModSecurity audit event detected from $(data.transaction.client_ip)</description>
  <group>waf,</group>
</rule>
```

- 通过 `match` 匹配原始日志中的 `"producer":{"modsecurity":"ModSecurity` 字符串，确认日志来自 ModSecurity。
- `$(data.transaction.client_ip)` 引用 JSON 解析后的嵌套字段。

```xml
<!-- 规则 100021：ModSecurity 拦截了请求 -->
<rule id="100021" level="7">
  <if_sid>100020</if_sid>
  <match>"is_interrupted":true</match>
  <description>ModSecurity blocked a request from $(data.transaction.client_ip)</description>
  <group>web_attack,waf,</group>
</rule>
```

- `<if_sid>100020</if_sid>`：前提是事件已命中 rule 100020。
- `"is_interrupted":true`：ModSecurity 的 JSON 日志中，`is_interrupted=true` 表示请求被拦截（返回 403）。

```xml
<!-- 规则 100022：ModSecurity 检测到 SQL 注入 -->
<rule id="100022" level="10">
  <if_sid>100021</if_sid>
  <match>"ruleId":"94</match>
  <description>ModSecurity blocked SQL injection attempt from $(data.transaction.client_ip)</description>
  <group>web_attack,waf,sqli,high_severity,</group>
</rule>
```

- `"ruleId":"94` 匹配 OWASP CRS 中 94x 系列的 SQL 注入规则 ID（如 `949110`）。

#### 规则层级关系

这六条规则形成了清晰的层级结构：

```
内置 31101 (Web 4xx)
  └── 100001 (Juice Shop 401 登录失败)
        └── 100002 (8 次/120s → 暴力破解关联告警)

内置 31150 (Web 200)
  └── 100003 (登录成功 + /rest/user/login → 可能暴力破解成功)

无前置 (原始匹配)
  └── 100020 (ModSecurity 审计事件)
        └── 100021 (请求被拦截 is_interrupted=true)
              └── 100022 (SQL 注入 ruleId:94x)
```

### 5.4.5 理解 Decoder 和 Rule 的关系

| 组件 | 核心问题 | 职责 |
|---|---|---|
| **Decoder** | 这条日志包含什么信息？ | 解析原始日志，提取结构化字段 |
| **Rule** | 这条日志意味着什么？ | 判断事件是否匹配安全规则 |
| **Alert** | 需要把什么事件交给安全人员？ | 记录符合告警条件的事件 |

> **重要**：Decoder 不负责判断攻击是否发生，它帮助识别和提取事件信息。安全判断主要由 Rule 及其关联条件完成。

### 5.4.6 验证工具：wazuh-logtest

在部署或修改规则后，应该使用 Wazuh Manager 内置的 `wazuh-logtest` 工具验证解析和匹配结果，而不是直接通过实际攻击来测试。

```bash
# 进入 Wazuh Manager 容器
docker compose exec wazuh-manager /var/ossec/bin/wazuh-logtest
```

然后输入日志样本，检查：

1. 是否命中了预期的 Decoder。
2. 关键字段（`srcip`、`url`、`status` 等）是否被正确提取。
3. 是否命中了对应的 Rule。
4. 告警等级是否符合预期。

**这是验证规则正确性的标准做法**，不需要每次都通过实际攻击来确认规则是否工作。

## 5.5 实验：两层攻击检测

### 5.5.1 实验目标

验证 Wazuh Manager 能否同时检测两类安全事件：

1. **WAF 层**：SQL 注入攻击被 ModSecurity 拦截并告警。
2. **业务层**：暴力破解登录被关联规则聚合为高级别告警。

### 5.5.2 实验环境检查

确保所有服务正常运行：

```bash
cd lesson-05
docker compose ps
```

确认 Wazuh Manager API 就绪：

```bash
curl -sf http://localhost:55000 -o /dev/null -w "%{http_code}"
# 预期返回 401（需要认证），说明 API 已运行
```

### 5.5.3 第一阶段：SQL 注入攻击

执行攻击脚本，或直接手动发送请求：

```bash
bash attack.sh
```

脚本会自动执行以下操作：

**Phase 1 — SQL 注入攻击（5 次尝试）：**

```bash
# 布尔注入：构造永真条件
curl -s "http://localhost:80/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"'\'' OR '\''1'\''='\''1","password":"test"}'

# UNION 注入：联合查询探测
curl -s "http://localhost:80/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"'\'' UNION SELECT NULL--","password":"test"}'

# 注释截断
curl -s "http://localhost:80/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin'\''--","password":"test"}'

# 破坏性注入
curl -s "http://localhost:80/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"'\''; DROP TABLE users--","password":"test"}'

# 复合注入
curl -s "http://localhost:80/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"'\'' OR 1=1; SELECT * FROM users--","password":"test"}'
```

**预期结果**：

- ModSecurity 拦截这些请求，返回 HTTP 403。
- ModSecurity 审计日志（JSON 格式）写入 `/var/log/modsecurity/audit.log`。
- 日志通过 Docker volume 被 Wazuh Agent 采集。
- Agent 将日志发送给 Wazuh Manager。
- Manager 通过 `modsec-json` Decoder 解析，匹配 rule 100020 → 100021 → 100022。

**查看 ModSecurity 审计日志**：

```bash
docker compose exec nginx-modsecurity tail -1 /var/log/modsecurity/audit.log
```

你应该看到包含 `"is_interrupted":true` 和 `"ruleId":"949110"` 的 JSON 记录。

### 5.5.4 第二阶段：暴力破解攻击

脚本继续执行 60 次失败登录尝试：

```bash
for i in $(seq 1 60); do
  curl -s -X POST "http://localhost:80/rest/user/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@test.com","password":"wrong_password_'$i'"}'
  sleep 0.2
done
```

**预期结果**：

- 每次请求返回 HTTP 401（认证失败）。
- Juice Shop 的 access log 记录每次请求，格式为 Morgan combined。
- 日志被 Wazuh Agent 采集。
- Manager 通过内置 `web-accesslog` Decoder 解析，提取 `srcip`、`url`、`status=401`。
- 事件命中内置规则 31101（Web 4xx）→ 自定义规则 100001（/rest/user/login 的 401）。
- 2 分钟内累计 8 次后，关联规则 100002 触发，生成 `level=10` 的暴力破解告警。

**查看 Juice Shop access log**：

```bash
docker compose exec wazuh-agent ls -la /monitored/juice-shop/logs/
docker compose exec wazuh-agent tail -3 /monitored/juice-shop/logs/access.log.*
```

你应该看到类似这样的记录：

```
::ffff:172.20.0.4 - - [11/Oct/2026:10:15:32 +0000] "POST /rest/user/login HTTP/1.1" 401 35 "http://localhost:80/" "curl/8.1.2"
```

### 5.5.5 等待关联分析

关联规则依赖时间窗口（`timeframe=120`）。在攻击完成后，需要等待一段时间让 Wazuh Manager 完成关联分析：

```bash
# 等待至少 120 秒
sleep 130
```

### 5.5.6 查看告警结果

查看 Wazuh Manager 的告警文件：

```bash
docker compose exec wazuh-manager cat /var/ossec/logs/alerts/alerts.json
```

你应该看到两类告警：

**WAF 层告警（rule 100022）：**

```json
{
  "timestamp": "2026-10-11T10:15:35.000+0000",
  "rule": {
    "id": "100022",
    "level": 10,
    "description": "ModSecurity blocked SQL injection attempt from 172.20.0.1",
    "groups": ["web_attack", "waf", "sqli", "high_severity"]
  },
  "data": {
    "transaction": {
      "client_ip": "172.20.0.1",
      "response": {"http_code": 403},
      "is_interrupted": true
    }
  }
}
```

**暴力破解关联告警（rule 100002）：**

```json
{
  "timestamp": "2026-10-11T10:16:05.000+0000",
  "rule": {
    "id": "100002",
    "level": 10,
    "description": "Brute force attack detected — multiple failed logins from 172.20.0.4",
    "groups": ["bruteforce", "authentication"],
    "frequency": 8
  }
}
```

### 5.5.7 告警统计

脚本会统计告警总数：

```bash
docker compose exec wazuh-manager wc -l /var/ossec/logs/alerts/alerts.json
```

你应该看到多条告警，包括：

- 多次 rule 100001（单次登录失败）。
- 至少 1 条 rule 100002（暴力破解关联告警）。
- 多次 rule 100020/100021/100022（ModSecurity 事件）。

## 5.6 深度分析：日志处理链路的关键区分

### 5.6.1 三个独立阶段

本章最重要的概念区分：

> **日志被采集 ≠ 日志被正确解析 ≠ 一定会生成告警**

这三个阶段独立存在，任何一个环节失败，都会导致最终"没有告警"。

| 阶段 | 配置位置 | 失败表现 | 排查方向 |
|---|---|---|---|
| **采集** | Agent `ossec.conf` 中的 `<localfile>` | Agent 未读取到日志文件 | 文件路径是否正确、volume 是否挂载、文件权限 |
| **解析** | Manager 侧 Decoder | 日志被接收但字段未提取 | Decoder 的 prematch 是否匹配、JSON 格式是否正确 |
| **检测** | Manager 侧 Rule | 日志已解析但无告警 | Rule 条件是否满足、前置规则（if_sid）是否命中、频率阈值是否达到 |

### 5.6.2 "没有告警"的可能原因

当你在 Wazuh Manager 中没有看到预期告警时，不要直接得出"攻击没有被检测到"的结论。需要逐一排查：

1. **日志是否产生？** 检查应用是否正常输出了日志。
2. **日志是否被 Agent 读取？** 检查 `ossec.conf` 中的路径和 volume 挂载。
3. **日志是否被正确解析？** 使用 `wazuh-logtest` 输入同样的日志，查看 Decoder 输出。
4. **Rule 条件是否满足？** 检查 `if_sid` 前置规则、`match` 条件、`frequency` 和 `timeframe`。
5. **时间窗口是否已过去？** 关联规则需要等待 `timeframe` 指定的时间。

### 5.6.3 日志格式变化对检测的影响

假设 ModSecurity 升级后修改了日志格式：

- 如果只改变了日志的外部表示（如缩进、字段顺序），而解析后的字段和语义保持不变，通常不需要修改 Decoder 和 Rule。
- 如果字段名称发生变化（如 `client_ip` → `source_ip`），Rule 中引用该字段的条件将无法匹配，导致告警漏报。
- 如果事件语义发生变化（如 `is_interrupted` 被移除或含义改变），Rule 的判断逻辑可能不再正确。

因此，**Decoder 将日志解析与检测规则分离，降低了维护成本；但真正的兼容性需要通过字段约定、规则设计和回归测试来保证。**

升级后的验证流程：

1. 保存有代表性的原始日志样本。
2. 使用 `wazuh-logtest` 验证 Decoder 和 Rule 的匹配结果。
3. 应用升级后，使用新版本的日志样本重新测试。
4. 检查关键事件是否仍然触发预期告警。
5. 监控日志量、解析异常和告警数量，及时发现异常变化。

## 5.7 拓展：自定义 Decoder 与统一日志语义

### 5.7.1 为什么需要自定义 Decoder

Wazuh 已经提供了大量内置 Decoder，覆盖了常见的日志格式（SSH、Apache、Nginx、Windows 事件日志等）。但在以下场景中，仍然需要编写自定义 Decoder：

- 应用的日志格式不在 Wazuh 的内置支持范围内。
- 需要从日志中提取特定的字段，用于后续规则匹配。
- 希望将不同应用的日志统一为共同的事件分类，便于关联分析。

### 5.7.2 统一日志语义的示例

假设我们有三个系统，分别输出以下日志：

```
# Linux SSH
Failed password for admin from 192.168.1.10 port 51234 ssh2

# 某个应用
event=fail user=admin srcip=192.168.1.10

# 另一个应用
{"event":"password_failed","user":"admin","srcip":"192.168.1.10"}
```

它们的格式不同，但如果经过确认，三条日志确实都表示一次登录失败，我们希望最终得到类似的语义：

| 语义 | 示例值 |
|---|---|
| 事件类型 | authentication failure |
| 用户 | `admin` |
| 来源 IP | `192.168.1.10` |

**注意**：这张表表达的是我们希望建立的统一语义，并不是说 Wazuh 会自动将所有日志转成这个结构。这需要通过自定义 Decoder 和 Rule 来实现。

### 5.7.3 接入新日志源的标准流程

```text
日志接入                  事件解析                  安全检测
   │                        │                        │
   ▼                        ▼                        ▼
Agent / localfile        Decoder                 Rule
   │                        │                        │
   ▼                        ▼                        ▼
读取原始日志             提取结构化字段           匹配检测条件
```

| 步骤 | 主要配置 | 作用 |
|---|---|---|
| 传输与采集 | Docker volume、`ossec.conf` 中的 `<localfile>` | 让 Agent 能够读取目标日志 |
| 解析 | 内置 Decoder 或自定义 Decoder | 提取源 IP、URL、事件类型等字段 |
| 检测 | 内置规则或 `local_rules.xml` 中的自定义规则 | 判断事件是否符合检测条件，必要时生成告警 |

**不是每种日志都必须编写自定义 Decoder。** Wazuh 可能已经提供适用的解析器；JSON 日志也可以使用内置 JSON Decoder。选择哪种方式取决于日志格式、应用能力和现有架构。

## 5.8 常见故障排查

### 5.8.1 告警文件为空

如果 `/var/ossec/logs/alerts/alerts.json` 为空，按以下顺序排查：

1. **检查 Wazuh Manager 日志**：

   ```bash
   docker compose exec wazuh-manager tail -20 /var/ossec/logs/ossec.log
   ```

   查看是否有 Decoder 解析错误、Rule 加载失败或连接问题。

2. **检查 Agent 连接状态**：

   ```bash
   docker compose exec wazuh-manager tail -10 /var/ossec/logs/ossec.log | grep -i agent
   ```

3. **验证日志文件是否可读**：

   ```bash
   docker compose exec wazuh-agent cat /monitored/juice-shop/logs/access.log.* | tail -3
   docker compose exec wazuh-agent cat /monitored/modsecurity/audit.log | tail -3
   ```

### 5.8.2 只看到单次登录失败，没有暴力破解告警

这通常意味着关联规则 100002 的条件未满足：

1. **检查频率是否达到**：需要至少 8 次 rule 100001 命中。确认单次登录失败告警是否存在。
2. **检查时间窗口**：`timeframe=120` 表示 120 秒。如果请求间隔过长，可能不在同一窗口内。
3. **检查源 IP 是否一致**：`<same_source_ip />` 要求所有事件来自同一 IP。容器网络中的源 IP 可能与预期不同。

### 5.8.3 ModSecurity 告警缺失

1. **确认 ModSecurity 产生了审计日志**：

   ```bash
   docker compose exec nginx-modsecurity cat /var/log/modsecurity/audit.log
   ```

2. **确认 volume 已正确挂载**：Agent 应该能够读取 `/monitored/modsecurity/audit.log`。
3. **使用 wazuh-logtest 验证**：

   ```bash
   docker compose exec wazuh-manager /var/ossec/bin/wazuh-logtest
   # 输入一条 ModSecurity JSON 日志样本
   ```

   检查是否命中 `modsec-json` Decoder 和 rule 100020/100021/100022。

## 5.9 能力边界与局限

理解 SIEM 的能力边界，是建立正确安全思维的关键。

### 5.9.1 规则驱动的局限

Wazuh Manager 的检测机制主要依赖预定义的 Rule。这意味着：

- **已知模式可以被检测**：SQL 注入、暴力破解、端口扫描等有明确特征的攻击。
- **未知模式可能漏报**：零日攻击、定制化攻击、低频慢速攻击（low and slow）可能不触发任何规则。
- **存在误报**：正常用户也可能在 2 分钟内输错 8 次密码。

### 5.9.2 日志覆盖范围

SIEM 只能分析它收到的日志。如果某个安全事件没有产生日志，或者日志没有被采集到 SIEM，那么 SIEM 对此事件就完全不可见。

例如：

- 攻击者通过 SSH 直接登录服务器，不经过 Web 应用。如果 SSH 日志没有被采集，SIEM 不会知道。
- 攻击者利用内部网络漏洞横向移动，流量不经过 Suricata 的监控点。
- 内部人员直接在主机上复制了敏感文件，不产生网络流量和 Web 请求。

### 5.9.3 告警不等于已确认的安全事件

产生告警只意味着"某个规则的条件被满足了"，不等于"系统已经被入侵"。

安全人员需要进一步调查：

- 告警是否由合法用户的行为触发？（误报）
- 攻击是否被成功执行，还是被防护层拦截？
- 多个告警是否指向同一个攻击者？还是可以独立解释？

### 5.9.4 SIEM 不负责自动响应

Wazuh Manager 生成了告警，但它不会自动封禁 IP、隔离主机或重置密码。告警需要被安全人员查看、调查和处置。

如果需要自动响应，需要引入 SOAR（Security Orchestration, Automation and Response）系统，将 SIEM 的告警转化为自动处置动作。

**教学说明**：本实验中的 Wazuh Agent 配置了 `<active-response><disabled>yes</disabled></active-response>`，即主动响应功能被禁用。这是为了避免实验环境中的自动封禁行为影响后续实验。

## 5.10 本章总结

回顾本课的实验目的：将分散在不同组件中的安全日志汇聚起来，解析日志内容，通过规则识别安全事件，并统一查看告警。

### 5.10.1 完整数据流

```text
Juice Shop → access.log (Morgan) ─┐
                                  │ Docker Volume
ModSecurity → audit.log (JSON) ──┤
                                  │
                                  ▼
                            Wazuh Agent (logcollector)
                                  │ TCP :1514
                                  ▼
                            Wazuh Manager
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
              Decoder        Rule          Alert
           (解析提取字段)   (匹配条件)    (生成告警)
```

### 5.10.2 核心结论

1. **日志被采集，不等于它已经被正确解析。** Agent 读取了日志文件，但 Decoder 可能因为格式不匹配而无法提取字段。
2. **日志被解析，不等于它一定会生成告警。** Decoder 正确提取了字段，但 Rule 的条件可能不满足（如频率阈值未达到、前置规则未命中）。
3. **SIEM 的价值不只是集中保存日志。** 它将不同来源的事件转化为可分析的信息，通过规则检测和事件关联，帮助安全人员发现值得调查的行为。
4. **Decoder 和 Rule 各司其职。** Decoder 负责解析和提取，Rule 负责安全判断。两者通过结构化字段衔接，降低维护成本。
5. **规则驱动的检测有明确的能力边界。** 已知模式可检测，未知模式可能漏报，存在误报可能。告警不等于已确认的安全事件。

### 5.10.3 与前后章节的关系

- **承上**：前四章部署的 WAF、NIDS、HIDS 各自产生日志，本章展示了如何将这些日志汇聚到 SIEM 进行统一分析。
- **启下**：下一章将通过 Wazuh Dashboard 的可视化和检索能力，从实际告警定位证据并开展基础调查，将 SIEM 的分析结果转化为可操作的调查结论。

## 5.11 练习

1. **验证 Decoder 解析**：使用 `wazuh-logtest` 分别输入一条 Juice Shop 的 401 日志和一条 ModSecurity 的 JSON 审计日志，确认它们各自命中了哪些 Decoder 和 Rule。

2. **修改暴力破解阈值**：将 rule 100002 的 `frequency` 从 8 改为 3，重新执行暴力破解攻击，观察告警是否在更少的尝试次数后触发。思考：生产环境中为什么不建议使用这么低的阈值？

3. **日志格式变更模拟**：修改攻击脚本，使其在请求中包含一个额外的自定义 Header，观察这是否影响 Wazuh 的日志解析和告警生成。

4. **思考题**：如果攻击者使用了多个不同的源 IP 地址发起暴力破解（如通过代理池），本实验中的 `<same_source_ip />` 关联规则还能检测到吗？如果不能，如何设计更健壮的检测规则？

5. **拓展阅读**：查阅 Wazuh 官方文档，了解除了 `frequency` + `timeframe` + `same_source_ip` 之外，Rule 还支持哪些关联条件（如 `different_urls`、`if_matched_group` 等），并思考它们分别适用于什么场景。
