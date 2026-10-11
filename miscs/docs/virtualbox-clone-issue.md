# VirtualBox 7.2.6 + Ubuntu 24 ARM64：克隆多台 VM 后 Host-Only IP 冲突

## 1. 问题描述

环境：

* macOS 宿主机
* VirtualBox 7.2.6
* Ubuntu 24 ARM64
* 原始 VM：`u24`
* 从 `u24` 克隆多个实例
* 希望：

  * 每台 VM 可以访问 Internet
  * VM 之间可以互通
  * macOS 可以 SSH 进入每台 VM

最终采用两块网卡：

```text
enp0s8 → NAT
enp0s9 → Host-Only Network
```

网络结构：

```text
                         macOS
                           │
                    Host-Only Network
                    192.168.56.0/24
                           │
             ┌─────────────┼─────────────┐
             │             │             │
          u24-01         u24-02        u24-03
          .101            .102           .103
             │             │             │
             └─────────────┼─────────────┘
                           │
                        VM ↔ VM

每台 VM：

enp0s8 → NAT → Internet
```

VirtualBox 官方文档也说明，Host-only 网络允许 **Host ↔ VM** 和 **VM ↔ VM**，而 NAT 用于 VM 访问外部网络。([Oracle Docs][1])

---

# 2. 出现的问题

克隆后，两台 VM 的 IP 地址完全相同。

最初观察到：

```text
u24-01:
enp0s8 → 10.0.2.15
enp0s9 → 10.0.2.3

u24-02:
enp0s8 → 10.0.2.15
enp0s9 → 10.0.2.3
```

后来将 `enp0s9` 正确配置为 Host-Only Network 后，问题变成：

```text
u24-01:
enp0s9 → 192.168.56.2

u24-02:
enp0s9 → 192.168.56.2
```

这显然不正常，因为两个 VM 位于同一个：

```text
192.168.56.0/24
```

网络中，IP 必须唯一。

---

# 3. 首先排除 VirtualBox MAC 地址重复

在两台 VM 上执行：

```bash
ip link show enp0s8
ip link show enp0s9
```

得到：

### u24-01

```text
enp0s8
08:00:27:b2:1a:94

enp0s9
08:00:27:45:28:b6
```

### u24-02

```text
enp0s8
08:00:27:6f:e9:a0

enp0s9
08:00:27:a8:e1:08
```

因此可以确认：

> **VirtualBox 克隆后的虚拟网卡 MAC 地址是不同的。**

所以问题不是 Clone 时没有生成新的 MAC。

克隆 VM 时仍然建议选择：

```text
Generate new MAC addresses for all network adapters
```

---

# 4. Ubuntu 网络配置本身没有问题

两台 VM 使用：

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      dhcp4: true
    enp0s9:
      dhcp4: true
```

这是合理的。

检查路由：

```bash
ip route
```

正确结果类似：

```text
default via 10.0.2.2 dev enp0s8
10.0.2.0/24 dev enp0s8
192.168.56.0/24 dev enp0s9
```

说明：

* `enp0s8` 是默认出口
* `enp0s8` 负责 NAT / Internet
* `enp0s9` 负责 Host-Only 网络
* 没有错误的第二条 default route

因此没有必要修改 Netplan。

---

# 5. 正确的 VirtualBox 网络配置

## Adapter 1：NAT

```text
Adapter 1
Attached to: NAT
```

Ubuntu：

```text
enp0s8
10.0.2.x
```

用于：

```text
VM → Internet
```

注意：

> 多台 VM 的 NAT 网卡都可能得到 `10.0.2.15`，这是正常的。

因为每个 VM 的 NAT 私有网络是独立的。

所以：

```text
u24-01 → 10.0.2.15
u24-02 → 10.0.2.15
```

并不构成冲突。

---

## Adapter 2：Host-Only Network

VirtualBox 7.2 在较新的 macOS 上使用的是 **Host-Only Network**，而不是传统的 Host-Only Adapter。官方文档明确说明了这一点。([Oracle Docs][1])

配置：

```text
Adapter 2
Attached to: Host-Only Network
Name: HostNetwork
```

HostNetwork：

```text
Network:
192.168.56.0/24

