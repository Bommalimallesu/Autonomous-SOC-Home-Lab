# Shuffle SOAR Workflows Webhook Routers and ServiceNow Integrations
# Automation Setup – Wazuh → Shuffle → ServiceNow

## Overview

This document explains the configuration and implementation of the automated incident response pipeline used within the SOC Home Lab environment.

The automation workflow integrates:

- Wazuh SIEM
- Shuffle SOAR
- ServiceNow REST API

When a brute-force attack is detected by Wazuh, the alert is forwarded to Shuffle through a webhook integration. Shuffle processes the event and automatically creates an incident ticket in ServiceNow.

---

# Architecture Workflow

```txt
[Kali Linux Attacker]
        │
        ▼
[Windows 10 Endpoint]
(Event ID 4625)
        │
        ▼
[Wazuh Agent]
        │
 TCP 1514
        ▼
[Wazuh Manager]
(alert correlation)
        │
        ▼
[shuffle.py]
        │
 HTTPS POST
        ▼
[Shuffle Webhook]
        │
        ▼
[Shuffle SOAR Workflow]
        │
 REST API
        ▼
[ServiceNow Incident]
```

---

# Prerequisites

| Requirement | Purpose |
|---|---|
| Wazuh Manager | SIEM log collection & correlation |
| Windows 10 Agent | Endpoint telemetry |
| Shuffle Account | SOAR automation |
| ServiceNow Developer Instance | Incident management |
| Internet Connectivity | API & webhook communication |

---

# Lab Environment

| Component | IP Address | Role |
|---|---|---|
| Wazuh Manager | `192.168.100.100` | SIEM platform |
| Windows 10 Endpoint | `192.168.100.50` | Monitored target |
| Kali Linux | `192.168.100.200` | Attack simulation |
| pfSense Firewall | `192.168.100.1` | Gateway & segmentation |

---

# Step 1 — Configure ServiceNow REST API

1. Log into the ServiceNow Developer instance.
2. Navigate to:

```txt
All → REST API Explorer → Table API → Create a Record (POST)
```

3. Select the `incident` table.
4. Test the API using the following payload:

```json
{
  "short_description": "API Test",
  "impact": "2",
  "urgency": "2"
}
```

---

## Expected Result

```txt
HTTP 201 Created
```

Record the following information:

- ServiceNow instance URL
- API username
- API password

---

# Step 2 — Create Shuffle Workflow

## Workflow Configuration

| Setting | Value |
|---|---|
| Workflow Name | `Wazuh_to_ServiceNow_Automation` |
| Trigger Type | Webhook |
| Service Integration | ServiceNow |
| Workflow Status | Production |

---

## Configure Webhook Trigger

1. Create a new Webhook trigger.
2. Name the webhook:

```txt
Wazuh Alert Receiver
```

3. Copy the generated Webhook URL.
4. Click **START** on the webhook node.

---

## Configure ServiceNow Action

1. Add a ServiceNow node from Apps.
2. Connect the node to the webhook trigger.
3. Create a new ServiceNow connection.

### Connection Settings

| Parameter | Value |
|---|---|
| Instance URL | `https://devXXXXX.service-now.com` |
| Username | `admin` |
| Password | ServiceNow password |

4. Click **Verify**.
5. Set:

| Field | Value |
|---|---|
| Action | Create Record |
| Resource | Incident |

---

## Incident Payload Configuration

Paste the following JSON into Optional Parameters:

```json
{
  "short_description": "Wazuh Alert: {{.rule.description}}",
  "description": "Security alert triggered on endpoint. Details: Rule ID: {{.rule.id}}, Severity Level: {{.rule.level}}, Full Log: {{.full_log}}",
  "impact": "2",
  "urgency": "2",
  "category": "security",
  "assignment_group": "Security Operations"
}
```

Save the node and set the workflow status to:

```txt
Production
```

---

# Step 3 — Configure Wazuh Integration

All integration scripts are stored in:

```bash
/var/ossec/integrations/
```

---

# 3.1 Wrapper Script — custom-shuffle

## Create File

```bash
sudo tee /var/ossec/integrations/custom-shuffle > /dev/null << 'EOF'
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
EOF
```

---

# 3.2 Python Integration Script — custom-shuffle.py

## Create File

