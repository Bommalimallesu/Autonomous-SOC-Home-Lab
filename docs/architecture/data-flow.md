# End-to-End Log Telemetry Pipeline Routing Scheme
# End-to-End Log Telemetry Pipeline Routing Scheme

## Overview
This document describes the complete telemetry routing path within the SOC Home Lab environment. The pipeline demonstrates how security events generated during an RDP brute-force attack are collected, correlated, enriched, and transformed into actionable incidents through automated SOAR orchestration using Wazuh, Shuffle, and ServiceNow.

---

# SOC Lab Architecture

| Component | IP Address | Function |
|---|---|---|
| Kali Linux Attacker | `192.168.100.200` | Attack simulation & penetration testing |
| Windows 10 Victim | `192.168.100.50` | Endpoint telemetry source |
| Windows Server DC | `192.168.100.2` | Active Directory & authentication |
| Wazuh SIEM Server | `192.168.100.100` | SIEM monitoring & log correlation |
| pfSense Firewall | `192.168.100.1` | Network gateway & segmentation |
| Shuffle SOAR | Cloud / SaaS | Security orchestration |
| ServiceNow | Cloud / SaaS | Incident management platform |

---

# Pipeline Architecture

| Stage | Component | Protocol / Port | Primary Function |
|------|------|------|------|
| Ingestion | Wazuh Agent | TCP 1514 | Endpoint telemetry collection |
| Monitoring | Wazuh Manager | Internal Processing | Rule correlation & alert generation |
| Orchestration | Shuffle SOAR | HTTPS 443 | Workflow automation & enrichment |
| Incident Response | ServiceNow API | REST API / HTTPS | Incident creation & tracking |

---

# Attack & Telemetry Flow

## Stage 1 — Attack Generation

| Component | Action | Output |
|---|---|---|
| Kali Linux (`192.168.100.200`) | Hydra RDP brute-force attack | Invalid RDP authentication attempts |

```bash
hydra -l jdoe -P passwords.txt -t 1 -V 192.168.100.50 rdp
```

---

## Stage 2 — Windows Event Logging

| Component | Action | Output |
|---|---|---|
| Windows 10 Endpoint (`192.168.100.50`) | Receives failed RDP login attempts | Windows Security Event ID 4625 |

---

## Stage 3 — Sysmon & Wazuh Agent Collection

| Component | Action | Output |
|---|---|---|
| Sysmon | Captures process and network telemetry | Event ID 1 & Event ID 3 |
| Wazuh Agent | Reads Sysmon + Security event channels | Forwards logs to Wazuh Manager |

### Wazuh Agent Path

```powershell
C:\Program Files (x86)\ossec-agent\
```

### Event Channels Monitored

```txt
Microsoft-Windows-Sysmon/Operational
Security
```

---

## Stage 4 — Wazuh SIEM Correlation

| Component | Action | Output |
|---|---|---|
| Wazuh Manager (`192.168.100.100`) | Applies decoders & correlation rules | alerts.json generated |
| Detection Rules | Identifies brute-force behavior | MITRE ATT&CK T1110 |

### Triggered Rule IDs

```txt
5715
60204
108889
```

### Alert Storage Location

```bash
/var/ossec/logs/alerts/alerts.json
```

---

## Stage 5 — Integration & Webhook Dispatch

| Component | Action | Output |
|---|---|---|
| wazuh-integratord | Executes integration script | Sends webhook payload |
| custom-shuffle.py | Parses alert JSON | HTTP POST to Shuffle |

### Integration Script

```bash
/var/ossec/integrations/custom-shuffle.py
```

### Webhook Payload Example

```json
{
  "source_ip": "192.168.100.200",
  "target_host": "WIN10-ENDPOINT",
  "rule_id": "60204",
  "severity": "10",
  "event_type": "RDP Brute Force"
}
```

---

## Stage 6 — Shuffle SOAR Automation

| Component | Action | Output |
|---|---|---|
| Shuffle Webhook | Receives Wazuh alert | Starts automation workflow |
| SOAR Workflow | Executes orchestration logic | ServiceNow API execution |

