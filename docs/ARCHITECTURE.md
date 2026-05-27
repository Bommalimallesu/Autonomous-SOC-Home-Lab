# System Architecture Overview

## Purpose

This document provides a high-level architectural overview of the SOC Home Lab environment. The lab simulates a production-style Security Operations Center (SOC) infrastructure designed for threat detection, centralized logging, incident response automation, and security monitoring.

The environment integrates:
- **Wazuh SIEM/XDR** for telemetry collection and alerting
- **Shuffle SOAR** for workflow automation
- **ServiceNow** for incident management and ticket creation
- **Active Directory** for centralized authentication
- **pfSense Firewall** for network segmentation and perimeter control

Detailed installation and configuration procedures are available inside the `setup/` directory.

---

# 🏗️ High-Level Network Architecture

All virtual machines operate inside an isolated VMware Host-only network (`VMnet1`) using the subnet:

```text
192.168.100.0/24
```

The environment is fully segmented from the host operating system and external networks to safely simulate attacks, malware execution, and incident response scenarios.

---

# 🌐 Network Topology Diagram

```text
                              [ Internet ]
                                   │
                                   ▼
                    [ Host Machine – VMware ]
                                   │
          ┌────────────────────────┴────────────────────────┐
          │                                                 │
          │             pfSense Firewall Gateway            │
          │                                                 │
          │ WAN: NAT (Internet Access via Host)             │
          │ LAN: 192.168.100.1/24                           │
          │ Services: Firewall, Static, NAT, Routing        │
          └────────────────────────┬────────────────────────┘
                                   │
                     VMnet1 – 192.168.100.0/24
                                   │
        ┌──────────────┬──────────────┬──────────────┬──────────────┐
        │              │              │              │
        ▼              ▼              ▼              ▼

 [ Windows Server ] [ Windows 10 ] [ Ubuntu Wazuh ] [ Kali Linux ]
     192.168.100.2    192.168.100.50   192.168.100.100 192.168.100.200
      AD + DNS         Victim Endpoint    SIEM/XDR         Attacker
```

---

# 🧩 Core Infrastructure Components

| Component | Role | IP Address |
|---|---|---|
| **pfSense Firewall** | Network gateway, DHCP server, NAT router, firewall segmentation | `192.168.100.1` |
| **Windows Server 2022** | Active Directory Domain Controller (`soclab.local`) + DNS | `192.168.100.2` |
| **Windows 10 Endpoint** | Monitored endpoint with Sysmon and Wazuh agent | `192.168.100.50` |
| **Ubuntu 24.04 LTS** | Wazuh SIEM/XDR Manager, Indexer, Dashboard | `192.168.100.100` |
| **Kali Linux** | Adversary simulation platform (Hydra, Metasploit, SMB attacks) | `192.168.100.200` |
| **Shuffle (Cloud)** | SOAR orchestration engine and webhook automation | Cloud Hosted |
| **ServiceNow** | Incident management and ticket tracking platform | Cloud Hosted |

---

# 🔄 End-to-End Detection & Automation Flow

The SOC pipeline is designed to simulate real-world enterprise detection and automated response operations.

---

## Attack Simulation Workflow

### 1. Initial Attack

The Kali Linux system launches a brute-force RDP attack against the Windows 10 endpoint using Hydra:

```bash
hydra -l jdoe -P passwords.txt -t 1 -V 192.168.100.50 rdp
```

---

### 2. Windows Security Logging

Each failed authentication generates:

```text
Windows Security Event ID 4625
```

These events are written into the Windows Security Event Log.

---

### 3. Sysmon Telemetry Collection

Sysmon captures:
- Process creation
- Network connections
- Registry modifications
- PowerShell execution
- Parent-child process relationships

Sysmon operational logs provide deep endpoint visibility for detection engineering and threat hunting.

---

### 4. Wazuh Agent Collection

The Wazuh Windows agent collects:
- Security Event Logs
- Sysmon Event Logs
- File Integrity Monitoring data

The agent securely forwards telemetry to the Wazuh Manager over:

```text
TCP Port 1514
```

---

### 5. Wazuh SIEM Correlation

The Wazuh Manager:
- Decodes incoming logs
- Applies correlation rules
- Detects brute-force patterns
- Generates alerts

Example rule IDs:

| Rule ID | Description |
|---|---|
| `5715` | Windows failed logon |
| `60204` | Authentication anomaly |
| `108889` | Custom brute-force correlation rule |

Alerts are stored inside:

```text
/var/ossec/logs/alerts/alerts.json
```

---

### 6. Automation Script Execution

The Wazuh Integrator daemon executes:

```text
/var/ossec/integrations/custom-shuffle.py
```

The script:
- Reads alert JSON
- Formats payload data
- Sends webhook requests to Shuffle

---

### 7. Shuffle SOAR Workflow

The Shuffle workflow:

```text
Wazuh_to_ServiceNow_Automation
```

