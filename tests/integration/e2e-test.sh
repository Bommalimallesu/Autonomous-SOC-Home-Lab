# Bash Script: Executing End-to-End Simulation Pipeline Analysis Rules Validation
#!/usr/bin/env bash
# ==============================================================================
# End-to-End SOC Pipeline Validation Framework
# ==============================================================================
#
# File Name      : e2e-test.sh
# Author         : Bommali Mallesu
# Created Date   : May 26, 2026
# Version        : 2.0
# Platform       : Kali Linux / Ubuntu
#
# ==============================================================================
# DESCRIPTION
# ==============================================================================
# This script performs a complete End-to-End SOC pipeline validation:
#
#   [ATTACK SIMULATION]
#        ↓
#   Hydra RDP Brute Force Attack
#        ↓
#   Windows Security Event (4625)
#        ↓
#   Wazuh Detection & Correlation
#        ↓
#   Shuffle SOAR Webhook Processing
#        ↓
#   ServiceNow Incident Creation
#
# ==============================================================================
# FEATURES
# ==============================================================================
# ✔ Simulates RDP brute-force activity using Hydra
# ✔ Validates Wazuh API alert generation
# ✔ Confirms ServiceNow ticket creation
# ✔ Structured logging and color-coded console output
# ✔ Dependency validation
# ✔ Secure API authentication handling
# ✔ Automated workflow verification
#
# ==============================================================================
# REQUIREMENTS
# ==============================================================================
# - Hydra installed
# - jq installed
# - curl installed
# - Active Wazuh Manager
# - Active Shuffle workflow
# - Active ServiceNow integration
# - Windows target with auditing enabled
#
# ==============================================================================
# USAGE
# ==============================================================================
# chmod +x e2e-test.sh
#
# export WAZUH_PASSWORD="YourPassword"
# export SNOW_PASSWORD="YourPassword"
#
# ./e2e-test.sh
#
# ==============================================================================

set -euo pipefail

# ==============================================================================
# TERMINAL COLORS
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ==============================================================================
# CONFIGURATION VARIABLES
# ==============================================================================

# -----------------------------
# ATTACK TARGET CONFIGURATION
# -----------------------------
TARGET_IP="${TARGET_IP:-192.168.100.50}"
ATTACK_USER="${ATTACK_USER:-jdoe}"
ATTACK_PASS_FILE="${ATTACK_PASS_FILE:-passwords.txt}"
HYDRA_THREADS="${HYDRA_THREADS:-2}"

# -----------------------------
# WAZUH API CONFIGURATION
# -----------------------------
WAZUH_HOST="${WAZUH_HOST:-192.168.100.100}"
WAZUH_API_PORT="${WAZUH_API_PORT:-55000}"
WAZUH_USER="${WAZUH_USER:-admin}"
WAZUH_PASSWORD="${WAZUH_PASSWORD:-}"

# -----------------------------
# SERVICENOW CONFIGURATION
# -----------------------------
SNOW_INSTANCE="${SNOW_INSTANCE:-dev123456}"
SNOW_USER="${SNOW_USER:-admin}"
SNOW_PASSWORD="${SNOW_PASSWORD:-}"

# -----------------------------
# TIMING CONTROLS
# -----------------------------
ATTACK_RUNTIME=15
ALERT_WAIT=30
TICKET_WAIT=15

# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================

header() {
    echo ""
    echo -e "${PURPLE}=====================================================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}=====================================================================${NC}"
}

info() {
    echo -e "${BLUE}[*] INFO:${NC} $1"
}

success() {
    echo -e "${GREEN}[+] SUCCESS:${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[-] ERROR:${NC} $1"
}

# ==============================================================================
# DEPENDENCY VALIDATION
# ==============================================================================

check_dependencies() {

    header "PHASE 1 : DEPENDENCY VALIDATION"

    REQUIRED_TOOLS=("curl" "jq" "hydra" "base64")

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if command -v "$tool" &>/dev/null; then
            success "$tool detected."
        else
            error "$tool is not installed."
            exit 1
        fi
    done

    if [[ -z "$WAZUH_PASSWORD" ]]; then
        error "WAZUH_PASSWORD environment variable not configured."
        exit 1
    fi

    if [[ -z "$SNOW_PASSWORD" ]]; then
        error "SNOW_PASSWORD environment variable not configured."
        exit 1
    fi

    success "Environment validation completed successfully."
}

# ==============================================================================
# HYDRA ATTACK EXECUTION
# ==============================================================================

run_attack() {

    header "PHASE 2 : ATTACK SIMULATION"

    info "Preparing password list..."

    if [[ ! -f "$ATTACK_PASS_FILE" ]]; then
        cat > "$ATTACK_PASS_FILE" <<EOF
password
123456
Password@123
admin
letmein
winter2025
EOF
        success "Generated temporary password list."
    fi

    info "Launching Hydra RDP brute-force attack against ${TARGET_IP}..."

    hydra \
        -l "$ATTACK_USER" \
        -P "$ATTACK_PASS_FILE" \
        -t "$HYDRA_THREADS" \
        -V \
        -o /tmp/hydra_output.txt \
        "$TARGET_IP" rdp &

    HYDRA_PID=$!

    sleep "$ATTACK_RUNTIME"

    if kill -0 "$HYDRA_PID" 2>/dev/null; then
        kill "$HYDRA_PID" || true
        success "Hydra attack simulation stopped after ${ATTACK_RUNTIME} seconds."
    fi

    ATTEMPTS=$(grep -c "\[ATTEMPT\]" /tmp/hydra_output.txt 2>/dev/null || echo 0)

    success "Hydra generated approximately ${ATTEMPTS} authentication attempts."
}

