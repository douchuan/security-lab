# 🛡️ Lesson 04

## 你的服务器文件被篡改了——谁干的？

---

## 回顾：当前安全链路

```
攻击者 → WAF → Juice Shop → Suricata (NIDS)
                          ↓
                    Wazuh Agent (新课) → SIEM → Dashboard
```

WAF + NIDS 都已部署。但如果攻击者已经进了主机呢？

---

## 完整性

Bootkit & RootKit, 微软推动 secureboot & tpm

盗版盛行

- secure boot, tpm
- ubuntu iso
  - https://cdimage.ubuntu.com/ubuntu/releases/24.04.5/release/
- linux IMA (Integrity Measurement Architecture)
- linux kernel


### linux kernle 验签演示

todo:
- 公钥验签的基本原理 
- gpg 介绍

```bash

# import keys belonging to Linus Torvalds and Greg Kroah-Hartman
gpg --locate-keys torvalds@kernel.org gregkh@kernel.org

# list imported keys
gpg -k

# download kernel source
# https://www.kernel.org/

unxz linux-7.2.8.tar.xz
gpg --verify linux-7.2.8.tar.sign
```

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

## 关键概念：文件篡改

> **文件篡改 (File Tampering)** — 攻击者获得主机权限后，修改系统文件、创建后门、植入恶意代码。

**常见篡改行为：**
| 行为 | 目的 |
|------|------|
| 修改 `/etc/passwd` | 创建后门账户 |
| 修改 Web 文件 | 植入 WebShell |
| 删除日志文件 | 销毁攻击痕迹 |
| 修改 cron 任务 | 持久化恶意代码 |
| 安装 Rootkit | 隐藏恶意进程 |

**本实验模拟：**
```bash
docker exec juice-shop touch /tmp/.hidden_backdoor
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

---

## 关键概念：Wazuh Agent

**Wazuh Agent** — 部署在受监控主机上的轻量级代理。

**核心功能：**
- **文件完整性监控 (FIM)** — 监控关键文件的创建、修改、删除
- **日志监控** — 收集和分析系统日志
- **进程监控** — 检测可疑进程
- **Rootkit 检测** — 扫描系统中可能存在的 Rootkit

> 它是你在主机层的"眼睛"——从内部监控系统状态。

---

## 关键概念：FIM

> **FIM (File Integrity Monitoring)** — 文件完整性监控，持续监控关键文件和目录的变化。

**工作原理：**
```
基线快照 → 持续对比 → 发现变化 → 生成告警
  (初始)     (运行时)     (差异)      (通知)
```

**典型监控目标：**
- `/etc/passwd`, `/etc/shadow` — 用户账户
- `/etc/crontab` — 定时任务
- Web 根目录 — WebShell 植入
- 系统二进制文件 — Rootkit 替换

**Wazuh Agent 告警类型：**

| 来源 | Rule | 含义 |
|------|------|------|
| syscheck (FIM) | 550 | 文件校验和变化 |
| syscheck (FIM) | 553 | 文件被删除 |
| syscheck (FIM) | 554 | 新增文件 |
| SCA | 19007-19009 | CIS 安全基线合规检查 |
| ossec | 501/502 | Agent 上下线、Manager 启动 |

> FIM 就是 syscheck——同一个模块的两个名字。`grep 'syscheck'` 即可筛选出所有文件完整性告警。

> FIM 只检测和告警，不阻止。阻止需要访问控制或不可变文件系统。

---

## FIM 工作原理

**两轮扫描，一次 Diff：**

```
第 1 轮（基线）              第 2 轮（对比）
遍历监控目录 ───────→ 建立基线 ───────→ 再次遍历
                       ↓                  ↓
               记录每个文件的：       与基线逐条对比：
               • MD5/SHA256          • 文件不在基线 → 新增 (Rule 554)
               • 权限/UID/GID         • hash 变了     → 修改 (Rule 550)
               • inode/mtime          • 基线文件消失 → 删除 (Rule 553)
               ↓                  ↓
               无告警（仅建库）      发现差异 → 生成告警 → 发送至 Manager
```

**关键要点：**

> 篡改必须发生在基线建立**之后**，才能被检测为"变化"。如果篡改与基线扫描同时进行，文件会被当作正常状态收录，不会产生告警。

---

## NIDS vs HIDS

| 维度 | NIDS (Suricata) | HIDS (Wazuh Agent) |
|------|----------------|-------------------|
| 监控位置 | 网络接口 | 主机系统 |
| 数据来源 | 网络流量包 | 系统日志、文件、进程 |
| 擅长检测 | 端口扫描、协议攻击 | 文件篡改、Rootkit |
| 盲区 | 主机内部活动 | 未安装 Agent 的主机 |
| 比喻 | 摄像头看大楼入口 | 监控看每个房间 |

> **最佳实践：同时部署 NIDS + HIDS，互补而非替代。**

---

## 动手验证

```bash
cd lesson-04
docker compose up -d

# 运行攻击演示（自动等待基线 → 篡改 → 检测）
bash attack.sh

# 手动查看 Manager 端 FIM 告警
docker exec wazuh-manager sh -c \
  "grep 'syscheck' /var/ossec/logs/alerts/alerts.json | tail -5"
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

## 下一课

→ HIDS 上线了，但你遇到了一个新问题：**你有 4 个安全组件，每个都在产生日志。**

WAF 日志、Suricata 日志、Wazuh Agent 日志、应用访问日志……

**攻击者同时触发了多个组件的告警，但你无法把它们关联起来。**

下一课部署 **SIEM，将所有日志集中到一个平台进行关联分析。**

---

## 参考资料

| 文档 | 链接 |
|------|------|
| Wazuh FIM 官方文档 | https://documentation.wazuh.com/current/user-manual/capabilities/file-integrity/index.html |
| FIM 配置指南 | https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/syscheck.html |
| FIM 告警 Rule ID | https://documentation.wazuh.com/current/rule-reference/ruleset-fim.html |
| Wazuh Agent 安装 | https://documentation.wazuh.com/current/installation-guide/wazuh-agent.html |
| Wazuh 架构 | https://documentation.wazuh.com/current/getting-started/architecture.html |