performs:
- Webhook trigger processing
- JSON field extraction
- Severity mapping
- Automated incident creation

---

### 8. ServiceNow Ticket Creation

Shuffle sends the incident payload to ServiceNow using:

```text
/api/now/table/incident
```

A new incident is automatically generated containing:
- Alert title
- Source IP
- Full alert details
- Severity level
- Event description

---

# 🔐 Security Architecture & Isolation Controls

## Network Segmentation

The environment uses:
- VMware Host-only networking
- NAT isolation
- Stateful firewall inspection

This ensures malicious traffic remains completely contained inside the lab.

---

## Firewall Policy Model

pfSense enforces:
- LAN-to-LAN communication
- Internal management access
- Default-deny WAN policy
- Controlled outbound routing

---

## Authentication Security

Active Directory provides:
- Centralized authentication
- Domain account management
- Windows event auditing
- Policy enforcement

---

## Logging & Auditability

Wazuh stores:
- Raw telemetry archives
- Alert metadata
- Integration logs
- SOAR trigger events

Key log files:

| File | Purpose |
|---|---|
| `archives.json` | Raw telemetry |
| `alerts.json` | Correlated alerts |
| `ossec.log` | Manager operational logs |

---

# ⚙️ Automation Stack

| Layer | Technology | Function |
|---|---|---|
| SIEM/XDR | Wazuh | Detection, alerting, telemetry analysis |
| SOAR | Shuffle | Workflow orchestration and webhook handling |
| ITSM | ServiceNow | Incident creation and ticket management |
| Endpoint Telemetry | Sysmon | Deep Windows visibility |
| Firewall | pfSense | Network isolation and segmentation |

---

# 🖥️ Resource Allocation Strategy

The lab is optimized for a host machine with:

```text
16 GB RAM
```

---

## Always-On Infrastructure

| System | RAM Allocation |
|---|---|
| pfSense | 1.5 GB |
| Windows Server DC | 1.5 GB |
| Ubuntu Wazuh | 4 GB |

Total baseline consumption:

```text
~7 GB
```

---

## On-Demand Systems

| System | RAM Allocation |
|---|---|
| Windows 10 Endpoint | 3 GB |
| Kali Linux | 2 GB |

Maximum simultaneous usage:

```text
~12 GB Total
```

Leaving sufficient memory headroom for:
- VMware
- Host OS
- Browser
- Dashboard operations

---

# 📂 Critical Configuration Files

| Component | File Path | Purpose |
|---|---|---|
| Wazuh Manager | `/var/ossec/etc/ossec.conf` | Main SIEM configuration |
| Wazuh Integration Script | `/var/ossec/integrations/shuffle.py` | SOAR webhook forwarding |
| Windows Wazuh Agent | `C:\Program Files (x86)\ossec-agent\ossec.conf` | Endpoint telemetry collection |
| Shuffle Workflow | `Wazuh_to_ServiceNow_Automation` | Automation orchestration |
| ServiceNow API | `/api/now/table/incident` | Incident creation |
| pfSense Rules | Firewall → LAN Rules | Network segmentation |

---

# 🧪 Detection Engineering Objectives

The SOC lab supports:
- Brute-force attack detection
- Sysmon telemetry analysis
- Incident automation testing
- Threat simulation
- Log correlation engineering
- Active Directory monitoring
- SOAR workflow orchestration
- SIEM dashboard analysis

---

# 📋 Troubleshooting Reference Links

| Document | Purpose |
|---|---|
| `setup/pfsense-setup.md` | Firewall gateway deployment |
| `setup/windows-server-setup.md` | Active Directory setup |
| `setup/windows-10-setup.md` | Endpoint onboarding |
| `setup/wazuh-setup.md` | SIEM manager installation |
| `setup/automation-setup.md` | Wazuh → Shuffle → ServiceNow integration |
| `TROUBLESHOOTING.md` | Common issue resolution |

---

# 🚀 Future Expansion Possibilities

Potential enhancements include:
- Active Response IP blocking
- Cortex XSOAR integration
- Threat intelligence enrichment
- Malware sandboxing
- Multi-endpoint monitoring
- Sigma rule integration
- Elastic Stack integration
- Suricata IDS deployment
- Velociraptor DFIR integration

---

# ✅ Final Architecture Outcome

The completed SOC Home Lab successfully replicates the foundational components of a real-world enterprise SOC environment.

The platform demonstrates:
- Secure network segmentation
- Centralized log aggregation
- SIEM-based threat detection
- Endpoint telemetry monitoring
- Automated incident orchestration
- ITSM integration workflows
- Enterprise-style security operations

This environment provides a practical platform for:
- SOC analyst training
- Detection engineering
- Security research
- Incident response simulations
- Portfolio and interview demonstrations

---

**Document Version:** 2.0  
**Last Updated:** May 2026  
**Project:** Automated SOC Home Lab Using Wazuh, Shuffle, and ServiceNow