为了教学实验简单化，建议: 

- VM1 上只负责运行 Suricata 容器
- VM2 运行 Nmap

关键点是：**Suricata 容器必须能够看到 VM1 的 `enp0s9` 流量**，因此 Docker Compose 不能使用普通的 bridge 网络，而应该使用 `host` 网络模式。

# 双 VM 网络安全实验：Docker Suricata + Nmap

## 1. 实验目标

搭建一个最小化的网络安全实验环境：

* **VM1**：Docker Compose 启动 Suricata
* **VM2**：使用 Nmap 扫描 VM1
* 两台 VM 通过 VirtualBox Host-Only Network 通信
* Suricata 监听 VM1 的 Host-Only 网卡
* 观察 Nmap 扫描产生的检测事件

---

## 2. 网络架构

```text
                         macOS Host
                             │
                    Host-Only Network
                     192.168.56.0/24
                             │
              ┌──────────────┴──────────────┐
              │                             │
        ┌─────┴─────┐                 ┌─────┴─────┐
        │    VM1    │                 │    VM2    │
        │           │                 │           │
        │ .101      │◄────────────────│ .102      │
        │           │     Nmap        │           │
        │  Docker   │                 │   Nmap    │
        │ Suricata  │                 │           │
        └─────┬─────┘                 └─────┬─────┘
              │                             │
            NAT                           NAT
              │                             │
              └────────── Internet ─────────┘
```

| VM  | Host-Only IP     | 用途       |
| --- | ---------------- | -------- |
| VM1 | `192.168.56.101` | Suricata |
| VM2 | `192.168.56.102` | Nmap     |

---

# 3. VirtualBox 网络

两台 VM 都配置两个网卡。

### Adapter 1

```text
NAT
```

用于访问 Internet。

### Adapter 2

```text
Host-Only Network
HostNetwork
```

用于 VM ↔ VM 通信。

检查：

```bash
VBoxManage list hostonlynets
```

确认：

```text
192.168.56.0/24
```

---

# 4. 启动 Suricata

在 VM1：

```bash
docker compose up -d
```

检查：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f suricata
```

进入容器：

```bash
docker exec -it suricata sh
```

检查网卡：

```bash
ip addr
```

应该可以看到 VM 的：

```text
enp0s9
192.168.56.101
```

---

# 5. VM1：确认可以看到网络流量

这是整个实验中非常重要的一步。

VM1 执行：

```bash
sudo tcpdump -ni enp0s9
```

然后 VM2：

```bash
ping 192.168.56.101
```

VM1 应该能够看到：

```text
192.168.56.102 > 192.168.56.101
```

这说明：

```text
VM2
 │
 │ 192.168.56.0/24
 ▼
VM1 enp0s9
 │
 ▼
Suricata
```

网络链路正确。

---

# 6. 执行 Nmap 扫描

先进行简单扫描：

```bash
nmap 192.168.56.101
```

然后执行 SYN Scan：

```bash
sudo nmap -sS 192.168.56.101
```

也可以扫描常见端口：

```bash
sudo nmap -sS -p 22,80,443 192.168.56.101
```

---

# 7. 查看 Suricata

VM1：

```bash
docker exec -it suricata sh
```

查看：

```bash
tail -f /var/log/suricata/eve.json
```

---

# 8. 如果没有看到 Suricata 告警

首先不要急着修改规则。

先确认数据包：

```bash
sudo tcpdump -ni enp0s9 host 192.168.56.102
```

然后 VM2：

```bash
sudo nmap -sS 192.168.56.101
```

如果 `tcpdump` 能看到：

```text
192.168.56.102 → 192.168.56.101
```

说明网络没有问题。

此时再检查 Suricata：

```bash
docker compose logs suricata
```

以及：

```bash
docker exec suricata suricata --build-info
```

---

# 9. 最终实验链路

```text
                    Host-Only Network
                     192.168.56.0/24

        VM2                              VM1
   192.168.56.102                   192.168.56.101
        │                                │
        │       Nmap Scan                │
        │ ──────────────────────────────►│
        │                                │
        │                           enp0s9
        │                                │
        │                           ┌────▼────┐
        │                           │Suricata │
        │                           │ Docker  │
        │                           └────┬────┘
        │                                │
        │                           Detection
        │                                │
        │                           eve.json
        │                           fast.log
```

## 10. 本实验的核心知识点

```text
VirtualBox
    │
    ├── NAT
    │     └── Internet
    │
    └── Host-Only Network
          └── VM ↔ VM
                │
                ▼
              Nmap
                │
                ▼
          Network Traffic
                │
                ▼
        VM1 enp0s9
                │
                ▼
       Docker Host Network
                │
                ▼
            Suricata
                │
                ▼
       Detection / Logs
```

**最关键的一点：**

> Suricata 容器使用 `network_mode: host`，这样它才能直接监听 VM1 的 `enp0s9`，观察 VM2 → VM1 的扫描流量。

这样整个实验只需要两台 VM，而且 Suricata 不需要直接安装到 Ubuntu 主机中，后续也很容易销毁和重建实验环境。
