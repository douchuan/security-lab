# Security Lab Demo

## 1. 项目概述

### 1.1 项目定位

这是一个面向实习生的 **网络安全 / 安全工程实践项目**。

项目通过 Docker Compose 搭建一个简化的企业网络安全环境，模拟真实安全体系中的完整链路：

> **攻击 → 防火墙 → WAF → NIDS/HIDS → SIEM → 安全告警 → 态势感知**

项目的重点不是开发新的安全产品，而是通过集成成熟的开源安全软件，让学生理解不同安全组件的职责，以及它们如何协同完成安全检测和分析。

### 1.2 项目目标

最终形成一个可以一键启动、容易理解、容易演示的 Security Lab。

学生可以通过预设的攻击场景触发安全事件，并在系统中观察：

1. 攻击行为产生
2. 网络层安全设备进行处理
3. WAF 检测 Web 攻击
4. NIDS 检测网络攻击
5. HIDS 检测主机异常
6. SIEM 收集和关联安全事件
7. Dashboard 展示安全态势

---

# 2. 项目面向的实习方向

项目主要面向：

* 网络安全
* 安全工程
* SOC / 安全运营
* 网络与系统安全
* DevSecOps

学生不需要开发底层 IDS、WAF 或 SIEM，而是重点学习**安全系统集成、部署、配置和安全事件分析**。

---

# 3. 核心安全链路

系统整体逻辑如下：

```text
                         Attacker
                            │
                            ▼
                     ┌─────────────┐
                     │  Firewall   │
                     └──────┬──────┘
                            │
                            ▼
                     ┌─────────────┐
                     │     WAF     │
                     └──────┬──────┘
                            │
                            ▼
                     ┌─────────────┐
                     │ Web Service │
                     │ Juice Shop  │
                     └──────┬──────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
       ┌─────────────┐             ┌─────────────┐
       │  Suricata   │             │    Wazuh    │
       │    NIDS     │             │    HIDS     │
       └──────┬──────┘             └──────┬──────┘
              │                           │
              └─────────────┬─────────────┘
                            ▼
                     ┌─────────────┐
                     │    SIEM     │
                     │    Wazuh    │
                     └──────┬──────┘
                            │
                            ▼
                     ┌─────────────┐
                     │  Dashboard  │
                     │  Security   │
                     │  Situation  │
                     └─────────────┘
```

---

# 4. 技术选型

项目优先使用成熟的开源软件。

## 4.1 Firewall

优先考虑：

* OPNsense
* pfSense

Firewall 主要负责：

* 网络边界控制
* NAT
* ACL
* IP / Port 访问控制

如果 Firewall 不适合直接运行在 Docker 中，可以作为独立 VM 部署。

---

## 4.2 WAF

使用：

* Nginx
* ModSecurity

主要用于：

* HTTP 请求检测
* SQL Injection 检测
* XSS 检测
* 常见 Web 攻击拦截

---

## 4.3 Web Service

使用：

**OWASP Juice Shop**

Juice Shop 是一个专门用于安全学习的漏洞 Web 应用。

用于模拟真实业务系统，并提供可重复的 Web 攻击场景。

---

## 4.4 NIDS

使用：

**Suricata**

主要负责：

* 网络流量检测
* Port Scan 检测
* 网络攻击特征检测
* IDS Rule 告警

---

## 4.5 HIDS / SIEM

使用：

**Wazuh**

负责：

* Host Monitoring
* Security Event Collection
* File Integrity Monitoring
* Log Analysis
* Security Rules
* Alert Management
* SIEM

---

## 4.6 Dashboard

优先使用 Wazuh / OpenSearch 提供的 Dashboard。

用于展示：

* 安全事件数量
* 攻击来源
* 攻击类型
* WAF 告警
* NIDS 告警
* HIDS 告警
* Security Events Timeline

---

# 5. Docker 网络设计

系统应该使用多个 Docker Network，模拟不同的网络区域。

建议：

```text
                    attacker
                       │
                       ▼
                external network
                       │
                       ▼
                  firewall
                       │
                 internal network
                       │
                       ▼
                     WAF
                       │
                  web network
                       │
                       ▼
                  web service
```

安全监控组件可以连接到对应的网络，用于采集日志或网络流量。

网络划分的目的不仅是部署方便，更重要的是让学生理解：

> 不同安全组件位于网络中的不同位置，负责不同层面的安全检测。

---

# 6. 第一阶段 MVP

第一阶段不要追求复杂。

必须首先实现以下链路：

```text
Attacker
   ↓
WAF
   ↓
Juice Shop
   ↓
Suricata / Wazuh
   ↓
Security Alert
   ↓
Dashboard
```

同时保证所有核心组件可以通过 Docker Compose 启动。

目标：

```bash
docker compose up -d
```

即可启动整个实验环境。

---

# 7. 攻击场景

项目至少提供三个可重复执行的攻击场景。

## Scenario 1：Port Scan

模拟攻击者进行端口扫描。

```text
Attacker
   ↓
Port Scan
   ↓
Suricata
   ↓
NIDS Alert
   ↓
Wazuh
   ↓
Dashboard
```

学生应该能够看到：

* 攻击来源
* 扫描目标
* 扫描时间
* 检测规则
* 告警级别

---

## Scenario 2：SQL Injection

模拟 SQL Injection。

