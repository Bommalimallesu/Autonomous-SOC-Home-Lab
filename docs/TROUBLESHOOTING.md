# Diagnostic and endpoint triage error resolution catalog index.
# Diagnostic and Endpoint Triage – Error Resolution Catalog

This document provides a systematic troubleshooting guide for the SOC Home Lab. Each section addresses common errors, their symptoms, likely causes, and step-by-step solutions. Use the index below to quickly locate the issue you are experiencing.

---

# Index

1. Network & Connectivity Issues  
2. pfSense Firewall  
3. Windows Server (Domain Controller)  
4. Windows 10 Client (Agent, Sysmon, Domain Join)  
5. Wazuh Agent (Enrollment, Disconnected, No Logs)  
6. Wazuh Manager (Installation, Rules, Integration)  
7. Shuffle SOAR (Webhook, Workflow, ServiceNow Action)  
8. ServiceNow (API, Authentication, Ticket Creation)  
9. Kali Linux (Attacks, Connectivity, Hydra)  
10. General Commands & Diagnostic Tools  

---

# 1. Network & Connectivity Issues

## 1.1 Host cannot ping `192.168.100.1` (pfSense LAN)

| Symptom | `ping 192.168.100.1` returns `Destination host unreachable` or timeout |
|---|---|
| Cause | Host VMnet1 adapter not on same subnet or pfSense VM powered off |
| Solution | 1. Verify pfSense VM is running.<br>2. Configure VMware Network Adapter VMnet1 with IP `192.168.100.10`, subnet `255.255.255.0`, gateway `192.168.100.1`.<br>3. Ensure VMnet1 is Host-only and DHCP disabled. |

---

## 1.2 Lab VMs cannot reach internet

| Symptom | `ping 8.8.8.8` fails |
|---|---|
| Cause | pfSense WAN not configured with NAT |
| Solution | 1. Set pfSense WAN to DHCP/NAT.<br>2. Verify Firewall → NAT → Outbound is Automatic.<br>3. Restart pfSense. |

---

## 1.3 VMs cannot ping each other

| Symptom | Ping between Kali and Windows fails |
|---|---|
| Cause | Firewall blocking traffic |
| Solution | 1. Allow LAN → LAN traffic in pfSense.<br>2. Temporarily disable Windows Firewall for testing.<br>3. Create inbound ICMP rule if required. |

---

## 1.4 DNS resolution fails

| Symptom | `nslookup soclab.local` times out |
|---|---|
| Cause | DNS not pointing to Domain Controller |
| Solution | 1. Set DNS to `192.168.100.2`.<br>2. Flush DNS cache.<br>3. Disable IPv6 if required. |

---

# 2. pfSense Firewall

## 2.1 Cannot access pfSense Web GUI

| Symptom | Browser cannot open `http://192.168.100.1` |
|---|---|
| Cause | Wrong protocol or service stopped |
| Solution | 1. Use HTTP instead of HTTPS.<br>2. Restart webConfigurator using pfSense console option `11`.<br>3. Verify LAN IP configuration. |

---

## 2.2 DHCP not assigning IPs

| Symptom | VM receives `169.254.x.x` address |
|---|---|
| Cause | DHCP disabled |
| Solution | 1. Enable DHCP Server on LAN.<br>2. Configure range `192.168.100.50 – 192.168.100.200`.<br>3. Apply changes and restart DHCP service. |

---

# 3. Windows Server (Domain Controller)

## 3.1 Domain Controller promotion fails

| Symptom | “The specified domain either does not exist or could not be contacted” |
|---|---|
| Cause | Incorrect DNS before promotion |
| Solution | 1. Configure static IP `192.168.100.2`.<br>2. Preferred DNS = `127.0.0.1`.<br>3. Run `ipconfig /flushdns` and retry. |

---

## 3.2 `nslookup soclab.local` fails after promotion

| Symptom | DNS timeout |
|---|---|
| Cause | IPv6 conflict or DNS service delay |
| Solution | 1. Disable IPv6.<br>2. Restart DNS service.<br>3. Reconfigure DNS to `127.0.0.1`. |

---

