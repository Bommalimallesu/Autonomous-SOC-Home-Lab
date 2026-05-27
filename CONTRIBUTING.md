# Contributing Guide
# Contributing to  Autonomous SOC Home Lab

![Open Source](https://img.shields.io/badge/Open%20Source-%E2%9D%A4-brightgreen)
![Version](https://img.shields.io/badge/Version-1.0.0-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

Thank you for your interest in contributing to **SOC Home Lab**! This project aims to provide a complete, working Security Operations Center environment for learning and experimentation. Your help makes security education more accessible to the community.

---

## 📌 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [🛡️ Security First Policy](#-security-first-policy)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing & Validation](#testing--validation)
- [Commit Message Format](#commit-message-format)
- [Recognition Wall](#recognition-wall)

---

## Code of Conduct

This project adheres to the **Contributor Covenant Code of Conduct**. By participating, you agree to:
✅ **Be Respectful** | ✅ **Be Inclusive** | ✅ **Be Constructive** | ✅ **Be Honest**

---

## 🛡️ Security First Policy

> [!IMPORTANT]
> **NEVER commit real credentials.** This includes API keys, webhook URLs, authentication tokens, or production telemetry. Use environment variables and `.env` templates (which are ignored by git).

---

## How to Contribute

### Reporting Bugs
Please use the **Bug Report** issue template. Include:
- **Steps to reproduce:** (Commands run, VM config).
- **Environment:** (Host hardware, hypervisor, software versions).
- **Logs:** Excerpts from `ossec.log`, Shuffle outputs, or ServiceNow errors (Ensure you scrub sensitive data).

### Suggesting Enhancements
Use the **Feature Request** template. Describe:
- The current limitation or missing feature.
- Why it would be valuable for the lab.
- How you envision it working (include code snippets or workflow diagrams).

---

## Development Workflow

1. **Fork** the repository and create a feature branch (`feat/name` or `fix/name`).
2. **Commit** your changes following the [Commit Message Guidelines](#commit-message-format).
3. **Test** locally using the scripts in `tests/`.
4. **Submit** the PR. Include a summary of changes and reference the issue it addresses.

---

## Code Standards

### Python & Shell
- **Python:** Follow PEP 8. Include shebang (`#!/usr/bin/env python3`) and `if __name__ == "__main__":` guard.
- **Shell (Bash):** Use `set -euo pipefail` to ensure scripts fail loudly on errors.
- **Documentation:** All new features must update the relevant file in `docs/` using Markdown.

---

## Testing & Validation

Your contribution **must** pass local validation to be accepted:
1. **Webhook Test:** Run `bash tests/integration/test-webhook.sh`.
2. **Pipeline Test:** Run `python3 tests/integration/test-integration.py`.
3. **E2E Test:** Run `bash tests/integration/e2e-test.sh` to validate the full detection-to-ticket workflow.

---

## Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` A new detection rule, playbook, or integration.
- `fix:` Bug fixes or script patches.
- `docs:` Changes to documentation, diagrams, or comments.
- `refactor:` Code changes that don't change behavior.
- `test:` Adding or updating tests.
- `chore:` Maintenance, dependency updates, or `.gitignore` changes.

*Example: `feat: add custom rule for PowerShell process injection (T1059.001)`*

---

## Recognition Wall 🌟

The following amazing people have contributed to this project:

| Contributor | Contributions                              | Date |
|-------------|--------------------------------------------|------|
| Bommali Mallesu | [Created initial SOC Lab architecture] | TBD |

---

**Questions?** Open an issue with label "question"  
**Ideas?** Start a discussion or open an issue with "enhancement"  

Thank you for helping make the SOC Home Lab better for everyone! 🚀
