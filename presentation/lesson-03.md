# 法律知识

刑法修正案（七）在刑法第285条中增加两款（第二款、第三款）

> 违反国家规定，侵入前款规定以外的计算机信息系统或者采用其他技术手段，获取该计算机信息系统中存储、处理或者传输的数据，或者
> 对该计算机信息系统实施非法控制，情节严重的，处三年以下有期徒刑或者拘役，并处或者单处罚金；情节特别严重的，处三年以上七年
> 以下有期徒刑，并处罚金。

> 提供专门用于侵入、非法控制计算机信息系统的程序、工具，或者明知他人实施侵入、非法控制计算机信息系统的违法犯罪行为而为其提供
> 程序、工具，情节严重的，依照前款的规定处罚。

原则：

- 没有授权，不要扫描别人
- 没有授权，不要进行漏洞验证
- 安全实验必须在自己控制或者明确授权的环境中进行

# 护网

**护网行动**（也叫 "护网"、业内常称 "HVV/HW"）是由公安机关（公安部网安部门）组织的国家级网络安全实战攻防演习，自 2016 年起常态化开展，一般安排在每年年中到秋季，全国范围内的政府机关、金融、能源、交通、运营商等关键信息基础设施单位都要参加。

核心目的: 

- 用真实的攻击来检验重点单位的网络防护和应急处置能力
- 及时发现并整改深层次的漏洞隐患，检验关键信息基础设施的安全防护水平
- 强化重点单位、社会力量与公安机关的协同作战能力
- 通过实战提高攻防双方的技术对抗、决策指挥和应急处置能力

<html style="margin:0;padding:0;">
<title>护网行动攻防演练结构示意</title>
<div style="width:100%;box-sizing:border-box;font-family:-apple-system,'PingFang SC','Microsoft YaHei',sans-serif;background:#f7f9fc;padding:20px 16px;border-radius:12px;">
  <div style="font-size:16px;font-weight:700;color:#1a202c;text-align:center;">护网行动：国家级网络安全实战攻防演习（示意）</div>
  <div style="font-size:12px;color:#718096;text-align:center;margin:4px 0 16px;">组织方定规则 → 红蓝对抗 → 裁判记分 → 整改提升</div>

  <div style="display:flex;justify-content:center;margin-bottom:10px;">
    <div style="background:#2c3e50;color:#fff;border-radius:8px;padding:10px 18px;text-align:center;min-width:240px;">
      <div style="font-weight:700;">公安部（网安部门）· 组织方</div>
      <div style="font-size:13px;opacity:.9;margin-top:4px;">制定规则 · 组建队伍 · 评定成绩 · 通报整改</div>
    </div>
  </div>
  <div style="text-align:center;color:#718096;font-size:13px;margin-bottom:10px;">▼ 下达任务 / 提供支撑</div>

  <div style="display:flex;flex-wrap:wrap;gap:10px;justify-content:center;align-items:stretch;">
    <div style="flex:1;min-width:180px;background:#fdecec;border:2px solid #d64541;border-radius:8px;padding:12px;">
      <div style="font-weight:700;color:#c53030;">红队（攻击方）</div>
      <div style="font-size:13px;color:#555;margin-top:6px;">安全厂商、研究机构的专业队伍，模拟真实黑客，用渗透测试、漏洞挖掘、0day 等手段"不限路径"发起攻击，拿到权限或数据即得分</div>
    </div>
    <div style="display:flex;align-items:center;font-size:14px;color:#2c3e50;font-weight:600;">实网攻击 →</div>
    <div style="flex:1;min-width:180px;background:#eef4ff;border:2px solid #2b6cb0;border-radius:8px;padding:12px;">
      <div style="font-weight:700;color:#2b6cb0;">目标单位系统</div>
      <div style="font-size:13px;color:#555;margin-top:6px;">政府、金融、能源、交通、运营商等关键信息基础设施，使用真实生产环境进行演练</div>
    </div>
    <div style="display:flex;align-items:center;font-size:14px;color:#2c3e50;font-weight:600;">← 值守防守</div>
    <div style="flex:1;min-width:180px;background:#e6f4ef;border:2px solid #2f855a;border-radius:8px;padding:12px;">
      <div style="font-weight:700;color:#276749;">蓝队（防守方）</div>
      <div style="font-size:13px;color:#555;margin-top:6px;">被护单位的安全、运维、开发团队，7×24 小时监测流量日志、研判告警、封堵阻断、应急溯源，目标是最小化攻击损失</div>
    </div>
  </div>

  <div style="display:flex;justify-content:center;margin:14px 0;">
    <div style="background:#f3e8ff;border:2px solid #6b46c1;border-radius:8px;padding:10px 18px;text-align:center;min-width:240px;">
      <div style="font-weight:700;color:#553c9a;">紫队（裁判 / 仲裁）</div>
      <div style="font-size:13px;color:#555;margin-top:4px;">规则判定与记分 · 审批关键操作 · 监督"禁止破坏性操作、不得影响业务"</div>
    </div>
  </div>

  <div style="display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin-top:12px;align-items:center;">
    <div style="background:#fff;border:1px solid #cbd5e0;border-radius:6px;padding:8px 12px;font-size:13px;">发现问题漏洞</div>
    <div style="color:#718096;font-size:14px;">→</div>
    <div style="background:#fff;border:1px solid #cbd5e0;border-radius:6px;padding:8px 12px;font-size:13px;">限时整改</div>
    <div style="color:#718096;font-size:14px;">→</div>
    <div style="background:#fff;border:1px solid #cbd5e0;border-radius:6px;padding:8px 12px;font-size:13px;">通报与考核</div>
    <div style="color:#718096;font-size:14px;">→</div>
    <div style="background:#e6fffa;border:1px solid #319795;border-radius:6px;padding:8px 12px;font-size:13px;font-weight:600;color:#234e52;">提升整体防护能力</div>
  </div>
