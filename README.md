# Security Lab

一个面向实习生的网络安全实践项目，通过 Docker Compose 搭建完整的企业安全检测链路。

> **攻击 → 防火墙 → WAF → NIDS/HIDS → SIEM → 安全告警 → 态势感知**

## 课程结构

本项目分为六次课，每次课一个独立文件夹：

| 课程 | 主题 | 新增组件 | 攻击场景 |
|------|------|----------|----------|
| [Lesson 01](./lesson-01/) | 环境搭建 | Juice Shop | 验证应用可访问性 |
| [Lesson 02](./lesson-02/) | WAF | Nginx + ModSecurity | SQL 注入拦截 |
| [Lesson 03](./lesson-03/) | NIDS | Suricata | 端口扫描检测 |
| [Lesson 04](./lesson-04/) | HIDS | Wazuh Agent | 文件篡改检测 |
| [Lesson 05](./lesson-05/) | SIEM | Wazuh Manager | 暴力破解关联 |
| [Lesson 06](./lesson-06/) | Dashboard | Wazuh UI + OpenSearch | 端到端全链路 |

每次课的内容都是累积的 — 后面的课程包含前面课程的所有组件，并添加一个新的安全能力。

## 快速开始

```bash
# 选择要学习的课程
cd lesson-01

# 启动环境
docker compose up -d

# 运行攻击演示
bash attack.sh

# 查看日志
docker compose logs -f

# 清理
docker compose down
```

## 系统要求

- Docker + Docker Compose
- Lesson 01-03: 最低 2 GB RAM
- Lesson 04-06: 最低 8 GB RAM（Wazuh 组件较重）
- Suricata 的流量捕获功能需要 Linux 环境（macOS 上可能受限）

## 技术栈

- **WAF**: Nginx + ModSecurity (OWASP CRS)
- **Web 应用**: OWASP Juice Shop
- **NIDS**: Suricata
- **HIDS / SIEM / Dashboard**: Wazuh (Agent → Manager → Dashboard on OpenSearch)

## 详细文档

- [项目需求文档](./docs/requirements.md)