# 4. Windows 10 Client (Agent, Sysmon, Domain Join)

## 4.1 Cannot join domain

| Symptom | “The specified domain either does not exist” |
|---|---|
| Cause | Wrong DNS configuration |
| Solution | 1. Set DNS to `192.168.100.2`.<br>2. Ping the Domain Controller.<br>3. Flush DNS cache. |

---

## 4.2 Sysmon installation error

| Symptom | “Failed to open xml configuration” |
|---|---|
| Cause | Incorrect XML file location |
| Solution | 1. Keep `sysmonconfig-export.xml` in same folder as `sysmon64.exe`.<br>2. Ensure file extension is `.xml` only.<br>3. Run as Administrator. |

---

## 4.3 Wazuh agent disconnected

| Symptom | Dashboard shows `Disconnected` |
|---|---|
| Cause | Wrong manager IP or firewall issue |
| Solution | 1. Verify manager IP in `ossec.conf`.<br>2. Test connectivity using `Test-NetConnection`.<br>3. Re-enroll the agent if required.<br>4. Allow outbound TCP 1514. |

---

## 4.4 Sysmon logs not reaching Wazuh

| Symptom | No Sysmon alerts in dashboard |
|---|---|
| Cause | Missing Sysmon localfile block |
| Solution | Add this block to `ossec.conf`:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

Restart the agent:

```cmd
net stop WazuhSvc && net start WazuhSvc
```

---

# 5. Wazuh Agent (Enrollment, Disconnected, No Logs)

## 5.1 Agent never connects

| Symptom | Dashboard shows `Never connected` |
|---|---|
| Cause | Wrong manager IP or missing client key |
| Solution | 1. Verify `<address>192.168.100.100</address>`.<br>2. Ensure `client.keys` exists.<br>3. Test port 1514 connectivity. |

---

## 5.2 Logs not arriving at manager

| Symptom | No logs in `archives.json` |
|---|---|
| Cause | Firewall or configuration issue |
| Solution | 1. Verify Security and Sysmon log collection blocks.<br>2. Restart the agent.<br>3. Ensure port 1514 is listening.<br>4. Allow firewall rule with `ufw allow 1514/tcp`. |

---

# 6. Wazuh Manager (Installation, Rules, Integration)

## 6.1 Wazuh manager fails after custom rules

| Symptom | `wazuh-manager` service fails |
|---|---|
| Cause | XML syntax error |
| Solution |

```bash
xmllint --noout /var/ossec/etc/rules/local_rules.xml
```

Install validator if missing:

```bash
sudo apt install libxml2-utils
```

Restart manager after fixing errors.

---

## 6.2 Integration script not executing

| Symptom | No Shuffle logs in `ossec.log` |
|---|---|
| Cause | Missing files or permissions |
| Solution |

```bash
sudo chmod 750 /var/ossec/integrations/custom-shuffle*
sudo chown root:wazuh /var/ossec/integrations/custom-shuffle*
```

Restart manager afterward.

---

## 6.3 “Skipping: Integration disabled”

| Symptom | `Integration disabled` appears in logs |
|---|---|
| Cause | Integrator disabled |
| Solution | Enable integrator inside `ossec.conf` and restart Wazuh. |

---

# 7. Shuffle SOAR (Webhook, Workflow, ServiceNow Action)

## 7.1 Webhook timeout

| Symptom | `curl` request hangs |
|---|---|
| Cause | Workflow not active |
| Solution | 1. Set workflow to Production.<br>2. Start webhook trigger.<br>3. Copy correct webhook URL. |

---

## 7.2 Liquid syntax error

| Symptom | Workflow execution fails |
|---|---|
| Cause | Invalid JSON |
| Solution |

```json
{
  "short_description": "Wazuh Alert: {{.rule.description}}",
  "description": "Full alert: {{.full_log}}"
}
```

---

## 7.3 ServiceNow returns HTTP 400

| Symptom | Bad Request |
|---|---|
| Cause | Missing `short_description` |
| Solution | Ensure JSON includes valid `short_description`. |

---

## 7.4 ServiceNow returns HTTP 401

