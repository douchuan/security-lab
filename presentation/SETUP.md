# Security Lab — 环境准备指南

本指南列出完成六节安全实验课所需的全部前置软件和环境要求。

---

## 系统要求

| 课程范围 | 最低内存 | 推荐内存 | CPU | 磁盘空间 |
|----------|---------|---------|-----|---------|
| Lesson 01-03 | 2 GB | 4 GB | 2 核 | 5 GB |
| Lesson 04-06 | 8 GB | 16 GB | 4 核 | 15 GB |

> Lesson 04-06 包含 Wazuh 和 OpenSearch 组件，资源消耗较大。

---

## 必需软件

### 1. Docker + Docker Compose

**版本要求：** Docker 20.10+，Docker Compose v2.0+

**资源设置（Docker Desktop）：**
- macOS: Docker Desktop → Settings → Resources → **至少分配 4 CPU / 8 GB RAM**（Lesson 04-06）
- 建议将磁盘镜像文件大小设置为 **至少 30 GB**

---

### 2. Git

**版本要求：** Git 2.30+

**验证：**
```bash
git --version
```

---

### 3. Bash

**版本要求：** Bash 4.0+（macOS 默认 3.2，但实验脚本兼容）

**验证：**
```bash
bash --version
```

---

### 4. curl

**用途：** 实验脚本用于发送 HTTP 请求测试 WAF

**安装：** macOS / Linux 通常已预装。

**验证：**
```bash
curl --version
```

---

### 5. nmap（端口扫描工具）

**用途：** Lesson 03 端口扫描演示

**验证：**
```bash
nmap --version
```

---

### 6. Web 浏览器

**推荐：** Chrome / Firefox / Edge（最新版）

**用途：**
- 访问 Juice Shop 应用（http://localhost:3000）
- 访问 Wazuh Dashboard（https://localhost:443）
- 预览 Marp 生成的 HTML 幻灯片

---

## 安装检查清单

在开始实验前，请确认以下检查全部通过：

- [ ] `docker --version` 返回 Docker 20.10 或更高版本
- [ ] `docker compose version` 返回 Compose v2.0 或更高版本
- [ ] `docker run hello-world` 正常运行
- [ ] Docker Desktop 资源已设置为至少 4 CPU / 8 GB RAM（Lesson 04-06）
- [ ] `git --version` 正常
- [ ] `curl --version` 正常
- [ ] 浏览器可正常访问 http://localhost

---

## 常见问题

### Q: Docker Compose 启动 Wazuh 组件后一直重启

**原因：** 资源不足。Wazuh Manager + Indexer + Dashboard 需要至少 8 GB RAM。

**解决：** Docker Desktop → Settings → Resources → 将内存调至 8 GB 以上，重启 Docker。

### Q: macOS 上 Suricata 端口扫描检测不到

**原因：** macOS 的网络驱动限制，Suricata 的 PCAP 抓包功能可能不完整。

**解决：** 这是已知限制。可以在 Docker 容器内使用 nmap 测试连通性作为替代验证。

### Q: Wazuh Dashboard 无法访问（https://localhost:443）

**原因：** Dashboard 首次启动需要 60-90 秒初始化。

**解决：** 等待所有容器健康后再访问：
```bash
docker compose ps   # 确认所有容器 Up
```

### Q: 端口 443 被其他程序占用

**解决：** 查找并停止占用端口的程序：
```bash
# macOS
lsof -i :443
sudo kill <PID>

# Linux
sudo lsof -i :443
sudo kill <PID>
```

---

## 网络端口占用一览

实验启动后，以下端口将被占用：

| 端口 | 服务 | 课程 |
|------|------|------|
| 3000 | Juice Shop（直连） | 01 |
| 80 | WAF (Nginx) | 02-06 |
| 443 | Wazuh Dashboard | 06 |

请确保这些端口未被其他程序占用。

---

*完成以上准备后，即可开始本课程*