```bash
sudo tee /var/ossec/integrations/shuffle.py > /dev/null << 'EOF'
#!/usr/bin/env python3

#!/usr/bin/env python3
import sys
import json
import requests
import urllib3

# Suppress self-signed TLS/SSL certificate verification warnings in the testing sandbox
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def send_to_webhook(alert_data, webhook_url):
    """
    Formulates and executes the HTTP POST telemetry payload transfer to Shuffle SOAR.
    """
    try:
        response = requests.post(
            webhook_url, 
            json=alert_data, 
            headers={"Content-Type": "application/json"}, 
            timeout=10, 
            verify=False  # Crucial bypass for self-signed certificates inside a home lab
        )
        
        if response.status_code == 200:
            print("SUCCESS: Alert telemetry transmitted to Shuffle webhook plane.")
        else:
            print(f"FAILED: Ingestion dropped with HTTP status code {response.status_code}")
        return True
    except Exception as e:
        print(f"CRITICAL: Pipeline transport exception encountered: {e}")
        return False

if __name__ == "__main__":
    # Validate that the core runtime arguments are passed successfully by the Wazuh manager
    if len(sys.argv) < 4:
        print("ERROR: Invalid execution argument parameters. Syntax targets missing.")
        sys.exit(1)
        
    alert_file = sys.argv[1]   # Filepath to the raw event JSON file passed by Wazuh
    webhook_url = sys.argv[3]  # Hook address configured in your ossec.conf structure
    
    try:
        with open(alert_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        alert_data = json.loads(line)
                        send_to_webhook(alert_data, webhook_url)
                    except json.JSONDecodeError:
                        continue
    except Exception as err:
        print(f"CRITICAL: Resource reading failure on target file descriptor: {err}")
        sys.exit(1)
        
    sys.exit(0)
EOF
```

---

# 3.3 Configure Permissions

```bash
sudo chmod 750 /var/ossec/integrations/shuffle
sudo chmod 750 /var/ossec/integrations/shuffle.py

sudo chown root:wazuh /var/ossec/integrations/shuffle
sudo chown root:wazuh /var/ossec/integrations/shuffle.py
```

---

# Step 4 — Configure Wazuh Manager

## Open Configuration File

```bash
sudo nano /var/ossec/etc/ossec.conf
```

---

## Enable Integrator

```xml
<integrator>
  <disabled>no</disabled>
</integrator>
```

---

## Add Shuffle Integration Block

```xml
<integration>
  <name>custom-shuffle</name>
  <hook_url>https://shuffler.io/api/v1/hooks/webhook_dafe5243-9071-4d75-80b5-4229f356e1ae</hook_url>
  <level>3</level>
  <alert_format>json</alert_format>
</integration>
```

Replace:

```txt
YOUR_WEBHOOK_URL
```

with the webhook URL generated by Shuffle.

---

## Restart Wazuh Manager

```bash
sudo systemctl restart wazuh-manager
```

---

# Step 5 — Test the Automation Pipeline

# 5.1 Manual Webhook Test

```bash
curl -X POST -k \
"https://shuffler.io/api/v1/hooks/YOUR_WEBHOOK_URL" \
-H "Content-Type: application/json" \
-d '{"rule": {"description": "Test"}, "full_log": "test"}'
```

---

## Expected Response

```json
{
  "success": true,
  "execution_id": "..."
}
```

---

# 5.2 End-to-End Attack Simulation

Run the Hydra brute-force attack from Kali Linux:

```bash
hydra -l jdoe \
-P /usr/share/wordlists/rockyou.txt \
-t 1 -V 192.168.100.50 rdp
```

---

## Monitor Wazuh Logs

```bash
sudo tail -f /var/ossec/logs/ossec.log | grep shuffle
```

Expected output:

```txt
Alert sent successfully
```

---

# Verify Shuffle Workflow

1. Open Shuffle.
2. Click the **Executions** icon.
3. Verify a new workflow execution appears.

---

# Verify ServiceNow Incident

Navigate to:

```txt
Incidents → All
```

Expected incident fields:

| Field | Expected Value |
|---|---|
| Short Description | Wazuh Alert: Windows Logon Failure |
| Impact | 2 |
| Urgency | 2 |
| Category | Security |

---

# Verification Checklist

| Component | Verification | Status |
|---|---|---|
| Shuffle Webhook | Returns success response | ✅ |
| Wazuh Integration | Alert sent successfully | ✅ |
| ossec.conf | Integration block present | ✅ |
| Wazuh Logs | No integration errors | ✅ |
| Shuffle Execution | Workflow triggered | ✅ |
| ServiceNow Incident | Ticket created successfully | ✅ |

---

# Troubleshooting

| Issue | Cause | Resolution |
|---|---|---|
| Webhook not triggering | Workflow not in Production | Enable Production mode |
| No alerts forwarded | Incorrect permissions | Verify chmod/chown |
| ServiceNow 400 error | Invalid JSON payload | Validate JSON syntax |
| Empty incident title | Incorrect placeholder mapping | Verify JSON placeholders |
| No Wazuh alerts | Agent disconnected | Check connectivity |

---

# Future Improvements

- Threat intelligence enrichment
- Slack / Teams integration
- Automated IP blocking
- Active response automation
- Severity-based escalation
- Multi-stage SOAR playbooks

---

# Outcome

The completed automation pipeline demonstrates a production-style SOC workflow capable of:

- Real-time attack detection
- Automated SIEM correlation
- SOAR-driven orchestration
- Automatic incident generation
- Centralized alert management
- Reduced incident response time

This project provides practical hands-on experience with enterprise security monitoring, automation engineering, and incident response workflows.