### Workflow Name

```txt
Wazuh_to_ServiceNow_Automation
```

### Automated Workflow Actions

- IOC enrichment
- Reputation validation
- JSON normalization
- Conditional logic execution
- Automated response workflow
- Incident ticket generation

---

## Stage 7 — Threat Enrichment & Containment

| Action | Description |
|---|---|
| VirusTotal Lookup | Validates malicious IP reputation |
| Active Directory Check | Verifies compromised user status |
| Firewall Rule Execution | Blocks attacker IP |
| Account Isolation | Disables compromised account |

### Automated PowerShell Containment

```powershell
New-NetFirewallRule `
-DisplayName "Block-Attacker-IP" `
-RemoteAddress 192.168.100.200 `
-Action Block
```

---

## Stage 8 — ServiceNow Incident Creation

| Component | Action | Output |
|---|---|---|
| ServiceNow REST API | Creates incident record | HTTP 201 Created |
| SOC Dashboard | Displays incident | Analyst triage workflow |

### Example Incident

```txt
INC0010100
```

### API Endpoint

```txt
https://devXXXXX.service-now.com/api/now/table/incident
```

---

# ASCII Data Flow Diagram

```txt
[Kali Linux Attacker]
        │
        ▼
[Windows 10 Security Log]
(Event ID 4625)
        │
        ▼
[Sysmon + Wazuh Agent]
        │
 TCP 1514
        ▼
[Wazuh Manager / SIEM]
(alerts.json)
        │
        ▼
[custom-shuffle.py]
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
(INC001xxxx)
```

---

# Routing Summary

| Source | Destination | Protocol | Port |
|---|---|---|---|
| Wazuh Agent | Wazuh Manager | TCP | 1514 |
| Wazuh Manager | Shuffle Webhook | HTTPS | 443 |
| Shuffle SOAR | ServiceNow API | HTTPS | 443 |
| Kali Linux | Windows 10 | RDP | 3389 |

---

# Key Configuration Files

| Component | File Path | Purpose |
|---|---|---|
| Wazuh Agent | `ossec.conf` | Event channel monitoring |
| Wazuh Manager | `/var/ossec/etc/ossec.conf` | Integration configuration |
| Integration Script | `/var/ossec/integrations/custom-shuffle.py` | Webhook forwarding |
| Shuffle SOAR | `Wazuh_to_ServiceNow_Automation` | Workflow orchestration |
| ServiceNow | Incident REST API | Ticket management |

---

# Troubleshooting & Validation

| Checkpoint | Verification Command |
|---|---|
| Windows failed logons | `Get-WinEvent -LogName Security -MaxEvents 5` |
| Wazuh connectivity | `Test-NetConnection 192.168.100.100 -Port 1514` |
| Alert verification | `sudo tail -f /var/ossec/logs/alerts/alerts.json` |
| Integration script | `sudo /var/ossec/integrations/custom-shuffle.py` |
| Shuffle execution | Review Executions tab |
| ServiceNow incident | Query incident table via REST API |

---

# Security Features Implemented

- Centralized SIEM monitoring
- Sysmon endpoint telemetry
- Automated brute-force detection
- MITRE ATT&CK mapping
- SOAR orchestration workflows
- REST API integration
- Automated firewall containment
- Incident lifecycle management
- TLS encrypted communication

---

# SOC Workflow Outcome

This project demonstrates a production-style SOC pipeline integrating:

- Wazuh SIEM
- Sysmon telemetry
- Shuffle SOAR automation
- ServiceNow incident management
- Active Directory monitoring
- Automated containment logic

The environment enables real-time detection, enrichment, orchestration, and incident response for brute-force authentication attacks while reducing Mean Time to Respond (MTTR) and improving SOC operational efficiency.

---

# Project Objective

To simulate an enterprise-grade SOC environment capable of detecting, correlating, enriching, and responding to security threats using open-source SIEM, SOAR automation, and ITSM integration technologies.
