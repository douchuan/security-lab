# Lesson 02: WAF — Web 应用防火墙

## 实验目标

1. 在 Juice Shop 前面部署 Nginx + ModSecurity 作为 WAF
2. 理解 WAF 的工作原理和防护机制
3. 观察 WAF 对 SQL 注入攻击的拦截

## 架构

```
  用户浏览器 / 攻击者
         │
         ▼ (http://localhost:80)
┌──────────────────┐
│  Nginx + ModSec  │  ← WAF：检测并拦截恶意 HTTP 请求
└────────┬─────────┘
         │ (内部网络，不对外暴露)
         ▼
┌──────────────────┐
│   Juice Shop     │  ← 脆弱 Web 应用
└──────────────────┘
```

## 网络设计

- **dmz-net**：WAF 所在网络，对外暴露端口 80
- **app-net**：Juice Shop 所在网络，仅允许 WAF 访问

## 快速开始

```bash
# 启动应用
docker compose up -d

# 查看容器状态
docker compose ps

# 查看 WAF 日志
docker compose logs -f nginx-modsecurity

# 停止并清理
docker compose down
```

## 验证 WAF

### 正常请求（应通过）

```bash
curl http://localhost:80
```

### SQL 注入攻击（应被 WAF 拦截，返回 403）

```bash
curl "http://localhost:80/rest/products/search?q=' OR 1=1 --"
```

你应该看到 WAF 返回 403 Forbidden 响应。

### 运行攻击脚本

```bash
bash attack.sh
```

脚本会：
1. 验证正常请求可以通过 WAF
2. 发送 SQL 注入请求，观察 403 拦截
3. 发送 XSS 请求，观察拦截
4. 查看 ModSecurity 审计日志

## 思考题

1. WAF 是如何判断一个请求是恶意的？（规则匹配）
2. WAF 的两种模式：检测模式 vs 拦截模式，有什么区别？
3. WAF 能防御所有类型的攻击吗？有哪些它无法防护的攻击？

## 知识点

- **ModSecurity**：开源 Web 应用防火墙，支持 OWASP CRS（核心规则集）
- **OWASP CRS**：一组预定义的规则，用于检测 SQL 注入、XSS、文件包含等常见 Web 攻击
- **反向代理**：WAF 作为反向代理，所有流量先经过 WAF 检测，再转发给后端应用

## 下一步

完成本课后，继续学习 Lesson 03 —— 添加 Suricata NIDS 来检测网络层攻击。
