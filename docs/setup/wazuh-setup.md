# Linux Host Wazuh SIEM Manager Ingestion Node Deployment
# 🐺 Wazuh SIEM Manager Deployment & Log Ingestion Setup

The Wazuh manager acts as the central SIEM/XDR platform for the SOC home lab environment. It collects endpoint telemetry, analyzes security events, correlates attack patterns, and forwards high-severity alerts to the automation pipeline (Shuffle → ServiceNow).

This deployment uses an all-in-one Wazuh architecture where the manager, indexer, and dashboard run on a single Ubuntu Server instance.

---

# 📌 System Specifications

| Component | Value |
|---|---|
| Operating System | Ubuntu Server 24.04 LTS |
| Hostname | `wazuh-manager` |
| IP Address | `192.168.100.100/24` |
| Gateway | `192.168.100.1` |
| DNS | `192.168.100.2`, `8.8.8.8` |
| vCPUs | 2 |
| RAM | 4 GB (6 GB recommended) |
| Disk | 80 GB |
| Role | SIEM / XDR / Log Aggregation |

---

# 🧱 Architecture Overview

```text
                    ┌─────────────────────────┐
                    │      pfSense FW         │
                    │    192.168.100.1        │
                    └──────────┬──────────────┘
                               │
             ┌─────────────────┴─────────────────┐
             │                                   │
             ▼                                   ▼
  ┌─────────────────────┐            ┌─────────────────────┐
  │ Windows 10 Endpoint │            │   Kali Linux        │
  │ 192.168.100.50      │            │ 192.168.100.200     │
  └──────────┬──────────┘            └─────────────────────┘
             │
             │ Wazuh Agent Logs
             │ TCP/1514
             ▼
  ┌──────────────────────────────────────────────┐
  │         Wazuh SIEM Manager                   │
  │         Ubuntu 24.04 LTS                    │
  │         192.168.100.100                     │
  └──────────────────────────────────────────────┘
                         │
                         │ HTTPS Webhook
                         ▼
                ┌─────────────────┐
                │ Shuffle SOAR    │
                └─────────────────┘
                         │
                         ▼
                ┌─────────────────┐
                │ ServiceNow      │
                └─────────────────┘
```

---

# ⚙️ Step 1 — Update Ubuntu Server

Update all packages before installation.

```bash
sudo apt update && sudo apt upgrade -y
```

Optional reboot:

```bash
sudo reboot
```

---

# 📦 Step 2 — Install Wazuh All-in-One Stack

Download the official installation script:

```bash
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
```

Run the installer:

```bash
sudo bash ./wazuh-install.sh -a -i
```

### Installation Flags

| Flag | Purpose |
|---|---|
| `-a` | Install manager + indexer + dashboard |
| `-i` | Ignore minimum hardware requirement checks |

---

# 🔐 Step 3 — Save Dashboard Credentials

At the end of installation, Wazuh generates administrator credentials.

Example:

```text
User: admin
Password: xxxxxxxxxxxxxx
```

Save the password securely.

---

# 🌍 Step 4 — Access the Wazuh Dashboard

From your Windows host machine, open:

```text
https://192.168.100.100
```

Accept the self-signed certificate warning.

Login using:

| Username | Password |
|---|---|
| `admin` | Generated installation password |

---

# 📁 Step 5 — Enable Full Archive Logging

Enable raw telemetry archiving for threat hunting and troubleshooting.

Edit the Wazuh configuration file:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

Inside the `<global>` section, enable:

```xml
<logall>yes</logall>
<logall_json>yes</logall_json>
```

Save and restart Wazuh:

```bash
sudo systemctl restart wazuh-manager
```

Raw logs will now be stored at:

```text
/var/ossec/logs/archives/archives.json
```

---

# 🛡️ Step 6 — Configure Custom Detection Rules

Create a custom rules file:

```bash
sudo nano /var/ossec/etc/rules/local_rules.xml
```

Paste the following brute-force detection rules:

```xml
<?xml version="1.0" encoding="UTF-8"?>

<group name="windows,authentication,bruteforce,">

  <rule id="108889" level="3">
    <if_sid>18150</if_sid>
    <field name="win.system.eventID">^4625$</field>

    <description>
      Windows authentication failure detected.
    </description>
  </rule>

  <rule id="108890"
        level="10"
        frequency="5"
        timeframe="30"
        ignore="60">

    <if_matched_sid>108889</if_matched_sid>
    <same_source_ip />

    <description>
      Multiple Windows logon failures detected from source IP $(srcip).
    </description>

    <mitre>
      <id>T1110</id>
    </mitre>

  </rule>

</group>
```

Restart Wazuh:

```bash
sudo systemctl restart wazuh-manager
```

---

# 🔄 Step 7 — Configure Shuffle Integration

Edit the Wazuh configuration file:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

Add the following integration block inside `<ossec_config>`:

```xml
<integration>
  <name>custom-shuffle</name>
  <hook_url>https://shuffler.io/api/v1/hooks/YOUR_WEBHOOK_URL</hook_url>
  <level>3</level>
  <alert_format>json</alert_format>
</integration>
```

Replace:

```text
YOUR_WEBHOOK_URL
```

with your actual Shuffle webhook URL.

---

# 🤖 Step 8 — Create the Integration Wrapper Script

Create the wrapper file:

```bash
sudo nano /var/ossec/integrations/custom-shuffle
```

Paste:

