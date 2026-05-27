# Python Script: Orchestrating Ticket Routing into ServiceNow IT Queue
#!/usr/bin/env python3
"""
SIEM to ServiceNow ITSM Incident Integration Engine.

This script processes security alert payloads and uses the ServiceNow Table API
to automatically create structured ITIL incidents for high-severity events.

File Name      : servicenow_integration.py
Author         : Bommali Mallesu
Date Created   : May 26, 2026
Language       : Python 3.x
Dependencies   : requests (pip install requests)
"""

import sys
import json
import requests
from requests.auth import HTTPBasicAuth

# ==============================================================================
# GLOBAL CONFIGURATIONS (Safe local logging for testing & clean repositories)
# ==============================================================================
LOG_FILE = "./servicenow.log"

# ServiceNow Instance Credentials (Update with your Personal Developer Instance details)
SNOW_INSTANCE = "dev396259"  # e.g., if your URL is dev12345.service-now.com, put "dev12345"
SNOW_USER     = "admin"
SNOW_PASS     = "YourSecurePasswordHere"

# Target Endpoint for the ServiceNow Table API (Incident Table)
SERVICENOW_API_URL = f"https://dev396259.service-now.com/api/now/table/incident"


def create_servicenow_incident(alert_data, api_url):
    """
    Parses incoming telemetry fields and maps them to a ServiceNow incident record.
    """
    # Extract structural components safely from the incoming SIEM payload
    rule_id     = alert_data.get('rule', {}).get('id', 'Unknown Rule')
    description = alert_data.get('rule', {}).get('description', 'No description provided.')
    agent_name  = alert_data.get('agent', {}).get('name', 'Unknown Endpoint')
    alert_id    = alert_data.get('id', 'N/A')
    
    # Dynamic Severity Mapping Matrix (Maps Wazuh 0-15 levels to ITIL 1-3 priorities)
    severity_level = int(alert_data.get('rule', {}).get('level', 0))
    if severity_level >= 12:
        urgency, impact = "1", "1"  # P1 - Critical (e.g., Active Ransomware / Data Exfiltration)
    elif severity_level >= 7:
        urgency, impact = "2", "2"  # P2 - Medium (e.g., Successful Brute Force)
    else:
        urgency, impact = "3", "3"  # P3 - Low (e.g., Minor Policy Violations)

    # Build the incident body envelope matching ServiceNow schema definitions
    payload = {
        "short_description": f"SIEM Alert [Rule {rule_id}]: {description[:60]}",
        "description": (
            f"Automated Alert Telemetry Dispatch:\n"
            f"- Alert ID: {alert_id}\n"
            f"- Affected Host: {agent_name}\n"
            f"- Rule ID: {rule_id}\n"
            f"- Rule Level: {severity_level}\n"
            f"- Detection Summary: {description}"
        ),
        "urgency": urgency,
        "impact": impact,
        "category": "Security",
        "subcategory": "Unauthorized Access",
        "assignment_group": "Security Operations Center",
        "contact_type": "SIEM Automation Pipeline"
    }

    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "Wazuh-ServiceNow-Pipeline/2.0"
    }

    try:
        response = requests.post(
            url=api_url,
            auth=HTTPBasicAuth(SNOW_USER, SNOW_PASS),
            headers=headers,
            json=payload,
            timeout=10
        )

        # Track and verify creation (ServiceNow API returns HTTP 201 Created on success)
        if response.status_code == 201:
            response_data = response.json()
            ticket_number = response_data.get('result', {}).get('number', 'UNKNOWN')
            
            log_msg = f"STATUS: 201 - Successfully created ServiceNow Incident: {ticket_number}\n"
            with open(LOG_FILE, "a") as f:
                f.write(log_msg)
                
            print(f"[+] ServiceNow Incident successfully initialized: {ticket_number}")
            return True
        else:
            print(f"[-] ServiceNow rejected request with status code {response.status_code}")
            return False

    except Exception as err:
        print(f"[-] Pipeline transport interface failure: {err}")
        return False


# ==============================================================================
# MAIN EXECUTION ROUTINE
# ==============================================================================
if __name__ == "__main__":
    # Check execution constraints. If running manually, we fall back to global vars
    if len(sys.argv) < 4:
        print("[*] Manual execution detected. Processing payload via hardcoded credentials.")
        target_url = SERVICENOW_API_URL
        
        if len(sys.argv) < 2:
            print("[-] ERROR: A log file path must be provided. Usage: python3 script.py <alert_file.json>")
            sys.exit(1)
        alert_file_path = sys.argv[1]
    else:
        # Production mode launched natively by the Wazuh manager daemon process
        alert_file_path = sys.argv[1]
        target_url      = sys.argv[3]

    try:
        # Stream read the log contents line by line to support NDJSON streaming architectures
        with open(alert_file_path, 'r', encoding='utf-8') as file:
            for line in file:
                line = line.strip()
                if not line:
                    continue
                
                try:
                    alert_payload = json.loads(line)
                    create_servicenow_incident(alert_payload, target_url)
                except json.JSONDecodeError:
                    continue

    except Exception as init_err:
        print(f"[-] Critical system resource access error: {init_err}")
        sys.exit(1)

    sys.exit(0)