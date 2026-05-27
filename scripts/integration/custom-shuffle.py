# Python Script: Shipping Alerts from Wazuh Node to Shuffle Webhook
#!/usr/bin/env python3
"""
SIEM to Shuffle SOAR Integration Engine (NDJSON Stream Native).

This script processes Newline Delimited JSON (NDJSON) alert structures passed 
by a SIEM engine (such as Wazuh) and streams individual records to Shuffle SOAR 
webhooks for automated orchestration playbooks.

File Name      : shuffle_integration.py
Author         : Bommali Mallesu
Date Created   : May 26, 2026
Language       : Python 3.x
Dependencies   : requests, urllib3 (pip install requests urllib3)
"""

import sys
import json
import logging
import requests
import urllib3

# Suppress self-signed TLS/SSL certificate verification warnings in home lab testing sandboxes
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ==============================================================================
# LOGGING CONFIGURATION
# ==============================================================================
LOG_FILE = "/var/ossec/logs/integrations/shuffle.log"
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)


def send_to_webhook(alert_data, webhook_url):
    """
    Formulates and executes the HTTP POST telemetry payload transfer to Shuffle SOAR.
    """
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "Wazuh-Shuffle-Pipeline/2.0"
    }
    
    try:
        response = requests.post(
            url=webhook_url, 
            json=alert_data, 
            headers=headers, 
            timeout=10, 
            verify=False  # Vital bypass for self-signed SSL certs inside a closed lab environment
        )
        
        if response.status_code in [200, 201, 202]:
            logging.info(f"SUCCESS: Alert ID [{alert_data.get('id', 'N/A')}] transmitted to Shuffle plane.")
            return True
        else:
            logging.warning(f"FAILED: Ingestion dropped by Shuffle. HTTP Status: {response.status_code}")
            return False
            
    except Exception as error:
        logging.critical(f"CRITICAL: Pipeline transport exception encountered: {error}")
        return False


# ==============================================================================
# MAIN PIPELINE EXECUTION ENTRYPOINT
# ==============================================================================
if __name__ == "__main__":
    logging.info("Initializing Shuffle integration worker framework...")

    # Wazuh natively executes integrations by passing arguments in this precise positional order:
    # sys.argv[1] = Alert file path
    # sys.argv[2] = API Key (optional, defaults to empty string if not used)
    # sys.argv[3] = Custom Hook / API Target Address
    if len(sys.argv) < 4:
        logging.error("ERROR: Invalid execution parameters. Usage: script.py <alert_file> <api_key> <webhook_url>")
        sys.exit(1)
        
    alert_file_path = sys.argv[1]   
    webhook_target  = sys.argv[3]   
    
    try:
        # Stream parse the NDJSON alerts logfile line by line
        with open(alert_file_path, 'r', encoding='utf-8') as file:
            for line in file:
                line = line.strip()
                if not line:
                    continue  # Skip trailing empty newline breaks safely
                
                try:
                    alert_payload = json.loads(line)
                    send_to_webhook(alert_payload, webhook_target)
                except json.JSONDecodeError:
                    logging.warning("Skipped malformed NDJSON log line entry during parsing pass.")
                    continue
                    
    except Exception as init_err:
        logging.critical(f"CRITICAL: Resource access failure on target log file descriptor: {init_err}")
        sys.exit(1)
        
    logging.info("Integration pipeline processing complete.")
    sys.exit(0)