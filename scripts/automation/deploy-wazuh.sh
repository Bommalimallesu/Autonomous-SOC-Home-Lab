# Bash Script: Deploying Wazuh SIEM Component Stack Nodes
#!/bin/bash
# =============================================================================
# File Name    : deploy-wazuh-stack.sh
# Description  : Automated Wazuh All-in-One SIEM Deployment Script
# Author       : Bommali Mallesu
# Version      : 2.0
# Created      : May 2026
# Supported OS : Ubuntu Server 22.04 / 24.04 LTS
#
# PURPOSE
# -----------------------------------------------------------------------------
# This script automates the deployment of a complete Wazuh SIEM stack including:
#
#   • Wazuh Manager
#   • Wazuh Indexer
#   • Wazuh Dashboard
#   • Custom Detection Rules
#   • Archive Logging
#   • Firewall Configuration
#   • Service Validation
#
# LAB ENVIRONMENT
# -----------------------------------------------------------------------------
# Recommended VM Specs:
#   CPU    : 2 vCPUs
#   RAM    : 4 GB Minimum
#   Disk   : 80 GB
#   Network: Static IP Recommended
#
# EXECUTION
# -----------------------------------------------------------------------------
# chmod +x deploy-wazuh-stack.sh
# sudo ./deploy-wazuh-stack.sh
#
# =============================================================================

set -e

# =============================================================================
# TERMINAL COLORS
# =============================================================================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# BANNER
# =============================================================================
clear
echo -e "${CYAN}"
echo "============================================================================="
echo "             WAZUH SIEM STACK DEPLOYMENT AUTOMATION ENGINE"
echo "============================================================================="
echo -e "${NC}"

# =============================================================================
# ROOT PRIVILEGE CHECK
# =============================================================================
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be executed with root privileges."
    echo ""
    echo "Run using:"
    echo "sudo ./deploy-wazuh-stack.sh"
    exit 1
fi

# =============================================================================
# OPERATING SYSTEM VALIDATION
# =============================================================================
if ! grep -qi "ubuntu" /etc/os-release; then
    log_error "Unsupported operating system detected."
    log_warning "Supported Platforms: Ubuntu 22.04 / 24.04 LTS"
    exit 1
fi

# =============================================================================
# SYSTEM INFORMATION
# =============================================================================
HOSTNAME=$(hostname)
SERVER_IP=$(hostname -I | awk '{print $1}')
OS_VERSION=$(lsb_release -ds)

echo ""
log_info "System Information"
echo "------------------------------------------------------------"
echo "Hostname      : $HOSTNAME"
echo "Operating OS  : $OS_VERSION"
echo "Primary IP    : $SERVER_IP"
echo "------------------------------------------------------------"

# =============================================================================
# STEP 1 - SYSTEM UPDATE & DEPENDENCIES
# =============================================================================
echo ""
log_info "STEP 1 - Updating System Packages"

apt update -y
apt upgrade -y

log_info "Installing Required Dependencies"

apt install -y \
    curl \
    wget \
    unzip \
    gnupg \
    apt-transport-https \
    software-properties-common \
    lsb-release \
    ca-certificates \
    ufw

log_success "System dependencies installed successfully."

# =============================================================================
# STEP 2 - DOWNLOAD OFFICIAL WAZUH INSTALLER
# =============================================================================
echo ""
log_info "STEP 2 - Downloading Official Wazuh Deployment Script"

cd /tmp

curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh

chmod +x wazuh-install.sh

log_success "Installer downloaded successfully."

# =============================================================================
# STEP 3 - INSTALL WAZUH ALL-IN-ONE STACK
# =============================================================================
echo ""
log_info "STEP 3 - Installing Wazuh SIEM Stack"

log_warning "This process may take several minutes..."

bash ./wazuh-install.sh -a -i

log_success "Wazuh stack installation completed."

# =============================================================================
# STEP 4 - RETRIEVE GENERATED ADMIN PASSWORD
# =============================================================================
echo ""
log_info "STEP 4 - Extracting Dashboard Credentials"

WAZUH_PASSWORD=$(grep -oP '(?<=The password is: )\S+' \
/var/log/wazuh-install.log | head -1)

if [[ -n "$WAZUH_PASSWORD" ]]; then

    echo "$WAZUH_PASSWORD" > /root/wazuh_dashboard_password.txt

    chmod 600 /root/wazuh_dashboard_password.txt

    log_success "Dashboard password extracted successfully."

else
    log_warning "Password extraction failed."
    log_warning "Check: /var/log/wazuh-install.log"
fi

# =============================================================================
# STEP 5 - ENABLE ARCHIVE LOGGING
# =============================================================================
echo ""
log_info "STEP 5 - Enabling Full Archive Logging"

OSSEC_CONF="/var/ossec/etc/ossec.conf"

if [[ -f "$OSSEC_CONF" ]]; then

    sed -i 's/<logall>no<\/logall>/<logall>yes<\/logall>/' "$OSSEC_CONF"

    sed -i 's/<logall_json>no<\/logall_json>/<logall_json>yes<\/logall_json>/' "$OSSEC_CONF"

    log_success "Archive logging enabled successfully."

else
    log_error "ossec.conf not found."
fi

# =============================================================================
# STEP 6 - DEPLOY CUSTOM DETECTION RULES
# =============================================================================
echo ""
log_info "STEP 6 - Configuring Custom Detection Rules"

CUSTOM_RULES="/var/ossec/etc/rules/local_rules.xml"