```bash
#!/bin/sh

WPYTHON_BIN="framework/python/bin/python3"

SCRIPT_PATH_NAME="$0"

DIR_NAME="$(cd $(dirname ${SCRIPT_PATH_NAME}); pwd -P)"

SCRIPT_NAME="$(basename ${SCRIPT_PATH_NAME})"

case ${DIR_NAME} in
    */integrations)
        if [ -z "${WAZUH_PATH}" ]; then
            WAZUH_PATH="$(cd ${DIR_NAME}/..; pwd)"
        fi
        PYTHON_SCRIPT="${DIR_NAME}/${SCRIPT_NAME}.py"
    ;;
esac

${WAZUH_PATH}/${WPYTHON_BIN} ${PYTHON_SCRIPT} "$@"
```

Save and exit.

---

# 🧩 Step 9 — Create the Python Webhook Script

Create the Python integration file:

```bash
sudo nano /var/ossec/integrations/custom-shuffle.py
```

Paste:

```python
#!/usr/bin/env python3

import sys
import json
import requests
import urllib3

urllib3.disable_warnings(
    urllib3.exceptions.InsecureRequestWarning
)

def send_to_webhook(alert_data, webhook_url):

    try:
        response = requests.post(
            webhook_url,
            json=alert_data,
            headers={
                "Content-Type": "application/json"
            },
            timeout=10,
            verify=False
        )

        if response.status_code == 200:
            print("Alert sent successfully")
        else:
            print(f"HTTP Error: {response.status_code}")

        return True

    except Exception as e:
        print(f"Webhook Error: {e}")
        return False

if __name__ == "__main__":

    if len(sys.argv) < 4:
        print(
            "Usage: custom-shuffle.py "
            "<alert_file> <unused> <webhook>"
        )
        sys.exit(1)

    alert_file = sys.argv[1]
    webhook_url = sys.argv[3]

    try:
        with open(alert_file, 'r') as f:

            for line in f:

                line = line.strip()

                if line:

                    try:
                        alert_data = json.loads(line)

                        send_to_webhook(
                            alert_data,
                            webhook_url
                        )

                    except json.JSONDecodeError:
                        continue

    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)

    sys.exit(0)
```

---

# 🔒 Step 10 — Configure File Permissions

Apply secure permissions:

```bash
sudo chown root:wazuh /var/ossec/integrations/custom-shuffle*
```

```bash
sudo chmod 750 /var/ossec/integrations/custom-shuffle*
```

---

# 🔄 Step 11 — Restart Wazuh Services

Restart the manager:

```bash
sudo systemctl restart wazuh-manager
```

Verify status:

```bash
sudo systemctl status wazuh-manager
```

Expected result:

```text
active (running)
```

---

# 📊 Step 12 — Live Monitoring Commands

## View Active Alerts

```bash
sudo tail -f /var/ossec/logs/alerts/alerts.json
```

## View Raw Logs

```bash
sudo tail -f /var/ossec/logs/archives/archives.json
```

## Monitor Shuffle Integration

```bash
sudo tail -f /var/ossec/logs/ossec.log | grep shuffle
```

## List Connected Agents

```bash
sudo /var/ossec/bin/agent_control -lc
```

---

# 🧪 Step 13 — Validate Brute-Force Detection

From Kali Linux:

```bash
hydra -l jdoe \
-P passwords.txt \
-t 1 \
-V 192.168.100.50 rdp
```

Expected Result:

| Component | Expected Outcome |
|---|---|
| Windows 10 | Event ID 4625 generated |
| Wazuh Agent | Logs forwarded |
| Wazuh Manager | Rule 108890 triggered |
| Shuffle | Workflow execution created |
| ServiceNow | Incident ticket generated |

---

# ✅ Verification Checklist

| Check | Command / Action | Expected Result |
|---|---|---|
| Dashboard Access | Browser → `https://192.168.100.100` | Login page |
| Manager Status | `systemctl status wazuh-manager` | Running |
| Raw Logs | `tail archives.json` | JSON events |
| Alerts | `tail alerts.json` | Detection alerts |
| Agent Connectivity | `agent_control -lc` | Active agent |
| Shuffle Integration | `grep shuffle ossec.log` | Alert sent |
| ServiceNow Ticket | Incidents → All | Incident created |

---

# 🚨 Troubleshooting

| Issue | Cause | Resolution |
|---|---|---|
| Dashboard unavailable | Indexer not ready | Restart Wazuh indexer |
| Manager won't start | XML syntax issue | Validate `ossec.conf` |
| No alerts generated | Rules not loaded | Restart manager |
| Agent disconnected | Port blocked | Verify TCP/1514 |
| No webhook execution | Wrong URL | Verify Shuffle webhook |
| Empty incidents | Bad JSON mapping | Validate ServiceNow fields |

---

# 📸 Recommended Snapshot

After successful deployment:

```text
Ubuntu - Wazuh Clean Install
```

This snapshot provides a stable rollback point before adding agents and automation workflows.

---

# 📚 Next Steps

- Install Sysmon on Windows 10
- Enroll Windows endpoints into Wazuh
- Configure Shuffle SOAR workflows
- Integrate ServiceNow automation
- Implement active response for automated IP blocking

---

**Document Version:** 1.0  
**Environment:** SOC Home Lab  
**Platform:** Ubuntu Server 24.04 LTS + Wazuh 4.x  
**Purpose:** Security Monitoring, Threat Detection, and Automated Incident Response