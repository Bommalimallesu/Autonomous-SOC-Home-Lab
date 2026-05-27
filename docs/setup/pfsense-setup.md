## pfSense Gateway Installation & Network Rule Provisioning Matrix

## Overview

This document details the deployment and configuration of the pfSense firewall used as the perimeter gateway for the SOC Home Lab environment. The firewall provides:

- Network segmentation
- DHCP services
- Internal routing
- Internet access through NAT
- Stateful firewall filtering
- Traffic isolation for attack simulations

The lab network operates within an isolated host-only subnet (`192.168.100.0/24`) to safely conduct offensive security testing and security monitoring exercises.

---

# Network Topology

```text
                             [ INTERNET ]
                                  │
                                  ▼
                     ┌────────────────────┐
                     │     VMware NAT     │
                     └─────────┬──────────┘
                               │
                        WAN Interface
                          DHCP / NAT
                               │
                     ┌─────────▼──────────┐
                     │      pfSense       │
                     │  Firewall Gateway  │
                     │                    │
                     │ WAN : em0          │
                     │ LAN : em1          │
                     │ 192.168.100.1/24   │
                     └─────────┬──────────┘
                               │
                     VMnet1 (Host-Only)
                        192.168.100.0/24
                               │
        ┌──────────────┬──────────────┬──────────────┬──────────────┐
        │              │              │              │
        ▼              ▼              ▼              ▼
 ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐
 │ Windows DC │ │ Windows 10 │ │ Ubuntu     │ │ Kali Linux │
 │ 192.168.   │ │ 192.168.   │ │ Wazuh SIEM │ │ Attacker   │
 │ 100.2      │ │ 100.50     │ │ 100.100    │ │ 100.200    │
 └────────────┘ └────────────┘ └────────────┘ └────────────┘
```

---

# Virtual Machine Specifications

| Resource | Configuration |
|----------|---------------|
| Hypervisor | VMware Workstation |
| Guest OS | pfSense CE (FreeBSD 64-bit) |
| vCPU | 1 Core |
| Memory | 1536 MB |
| Disk | 20 GB |
| Network Adapter 1 | NAT (WAN) |
| Network Adapter 2 | VMnet1 Host-Only (LAN) |

---

# Step 1 — Create the pfSense Virtual Machine

1. Open VMware Workstation.
2. Select:
   - `File → New Virtual Machine`
3. Choose:
   - `Custom (Advanced)`
4. Select:
   - `I will install the operating system later`
5. Operating System:
   - Type: `FreeBSD`
   - Version: `FreeBSD 12 or later`
6. VM Name:
   - `pfSense-FW`
7. Configure hardware:
   - CPU: `1`
   - RAM: `1536 MB`
   - Disk: `20 GB`
8. Configure network adapters:
   - Adapter 1 → `NAT`
   - Adapter 2 → `VMnet1`
9. Attach the pfSense ISO image.
10. Finish VM creation.

---

# Step 2 — Install pfSense

1. Power on the VM.
2. At the boot menu:
   - Press `Enter`
3. Select:
   - `Install pfSense`
4. Keyboard Layout:
   - `Accept Default`
5. Partitioning:
   - `Auto (ZFS)`
6. ZFS Type:
   - `Stripe`
7. Select installation disk:
   - `ada0`
8. Confirm installation.
9. Reboot after installation completes.
10. Remove the ISO from VMware.

---

# Step 3 — Interface Assignment

After reboot, pfSense opens the console configuration menu.

## Assign Interfaces

| Interface | Adapter | Purpose |
|-----------|---------|----------|
| WAN | em0 | Internet/NAT |
| LAN | em1 | Internal SOC Lab Network |

### Procedure

1. Select option:
   ```text
   1) Assign Interfaces
   ```

2. VLAN configuration:
   ```text
   n
   ```

3. Assign interfaces:
   ```text
   WAN → em0
   LAN → em1
   ```

4. Confirm configuration:
   ```text
   y
   ```

---

# Step 4 — Configure LAN Interface

From the pfSense console menu:

```text
2) Set Interface(s) IP Address
```

## LAN Configuration

| Setting | Value |
|---------|------|
| LAN IP | 192.168.100.1 |
| Subnet | /24 |
| DHCP | Enabled |
| DHCP Range Start | 192.168.100.50 |
| DHCP Range End | 192.168.100.200 |