Host:
192.168.56.1

DHCP range:
192.168.56.2 ~ 192.168.56.199
```

VirtualBox 7.2 的 `hostonlynet` 文档明确规定：

* `lower-ip` 是地址范围下界
* `upper-ip` 是地址范围上界
* lower address 保留给 Host
* 其余地址用于 DHCP 分配。([Oracle Docs][2])

因此理论上：

```text
macOS    → 192.168.56.1
u24-01   → 192.168.56.2
u24-02   → 192.168.56.3
u24-03   → 192.168.56.4
```

---

# 6. 最终发现：Ubuntu Clone 后的 machine-id 相同

问题最终定位到：

> **克隆出来的 Ubuntu 实例继承了相同的 `/etc/machine-id`。**

虽然 VirtualBox 已经为两个 VM 生成了不同的 MAC：

```text
VM1 → MAC A
VM2 → MAC B
```

但是 Ubuntu/systemd 的 DHCP 客户端并不一定只使用 MAC 作为 DHCP Client Identifier。

`systemd-networkd` 的 DHCPv4 `ClientIdentifier` 默认是 `duid`；DUID 的生成与机器身份有关。Ubuntu 文档也明确说明 DHCPv4 可以使用 DUID，而默认配置使用 DUID。([Ubuntu Manpages][3])

因此 Clone 后：

```text
u24-01
machine-id = X

u24-02
machine-id = X
```

可能导致 DHCP server 将两个实例视为同一个 DHCP client。

这也解释了为什么：

```text
MAC 不同
       ↓
DHCP Client Identity 仍可能相同
       ↓
两个 VM 得到相同的 IP
```

---

# 7. 验证 machine-id

在每台 VM 执行：

```bash
cat /etc/machine-id
```

如果两个 Clone 输出完全相同，就说明 Clone 时把机器身份一起复制了。

例如：

```text
u24-01:
1234567890abcdef1234567890abcdef

u24-02:
1234567890abcdef1234567890abcdef
```

这就是问题的重要证据。

---

# 8. 修复方法

在已经克隆出来的实例，例如 `u24-02`：

```bash
sudo truncate -s 0 /etc/machine-id
```

然后重新生成：

```bash
sudo systemd-machine-id-setup
```

检查：

```bash
cat /etc/machine-id
```

确认它与其他 VM 不同。

然后重启：

```bash
sudo reboot
```

重启后：

```bash
ip addr show enp0s9
```

正常情况下，两台 VM 就会获得不同的 Host-Only IP：

```text
u24-01 → 192.168.56.2
u24-02 → 192.168.56.3
```

---

# 9. 正确的 Golden Image 制作方式

如果 `u24` 是以后反复 Clone 的母机，最好的方式不是每次 Clone 后再修复，而是在制作 Golden Image 时清理 machine identity。

在母机 `u24` 上：

```bash
sudo truncate -s 0 /etc/machine-id
```

然后关机：

```bash
sudo poweroff
```

再从这个母机进行 Full Clone。

Clone 时：

```text
Full Clone
+
Generate new MAC addresses for all network adapters
```

最终：

```text
                    u24
               Golden Image
                    │
          ┌─────────┼─────────┐
          │         │         │
        Clone     Clone     Clone
          │         │         │
       u24-01    u24-02    u24-03
          │         │         │
      MAC A      MAC B     MAC C
      ID A       ID B      ID C
```

这样同时保证：

```text
VirtualBox MAC
       +
Ubuntu machine-id
       ↓
