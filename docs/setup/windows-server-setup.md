# # Windows Server 2022 Active Directory Domain Controller Setup

This document covers the deployment and configuration of Windows Server 2022 as the Active Directory Domain Controller (DC) for the SOC Home Lab environment. The server provides centralized authentication, DNS resolution, domain management, and logon auditing for all lab systems within the `soclab.local` domain.

---

# System Specifications

| Component | Value |
|---|---|
| Hostname | `WS2022-DC` |
| Operating System | Windows Server 2022 |
| Role | Active Directory Domain Controller + DNS |
| IP Address | `192.168.100.2` |
| Gateway | `192.168.100.1` |
| Network | VMnet1 (Host-Only) |
| Domain Name | `soclab.local` |

---

# Virtual Machine Provisioning

Create a new virtual machine in VMware Workstation using the following configuration:

| Setting | Configuration |
|---|---|
| Guest OS | Windows Server 2022 |
| vCPU | 1–2 |
| RAM | 1.5 GB (2 GB recommended) |
| Disk | 60 GB (SCSI) |
| Network Adapter | Custom → VMnet1 |
| Firmware | BIOS |
| ISO | Windows Server 2022 Evaluation ISO |

---

# Step 1 — Install Windows Server 2022

1. Mount the Windows Server 2022 ISO.
2. Power on the VM.
3. Boot from the ISO and begin installation.
4. Select:
   - Language
   - Keyboard layout
   - Time format
5. Click **Install Now**.

## Recommended Editions

| Environment | Edition |
|---|---|
| Low-resource lab | Windows Server 2022 Standard Evaluation (Core) |
| GUI preferred | Windows Server 2022 Standard Evaluation (Desktop Experience) |

6. Accept the license agreement.
7. Select:
   - `Custom: Install Windows only`
8. Choose the unallocated disk and continue.
9. After installation completes, configure the Administrator password.

Example:

```text
Username: Administrator
Password: P@ssw0rd
```

---

# Step 2 — Configure Static Networking

After logging in, configure a static IP address.

## Desktop Experience

Navigate to:

```text
Control Panel → Network and Sharing Center → Change Adapter Settings
```

Open Ethernet adapter properties:

```text
Internet Protocol Version 4 (TCP/IPv4)
```

Configure:

| Setting | Value |
|---|---|
| IP Address | `192.168.100.2` |
| Subnet Mask | `255.255.255.0` |
| Default Gateway | `192.168.100.1` |
| Preferred DNS | `127.0.0.1` |

---

## Server Core (sconfig)

Run:

```powershell
sconfig
```

Select:

```text
8) Network Settings
```

Configure the same static IP settings listed above.

---

# Step 3 — Rename the Server

Rename the machine before domain promotion.

## PowerShell

```powershell
Rename-Computer -NewName "WS2022-DC" -Restart
```

The server will reboot automatically.

---

# Step 4 — Install VMware Tools

From VMware:

```text
VM → Install VMware Tools
```

Inside the VM:

1. Open mounted DVD drive.
2. Run:

```text
setup64.exe
```

3. Complete installation.
4. Reboot the server.

---

# Step 5 — Install Active Directory Domain Services

Open PowerShell as Administrator.

Install the AD DS role:

```powershell
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
```

---

# Step 6 — Promote Server to Domain Controller

Create the new forest and domain:

```powershell
Install-ADDSForest `
-DomainName "soclab.local" `
-SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) `
-InstallDNS `
-Force
```

## Configuration Summary

| Parameter | Purpose |
|---|---|
| `-DomainName` | Creates the new domain |
| `-InstallDNS` | Installs integrated DNS |
| `-SafeModeAdministratorPassword` | DSRM recovery password |
| `-Force` | Suppresses prompts |

The system will reboot automatically after promotion.

---

# Step 7 — Post-Promotion Hardening & Configuration

After reboot, log in using:

```text
SOCLAB\Administrator
```

---

## 7.1 Disable IPv6 (Optional)

```powershell
Disable-NetAdapterBinding -Name "Ethernet0" -ComponentID ms_tcpip6
```

---

## 7.2 Configure DNS

Set the server to use itself for DNS resolution:

```powershell
Set-DnsClientServerAddress `
-InterfaceAlias "Ethernet0" `
-ServerAddresses 127.0.0.1
```

---

## 7.3 Create Organizational Unit

```powershell
New-ADOrganizationalUnit `
-Name "SOCLab" `
-Path "DC=soclab,DC=local"
```

---

# Step 8 — Create Domain Users