| Symptom | Unauthorized |
|---|---|
| Cause | Wrong credentials |
| Solution | Reconfigure ServiceNow instance URL, username, and password in Shuffle. |

---

# 8. ServiceNow (API, Authentication, Ticket Creation)

## 8.1 API authentication failure

| Symptom | HTTP 401 |
|---|---|
| Cause | Invalid credentials |
| Solution | Verify ServiceNow credentials and REST API roles. |

---

## 8.2 Ticket fields empty

| Symptom | Incident created with blank fields |
|---|---|
| Cause | Incorrect Liquid syntax |
| Solution |

```json
{
  "short_description": "Wazuh Alert: {{.rule.description}}"
}
```

---

# 9. Kali Linux (Attacks, Connectivity, Hydra)

## 9.1 Hydra RDP attack fails

| Symptom | `connection refused` |
|---|---|
| Cause | RDP disabled or NLA enabled |
| Solution |

Enable Remote Desktop and disable NLA:

```powershell
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "UserAuthentication" /t REG_DWORD /d "0" /f
```

---

## 9.2 Hydra missing password list

| Symptom | “no password list provided” |
|---|---|
| Cause | Invalid path |
| Solution |

```bash
echo -e "password\n123456\nPassword@123" > passwords.txt
```

---

## 9.3 Kali cannot ping targets

| Symptom | No connectivity |
|---|---|
| Cause | Wrong VMware network |
| Solution |

```bash
sudo ip addr add 192.168.100.200/24 dev eth0
sudo ip route add default via 192.168.100.1
```

---

# 10. General Commands & Diagnostic Tools

## 10.1 Wazuh Manager Diagnostics

```bash
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-indexer
sudo systemctl status wazuh-dashboard
sudo tail -50 /var/ossec/logs/ossec.log
sudo tail -f /var/ossec/logs/archives/archives.json
sudo /var/ossec/bin/agent_control -lc
```

---

## 10.2 Windows Agent Diagnostics

```cmd
sc query WazuhSvc
net stop WazuhSvc && net start WazuhSvc
type "C:\Program Files (x86)\ossec-agent\logs\ossec.log" | findstr /i error
```

PowerShell connectivity test:

```powershell
Test-NetConnection 192.168.100.100 -Port 1514
```

---

## 10.3 Network Diagnostics

```bash
ping 192.168.100.1
nslookup soclab.local
sudo tcpdump -i eth0 -n port 1514
```

---

## 10.4 Integration Script Test

```bash
sudo /var/ossec/integrations/custom-shuffle /var/ossec/logs/alerts/alerts.json 0 "https://shuffler.io/api/v1/hooks/YOUR_WEBHOOK_URL"
```

---

## 10.5 Shuffle Webhook Test

```bash
curl -X POST -k "YOUR_WEBHOOK_URL" \
-H "Content-Type: application/json" \
-d '{"test":"testing"}'
```

---

# How to Use This Catalog

1. Identify the exact symptom.
2. Navigate to the matching section.
3. Follow troubleshooting steps sequentially.
4. Enable debug logging if necessary:

```bash
echo "integrator.debug=2" | sudo tee -a /var/ossec/etc/local_internal_options.conf
sudo systemctl restart wazuh-manager
```

5. Collect logs and compare with expected outputs.

---

# Recommended Log Files

| Component | Log File |
|---|---|
| Wazuh Manager | `/var/ossec/logs/ossec.log` |
| Wazuh Alerts | `/var/ossec/logs/alerts/alerts.json` |
| Wazuh Archives | `/var/ossec/logs/archives/archives.json` |
| Windows Agent | `C:\Program Files (x86)\ossec-agent\logs\ossec.log` |
| Sysmon | Event Viewer → Applications and Services Logs → Microsoft → Windows → Sysmon |

---

# Best Practices

- Take VMware snapshots after every successful configuration stage.
- Use static IPs for all infrastructure VMs.
- Keep backups of `ossec.conf`, custom rules, and integration scripts.
- Test webhook integrations manually before running attacks.
- Validate XML files before restarting Wazuh services.

---

**Last Updated:** May 2026  
**Version:** 2.0