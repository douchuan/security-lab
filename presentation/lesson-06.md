# 🛡️ Lesson 06

## 回顾：当前安全链路

![siem](./06/siem.png)

安全链路的部署已基本完成，让我们补上最后一块拼图: **可视化**。

---

## 全链路架构

```
  攻击者
     ▼
┌─────────────────────────────────────────────────────┐
│              被监控的主机/容器                       │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │  WAF (Nginx) │  │ Juice Shop   │  │ Suricata  │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘ │
│         │                 │                │       │
│         ▼                 ▼                ▼       │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ Wazuh Agent  │  │ Wazuh Agent  │  │Wazuh Agent│ │
│  │  (WAF 主机)  │  │  (JS 主机)   │  │ (NIDS主机)│ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘ │
│         │                 │                │       │
│         └─────────────────┼────────────────┘       │
│                           │                        │
└───────────────────────────┼────────────────────────┘
                            │ 采集并转发日志
                            ▼
                     ┌──────────────┐
                     │  Wazuh       │
                     │  Manager     │  ← 你的大脑 (SIEM)
                     │  (SIEM)      │    关联分析、告警生成
                     └──────┬───────┘
                            │ 发送分析后的告警
                            ▼
                     ┌──────────────┐
                     │  Wazuh       │  ← 你的存储
                     │  Indexer     │    (OpenSearch)
                     │  (OpenSearch)│
                     └──────┬───────┘
                            │ 查询
                            ▼
                     ┌──────────────┐
                     │  Wazuh       │  ← 你的指挥中心
                     │  Dashboard   │    https://localhost:443
                     └──────────────┘
```

新增组件
- Wazuh Indexer
- Wazuh Dashboard

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

## DQL — Dashboard Query Language

在 Dashboard 中筛选和检索告警，使用的是 **DQL**（Dashboard Query Language）。
它运行在 OpenSearch Dashboards 搜索栏中，语法直观，底层自动转换为 Lucene 查询。

### 基本语法：`字段名: 值`

| 场景 | DQL 查询 |
|------|----------|
| WAF 告警 | `rule.groups: waf` |
| SQL 注入 | `rule.groups: sqli` |
| 高严重级别 | `rule.level >= 7` |
| 特定规则 | `rule.id: 100022` |
| 组合条件（AND） | `rule.groups: waf AND rule.level >= 10` |
| 组合条件（OR） | `rule.groups: sqli OR rule.groups: xss` |
| 排除某类事件 | `NOT rule.groups: sca` |
| 通配符匹配 | `data.transaction.request.uri: /rest/*` |

### 实操技巧

1. 在 Dashboard 搜索栏直接输入 DQL 即可实时过滤
2. 点击事件字段可快速添加筛选条件（自动构建 DQL）
3. 用 `rule.level >= 7` 快速定位高风险告警，避免告警疲劳

---

## SIEM 日志存储与成本控制

部署 SIEM（如 Wazuh）时，需要关注日志持续增长带来的存储成本。日志保留策略应综合考虑**监管要求、业务需求和预算限制**。

- **明确保留要求**：根据适用的法律法规、行业规范及企业审计要求，确定日志类型和保留期限。
- **实施分层存储**：近期、高价值的安全日志用于在线检索与分析；需要长期保留的日志可采用低成本归档存储。
- **控制存储成本**：通过日志过滤、合理设置索引范围和自动清理策略，避免无差别地长期存储所有日志。

**核心原则：在满足合规与审计要求的前提下，制定合理的日志保留和存储方案，平衡安全价值与存储成本。**

## Cloud Security 集成方式

![Cloud Security Integration](06/cloud-security.png)


Wazuh 不仅可以通过 Agent 监控云主机，还可以接入云平台及 SaaS 服务产生的安全日志，集中进行安全分析、告警和审计。

不同云服务提供的数据接口不同，因此 Wazuh 采用多种方式采集日志。

### 常见集成方式

| 集成方式 | 基本原理 | 典型场景 |
|---|---|---|
| REST API 拉取 | 定期调用云服务 API 获取审计日志或安全事件 | GitHub、Microsoft 365、部分 Azure 服务 |
| 云存储读取 | 从对象存储中读取云服务生成的日志文件 | AWS S3、Azure Blob Storage、Google Cloud Storage |
| 消息队列订阅 | 从消息队列中接收云平台转发的日志 | Google Cloud Pub/Sub |
| Agent 采集 | 在云主机中安装 Wazuh Agent，采集系统日志和安全事件 | AWS EC2、Azure VM、Google Cloud VM |
| 日志转发 | 通过 syslog 或其他日志传输机制接入外部系统日志 | 网络设备、应用程序及其他安全产品 |

具体支持的采集方式取决于对应的 Wazuh 集成模块和云服务能力。

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

## 继续探索

课程完成了，但安全之路才刚开始。

