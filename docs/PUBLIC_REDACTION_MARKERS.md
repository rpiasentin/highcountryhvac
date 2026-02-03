# Public Release Redaction Markers

This repo is currently private and includes sensitive content. If you ever make it public, review and remove or redact the following paths and patterns.

## High-Risk Files and Directories
- `secrets.yaml`
- `.storage/auth`
- `.storage/http.auth`
- `.storage/auth_provider.*`
- `.storage/core.restore_state`
- `.storage/homeassistant.exposed_entities`
- `.storage/hassio`
- `.storage/person`
- `.storage/backup`
- `home-assistant_v2.db*`
- `*.log*`
- `*.pem`
- `deps/`
- `backup_trigger_evidence_*`
- `*_support_*`
- `*_dump_*`
- `*_inventory_*`
- `*.tar`
- `*.tgz`

## Public-Release Checklist
1. Remove secrets and auth artifacts.
2. Remove backups, dumps, and logs.
3. Re-run inventories on the cleaned tree.
4. Validate that Lovelace dashboards and packages still load.
5. Rotate any exposed credentials after the clean.
