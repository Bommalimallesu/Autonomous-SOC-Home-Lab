# Changelog

All notable changes to this project will be documented in this file. This project adheres to strict Semantic Versioning.

## [1.1.0] - 2026-05-26

### Added
- Created `servicenow_integration.py` to automatically ingest SIEM events and programmatically spawn ITIL incident tickets via the ServiceNow Table API.
- Engineered an automated Python testing engine (`test_integration.py`) to simulate high-severity Windows Event Channel telemetry (Event ID 4625 - RDP Brute Force) using an ephemeral NDJSON stream wrapper.
- Developed a modular Bash script (`test_webhook.sh`) utilizing `curl` and network evaluation response logic to audit webhook firing statuses.
- Formulated a comprehensive end-to-end orchestration framework (`e2e_test.sh`) to automatically validate script dependencies, file permissions, and data transport loops.

### Changed
- **Security Hardening**: Deprecated hardcoded passwords and target webhook identification strings inside source integration scripts. Refactored architecture to securely pull variables dynamically from the operating system environment using `os.environ.get`.

### Fixed
- Resolved Python `IndentationError` bugs inside the core validation engine's error handling and process monitoring exception blocks.
- Fixed filesystem access crashes by updating file configuration paths to resolve locally, preventing directory structure exceptions on deployment systems.

---

## [1.0.0] - 2026-05-24

### Added
- Initial deployment of `shuffle_integration.py` to establish a dedicated data pipeline streaming high-priority security telemetry directly from Wazuh SIEM rules to Shuffle SOAR workflows.
- Implemented core JSON ingestion parsing models to seamlessly extract system metadata, host telemetry, and threat characteristics from inbound network traffic logs.
- Configured repository baseline `.gitignore` guardrails to comprehensively block credentials, compiled Python binaries (`__pycache__`), and local raw SIEM text logs from public exposure.
