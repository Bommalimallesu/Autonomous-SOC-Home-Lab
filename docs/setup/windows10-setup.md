# Windows 10 Client Configuration – Sysmon Logging & Wazuh Agent Enrollment

This guide covers the deployment and hardening of the Windows 10 monitored endpoint inside the SOC lab environment. The endpoint acts as the primary victim workstation used for telemetry generation, brute-force simulations, Sysmon event collection, and Wazuh agent monitoring.

The system will:
- Join the `soclab.local` Active Directory domain
- Generate Windows Security and Sysmon telemetry
- Forward logs to the Wazuh SIEM Manager
- Serve as the primary target during attack simulations from Kali Linux

---

# 🖥️ System Specifications

| Component | Value |
|---|---|
| Hostname | `WIN10-ENDPOINT` |
| Operating System | Windows 10 Pro / Enterprise |
| IP Address | `192.168.100.50` |
| Gateway | `192.168.100.1` |
| DNS Server | `192.168.100.2` |
| Domain | `soclab.local` |
| RAM | 3 GB |
| vCPU | 2 |
| Disk | 60 GB |
| Network | VMware VMnet1 (Host-only) |

---

# 📦 Prerequisites

Before beginning, ensure the following infrastructure components are already operational:

- pfSense Firewall configured (`192.168.100.1`)
- Windows Server Domain Controller online (`192.168.100.2`)
- Wazuh SIEM Manager deployed (`192.168.100.100`)
- VMware Tools available
- Windows 10 ISO downloaded

---

# ⚙️ Step 1 – Create the Windows 10 Virtual Machine

1. Open VMware Workstation.
2. Select:

   ```text
   File → New Virtual Machine
   ```

3. Choose:

   ```text
   Custom (Advanced)
   ```

4. Select:

   ```text
   I will install the operating system later
   ```

5. Guest OS:
   - Microsoft Windows
   - Windows 10 x64

6. Configure hardware:

| Setting | Value |
|---|---|
| vCPU | 2 |
| RAM | 3072 MB |
| Disk | 60 GB |
| Disk Type | SCSI |
| Network | NAT (temporary) |

7. Mount the Windows 10 ISO.
8. Finish VM creation.
9. Power on the VM.

---

# 💿 Step 2 – Install Windows 10

1. Boot from the ISO.
2. Follow the installation wizard.
3. Select:

   ```text
   Windows 10 Pro
   ```

4. Choose:

   ```text
   I don't have a product key
   ```

5. Create a local account:

| Username | Example |
|---|---|
| Local User | `LocalUser` |

6. Complete installation.

---

# 🔧 Step 3 – Install VMware Tools

Inside VMware:

```text
VM → Install VMware Tools
```

Inside Windows:

1. Open File Explorer
2. Open mounted VMware Tools drive
3. Run:

```text
setup64.exe
```

4. Reboot after installation.

---

# 🌐 Step 4 – Configure Static IP Address

After Windows installation:

1. Shut down the VM.
2. Change VMware network adapter:
   
```text
NAT → Custom: VMnet1
```

3. Boot Windows.
4. Open:

```text
Control Panel → Network and Sharing Center → Change Adapter Settings
```

5. Right-click Ethernet → Properties
6. Open:

```text
Internet Protocol Version 4 (TCP/IPv4)
```

7. Configure:

| Setting | Value |
|---|---|
| IP Address | `192.168.100.50` |
| Subnet Mask | `255.255.255.0` |
| Gateway | `192.168.100.1` |
| Preferred DNS | `192.168.100.2` |

8. Click OK.

---

# 🏢 Step 5 – Join the Active Directory Domain

1. Open:

```text
System → Rename this PC (Advanced)
```

2. Click:

```text
Change
```

3. Select:

```text
Domain
```

4. Enter:

```text
soclab.local
```

5. Authenticate using:

| Field | Value |
|---|---|
| Username | `SOCLAB\Administrator` |
| Password | Your domain admin password |

6. Accept prompts.
7. Restart the machine.

---

# 🔍 Step 6 – Install Sysmon for Deep Endpoint Telemetry

Sysmon provides enterprise-grade Windows event logging including:
- Process creation
- Network connections
- Registry changes
- File creation events
- PowerShell activity

---

## 6.1 Create Sysmon Working Directory

Open PowerShell as Administrator:

```powershell
mkdir C:\Sysmon
cd C:\Sysmon
```

---

## 6.2 Download Sysmon

```powershell
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "Sysmon.zip"
Expand-Archive -Path Sysmon.zip -DestinationPath .
```

---

