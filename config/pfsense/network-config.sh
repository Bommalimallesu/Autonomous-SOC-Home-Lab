# System Network Subnet Routing Rules Framework Script
#!/bin/bash
================================================================================
# SOC LAB COMPONENT: NETWORK CONFIGURATION HELPER REFERENCE
# Path: config/pfsense/network-conf.sh
# Purpose: Documenting interfaces, address mappings, and route states for the lab gateway.
================================================================================

# --- SYSTEM SUB-NET ENVIRONMENT DEFINITIONS ---
LAB_SUBNET="192.168.100.0/24"
GATEWAY_IP="192.168.100.1"
DNS_SERVER="192.168.100.2"

# --- CORE ENDPOINT IP STATICS ---
DC_AD_SERVER="192.168.100.2"
WIN10_VICTIM="192.168.100.50"
WAZUH_SIEM="192.168.100.100"
KALI_ATTACKER="192.168.100.200"

echo "=== [SOC LAB NETWORK LAYOUT REFERENCE VERIFICATION] ==="
echo "Subnet Mask Context   : ${LAB_SUBNET}"
echo "Gateway Interface     : ${GATEWAY_IP} (pfSense LAN Interface)"
echo "Internal Identity DNS : ${DNS_SERVER} (Windows Server AD/DNS Core)"
echo "--------------------------------------------------------"
echo "Component Map Configured:"
echo " -> Domain Controller  : ${DC_AD_SERVER}"
echo " -> Windows Workstation: ${WIN10_VICTIM} (Sysmon Logs Provider)"
echo " -> SIEM Infrastructure: ${WAZUH_SIEM} (Wazuh Processing Manager)"
echo " -> Offensive Sandbox  : ${KALI_ATTACKER} (Hydra Attack Platform)"
echo "========================================================"

# Note: This is an architectural descriptor asset. 
# Physical network routing configurations are initialized natively via the pfSense Web GUI 
# mapping WAN (em0) interface to NAT mode, and LAN (em1) to Host-Only VMnet1.