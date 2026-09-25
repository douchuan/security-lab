#!/bin/sh
# Suricata 启动脚本 — 自动检测网卡并动态生成配置

# 三重检测策略获取网卡名
IFACE=$(ip -4 addr show 2>/dev/null | grep -E 'inet ' | grep -v '127.0.0.1' | grep -v '172\.' | head -1 | awk '{print $NF}')
if [ -z "$IFACE" ]; then
  IFACE=$(ip route 2>/dev/null | grep default | awk '{print $5}')
fi
if [ -z "$IFACE" ]; then
  IFACE=$(ls /sys/class/net/ 2>/dev/null | grep -v lo | head -1)
fi
echo "Using interface: $IFACE"

# 动态生成 Suricata 配置（直接写入实际的网卡名）
cat > /etc/suricata/suricata-dynamic.yaml <<YAMLEOF
%YAML 1.1
---
vars:
  address-groups:
    HOME_NET: "[10.0.0.0/8,172.16.0.0/12,192.168.0.0/16]"
    EXTERNAL_NET: "!$HOME_NET"
  port-groups:
    HTTP_PORTS: "80"
    SSH_PORTS: "22"
af-packet:
  - interface: ${IFACE}
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
default-log-dir: /var/log/suricata
outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert:
            payload: yes
            payload-printable: yes
        - stats:
            enabled: yes
            totals: yes
detect:
  scan-consolidated-alerts: yes
default-rule-path: /var/lib/suricata/rules
rule-files:
  - /etc/suricata/rules/custom.rules
YAMLEOF

exec suricata -c /etc/suricata/suricata-dynamic.yaml -l /var/log/suricata -i "$IFACE"