cat > "$CUSTOM_RULES" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<group name="local,custom_windows,sshd,">

  <!-- SSH Authentication Failure -->
  <rule id="100001" level="5">
    <if_sid>5716</if_sid>
    <srcip>1.1.1.1</srcip>
    <description>sshd: authentication failed from IP 1.1.1.1.</description>
    <group>authentication_failed,pci_dss_10.2.4,pci_dss_10.2.5</group>
  </rule>

  <!-- Windows Logon Failure -->
  <rule id="100088" level="5">
    <if_sid>60106</if_sid>
    <field name="win.system.eventID">^4625$</field>
    <description>Windows: Logon failure detected (Event ID 4625).</description>
  </rule>

  <!-- Windows Brute Force Detection -->
  <rule id="100089"
        level="10"
        frequency="5"
        timeframe="60">

    <if_matched_sid>100088</if_matched_sid>
    <same_source_ip />

    <description>
      Multiple Windows logon failures detected from same source IP.
    </description>

    <options>no_full_log</options>
  </rule>

  <!-- Registry Modification Detection -->
  <rule id="100090" level="10">
    <if_sid>60103</if_sid>
    <field name="win.system.eventID">^4657$</field>
    <description>
      CRITICAL: Registry value modified in monitored key.
    </description>
  </rule>

</group>

<group name="local,reconnaissance,">

  <!-- Local Group Enumeration -->
  <rule id="100095" level="10">
    <if_sid>60103</if_sid>
    <field name="win.system.eventID">^4798$</field>

    <description>
      Security reconnaissance detected: Local group enumeration.
    </description>
  </rule>

</group>
EOF

log_success "Custom detection rules deployed."

# =============================================================================
# STEP 7 - VALIDATE XML RULE STRUCTURE
# =============================================================================
echo ""
log_info "STEP 7 - Validating XML Rule Syntax"

apt install -y libxml2-utils > /dev/null 2>&1

xmllint --noout "$CUSTOM_RULES"

log_success "XML validation completed successfully."

# =============================================================================
# STEP 8 - RESTART WAZUH SERVICES
# =============================================================================
echo ""
log_info "STEP 8 - Restarting Wazuh Services"

systemctl restart wazuh-manager
systemctl restart wazuh-indexer
systemctl restart wazuh-dashboard

sleep 5

log_success "All Wazuh services restarted."

# =============================================================================
# STEP 9 - CONFIGURE FIREWALL RULES
# =============================================================================
echo ""
log_info "STEP 9 - Configuring UFW Firewall"

ufw --force enable

ufw allow 22/tcp
ufw allow 1514/tcp
ufw allow 1515/tcp
ufw allow 55000/tcp
ufw allow 443/tcp

log_success "Firewall rules configured successfully."

# =============================================================================
# STEP 10 - SERVICE STATUS VERIFICATION
# =============================================================================
echo ""
log_info "STEP 10 - Verifying Wazuh Services"

echo ""
systemctl --no-pager --type=service | grep wazuh

echo ""

MANAGER_STATUS=$(systemctl is-active wazuh-manager)
INDEXER_STATUS=$(systemctl is-active wazuh-indexer)
DASHBOARD_STATUS=$(systemctl is-active wazuh-dashboard)

if [[ "$MANAGER_STATUS" == "active" ]] && \
   [[ "$INDEXER_STATUS" == "active" ]] && \
   [[ "$DASHBOARD_STATUS" == "active" ]]; then

    log_success "All Wazuh services are operational."

else
    log_error "One or more Wazuh services failed."
    log_warning "Run: journalctl -xe"
    exit 1
fi

# =============================================================================
# FINAL DEPLOYMENT SUMMARY
# =============================================================================
echo ""
echo -e "${CYAN}=============================================================================${NC}"
echo -e "${GREEN}                WAZUH SIEM DEPLOYMENT COMPLETED SUCCESSFULLY${NC}"
echo -e "${CYAN}=============================================================================${NC}"

echo ""
echo "Dashboard URL  : https://$SERVER_IP"
echo "Username       : admin"

if [[ -f /root/wazuh_dashboard_password.txt ]]; then
    echo "Password       : $(cat /root/wazuh_dashboard_password.txt)"
else
    echo "Password       : Check /var/log/wazuh-install.log"
fi

echo ""
echo "Enabled Ports:"
echo "------------------------------------------------------------"
echo "22/tcp    - SSH"
echo "1514/tcp  - Wazuh Agent Communication"
echo "1515/tcp  - Agent Enrollment"
echo "55000/tcp - Wazuh API"
echo "443/tcp   - Wazuh Dashboard"
echo "------------------------------------------------------------"

echo ""
echo "Custom Detection Rules:"
echo "------------------------------------------------------------"
echo "100001 - SSH Authentication Failure"
echo "100088 - Windows Logon Failure"
echo "100089 - Windows Brute Force Detection"
echo "100090 - Registry Modification Detection"
echo "100095 - Local Group Enumeration"
echo "------------------------------------------------------------"

echo ""
echo "Next Steps:"
echo "------------------------------------------------------------"
echo "1. Install Wazuh agents on endpoints"
echo "2. Configure Sysmon on Windows systems"
echo "3. Verify agent connectivity"
echo "4. Launch attack simulations"
echo "5. Validate alert generation in dashboard"
echo "------------------------------------------------------------"

echo ""
log_success "Deployment process completed successfully."

exit 0