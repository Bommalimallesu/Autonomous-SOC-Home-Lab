# Python Script: Testing REST API Interface Authentication Pipelines
#!/usr/bin/env python3
"""
SIEM Integration Simulation and Testing Harness.

This script mocks a high-severity incident payload, formats it into Newline 
Delimited JSON (NDJSON), and executes a target integration API script by 
replicating the exact environment and positional parameters used by SIEM daemons.

File Name      : test_integration.py
Author         : Bommali Mallesu
Date Created   : May 26, 2026
Language       : Python 3.x
Usage          : python3 test_integration.py <path_to_integration_script.py>
"""

import os
import sys
import json
import subprocess
import tempfile

# ==============================================================================
# MOCK TELEMETRY PAYLOAD MATRIX (Simulating a Critical RDP Brute Force Attack)
# ==============================================================================
MOCK_ALERT = {
    "id": "1779774242.894102",
    "timestamp": "2026-05-26T14:15:00.123Z",
    "agent": {
        "id": "002",
        "name": "WIN10-ENDPOINT",
        "ip": "192.168.100.50"
    },
    "manager": {
        "name": "ubuntu-siem"
    },
    "rule": {
        "id": "60123",
        "level": 11,
        "description": "Active RDP Brute Force Attack Detected - Password Guessing Matrix",
        "mitre": {
            "id": ["T1110.001"],
            "tactic": ["Credential Access"],
            "technique": ["Brute Force: Password Guessing"]
        }
    },
    "decoder": {
        "name": "windows_eventchannel"
    },
    "data": {
        "win": {
            "system": {
                "eventID": "4625",
                "channel": "Security",
                "severityValue": "AUDIT_FAILURE"
            },
            "eventdata": {
                "targetUserName": "Administrator",
                "logonType": "10",
                "ipAddress": "192.168.100.200"
            }
        }
    }
}


def run_integration_test(integration_script_path):
    """
    Creates a temporary log asset and builds the system process mock wrapper
    with strict exception handling.
    """
    # Defensive check: Ensure the user actually passed a valid file target
    if not os.path.exists(integration_script_path):
        print(f"[-] ERROR: Target integration script not found: {integration_script_path}")
        return False

    # Mock parameters representing variables inside typical SIEM configs
    mock_api_key = "test_sandbox_api_key_xyz987"
    mock_hook_url = "https://httpbin.org/post"  # Public REST echo server to safely verify transport

    print("[*] Generating mock NDJSON telemetry log payload...")
    
    # Create a secure temporary file to house our test log entry stream
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as temp_alert_file:
        # Write payload followed by a clean newline to strictly match NDJSON standards
        temp_alert_file.write(json.dumps(MOCK_ALERT) + "\n")
        temp_file_path = temp_alert_file.name

    print(f"[+] Temporary alert tracking asset initialized: {temp_file_path}")
    print(f"[*] Simulating process execution environment...")
    
    # Replicate the exact positional array architecture used by the SIEM engine:
    # Arg 0: Script Name | Arg 1: Temp Log Path | Arg 2: API Key | Arg 3: Endpoint URL
    cmd = ["python3", integration_script_path, temp_file_path, mock_api_key, mock_hook_url]
    print(f"[*] Command: {' '.join(cmd)}\n")

    try:
        # Execute the process thread, capture console descriptors, and force validation hooks
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        
        print("=" * 70)
        print("[SUCCESS] Test harness completed execution without crashes.")
        print(f"[STDOUT FROM SCRIPT]:\n{result.stdout if result.stdout else '(No console outputs generated)'}")
        print("=" * 70)
        return True

    except subprocess.CalledProcessError as proc_err:
        print("=" * 70)
        print(f"[CRITICAL FAILURE] Target script exited with errors. Code: {proc_err.returncode}")
        print(f"[STDERR FROM SCRIPT]:\n{proc_err.stderr}")
        print(f"[STDOUT FROM SCRIPT]:\n{proc_err.stdout}")
        print("=" * 70)
        return False

    finally:
        # Guarantee removal of the temporary storage file asset to maintain workspace health
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)
            print("[+] Volatile test log asset successfully unlinked from system storage.")


if __name__ == "__main__":
    # Ensure correct terminal syntax constraints
    if len(sys.argv) < 2:
        print("[-] ERROR: Target integration script parameter missing.")
        print("Usage: python3 test_integration.py <path_to_integration_script.py>")
        sys.exit(1)

    target_script = sys.argv[1]
    success = run_integration_test(target_script)
    
    if success:
        sys.exit(0)
    else:
        sys.exit(1)
