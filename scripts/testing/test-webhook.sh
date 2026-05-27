# Bash Script: Evaluating Integration Webhook JSON Payload Firing Status
#!/usr/bin/env bash
# =============================================================================
# File Name    : test-webhook.sh
# Description  : Wazuh → Shuffle Webhook Connectivity & Payload Validation Tool
# Author       : Bommali Mallesu
# Version      : 3.0
# Created      : May 2026
#
# PURPOSE
# -----------------------------------------------------------------------------
# This script validates end-to-end webhook communication between:
#
#   Wazuh SIEM  --->  Shuffle SOAR  --->  ServiceNow
#
# It sends a simulated Wazuh alert payload to a Shuffle webhook endpoint
# and evaluates the HTTP/API response returned by the SOAR platform.
#
# FEATURES
# -----------------------------------------------------------------------------
# • Sends realistic Wazuh alert JSON payloads
# • Validates webhook connectivity
# • Displays HTTP response codes
# • Supports verbose debugging mode
# • Parses execution IDs automatically
# • Provides troubleshooting feedback
# • SOC-lab friendly output formatting
#
# USAGE
# -----------------------------------------------------------------------------
# chmod +x test-webhook.sh
#
# ./test-webhook.sh <WEBHOOK_URL>
#
# Example:
# ./test-webhook.sh https://shuffler.io/api/v1/hooks/xxxxxxxx
#
# Verbose Mode:
# ./test-webhook.sh https://shuffler.io/api/v1/hooks/xxxxxxxx --verbose
#
# =============================================================================

set -o errexit
set -o pipefail

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
echo "           SHUFFLE WEBHOOK VALIDATION & ALERT PIPELINE TESTER"
echo "============================================================================="
echo -e "${NC}"

# =============================================================================
# USAGE FUNCTION
# =============================================================================
usage() {
    echo ""
    echo "Usage:"
    echo "------------------------------------------------------------"
    echo "  $0 <WEBHOOK_URL> [--verbose]"
    echo ""
    echo "Examples:"
    echo "------------------------------------------------------------"
    echo "  $0 https://shuffler.io/api/v1/hooks/abcd1234"
    echo ""
    echo "  $0 https://shuffler.io/api/v1/hooks/abcd1234 --verbose"
    echo "------------------------------------------------------------"
    echo ""
    exit 1
}