Create a reusable password object:

```powershell
$pass = ConvertTo-SecureString "Password@123" -AsPlainText -Force
```

Create test accounts:

```powershell
New-ADUser `
-Name "John Doe" `
-SamAccountName "jdoe" `
-UserPrincipalName "jdoe@soclab.local" `
-Path "OU=SOCLab,DC=soclab,DC=local" `
-AccountPassword $pass `
-Enabled $true
```

```powershell
New-ADUser `
-Name "Admin User" `
-SamAccountName "admin" `
-Path "OU=SOCLab,DC=soclab,DC=local" `
-AccountPassword $pass `
-Enabled $true
```

```powershell
New-ADUser `
-Name "Test User" `
-SamAccountName "testuser" `
-Path "OU=SOCLab,DC=soclab,DC=local" `
-AccountPassword $pass `
-Enabled $true
```

---

# Step 9 — Enable Security Auditing

Enable successful and failed logon auditing:

```powershell
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
```

```powershell
auditpol /set /subcategory:"Account Logon" /success:enable /failure:enable
```

These logs will later be collected by Wazuh for brute-force detection.

---

# Step 10 — Increase Security Log Size

Increase Windows Security Event Log retention capacity:

```powershell
wevtutil set-log Security /maxsize:1073741824 /retention:false
```

---

# Step 11 — Verify Domain Functionality

## Verify Domain Membership

```powershell
(Get-WmiObject Win32_ComputerSystem).Domain
```

Expected output:

```text
soclab.local
```

---

## Verify DNS Resolution

```powershell
nslookup soclab.local
```

Expected output:

```text
192.168.100.2
```

---

## Verify LDAP SRV Records

```powershell
nslookup -type=SRV _ldap._tcp.dc._msdcs.soclab.local
```

Expected result:

```text
LDAP SRV records returned successfully
```

---

## Verify AD Users

```powershell
Get-ADUser -Filter *
```

Expected users:

```text
jdoe
admin
testuser
```

---

# Security Logging Integration

The Domain Controller serves as a primary telemetry source for the SOC pipeline.

## Generated Security Events

| Event ID | Description |
|---|---|
| 4624 | Successful Logon |
| 4625 | Failed Logon |
| 4720 | User Account Created |
| 4726 | User Account Deleted |
| 4732 | User Added to Group |

These events are later forwarded to:

```text
Windows Endpoint → Wazuh Agent → Wazuh Manager → Shuffle → ServiceNow
```

---

# VMware Snapshot Recommendation

After successful configuration:

1. Shut down the VM.
2. Right-click VM → Snapshot → Take Snapshot.

## Snapshot Name

```text
WS2022-DC - Clean Domain Controller
```

This provides a stable rollback point for future testing.

---

# Verification Checklist

| Check | Command / Action | Expected Result |
|---|---|---|
| Static IP | `ipconfig` | `192.168.100.2` |
| Domain Active | `(Get-WmiObject Win32_ComputerSystem).Domain` | `soclab.local` |
| DNS Working | `nslookup soclab.local` | Returns DC IP |
| Users Created | `Get-ADUser -Filter *` | User list appears |
| Auditing Enabled | `auditpol /get /subcategory:"Logon"` | Success + Failure enabled |

---

# Troubleshooting

## Domain Promotion Fails

### Cause
DNS or static IP misconfiguration.

### Fix

Ensure:
- Static IP is configured.
- Preferred DNS is set to `127.0.0.1`.

---

## Cannot Log Into Domain

### Cause
AD services not fully initialized after reboot.

### Fix

Wait 1–2 minutes and retry:

```text
SOCLAB\Administrator
```

---

## DNS Resolution Fails

### Fix

Disable IPv6:

```powershell
Disable-NetAdapterBinding -Name "Ethernet0" -ComponentID ms_tcpip6
```

---

# Next Steps

After the Domain Controller is operational:

1. Join Windows 10 endpoint to `soclab.local`.
2. Install Sysmon on the Windows endpoint.
3. Deploy the Wazuh agent.
4. Configure the Wazuh → Shuffle → ServiceNow automation pipeline.
5. Begin brute-force attack simulations using Kali Linux.

---

# Architecture Role in SOC Pipeline

```text
Windows Server 2022 (AD DS + DNS)
            │
            ▼
Domain Authentication Events
            │
            ▼
Windows 10 Endpoint Logs
            │
            ▼
Wazuh SIEM Detection Engine
            │
            ▼
Shuffle SOAR Automation
            │
            ▼
ServiceNow Incident Creation
```