```text
Attacker
   ↓
Malicious HTTP Request
   ↓
WAF
   ↓
ModSecurity
   ↓
SQL Injection Alert
   ↓
Dashboard
```

如果 WAF 配置为阻断模式，还应该能够看到：

```text
Request
   ↓
WAF
   ↓
BLOCK
```

---

## Scenario 3：Brute Force

模拟 Web 登录暴力破解。

```text
Attacker
   ↓
Multiple Login Attempts
   ↓
Web Service
   ↓
Access Log
   ↓
Wazuh
   ↓
Correlation
   ↓
Brute Force Alert
```

该场景用于展示：

> 单个请求可能并不构成攻击，但大量行为结合起来可以形成安全事件。

---

# 8. 安全事件模型

系统最终需要能够把不同来源的事件统一展示。

例如：

```text
Security Event

Event ID
Timestamp
Source IP
Destination IP
Source
Event Type
Severity
Description
Detection Rule
Status
```

事件来源包括：

* Firewall
* WAF
* Suricata
* Wazuh Agent
* Web Application

---

# 9. Dashboard

Dashboard 不要求实现复杂的商业级 SOC 平台。

重点是能够直观展示整个安全环境的状态。

建议至少包含：

### Security Overview

```text
Critical       3
High          17
Medium        43
Low          128
```

### Attack Types

```text
Port Scan
SQL Injection
XSS
Brute Force
Suspicious Process
File Modification
```

### Event Timeline

展示最近发生的安全事件。

### Source IP

展示攻击来源。

### Security Components

展示：

```text
Firewall     Online
WAF          Online
NIDS         Online
HIDS         Online
SIEM         Online
```

---

# 10. 学生需要掌握的专业技能

通过项目实践，学生应该获得以下能力：

### 网络安全

理解：

* Firewall
* WAF
* IDS / HIDS / NIDS
* SIEM
* SOC
* Security Event

### Linux

能够：

* 使用 Linux
* 查看系统日志
* 分析进程
* 配置网络
* 排查服务问题

### Docker

能够：

* 编写 Dockerfile
* 使用 Docker Compose
* 配置 Docker Network
* 管理多容器应用
* 排查容器之间的网络问题

### 安全工具

能够实际使用：

* ModSecurity
* Suricata
* Wazuh
* OpenSearch / Dashboard

### 安全分析

能够从：

```text
Network Traffic
       ↓
Log
       ↓
Alert
       ↓
Security Event
       ↓
Attack Scenario
```

分析一次完整的安全事件。

---

# 12. 实习最终成果

实习结束时，学生应该完成：

### 1. 一个完整的 Security Lab

能够通过 Docker Compose 启动。

### 2. 完整安全链路

能够展示：

> Attack → Firewall → WAF → NIDS/HIDS → SIEM → Dashboard

### 3. 至少三个攻击场景

包括：

* Port Scan
* SQL Injection
* Brute Force

### 4. 安全 Dashboard

能够展示安全事件和当前安全态势。

### 5. 项目文档

包括：

* 系统架构
* 部署方法
* 组件介绍
* 攻击场景
* 告警分析
* 常见问题

### 6. Demo Presentation

学生能够在 10～20 分钟内完成一次完整演示：

```text
启动系统
   ↓
执行攻击
   ↓
观察 WAF / NIDS / HIDS
   ↓
产生安全告警
   ↓
进入 SIEM
   ↓
Dashboard 展示
   ↓
解释整个安全链路
```

---

# 13. 验收标准

项目完成后，必须满足：

* [ ] Docker Compose 可以正常启动核心组件
* [ ] 各组件之间网络连通正常
* [ ] WAF 可以检测至少一种 Web 攻击
* [ ] Suricata 可以检测 Port Scan
* [ ] Wazuh 可以接收和分析安全日志
* [ ] 安全事件能够进入 SIEM
* [ ] Dashboard 能够看到安全事件
* [ ] 至少三个攻击场景可以重复执行
* [ ] 每个攻击场景都有对应的检测结果
* [ ] 项目具有完整 README
* [ ] 学生能够解释每一个安全组件在链路中的作用

---

# 14. 非目标

第一版不需要：

* 自研 WAF
* 自研 IDS
* 自研 SIEM
* 自研复杂前端
* 生产级高可用
* 大规模集群
* 云平台部署
* 复杂 Threat Intelligence
* 自动化攻击响应

重点是：

> **把成熟的开源安全组件组合起来，形成一个完整、可运行、可观察、可演示的安全链路。**

---

# 15. Claude Code 实现要求

Claude Code 应按照以下原则实现：

1. 优先选择成熟、稳定、文档完善的开源组件。
2. 尽可能使用 Docker Compose 完成部署。
3. 所有配置文件纳入 Git。
4. 不依赖人工修改容器内部配置。
5. 所有攻击场景都应该可以重复执行。
6. 每个组件的配置都应该有清晰注释。
7. README 必须能够让第一次接触项目的人完成部署。
8. 优先保证 MVP 链路完整，而不是增加大量组件。
9. 遇到技术复杂度较高的组件时，优先选择简单可靠的实现方案。
10. 每完成一个阶段，都应该提供可验证的运行结果。

最终目标不是“部署很多安全软件”，而是形成一个能够清晰展示：

> **网络攻击是如何产生的 → 安全设备在哪里检测 → 告警如何产生 → 日志如何进入 SIEM → 最终如何形成安全态势**

的完整教学 Demo。