建议继续探索：
- 编写 ModSecurity 自定义规则
- 尝试 Suricata 的 IPS 模式（从被动检测到主动拦截）
- 扩展 Wazuh 规则，检测更多类型的威胁
- 研究真实企业安全架构（SOC、SOAR、威胁情报集成）

---

## 安全之路才刚开始

毕业后，如何持续更新和迭代自己的知识 ？

建议: 考取各类证书，以考促学，在备考过程中系统性地提升自己。

取得证书之后，可以加入一个持证者圈子, 帮助你拓展人脉、交流经验，带来新的职业机会。

下面整理了几类较有价值的证书及其颁发机构，并从证书内容、含金量、考后收益三个维度进行细化说明:

注意:
- CISSP、CISA、CISM 这类高级认证，申请认证时需要数年相关工作经验
- 维持成本：证书通常需要每年积累继续教育学分（CPE） 并缴纳年费来维持有效性

<html>
<table style="border-collapse: collapse; width: 100%; font-size: 14px;">
  <thead>
    <tr>
      <th style="border: 1px solid #ccc; padding: 8px; text-align: left;">证书名称</th>
      <th style="border: 1px solid #ccc; padding: 8px; text-align: left;">颁发机构</th>
      <th style="border: 1px solid #ccc; padding: 8px; text-align: left;">考试内容</th>
      <th style="border: 1px solid #ccc; padding: 8px; text-align: left;">含金量</th>
      <th style="border: 1px solid #ccc; padding: 8px; text-align: left;">收益</th>
    </tr>
  </thead>
  <tbody>
    <!-- ===== 偏管理类 ===== -->
    <tr style="background-color: #eaf3fb;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>CISSP</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">ISC2</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>信息安全“通才”认证</strong>，覆盖8大知识域：安全与风险管理、资产安全、安全工程、通信与网络安全、身份与访问管理、安全评估与测试、安全运营、软件开发安全。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>安全领域“金牌标准”</strong>，全球公认的权威认证，侧重体系构建与管理，是安全架构师、CISO的必备或优先资质。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>薪资溢价显著</strong>（平均高出20%-40%），岗位方向为安全架构师、安全顾问、CISO。国内持证者稀缺，在金融、互联网大厂认可度极高。</td>
    </tr>
    <tr style="background-color: #eaf3fb;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>CISA</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">ISACA</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>IT审计“专业”认证</strong>。覆盖信息系统审计流程、IT治理、系统开发实施、运营与业务韧性、信息资产保护五大领域，侧重审计视角。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>IT审计领域的权威资质</strong>。在四大会计师事务所、金融机构内审、合规风控部门需求旺盛，是从事IT审计业务的“标配”。</td>
      <td style="border: 1px solid #ccc; padding: 8px;">职业路径清晰：<strong>内部审计</strong>（企业内审）或<strong>外部审计</strong>（事务所）。持证者平均薪资比未持证者高25%-40%，在强监管行业优势明显。</td>
    </tr>
    <tr style="background-color: #eaf3fb;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>CISM</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">ISACA</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>信息安全管理“经理”认证</strong>。聚焦四大管理领域：安全治理、风险管理、安全项目开发、事件管理。强调<strong>从管理者视角做决策</strong>。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>从技术岗转向管理岗的“认证背书”</strong>。与CISSP互补，CISSP是“架构师”，CISM更接近“安全总监”。在国企、政府、金融机构的管理岗招聘中认可度高。</td>
      <td style="border: 1px solid #ccc; padding: 8px;">专为<strong>安全经理、GRC负责人、准CISO</strong>设计。帮助技术人员建立商业语言和风险沟通能力。</td>
    </tr>
    <tr style="background-color: #eaf3fb;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>PMP</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">PMI</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>项目管理“通用”认证</strong>。基于《PMBOK®指南》，覆盖<strong>人员、过程、业务环境</strong>三大领域，考察预测型、敏捷型和混合型项目管理方法论。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>项目管理领域的“国际通行证”</strong>。全球认可度极高，是IT、工程、制造等行业<strong>项目经理岗位的硬通货</strong>。国内一线城市将其纳入人才引进目录。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>薪资提升明显</strong>（PMI官方报告显示中位数高出17%-24%）。是<strong>技术骨干转向管理岗</strong>的系统性学习路径，能显著提升流程把控与团队协同能力。</td>
    </tr>
    <tr style="background-color: #eaf7ee;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>OSCP</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">OffSec</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>渗透测试“实操”认证</strong>。考试为<strong>24小时纯实操</strong>，需攻破多台靶机并撰写专业报告，考察漏洞利用、权限提升、缓冲区溢出等真实攻击能力。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>渗透测试领域的“黄金标准”</strong>，证明持证人具备<strong>真刀真枪的实战能力</strong>，而非纸上谈兵。在红队、渗透测试岗位招聘中具有决定性优势。</td>
      <td style="border: 1px solid #ccc; padding: 8px;">直接对口<strong>渗透测试工程师、红队成员</strong>。全球认可度高，是求职安全服务岗位的强力敲门砖。需注意，新版OSCP+要求三年续证。</td>
    </tr>
    <tr style="background-color: #eaf7ee;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>RHCE</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">Red Hat</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>企业级Linux“实操”认证</strong>。<strong>全程上机操作</strong>，基于RHEL 9，重点考察<strong>Ansible自动化</strong>、系统安全管理、网络服务配置、容器基础等。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>Linux运维领域的“事实标准”</strong>。以“没有选择题，全靠真本事”著称，持证者被认为具备真实的生产环境操作能力，在金融、电信、政府项目招标中常被明确要求。</td>
      <td style="border: 1px solid #ccc; padding: 8px;">是<strong>Linux运维、SRE、DevOps工程师</strong>的基石认证。打好Linux底层基础后，向容器（CKA）、云原生方向进阶会事半功倍，职业生命周期长。</td>
    </tr>
    <tr style="background-color: #eaf7ee;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>AWS认证</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">AWS</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>按层级和方向划分</strong>。<strong>Solution Architect</strong>验证架构设计；<strong>Security</strong>聚焦安全专项；<strong>AI</strong>（如AI Practitioner）验证AI/ML基础。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>云计算领域的绝对领导者</strong>。全球市场占有率第一，认证是进入云计算领域的有效凭证，能证明持证者掌握行业标准技术栈。</td>
      <td style="border: 1px solid #ccc; padding: 8px;">提升在<strong>云架构师、云安全、云运维</strong>岗位的竞争力。企业招聘云岗位时，AWS认证是重要的能力信号，有助于获得面试机会和薪资谈判优势。</td>
    </tr>
    <tr style="background-color: #eaf7ee;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>Microsoft认证</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">Microsoft</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>按角色和技能划分</strong>。涵盖Azure云、安全、数据、AI等，分为<strong>Fundamentals（基础）、Associate（助理）、Expert（专家）</strong>等层级，也有基于实操的<strong>Applied Skills</strong>。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>企业级IT环境的通用凭证</strong>。在大量使用Microsoft技术栈的企业中认可度高。<strong>Applied Skills</strong>以实验室实操形式验证特定任务能力，更贴近实际工作。</td>
      <td style="border: 1px solid #ccc; padding: 8px;">验证特定技术领域的实操能力，有助于<strong>在现有企业内获得晋升或承担更重要的项目</strong>。官方数据显示，持证者获得晋升的比例和展现创新能力均更高。</td>
    </tr>
    <tr style="background-color: #eaf7ee;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>CISCO认证</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">Cisco</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>网络技术分级体系</strong>：<strong>CCNA</strong>（入门）、<strong>CCNP</strong>（高级）、<strong>CCIE</strong>（专家）。方向涵盖路由交换、<strong>安全</strong>、<strong>自动化</strong>等。CCIE是网络领域顶级认证。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>网络技术领域的“黄金标准”</strong>。尤其是<strong>CCIE</strong>，被公认为IT业最权威的认证之一。在传统网络、运营商、大型企业基础架构岗位中具有极高声望。</td>
      <td style="border: 1px solid #ccc; padding: 8px;">是<strong>网络工程师、网络架构师</strong>的经典成长路径。CCIE持证者在就业市场具有极强的议价能力，职业发展天花板高。</td>
    </tr>
    <tr style="background-color: #eaf7ee;">
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>HCIE</strong></td>
      <td style="border: 1px solid #ccc; padding: 8px;">华为</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>专家级ICT认证</strong>。以<strong>实验考试</strong>为最大挑战（长达8小时），考察真实场景下的<strong>云平台搭建、业务部署、故障排查</strong>等综合能力。</td>
      <td style="border: 1px solid #ccc; padding: 8px;"><strong>国内ICT领域的顶级认证</strong>。在华为生态合作伙伴、政府采购项目中具有<strong>明显竞争优势</strong>。随着企业云化转型，HCIE云计算等方向持证者薪资持续攀升。</td>
      <td style="border: 1px solid #ccc; padding: 8px;">主要面向<strong>华为生态内的云架构师、高级工程师、解决方案专家</strong>。平均年薪已突破三十万元，在政企市场和相关集成商中认可度极高。</td>
    </tr>
  </tbody>
</table>
</html>

## AI

![](./06/march_of_ai_progress.png)

伙伴 ？敌人 ？ 

历史的车轮谁都无法阻挡

打不过 AI, 就加入

用新工具解决新问题，才是面向未来最可靠的路径

---

## 🙏 感谢参与

Security Lab — CISO 安全事件响应实践课程

没有 100% 的安全 —— **保持警惕**
