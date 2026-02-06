# Access and Test Bridge

Direct network access to Home Assistant from the Codex environment is blocked, so live tests must be executed from a local terminal (your Mac) or the HA Terminal add-on.

## Local Snapshot Script (Preferred)
Run the snapshot script from your Mac and share the output (or commit the JSON file).

1. Export your local token (do not commit it):
   ```bash
   export HC_HA_URL="http://192.168.1.113:8123"
   export HC_HA_TOKEN="PASTE_TOKEN_HERE"
   ```

2. Run the snapshot:
   ```bash
   python3 tools/ha_snapshot.py
   ```

3. Optional: write to a file the repo can read:
   ```bash
   HC_HA_OUT=reports/ha_state_snapshot.json python3 tools/ha_snapshot.py
   ```

The entities are controlled by `tools/ha_snapshot_entities.txt`.

## HA Terminal Add-on (Fallback)
If Python is not available, we can provide a curl-based command that queries the same entities through the Supervisor token.