# =============================================================================
# INPUT VALIDATION
# =============================================================================
if [[ $# -lt 1 ]]; then
    usage
fi

WEBHOOK_URL="$1"
VERBOSE=false

if [[ "$2" == "--verbose" ]]; then
    VERBOSE=true
fi

# =============================================================================
# VALIDATE URL FORMAT
# =============================================================================
if [[ ! "$WEBHOOK_URL" =~ ^https?:// ]]; then
    log_error "Invalid webhook URL format."
    exit 1
fi

# =============================================================================
# BUILD SAMPLE WAZUH ALERT PAYLOAD
# =============================================================================
log_info "Generating simulated Wazuh alert payload..."

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

read -r -d '' PAYLOAD << EOF || true
{
  "timestamp": "$TIMESTAMP",
  "rule": {
    "id": 100089,
    "level": 10,
    "description": "Multiple Windows logon failures detected from same source IP.",
    "groups": [
      "windows",
      "authentication_failed",
      "bruteforce"
    ]
  },
  "agent": {
    "id": "001",
    "name": "WIN10-ENDPOINT",
    "ip": "192.168.100.50"
  },
  "manager": {
    "name": "ubuntu-siem"
  },
  "data": {
    "win": {
      "system": {
        "eventID": 4625,
        "channel": "Security",
        "computer": "WIN10-ENDPOINT.soclab.local"
      },
      "eventdata": {
        "targetUserName": "jdoe",
        "ipAddress": "192.168.100.200",
        "logonType": 10
      }
    }
  },
  "full_log": "An account failed to log on. Account Name: jdoe, Source IP: 192.168.100.200, Logon Type: 10",
  "location": "EventChannel",
  "decoder": {
    "name": "windows_eventchannel"
  }
}
EOF

# =============================================================================
# DISPLAY TARGET INFORMATION
# =============================================================================
echo ""
log_info "Webhook Target Information"
echo "------------------------------------------------------------"
echo "Target URL : $WEBHOOK_URL"
echo "Verbose    : $VERBOSE"
echo "Timestamp  : $TIMESTAMP"
echo "------------------------------------------------------------"

# =============================================================================
# SEND REQUEST
# =============================================================================
echo ""
log_info "Sending payload to Shuffle webhook..."

if [[ "$VERBOSE" == true ]]; then

    curl \
        --request POST \
        --header "Content-Type: application/json" \
        --data "$PAYLOAD" \
        --write-out "\nHTTP Status Code: %{http_code}\n" \
        --verbose \
        "$WEBHOOK_URL"

    exit 0
fi

# =============================================================================
# SILENT REQUEST MODE
# =============================================================================
HTTP_RESPONSE=$(curl \
    --silent \
    --show-error \
    --write-out "\nHTTP_STATUS:%{http_code}" \
    --request POST \
    --header "Content-Type: application/json" \
    --data "$PAYLOAD" \
    --connect-timeout 10 \
    --max-time 20 \
    "$WEBHOOK_URL")

# =============================================================================
# EXTRACT RESPONSE BODY & STATUS CODE
# =============================================================================
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTP_STATUS\:.*//g')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')

# =============================================================================
# DISPLAY RESULTS
# =============================================================================
echo ""
echo "============================================================================="
log_info "Webhook Response Evaluation"
echo "============================================================================="

echo "HTTP Status Code : $HTTP_STATUS"
echo ""

# =============================================================================
# RESPONSE HANDLING MATRIX
# =============================================================================
case "$HTTP_STATUS" in

    200|201|202)

        log_success "Webhook accepted the payload successfully."

        # Attempt to extract execution ID
        EXEC_ID=$(echo "$HTTP_BODY" | grep -o '"execution_id":"[^"]*"' | cut -d '"' -f4 || true)

        if [[ -n "$EXEC_ID" ]]; then
            echo ""
            echo "Execution ID : $EXEC_ID"
        fi

        echo ""
        echo "Recommended Validation Steps:"
        echo "------------------------------------------------------------"
        echo "1. Open Shuffle dashboard"
        echo "2. Check workflow execution history"
        echo "3. Verify ServiceNow incident creation"
        echo "4. Confirm Wazuh alert correlation"
        echo "------------------------------------------------------------"

        ;;

    400)

        log_error "HTTP 400 - Bad Request"
        echo ""
        echo "Possible Causes:"
        echo "------------------------------------------------------------"
        echo "• Invalid JSON payload format"
        echo "• Missing required workflow fields"
        echo "• Incorrect webhook configuration"
        echo "------------------------------------------------------------"

        ;;

    401|403)

        log_error "Authentication or authorization failure."
        echo ""
        echo "Possible Causes:"
        echo "------------------------------------------------------------"
        echo "• Invalid webhook token"
        echo "• Expired workflow"
        echo "• Incorrect permissions"
        echo "------------------------------------------------------------"

        ;;

    404)

        log_error "Webhook endpoint not found."
        echo ""
        echo "Possible Causes:"
        echo "------------------------------------------------------------"
        echo "• Incorrect webhook URL"
        echo "• Workflow deleted"
        echo "• Workflow not deployed"
        echo "------------------------------------------------------------"

        ;;

    500|502|503|504)

        log_error "Server-side processing failure."
        echo ""
        echo "Possible Causes:"
        echo "------------------------------------------------------------"
        echo "• Shuffle backend unavailable"
        echo "• ServiceNow node failure"
        echo "• Workflow logic exception"
        echo "------------------------------------------------------------"

        ;;

    000)

        log_error "Connection failure or timeout."
        echo ""
        echo "Possible Causes:"
        echo "------------------------------------------------------------"
        echo "• No internet connectivity"
        echo "• DNS resolution failure"
        echo "• Firewall restrictions"
        echo "• Target server unreachable"
        echo "------------------------------------------------------------"

        ;;

    *)

        log_warning "Unexpected HTTP response received."
        echo ""
        echo "Response Body:"
        echo "------------------------------------------------------------"
        echo "$HTTP_BODY"
        echo "------------------------------------------------------------"

        ;;
esac

# =============================================================================
# TROUBLESHOOTING REFERENCE
# =============================================================================
echo ""
echo "============================================================================="
log_info "Quick Troubleshooting Reference"
echo "============================================================================="

echo ""
echo "Connection Test:"
echo "------------------------------------------------------------"
echo "curl -I https://shuffler.io"
echo ""

echo "DNS Validation:"
echo "------------------------------------------------------------"
echo "nslookup shuffler.io"
echo ""

echo "Verbose Debugging:"
echo "------------------------------------------------------------"
echo "./test-webhook.sh <WEBHOOK_URL> --verbose"
echo ""

echo "Check Wazuh Integration Logs:"
echo "------------------------------------------------------------"
echo "sudo tail -f /var/ossec/logs/ossec.log"
echo ""

echo "Check Raw Alerts:"
echo "------------------------------------------------------------"
echo "sudo tail -f /var/ossec/logs/alerts/alerts.json"
echo ""

# =============================================================================
# COMPLETION MESSAGE
# =============================================================================
echo "============================================================================="

if [[ "$HTTP_STATUS" =~ ^(200|201|202)$ ]]; then
    log_success "Webhook pipeline validation completed successfully."
    exit 0
else
    log_error "Webhook pipeline validation failed."
    exit 1
fi