</div>
</html>

---

# 🛡️ Lesson 03

有人在扫描你的网络——你能看见吗？

---

## 杀伤链

洛克希德·马丁公司创建了一个网络杀伤链框架，其中包含 7 个有序的攻击阶段:

1. 侦察: 攻击者收集有关目标的信息
2. 武器化: 攻击者识别目标可供利用的漏洞，以及发送漏洞利用点的方法
3. 交付: 攻击者通过网络钓鱼攻击、恶意电子邮件附件、被操纵的网站或其他常用社会工程伎俩向目标发送武器。
4. 利用: 武器利用目标系统的漏洞
5. 安装: 开发可以利用漏洞并安装恶意软件的代码。恶意软件通常包含后门，允许目标远程访问系统
6. 指挥和控制: 攻击者维护一个指挥和控制系统，以控制目标和其他被操纵的系统
7. 目标行动: 攻击者达成自己的最初目标，如偷盗钱财、盗窃数据、破坏数据或安装额外的恶意代码（如勒索软件）等

## 扫描

扫描的目的就是在侦察阶段，收集目标的信息，包括端口、服务、协议等，结合 CVE 数据库，识别目标系统中的漏洞。

**每个端口 = 一个潜在入口：**

| 端口 | 常见服务 | 风险 |
|------|---------|------|
| 22 | SSH | 远程管理入口 |
| 80 | HTTP | Web 服务 |
| 3306 | MySQL | 数据库（不应暴露） |
| 3000 | Node.js | 应用服务 |

## 信息搜集

信息收集的目标：

- 目标主机: 获取其端口的开放情况和网络服务的详细信息
- 目标网络: 网络拓扑结构
- 目标应用/服务以及目标人: 收集了解目标人的行为习惯、兴趣爱好，是进行针对性社会工程学攻击的必要条件 

## 扫描原理

![扫描原理](./03/scan_principle.png)

## 主流操作系统指纹示例

Linux 系统指纹

![Linux 系统指纹](./03/linux_fingerprint.png)

Windows 系统指纹

![Windows 系统指纹](./03/win_fingerprint.png)

## nmap

常见工具扫描工具: nmap

它本质上是在发送探测报文，然后观察目标主机的响应

扫描行为:

```
攻击者
   │
   ├── TCP SYN → 22
   ├── TCP SYN → 80
   ├── TCP SYN → 443
   ├── TCP SYN → 3306
   └── TCP SYN → 8080
```

目标主机:

```
22    → SYN/ACK → OPEN
80    → SYN/ACK → OPEN
443   → RST     → CLOSED
3306  → 无响应 → FILTERED
```
既然攻击者需要发送这些流量，那么我们能不能在网络里观察到这些行为？

## NIDS

```
  ☠️ 攻击者
       ▼
┌──────────────┐
│  WAF (Nginx) │  ← 应用层防护（已有）
└──────┬───────┘
       ▼
┌──────────────┐     ┌──────────────────┐
│ Juice Shop   │     │   Suricata (NIDS)│  ← 新防线
│              │────▶│  监控网络流量     │
└──────────────┘     │  检测端口扫描     │
                     │  生成 EVE 告警    │
                     └──────────────────┘
```

NIDS (Network Intrusion Detection System) — 网络入侵检测系统。

工作原理：

> 网络流量 → Suricata 抓包 → 规则/行为匹配 → 生成告警

NIDS 如何检测端口扫描：

> 短时间内对同一主机的多个端口发起连接 → 行为模式识别 → 生成端口扫描告警

### 名词: Suricata

Suricata 高性能开源 IDS/IPS，支持多线程处理。

核心能力：

- 端口扫描检测（行为分析）
- 网络攻击特征匹配（ET 规则集）
- 协议异常检测
- 流量分析

### 名词: IPS

IDS 发现攻击, 生成告警, 通常不主动阻断

IPS (Intrusion Prevention System), 发现攻击, 主动阻断

---

## 动手验证

