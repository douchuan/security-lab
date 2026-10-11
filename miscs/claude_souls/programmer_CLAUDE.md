# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**security-lab** is a Docker Compose–based cybersecurity education environment for interns, structured as six progressive lessons. Each lesson is a self-contained folder that students can `docker compose up -d` to run.

The complete security defense chain:

> Attack → Firewall → WAF → NIDS/HIDS → SIEM → Security Alerts → Situational Awareness Dashboard

## Six-Lesson Structure

| Lesson | Topic | New Component | Attack Scenario |
|--------|-------|---------------|-----------------|
| 01 | 环境搭建 | Juice Shop | 验证应用可访问性 |
| 02 | WAF | Nginx + ModSecurity | SQL 注入拦截 |
| 03 | NIDS | Suricata | 端口扫描检测 |
| 04 | HIDS | Wazuh Agent | 文件篡改检测 |
| 05 | SIEM | Wazuh Manager | 暴力破解关联 |
| 06 | Dashboard | Wazuh Dashboard + OpenSearch | 端到端全链路 |

Each lesson builds on the previous one, adding exactly one new security capability.

## Tech Stack

| Component     | Technology              |
|---------------|-------------------------|
| Firewall      | OPNsense / pfSense (future) |
| WAF           | Nginx + ModSecurity (owasp/modsecurity-crs:nginx) |
| Web Service   | OWASP Juice Shop (bkimminich/juice-shop) |
| NIDS          | Suricata (jasonish/suricata) |
| HIDS          | Wazuh Agent (wazuh/wazuh-agent:4.9.0) |
| SIEM          | Wazuh Manager (wazuh/wazuh-manager:4.9.0) |
| Dashboard     | Wazuh Dashboard + OpenSearch (wazuh-indexer) |

## Project Structure

```
security-lab/
├── lesson-01/          # Juice Shop + Docker networking
├── lesson-02/          # + WAF (Nginx + ModSecurity)
├── lesson-03/          # + NIDS (Suricata)
├── lesson-04/          # + HIDS (Wazuh Agent)
├── lesson-05/          # + SIEM (Wazuh Manager)
├── lesson-06/          # + Dashboard (Wazuh UI + OpenSearch)
├── docs/
│   └── requirements.md
├── README.md
└── CLAUDE.md
```

Each lesson folder contains:
- `docker-compose.yml` — self-contained, can run independently
- `attack.sh` — executable attack demo script
- `README.md` — lesson objectives, how to run, expected output, exercises
- `configs/` — component configuration files

## Commands

```bash
# Run a specific lesson
cd lesson-01
docker compose up -d        # Start all containers
docker compose ps           # Check running services
bash attack.sh              # Run the attack demo
docker compose logs -f      # Follow logs
docker compose down         # Stop and remove

# Lessons 4-6 require more resources (8GB+ RAM recommended)
cd lesson-06
docker compose up -d        # Full stack (~2-3 min startup for Wazuh components)
```

## Key Principles

- Use mature, stable open-source components — **do not build WAF/IDS/SIEM from scratch**
- All configuration via Docker Compose and version-controlled config files
- No manual modification of container internals
- Every attack scenario must be reproducible via `bash attack.sh`
- Each lesson is self-contained (referencing sibling configs via relative paths)
- **Prioritize MVP chain completeness over adding more components**

## Docker Networks

Each lesson uses multiple Docker networks to simulate network segments:
- `dmz-net` — WAF facing network
- `app-net` — backend application network (often `internal: true`)
- `monitor-net` — Suricata monitoring network
- `hids-net` — Wazuh Agent network
- `siem-net` — SIEM internal network
- `dashboard-net` — Dashboard facing network

## Resource Notes

- Lessons 1-3: 2-4 GB RAM, 2 CPUs
- Lessons 4-6 (Wazuh stack): 8 GB RAM minimum, 4 CPUs recommended
- Wazuh components take 60-90 seconds to initialize on first start
- Suricata `cap_add` requires Linux; on macOS, port scan detection may have limitations

## Non-Goals

Custom-built WAF/IDS/SIEM, production HA, cloud deployment, complex threat intelligence, automated attack response.
