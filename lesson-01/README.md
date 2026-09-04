# Lesson 01: 环境搭建 — 部署脆弱 Web 应用

## 实验目标

1. 使用 Docker Compose 部署 OWASP Juice Shop（一个故意包含漏洞的 Web 应用）
2. 理解 Docker Network 的基本概念
3. 学会访问和验证应用是否正常运行

## 架构

```
  用户浏览器
       │
       ▼ (http://localhost:3000)
┌──────────────────┐
│   Juice Shop     │  — 脆弱 Web 应用（端口 3000）
│   (Node.js)      │
└──────────────────┘
```

## 快速开始

```bash
# 启动应用
docker compose up -d

# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f

# 停止并清理
docker compose down
```

## 验证应用

### 方式 1：浏览器访问

打开浏览器，访问 http://localhost:3000

你应该看到 OWASP Juice Shop 的首页。

### 方式 2：命令行验证

```bash
curl http://localhost:3000/rest/products
```

如果返回 JSON 格式的产品列表，说明应用正常运行。

### 方式 3：运行攻击脚本

```bash
bash attack.sh
```

脚本会：
1. 检查应用是否可访问
2. 获取 API 数据（展示这是一个没有防护的脆弱应用）
3. 尝试简单的注入测试（此时没有 WAF，应该成功）

## 思考题

1. Juice Shop 暴露在公网（localhost:3000），存在哪些安全风险？
2. 如果这是一个生产环境的应用，你应该如何保护它？
3. Docker Network 在这里起到什么作用？

## 知识点

- **OWASP Juice Shop**：OWASP 官方维护的漏洞 Web 应用，用于安全教学。它包含 SQL 注入、XSS、JWT 漏洞等多种常见漏洞。
- **Docker Compose**：用于定义和运行多容器 Docker 应用的工具。
- **Docker Network**：容器之间的网络隔离机制。

## 下一步

完成本课后，继续学习 Lesson 02 —— 在 Juice Shop 前面部署 WAF（Web 应用防火墙）。