实验环境搭建参考: [lesson-03-experiment](../docs/lesson-03-experiment.md)

## Suricata 告警示例

```json
{
  "timestamp": "2026-09-25T09:21:01.953114+0000",
  "flow_id": 1560322157847338,
  "in_iface": "enp0s9",
  "event_type": "alert",
  "src_ip": "192.168.56.3",
  "src_port": 51760,
  "dest_ip": "192.168.56.2",
  "dest_port": 8080,
  "proto": "TCP",
  "ip_v": 4,
  "pkt_src": "wire/pcap",
  "alert": {
    "action": "allowed",
    "gid": 1,
    "signature_id": 1000007,
    "rev": 1,
    "signature": "ET SCAN Port Scan - HTTP-Alt probe",
    "category": "Attempted Information Leak",
    "severity": 2
  },
  "direction": "to_server",
  "flow": {
    "pkts_toserver": 1,
    "pkts_toclient": 0,
    "bytes_toserver": 74,
    "bytes_toclient": 0,
    "start": "2026-09-25T09:21:01.953114+0000",
    "src_ip": "192.168.56.3",
    "dest_ip": "192.168.56.2",
    "src_port": 51760,
    "dest_port": 8080
  },
  "stream": 0
}
```

**基础信息**

| 字段 | 含义 |
|---|---|
| `timestamp` | 告警产生时间（UTC，ISO8601，含纳秒） |
| `flow_id` | 这条网络流的唯一标识，用于把同一流的多个事件关联起来 |
| `in_iface` | 抓到该流量的入口网卡，这里是 `enp0s9`（Suricata 监听的那块卡） |
| `event_type` | 事件类型，`alert` = 命中检测规则产生告警 |
| `pkt_src` | 数据来源，`wire/pcap` = 实时抓包（区别于离线读取 pcap 回放） |

**网络五元组**

| 字段 | 含义 |
|---|---|
| `src_ip` / `src_port` | 源地址：`192.168.56.3:51760`（发起方） |
| `dest_ip` / `dest_port` | 目的地址：`192.168.56.2:8080`（被探测方） |
| `proto` | 协议：TCP |
| `ip_v` | IP 版本：4 |
| `direction` | 流方向：`to_server` = 客户端发往服务端 |

**alert 对象**

| 字段 | 含义 |
|---|---|
| `action` | 处置动作：`allowed` = 放行且仅告警（IDS 模式默认；若 IPS drop 模式会显示 `drop`/`reject`） |
| `gid` | 规则组 ID，`1` = Emerging Threats 规则集 |
| `signature_id` | 规则编号，`1000007`（ET 规则：HTTP-Alt 端口探测） |
| `rev` | 规则修订版本号 |
| `signature` | 规则描述：**ET SCAN Port Scan - HTTP-Alt probe**（端口扫描特征——对常见 HTTP 备用端口 8080 的探测） |
| `category` | 攻击类别：`Attempted Information Leak`（尝试信息泄露） |
| `severity` | 严重级别 1~3：`2` = 中危（1 高 / 2 中 / 3 低） |

**flow 对象**

| 字段 | 含义 |
|---|---|
| `pkts_toserver` / `pkts_toclient` | 已见到的上行/下行包数：`1 / 0` |
| `bytes_toserver` / `bytes_toclient` | 对应字节数：`74 / 0` |
| `start` | 流开始时间 |
| 后面的 src/dest 字段 | 重复的五元组，方便单独看流对象 |

**stream**

`stream: 0` 表示这条告警**不关联到流重组上下文**——即不是针对载荷内容（如基于流内容的检测），而是纯粹根据报文特征（扫描探测）触发的，没有流级状态可绑定。

---

## NIDS vs WAF 互补

| 攻击类型 | WAF 能看到？ | NIDS 能看到？ |
|----------|-------------|--------------|
| SQL 注入 | ✅ | ❌ |
| XSS | ✅ | ❌ |
| 端口扫描 | ❌ | ✅ |
| 网络协议攻击 | ❌ | ✅ |
| DDoS | ❌ | ⚠️ 部分 |

> **WAF 工作在应用层（HTTP），NIDS 工作在网络层（TCP/IP）。它们互补，不替代。**

---

## CISO 观察记录

| 检查项 | 状态 | 备注 |
|--------|------|------|
| WAF | ✅ | 保护 HTTP 层 |
| NIDS | ✅ | Suricata 监控流量 |
| 端口扫描 | 🛡️ | 告警触发 |
| 主机威胁 | ❌ | 文件篡改不知道 |

> **NIDS 看网络层，WAF 看应用层。两者结合，才能看到更多威胁。**

---

## 下一课

→ NIDS 上线了，但**如果攻击者已经进来了怎么办？**

端口扫描只是侦察。如果攻击者已获得主机访问权限，开始篡改文件、植入后门……

**NIDS 看不到主机内部发生了什么。** 下一课部署 **HIDS（主机入侵检测系统）**。