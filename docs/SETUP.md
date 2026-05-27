# System Setup installation sequence timeline wrapper.
# System Setup – Installation Sequence Timeline

This document provides the complete chronological deployment sequence for building the Automated SOC Home Lab from scratch. Follow each phase in order to prevent dependency failures between infrastructure components.

---

# 🧱 SOC Home Lab Deployment Overview

| Phase | Infrastructure Component | Estimated Time | Dependency |
|------|--------------------------|----------------|------------|
| 0 | Host Machine Preparation | 15 Minutes | VMware + ISO files |
| 1 | VMware Network Configuration | 10 Minutes | VMware Installed |
| 2 | pfSense Firewall Gateway | 30 Minutes | VMnet1 Ready |
| 3 | Windows Server 2022 Domain Controller | 45 Minutes | pfSense Operational |
| 4 | Ubuntu Wazuh SIEM Manager | 45 Minutes | pfSense Operational |
| 5 | Windows 10 Endpoint + Sysmon + Wazuh Agent | 45 Minutes | Domain Controller Ready |
| 6 | Kali Linux Attacker Machine | 15 Minutes | Network Online |
| 7 | Shuffle + ServiceNow Automation Pipeline | 60 Minutes | Wazuh Running |
| 8 | Attack Simulation & Validation | 30 Minutes | Entire Lab Operational |

---

# 🌐 Phase 0 — Host Machine Preparation

Before deploying any virtual machines, prepare the physical host system.

## Requirements

- VMware Workstation Pro / VMware Player installed
- Minimum 16 GB RAM recommended
- At least 200 GB free SSD storage
- Internet connectivity

## Download Required Files

### Operating System ISOs

- pfSense Community Edition
- Windows Server 2022 Evaluation
- Windows 10 Pro / Enterprise
- Ubuntu Server 24.04 LTS

### Security Tools

- Kali Linux VMware Appliance
- Sysmon
- SwiftOnSecurity Sysmon Config

### Cloud Services

Create free accounts for:

- Shuffle SOAR
- ServiceNow Developer Instance

---

# 🖧 Phase 1 — VMware Virtual Network Configuration

## Configure VMnet1 Host-Only Network

Open VMware:

```text
Edit → Virtual Network Editor
```

Create:

| Setting | Value |
|---|---|
| Network | VMnet1 |
| Type | Host-Only |
| Subnet | 192.168.100.0 |
| Mask | 255.255.255.0 |
| DHCP | Disabled |

## Configure Host Adapter

Assign the Windows host VMnet1 adapter:

| Setting | Value |
|---|---|
| IP Address | 192.168.100.10 |
| Subnet Mask | 255.255.255.0 |
| Gateway | 192.168.100.1 |

---

# 🔥 Phase 2 — pfSense Firewall Gateway Deployment

The pfSense firewall acts as:

- Perimeter Gateway
- DHCP Server
- NAT Router
- Internal Segmentation Firewall

---

## Virtual Machine Specifications

| Setting | Value |
|---|---|
| VM Name | pfSense-FW |
| vCPU | 1 |
| RAM | 1.5 GB |
| Disk | 20 GB |
| Network Adapter 1 | NAT (WAN) |
| Network Adapter 2 | VMnet1 (LAN) |

---

## Install pfSense

### Boot Installation

1. Power on VM
2. Select:

```text
Install pfSense
```

3. Accept defaults
4. Install using:

```text
Auto (ZFS)
```

5. Reboot after installation
6. Remove ISO

---

## Interface Assignment

| Interface | Adapter |
|---|---|
| WAN | em0 |
| LAN | em1 |

---

## Configure LAN

Set:

| Setting | Value |
|---|---|
| LAN IP | 192.168.100.1 |
| CIDR | /24 |
| DHCP Enabled | Yes |
| DHCP Range | 192.168.100.50 – 192.168.100.200 |

---

## Access WebConfigurator

Open browser:

```text
http://192.168.100.1
```

### Default Credentials

| Username | Password |
|---|---|
| admin | pfsense |

Immediately rotate the administrator password.

---

## Configure Firewall Rules

Navigate:

```text
Firewall → Rules → LAN
```

### Rule 1 — Allow SSH

| Field | Value |
|---|---|
| Action | Pass |
| Protocol | TCP |
| Source | LAN Net |
| Destination | This Firewall |
| Port | 22 |

### Rule 2 — Allow Internal Traffic

| Field | Value |
|---|---|
| Action | Pass |
| Protocol | Any |
| Source | LAN Net |
| Destination | LAN Net |

Apply Changes.

---

# 🏢 Phase 3 — Windows Server 2022 Domain Controller

The Domain Controller provides:

- Active Directory
- DNS
- Authentication
- Centralized Identity Management

---

## Virtual Machine Specifications

| Setting | Value |
|---|---|
| VM Name | WS2022-DC |
| vCPU | 1 |
| RAM | 1.5 GB |
| Disk | 60 GB |
| Network | VMnet1 |

---

## Configure Static Network

| Setting | Value |
|---|---|
| IP Address | 192.168.100.2 |
| Gateway | 192.168.100.1 |
| DNS | 127.0.0.1 |

---

## Rename Server

Rename to:

```text
WS2022-DC
```

Reboot.

---

## Install Active Directory Services

Run PowerShell as Administrator:

```powershell
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
```

---

## Promote to Domain Controller

```powershell
Install-ADDSForest -DomainName "soclab.local" -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -InstallDNS -Force
```

The server will reboot automatically.

---

## Create Test Users

```powershell
New-ADOrganizationalUnit -Name "SOCLab" -Path "DC=soclab,DC=local"

$pass = ConvertTo-SecureString "Password@123" -AsPlainText -Force

New-ADUser -Name "John Doe" -SamAccountName "jdoe" -UserPrincipalName "jdoe@soclab.local" -Path "OU=SOCLab,DC=soclab,DC=local" -AccountPassword $pass -Enabled $true

New-ADUser -Name "Admin User" -SamAccountName "admin" -Path "OU=SOCLab,DC=soclab,DC=local" -AccountPassword $pass -Enabled $true
```

---

## Enable Security Auditing

```powershell
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Account Logon" /success:enable /failure:enable
```

---

# 🐺 Phase 4 — Ubuntu Wazuh SIEM Deployment

The Ubuntu server hosts:

- Wazuh Manager
- Wazuh Indexer
- Wazuh Dashboard

---

## Virtual Machine Specifications

| Setting | Value |
|---|---|
| VM Name | Ubuntu-Wazuh |
| vCPU | 2 |
| RAM | 4 GB |
| Disk | 80 GB |
| IP Address | 192.168.100.100 |

---

## Install Wazuh All-in-One

```bash
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
sudo bash ./wazuh-install.sh -a -i
```

Save the generated admin password.

---

## Access Dashboard

Open:

```text
https://192.168.100.100
```

Login:

| Username | Password |
|---|---|
| admin | Generated Password |

---

## Enable Raw Log Archiving

Edit:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

Add:

```xml
<logall>yes</logall>
<logall_json>yes</logall_json>
```

Restart:

```bash
sudo systemctl restart wazuh-manager
```

---

## Optional Custom Brute Force Rules

Edit:

```bash
sudo nano /var/ossec/etc/rules/local_rules.xml
```

Add:

```xml
<group name="local,custom_4625,">
  <rule id="108889" level="3">
    <if_sid>18150</if_sid>
    <field name="win.system.eventID">^4625$</field>
    <description>Windows Logon Failure.</description>
  </rule>

  <rule id="108890" level="10" frequency="5" timeframe="30">
    <if_matched_sid>108889</if_matched_sid>
    <same_source_ip />
    <description>Multiple Windows Logon Failures.</description>
  </rule>
</group>
```

Restart manager.

---

# 🖥️ Phase 5 — Windows 10 Endpoint Deployment

This VM acts as:

- Victim Endpoint
- Wazuh Agent
- Sysmon Logging Node

---

## Virtual Machine Specifications

| Setting | Value |
|---|---|
| VM Name | WIN10-ENDPOINT |
| vCPU | 2 |
| RAM | 3 GB |
| Disk | 60 GB |
| IP Address | 192.168.100.50 |

