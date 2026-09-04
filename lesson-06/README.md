# Lesson 06: 完整安全链路 — Dashboard 与端到端演示

## 实验目标

1. 运行完整的安全检测链路（WAF → NIDS → HIDS → SIEM → Dashboard）
2. 通过 Wazuh Dashboard 可视化所有安全事件
3. 完成端到端演示：攻击 → 检测 → 告警 → 态势感知

## 架构

```
  攻击者
    │
    ▼
┌──────────────┐
│  WAF (Nginx) │ ───── 日志 ──────┐
└──────┬───────┘                 │
       │                         ▼
       ▼                  ┌──────────────┐
┌──────────────┐          │              │
│ Juice Shop   │ ─ 日志 ─▶│  Wazuh       │
│              │          │   Manager    │
└──────────────┘          │   (SIEM)     │
       │                  │              │
       ▼                  │  关联分析    │
┌──────────────┐          │  告警生成    │
│  Suricata    │ ─ 日志 ──┘
│  (NIDS)      │
└──────────────┘          │
                          ▼
┌──────────────┐     ┌──────────────┐
│ Wazuh Agent  │     │  OpenSearch  │
│  (HIDS)      │     │  (存储)       │
└──────────────┘     └──────┬───────┘
                            │
                            ▼
                     ┌──────────────┐
                     │   Wazuh      │
                     │  Dashboard   │
                     └──────────────┘
```

## 网络设计

- **dmz-net**：WAF 所在网络，对外暴露
- **app-net**：Juice Shop 内部网络
- **monitor-net**：Suricata 监控网络
- **hids-net**：Wazuh Agent 网络
- **siem-net**：Wazuh Manager 内部网络（隔离）
- **dashboard-net**：Dashboard 和 OpenSearch 网络

## 快速开始

```bash
# 启动完整环境（首次启动需要 2-3 分钟）
docker compose up -d

# 查看容器状态
docker compose ps

# 等待所有组件健康
docker compose ps --format "table {{.Name}}\t{{.Status}}"

# 查看日志
docker compose logs -f

# 停止并清理
docker compose down -v
```

## 访问 Dashboard

- **Wazuh Dashboard**: https://localhost:443
- **默认账号**: admin / admin

> 注意：首次启动时 Dashboard 需要 60-90 秒初始化。请等待所有容器健康后再访问。

## 端到端演示

### 运行完整攻击脚本

```bash
bash attack.sh
```

脚本会依次执行：
1. SQL 注入攻击（WAF 检测）
2. 端口扫描（Suricata 检测）
3. 暴力破解（Wazuh 关联检测）
4. 等待告警聚合
5. 打印 Dashboard 访问指引

### 手动验证

#### 1. SQL 注入

```bash
# 发送 SQL 注入请求
curl "http://localhost:80/rest/products/search?q=%27%20OR%201%3D1%20--"

# 预期：WAF 返回 403，记录 ModSecurity 告警
```

#### 2. 端口扫描

```bash
# 执行端口扫描
nmap -sT localhost -p 80,3000,8080

# 预期：Suricata 检测到扫描行为
```

#### 3. 暴力破解

```bash
# 发送大量失败登录请求
for i in $(seq 1 30); do
  curl -s -X POST "http://localhost:80/api/users/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@test.com","password":"wrong'$i'"}' -o /dev/null
done

# 等待 30 秒后查看 Dashboard 中的暴力破解告警
```

## Dashboard 面板说明

| 面板 | 内容 |
|------|------|
| Security Overview | 按严重级别统计的事件数（Critical/High/Medium/Low） |
| Attack Types | 攻击类型分布饼图 |
| Event Timeline | 时间轴显示最近的安全事件 |
| Source IPs | 攻击来源 IP 列表 |
| Component Health | 各安全组件在线状态 |
| Alert Table | 告警详情（ID、时间、来源、类型、级别） |

## 思考题

1. 完整安全链路中，每个组件负责哪一层的防护？
2. 同一个攻击行为，可能被多个组件同时检测到吗？（例如 SQL 注入同时触发 WAF 和应用日志告警）
3. SIEM 的关联分析有什么价值？（为什么不是简单地查看所有日志？）
4. 如果某个组件宕机，安全检测链路会受到什么影响？
5. 这个实验室环境和真实企业安全架构的差距在哪里？

## 知识点总结

| 层次 | 组件 | 检测内容 |
|------|------|----------|
| 应用层 | ModSecurity (WAF) | SQL 注入、XSS、目录遍历 |
| 网络层 | Suricata (NIDS) | 端口扫描、网络攻击特征 |
| 主机层 | Wazuh Agent (HIDS) | 文件变化、可疑进程、日志异常 |
| 聚合层 | Wazuh Manager (SIEM) | 日志聚合、关联分析、暴力破解 |
| 展示层 | Wazuh Dashboard | 安全态势可视化 |

## 课程总结

通过六次课的学习，你完成了：

1. **Lesson 01** — 部署脆弱应用，理解 Docker 网络
2. **Lesson 02** — 添加 WAF，防护 Web 攻击
3. **Lesson 03** — 添加 NIDS，检测网络层威胁
4. **Lesson 04** — 添加 HIDS，监控主机层安全
5. **Lesson 05** — 添加 SIEM，聚合日志和关联分析
6. **Lesson 06** — 完整链路，Dashboard 可视化

完整的攻击检测链路：
> 攻击发生 → WAF 拦截 → NIDS 检测 → HIDS 监控 → SIEM 聚合 → Dashboard 展示

## 下一步

- 探索 ModSecurity 的自定义规则编写
- 尝试 Suricata 的 IPS 模式（主动拦截）
- 学习 Wazuh 的自定义规则扩展
- 研究真实企业安全架构的设计模式