# ==============================================================================
# WAZUH ALERT VALIDATION
# ==============================================================================

check_wazuh_alerts() {

    header "PHASE 3 : WAZUH ALERT VALIDATION"

    info "Authenticating with Wazuh API..."

    TOKEN=$(curl -sk -X POST \
        "https://${WAZUH_HOST}:${WAZUH_API_PORT}/security/user/authenticate" \
        -H "Authorization: Basic $(echo -n "${WAZUH_USER}:${WAZUH_PASSWORD}" | base64)" \
        | jq -r '.data.token')

    if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
        error "Failed to obtain Wazuh API token."
        exit 1
    fi

    success "Wazuh API authentication successful."

    info "Searching for brute-force alerts..."

    QUERY='(rule.id:5715 OR rule.id:108889 OR rule.id:100089)'

    ENCODED_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

    RESPONSE=$(curl -sk -X GET \
        "https://${WAZUH_HOST}:${WAZUH_API_PORT}/alerts?q=${ENCODED_QUERY}&limit=5&sort=-timestamp" \
        -H "Authorization: Bearer ${TOKEN}")

    TOTAL_ALERTS=$(echo "$RESPONSE" | jq '.data.total_affected_items')

    if [[ "$TOTAL_ALERTS" -gt 0 ]]; then

        ALERT_RULE=$(echo "$RESPONSE" | jq -r '.data.affected_items[0].rule.id')
        ALERT_DESC=$(echo "$RESPONSE" | jq -r '.data.affected_items[0].rule.description')

        success "Detected ${TOTAL_ALERTS} matching alert(s)."
        info "Latest Alert Rule ID : ${ALERT_RULE}"
        info "Latest Alert Message : ${ALERT_DESC}"

    else
        error "No matching alerts detected in Wazuh."
        exit 1
    fi
}

# ==============================================================================
# SERVICENOW INCIDENT VALIDATION
# ==============================================================================

check_servicenow_ticket() {

    header "PHASE 4 : SERVICENOW INCIDENT VALIDATION"

    info "Querying ServiceNow incident database..."

    QUERY="short_descriptionLIKEWazuh Alert"

    URL="https://${SNOW_INSTANCE}.service-now.com/api/now/table/incident?sysparm_query=${QUERY}&sysparm_limit=1&sysparm_fields=number,short_description,sys_created_on"

    RESPONSE=$(curl -s \
        -u "${SNOW_USER}:${SNOW_PASSWORD}" \
        -X GET "$URL")

    INCIDENT=$(echo "$RESPONSE" | jq -r '.result[0].number // empty')

    if [[ -n "$INCIDENT" ]]; then

        CREATED=$(echo "$RESPONSE" | jq -r '.result[0].sys_created_on')
        DESC=$(echo "$RESPONSE" | jq -r '.result[0].short_description')

        success "Incident successfully created in ServiceNow."
        info "Incident Number : ${INCIDENT}"
        info "Created On      : ${CREATED}"
        info "Description     : ${DESC}"

    else
        error "No Wazuh-generated incident found in ServiceNow."
        exit 1
    fi
}

# ==============================================================================
# FINAL REPORT
# ==============================================================================

final_report() {

    header "SOC PIPELINE VALIDATION COMPLETE"

    echo -e "${GREEN}✔ Attack simulation executed successfully.${NC}"
    echo -e "${GREEN}✔ Wazuh detection engine validated.${NC}"
    echo -e "${GREEN}✔ Shuffle SOAR webhook pipeline operational.${NC}"
    echo -e "${GREEN}✔ ServiceNow incident automation verified.${NC}"
    echo -e "${GREEN}✔ End-to-End SOC workflow functioning correctly.${NC}"

    echo ""
    echo -e "${BLUE}SOC Pipeline:${NC}"
    echo "Hydra → Windows Logs → Wazuh → Shuffle → ServiceNow"

    echo ""
    echo -e "${GREEN}[SUCCESS] End-to-End Security Operations Pipeline PASSED.${NC}"
}

# ==============================================================================
# MAIN EXECUTION FLOW
# ==============================================================================

main() {

    check_dependencies

    run_attack

    header "WAITING FOR ALERT PROCESSING"
    info "Allowing Wazuh indexer to process incoming telemetry..."
    sleep "$ALERT_WAIT"

    check_wazuh_alerts

    header "WAITING FOR TICKET GENERATION"
    info "Allowing Shuffle workflow to create ServiceNow incident..."
    sleep "$TICKET_WAIT"

    check_servicenow_ticket

    final_report
}

main "$@"