每台 VM 都具有独立身份
```

---

# 10. 关键验证命令

## 10.1 检查 MAC

```bash
ip link show enp0s8
ip link show enp0s9
```

不同 VM 的 MAC 应该不同。

---

## 10.2 检查 machine-id

```bash
cat /etc/machine-id
```

不同 VM 应该不同。

---

## 10.3 检查 IP

```bash
ip addr
```

重点关注：

```text
enp0s9
inet 192.168.56.x/24
```

---

## 10.4 检查路由

```bash
ip route
```

应该类似：

```text
default via 10.0.2.2 dev enp0s8
10.0.2.0/24 dev enp0s8
192.168.56.0/24 dev enp0s9
```

---

## 10.5 检查 Ubuntu 网络配置

```bash
sudo cat /etc/netplan/*.yaml
```

应该类似：

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      dhcp4: true
    enp0s9:
      dhcp4: true
```

---

## 10.6 macOS 检查 Host-Only Network

```bash
VBoxManage list hostonlynets
```

例如：

```text
Name:            HostNetwork
State:           Enabled
NetworkMask:     255.255.255.0
LowerIP:         192.168.56.1
UpperIP:         192.168.56.199
VBoxNetworkName: hostonly-HostNetwork
```

---

## 10.7 检查 VM 使用的网络

```bash
VBoxManage showvminfo "u24" --machinereadable | \
  grep -E 'nic[12]|hostonly'
```

应该类似：

```text
nic1="nat"
nic2="hostonlynetwork"
hostonly-network2="HostNetwork"
```

每台 VM 都应该如此。

---

# 11. 最终验证

假设：

```text
macOS     192.168.56.1
u24-01    192.168.56.2
u24-02    192.168.56.3
u24-03    192.168.56.4
```

## macOS → VM

```bash
ssh vboxuser@192.168.56.2
ssh vboxuser@192.168.56.3
```

---

## VM → VM

在 `u24-01`：

```bash
ping 192.168.56.3
```

或者：

```bash
ssh vboxuser@192.168.56.3
```

---

## VM → Internet

```bash
ping 8.8.8.8
```

或者：

```bash
curl https://example.com
```

这样就验证了：

```text
                    macOS
                       │
                 192.168.56.1
                       │
                Host-Only Network
                       │
          ┌────────────┼────────────┐
          │            │            │
       u24-01       u24-02       u24-03
       .2             .3            .4
          │            │            │
          └────────────┼────────────┘
                       │
                    VM ↔ VM


每台 VM：

enp0s8 ── NAT ── Internet
enp0s9 ── Host-Only ── macOS / VM
```

## 12. 一个容易混淆的点

在排查过程中还发现 macOS 上存在旧的：

```text
HostInterfaceNetworking-vboxnet0
```

DHCP 配置，例如：

```text
192.168.56.101 ~ 192.168.56.254
```

但当前 VM 实际使用的是：

```text
HostNetwork
VBoxNetworkName: hostonly-HostNetwork
```

因此：

> **不要把旧的 `vboxnet0` DHCP 配置误认为当前 `HostNetwork` 的 DHCP 配置。**

VirtualBox 7.2 在 macOS 上已经引入了新的 Host-Only Network 模型；`VBoxManage list hostonlynets` 是检查当前这类网络的关键命令。([Oracle Docs][1])

---

## 结论

这次问题的核心不是：

```text
❌ Netplan 配错
❌ NAT IP 冲突
❌ VirtualBox MAC 地址重复
❌ Host-Only Network 配错
```

而是：

```text
克隆 Ubuntu VM
       ↓
VirtualBox 生成新的 MAC
       ↓
但 Ubuntu machine-id 被复制
       ↓
systemd DHCP Client Identity 可能相同
       ↓
Host-Only DHCP 将多个 Clone 识别成同一个客户端
       ↓
获得相同的 192.168.56.x 地址
```

**以后制作 Ubuntu VM Golden Image 时，最重要的两个动作：**

```bash
sudo truncate -s 0 /etc/machine-id
sudo poweroff
```

然后 VirtualBox Clone 时：

```text
Full Clone
Generate new MAC addresses for all network adapters
```

这套流程就可以稳定地批量创建 `u24-01`、`u24-02`、`u24-03` 等 Ubuntu 实例。

[1]: https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/networkingdetails.html?utm_source=chatgpt.com "Virtual Networking"
[2]: https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/EN-VBOX-7-2-USER.pdf?utm_source=chatgpt.com "User Guide for Release 7.2"
[3]: https://manpages.ubuntu.com/manpages/jammy/man5/networkd.conf.5.html?utm_source=chatgpt.com "Ubuntu Manpage: networkd.conf, networkd.conf.d - Global Network configuration files"