## 6.3 Download SwiftOnSecurity Configuration

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "sysmonconfig-export.xml"
```

---

## 6.4 Install Sysmon

Open Command Prompt as Administrator:

```cmd
cd C:\Sysmon
sysmon64.exe -accepteula -i sysmonconfig-export.xml
```

---

## 6.5 Verify Sysmon Service

```cmd
sc query Sysmon64
```

Expected output:

```text
STATE : RUNNING
```

---

# 🐺 Step 7 – Install the Wazuh Agent

---

## 7.1 Download Wazuh Agent

Open PowerShell as Administrator:

```powershell
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.2-1.msi" -OutFile "$env:TEMP\wazuh-agent.msi"
```

---

## 7.2 Install the Agent

Open Command Prompt as Administrator:

```cmd
msiexec.exe /i "%TEMP%\wazuh-agent.msi" /q WAZUH_MANAGER="192.168.100.100" WAZUH_AGENT_NAME="WIN10-ENDPOINT"
```

---

# ⚙️ Step 8 – Configure Sysmon Log Collection

Open Notepad as Administrator.

Edit:

```text
C:\Program Files (x86)\ossec-agent\ossec.conf
```

Inside `<ossec_config>`, add:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

Save the file.

---

# 🔄 Step 9 – Restart the Wazuh Agent

Open Command Prompt as Administrator:

```cmd
net stop WazuhSvc
net start WazuhSvc
```

---

# 📁 Step 10 – Configure File Integrity Monitoring (Optional)

Inside `ossec.conf`, add:

```xml
<syscheck>
  <disabled>no</disabled>
  <directories check_all="yes" realtime="yes">C:\FIM_Test</directories>
</syscheck>
```

Create the monitored folder:

```cmd
mkdir C:\FIM_Test
```

Restart the agent again:

```cmd
net stop WazuhSvc
net start WazuhSvc
```

---

# 🧪 Step 11 – Verify Agent Connectivity

On the Wazuh server:

```bash
sudo /var/ossec/bin/agent_control -lc
```

Expected output:

```text
WIN10-ENDPOINT - Active
```

---

# 🔐 Step 12 – Generate a Failed Logon Event

Inside Windows:

```cmd
net use \\localhost\C$ /user:fake wrongpassword
```

---

# 📊 Step 13 – Verify Logs in Wazuh

On Ubuntu Wazuh Manager:

```bash
sudo tail -50 /var/ossec/logs/archives/archives.json | grep 4625
```

You should see Windows Event ID `4625` entries.

---

# 🖥️ Step 14 – Verify Dashboard Telemetry

Open the Wazuh dashboard:

```text
https://192.168.100.100
```

Navigate to:

```text
Agents → WIN10-ENDPOINT
```

Verify:
- Sysmon events visible
- Failed logons detected
- Alerts generated
- Agent status = Active

---

# 🧪 Optional RDP Attack Preparation

To allow Hydra RDP brute-force testing, disable NLA:

Open PowerShell as Administrator:

```powershell
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "UserAuthentication" /t REG_DWORD /d "0" /f
```

Enable RDP:

```powershell
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

---

# 📋 Verification Checklist

| Check | Command / Action | Expected Result |
|---|---|---|
| Domain Joined | `(Get-WmiObject Win32_ComputerSystem).Domain` | `soclab.local` |
| Sysmon Running | `sc query Sysmon64` | RUNNING |
| Wazuh Agent Running | `sc query WazuhSvc` | RUNNING |
| Agent Connected | `agent_control -lc` | Active |
| Failed Logons Visible | Search Event ID 4625 | Alerts visible |
| Sysmon Telemetry Working | Dashboard Events | Process/network logs visible |
| FIM Working | Create file in `C:\FIM_Test` | Rule 550 generated |

---

# 🛠️ Troubleshooting

## Agent Shows Disconnected

Verify:
- VM connected to VMnet1
- Wazuh manager reachable
- Port `1514/TCP` allowed
- Correct manager IP configured

---

## Sysmon Logs Missing

Verify:
- Sysmon service running
- `<localfile>` block added
- Agent restarted

---

## No Failed Logon Events

Enable auditing:

```powershell
auditpol /set /subcategory:"Logon" /failure:enable
```

---

## Hydra Cannot Attack RDP

Disable NLA using the registry command from Step 14.

---

# 📸 VMware Snapshot Recommendation

After successful configuration:

1. Shut down the VM
2. Right-click VM in VMware
3. Select:

```text
Snapshot → Take Snapshot
```

Snapshot Name:

```text
WIN10-ENDPOINT - Domain Joined + Sysmon + Wazuh Agent
```

---

# 🚀 Next Steps

- Launch Hydra attacks from Kali Linux
- Configure Wazuh → Shuffle → ServiceNow automation
- Enable Active Response IP blocking
- Add additional Windows/Linux endpoints
- Simulate phishing and malware scenarios

---

# ✅ Final Outcome

At this stage, your Windows 10 endpoint is fully operational as:
- A domain-joined enterprise workstation
- A monitored SIEM telemetry source
- A Sysmon-powered detection node
- A target for SOC attack simulations
- A live endpoint integrated into automated incident response workflows