---

## Join Domain

Join:

```text
soclab.local
```

Credentials:

```text
SOCLAB\Administrator
```

---

## Install Sysmon

Open PowerShell:

```powershell
mkdir C:\Sysmon
cd C:\Sysmon

Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "Sysmon.zip"

Expand-Archive Sysmon.zip

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "sysmonconfig-export.xml"
```

Install:

```cmd
sysmon64.exe -accepteula -i sysmonconfig-export.xml
```

---

## Install Wazuh Agent

```powershell
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.2-1.msi" -OutFile "$env:TEMP\wazuh-agent.msi"
```

Install:

```cmd
msiexec.exe /i "%TEMP%\wazuh-agent.msi" /q WAZUH_MANAGER="192.168.100.100" WAZUH_AGENT_NAME="WIN10-ENDPOINT"
```

---

## Configure Sysmon Collection

Edit:

```text
C:\Program Files (x86)\ossec-agent\ossec.conf
```

Add:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

Restart agent:

```cmd
net stop WazuhSvc && net start WazuhSvc
```

---

# ⚔️ Phase 6 — Kali Linux Attacker Machine

---

## Virtual Machine Specifications

| Setting | Value |
|---|---|
| VM Name | Kali-Attacker |
| RAM | 2 GB |
| IP Address | 192.168.100.200 |
| Network | VMnet1 |

---

## Connectivity Verification

```bash
ping 192.168.100.1
ping 192.168.100.50
ping 192.168.100.100
```

---

# 🤖 Phase 7 — Automation Pipeline Deployment

This phase integrates:

```text
Wazuh → Shuffle → ServiceNow
```

---

## Configure Shuffle

1. Create Workflow:

```text
Wazuh_to_ServiceNow_Automation
```

2. Add Webhook Trigger
3. Copy Webhook URL
4. Add ServiceNow Action
5. Configure Incident Creation

---

## Create Wazuh Integration Script

Create:

```bash
/var/ossec/integrations/custom-shuffle
```

and

```bash
/var/ossec/integrations/custom-shuffle.py
```

---

## Configure ossec.conf

Add:

```xml
<integrator>
  <disabled>no</disabled>
</integrator>

<integration>
  <name>custom-shuffle</name>
  <hook_url>https://shuffler.io/api/v1/hooks/YOUR_WEBHOOK_URL</hook_url>
  <level>3</level>
  <alert_format>json</alert_format>
</integration>
```

Restart manager:

```bash
sudo systemctl restart wazuh-manager
```

---

# 🚨 Phase 8 — Attack Simulation & Validation

Run Hydra brute force from Kali:

```bash
hydra -l jdoe -P passwords.txt -t 1 -V 192.168.100.50 rdp
```

---

# 🔍 Validation Checklist

| Validation | Expected Result |
|---|---|
| Wazuh Agent | Active |
| Sysmon Logs | Visible |
| Event ID 4625 | Triggered |
| Wazuh Alerts | Generated |
| Shuffle Workflow | Executes |
| ServiceNow Incident | Created |

---

# 📊 Final Architecture Summary

| Component | Role | IP Address |
|---|---|---|
| pfSense | Firewall / Gateway | 192.168.100.1 |
| Windows Server 2022 | Active Directory / DNS | 192.168.100.2 |
| Windows 10 | Endpoint / Victim | 192.168.100.50 |
| Ubuntu Wazuh | SIEM / XDR | 192.168.100.100 |
| Kali Linux | Attacker Machine | 192.168.100.200 |

---

# ✅ Final Result

After completing all deployment phases:

- Active Directory authentication is operational
- Windows endpoint logs flow into Wazuh
- Sysmon telemetry is collected
- Hydra attacks generate SIEM alerts
- Wazuh automatically triggers Shuffle workflows
- Shuffle creates ServiceNow incidents automatically
- Full SOC detection-to-response automation pipeline is functional

---

**Project:** Automated SOC Home Lab Using Wazuh, Shuffle, and ServiceNow  
**Version:** 2.0  
**Last Updated:** May 2026