---

# Step 5 — Access the WebConfigurator

Open a browser on the host machine:

```text
http://192.168.100.1
```

## Default Credentials

| Username | Password |
|----------|----------|
| admin | pfsense |

Immediately change the administrator password after login.

---

# Step 6 — Configure DHCP Services

Navigate to:

```text
Services → DHCP Server
```

## DHCP Settings

| Parameter | Value |
|-----------|------|
| Enable DHCP | Yes |
| Range Start | 192.168.100.50 |
| Range End | 192.168.100.200 |
| Gateway | 192.168.100.1 |
| Primary DNS | 192.168.100.2 |
| Secondary DNS | 8.8.8.8 |
| Domain | soclab.local |

---

# Step 7 — Firewall Rule Provisioning Matrix

Navigate to:

```text
Firewall → Rules → LAN
```

## Rule Matrix

| Order | Action | Source | Destination | Port | Description |
|------|------|------|------|------|------|
| 1 | PASS | LAN net | This Firewall | 22 | Allow SSH management |
| 2 | PASS | LAN net | This Firewall | 80 | Allow Web GUI access |
| 3 | PASS | LAN net | LAN net | ANY | Allow internal VM communication |
| 4 | BLOCK | LAN net | ANY | ANY | Prevent unauthorized outbound traffic |

---

# Step 8 — Apply Configuration

After creating rules:

1. Click:
   ```text
   Save
   ```

2. Then:
   ```text
   Apply Changes
   ```

---

# Step 9 — Validation & Health Checks

## Verify Gateway Connectivity

### Windows

```powershell
ping 192.168.100.1
```

### Linux

```bash
ping -c 4 192.168.100.1
```

---

## Verify DHCP Lease Assignment

### Windows

```powershell
ipconfig
```

### Linux

```bash
ip a
```

Expected subnet:

```text
192.168.100.0/24
```

---

## Verify Internal Communication

From Kali:

```bash
ping 192.168.100.100
```

From Windows 10:

```powershell
ping 192.168.100.2
```

---

# Security Design Notes

## Network Isolation

All systems operate inside a host-only network:

```text
VMnet1 → 192.168.100.0/24
```

This prevents offensive traffic from reaching external networks.

---

## NAT Boundary

Only pfSense has internet access through the WAN interface.

Internal VMs communicate externally only through controlled NAT routing.

---

## Logging & Monitoring

pfSense logs:

- Firewall events
- DHCP leases
- Interface activity
- NAT translations

These logs can later be forwarded into Wazuh for centralized monitoring.

---

# Recommended Snapshots

After completing setup:

| Snapshot Name | Purpose |
|---------------|----------|
| pfSense-Clean | Fresh installation baseline |
| pfSense-Rules | Firewall rules configured |
| pfSense-Stable | Final validated state |

---

# Troubleshooting

## Cannot Access Web GUI

### Verify:

- VMnet1 adapter exists
- Host machine has VMnet1 IP
- Browser uses HTTP:
  ```text
  http://192.168.100.1
  ```

---

## No DHCP Lease

### Verify:

- DHCP server enabled
- VM connected to VMnet1
- No IP conflicts with static hosts

---

## VMs Cannot Communicate

### Verify:

- Firewall rules applied
- All VMs connected to VMnet1
- Correct subnet mask:
  ```text
  255.255.255.0
  ```

---

# Final Validation Checklist

| Validation Item | Expected Result |
|----------------|----------------|
| pfSense boot successful | Console menu visible |
| Web GUI accessible | Login page loads |
| DHCP operational | VMs receive IP addresses |
| Internal routing works | VMs can ping each other |
| Internet access works | WAN reachable through NAT |
| Firewall rules applied | Traffic filtered correctly |

---

# Next Phase

After pfSense deployment:

1. Configure Active Directory (`192.168.100.2`)
2. Install Sysmon on Windows 10
3. Deploy Wazuh SIEM (`192.168.100.100`)
4. Configure Shuffle SOAR integration
5. Integrate ServiceNow incident automation

---

**Document Version:** 1.0  
**Environment:** SOC Home Lab  
**Network Segment:** 192.168.100.0/24  
**Firewall Platform:** pfSense Community Edition
