# Core System Engineering Design Components
# SOC Lab System Design Specification

## 1. Overview

The SOC Home Lab is a self-contained virtualized security operations environment designed to simulate enterprise-grade threat detection, monitoring, and automated incident response workflows.

The environment integrates:

- Wazuh SIEM
- Sysmon endpoint telemetry
- Shuffle SOAR automation
- ServiceNow incident management
- Active Directory authentication
- pfSense network segmentation

The lab is deployed within an isolated VMware network (`VMnet1`) to safely perform attack simulations, malware testing, and incident response exercises.

---

# 2. Lab Architecture

## Network Information

| Parameter | Value |
|---|---|
| Network Range | `192.168.100.0/24` |
| Virtual Network | `VMnet1 (Host-Only)` |
| Gateway | `192.168.100.1` |
| DHCP | Managed by pfSense |
| Internet Access | NAT via pfSense WAN |

---

## System Components

| Component | IP Address | Role |
|---|---|---|
| pfSense Firewall | `192.168.100.1` | Gateway, firewall, DHCP server |
| Windows Server 2022 | `192.168.100.2` | Active Directory Domain Controller |
| Windows 10 Pro | `192.168.100.50` | Monitored endpoint |
| Ubuntu 24.04 LTS | `192.168.100.100` | Wazuh SIEM platform |
| Kali Linux | `192.168.100.200` | Attack simulation system |

---

## External Security Services

| Service | Purpose |
|---|---|
| Shuffle SOAR | Security orchestration & automation |
| ServiceNow | Incident tracking & ticket management |

---

# 3. High-Level Interaction Diagram

```txt
                         INTERNET
                             │
                             ▼
                    ┌────────────────┐
                    │    pfSense     │
                    │ 192.168.100.1  │
                    └───────┬────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼

┌──────────────┐   ┌────────────────┐   ┌────────────────┐
│ Windows DC   │   │ Windows 10 VM │   │ Kali Linux     │
│ 192.168.2    │   │ 192.168.50    │   │ 192.168.200    │
│ Active Dir.  │   │ Wazuh Agent   │   │ Hydra Attacks  │
└──────┬───────┘   └────────┬───────┘   └────────────────┘
       │                    │
       │                    ▼
       │           ┌────────────────┐
       └──────────▶│ Ubuntu Wazuh   │
                   │ 192.168.100    │
                   │ SIEM Platform  │
                   └──────┬─────────┘
                          │
                    HTTPS Webhook
                          │
                          ▼
                   ┌──────────────┐
                   │ Shuffle SOAR │
                   └──────┬───────┘
                          │
                     REST API
                          │
                          ▼
                  ┌────────────────┐
                  │  ServiceNow    │
                  │ Incident Mgmt  │
                  └────────────────┘
```

---

# 4. End-to-End Security Workflow

## Stage 1 — Attack Simulation

Kali Linux executes Hydra-based RDP brute-force attacks against the Windows 10 endpoint.

```bash
hydra -l jdoe -P passwords.txt -t 1 -V 192.168.100.50 rdp
```

---

## Stage 2 — Windows Event Logging

The Windows endpoint records failed authentication attempts:

- Windows Security Event ID `4625`
- Sysmon Event ID `1`
- Sysmon Event ID `3`

---

## Stage 3 — Telemetry Collection

The Wazuh Agent collects:

- Windows Security logs
- Sysmon operational logs
- Authentication events
- Process execution telemetry
- Network connection events

### Agent Location

```powershell
C:\Program Files (x86)\ossec-agent\
```

---

## Stage 4 — Wazuh SIEM Correlation

The Wazuh Manager receives logs over TCP 1514 and applies:

- Decoders
- Correlation rules
- MITRE ATT&CK mapping
- Alert severity classification

### Triggered Rule IDs

```txt
5715
60204
108889
```

### Alert Storage

```bash
/var/ossec/logs/alerts/alerts.json
```

---

## Stage 5 — SOAR Integration

The `wazuh-integratord` daemon executes:

```bash
/var/ossec/integrations/custom-shuffle.py
```

The script:
- Parses alert JSON
- Extracts IOC data
- Sends HTTPS webhook payload to Shuffle SOAR

---

## Stage 6 — Automated SOAR Workflow

Shuffle executes the workflow:

```txt
Wazuh_to_ServiceNow_Automation
```

### Automated Actions

- Threat enrichment
- IOC validation
- Conditional response logic
- JSON normalization
- API orchestration
- Incident automation

---

## Stage 7 — ServiceNow Incident Creation

Shuffle sends REST API requests to ServiceNow:

```txt
/api/now/table/incident
```

Generated incidents include:
- Source IP
- Target host
- Severity
- Rule description
- Correlation data
- Response actions

### Example Incident

```txt
INC0010100
```

---

# 5. Security Controls

| Control | Description |
|---|---|
| Network Isolation | Host-only VMnet1 segmentation |
| Firewall Protection | pfSense default deny rules |
| Telemetry Encryption | TLS encrypted log forwarding |
| Audit Logging | Centralized SIEM event retention |
| Identity Management | Active Directory authentication |
| Incident Tracking | ServiceNow lifecycle management |

---

# 6. Automation Pipeline

| Step | Component | Action |
|---|---|---|
| 1 | Wazuh | Alert generation |
| 2 | custom-shuffle.py | HTTPS webhook dispatch |
| 3 | Shuffle SOAR | Workflow orchestration |
| 4 | ServiceNow | Incident ticket creation |

---

# 7. Resource Allocation

| VM | Memory Allocation |
|---|---|
| pfSense | 1.5 GB |
| Windows Server | 1.5 GB |
| Ubuntu Wazuh | 4 GB |
| Windows 10 | 3 GB |
| Kali Linux | 2 GB |

---

# 8. Failure Scenarios & Recovery

| Failure | Impact | Mitigation |
|---|---|---|
| Wazuh service failure | No alert generation | Restart manager service |
| Shuffle webhook offline | Automation interruption | Validate webhook status |
| ServiceNow API failure | Ticket creation failure | Verify API credentials |
| Agent disconnect | Missing telemetry | Re-enroll agent |
| pfSense outage | Network interruption | Snapshot recovery |

---

# 9. Key Configuration Files

| Component | File Path | Purpose |
|---|---|---|
| Wazuh Manager | `/var/ossec/etc/ossec.conf` | SIEM configuration |
| Wazuh Integration | `/var/ossec/integrations/custom-shuffle.py` | Webhook automation |
| Wazuh Agent | `ossec.conf` | Endpoint monitoring |
| Shuffle | `Wazuh_to_ServiceNow_Automation` | SOAR workflow |
| ServiceNow | Incident REST API | Ticket management |

---

# 10. Project Outcome

This SOC lab demonstrates a realistic enterprise-style Blue Team environment capable of:

- Real-time threat detection
- Endpoint telemetry monitoring
- SIEM-based correlation
- SOAR-driven automation
- Automated incident response
- REST API integration
- Incident lifecycle tracking
- Security operations workflow simulation

The environment provides hands-on experience with modern SOC operations, detection engineering, threat monitoring, and incident response automation.
