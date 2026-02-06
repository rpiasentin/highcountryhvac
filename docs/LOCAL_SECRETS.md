# Local Secrets (Do Not Commit Actual Values)

This file is a reminder for locally stored secrets needed for testing.
Do not place real tokens or passwords in the repository.

## Home Assistant API
- Store the long-lived token in a local secret manager (macOS Keychain, 1Password, etc).
- Environment variables expected by local scripts (if/when used):
  - `HC_HA_URL` (example: `http://192.168.1.113:8123`)
  - `HC_HA_TOKEN` (long-lived token value)

## Notes
- Codex sandbox cannot reach the Home Assistant API directly (network restricted).
- Use your local terminal for API-driven tests, or provide screenshots/logs from HA.
- For a repeatable workflow, see `docs/ACCESS.md` and `tools/ha_snapshot.py`.
