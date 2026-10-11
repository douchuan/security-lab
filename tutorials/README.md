# 《网络安全实践教材》

## 目录

| 章节 | 核心问题 | 文件 |
|---|---|---|
| 第一章 | 暴露的应用有什么风险？ | [chapter-01.md](chapter-01.md) |
| 第二章 | 能否在请求到达应用之前拦截部分攻击？ | [chapter-02.md](chapter-02.md) |
| 第三章 | 能否发现网络侦察行为？ | [chapter-03.md](chapter-03.md) |
| 第四章 | 能否发现主机文件发生异常变化？ | [chapter-04.md](chapter-04.md) |
| 第五章 | 如何从大量日志中识别有意义的安全事件？ | [chapter-05.md](chapter-05.md) |
| 第六章 | 如何利用安全事件开展初步调查？ | [chapter-06.md](chapter-06.md) |

## 课程主线

```
风险识别 → 防护控制 → 网络侧检测 → 主机侧检测 → 日志分析与事件识别 → 事件检索与初步调查
```

## 实验环境要求

- Docker 和 Docker Compose
- 宿主机（推荐 Linux 或 macOS，Windows 需 WSL2）
- 每章实验在 `lesson-01` 至 `lesson-06` 目录中独立实现
