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
If Python is not available, use the HA Terminal add-on to dump all states, then extract the dispatcher subset locally.

1. In the HA Terminal add-on, run:
   ```bash
   mkdir -p /config/reports
   curl -s -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
     http://supervisor/core/api/states > /config/reports/ha_states_all.json
   ```

2. Copy the file to your Mac:
   ```bash
   scp root@192.168.1.113:/config/reports/ha_states_all.json /Users/giovanipiasentin/dev/codex/highcountryhvac/reports/
   ```

3. Extract the dispatcher snapshot:
   ```bash
   python3 tools/ha_extract_snapshot.py reports/ha_states_all.json
   ```

## Test Scripts (HA Terminal)
The `tools/` folder includes two optional test scripts to reduce manual errors.

- `tools/ha_dispatch_test_matrix.sh`: deterministic Matrix test (no near-call required).
- `tools/ha_dispatch_test_opportunistic.sh`: opportunistic test (near-call required).

To run them, copy to `/config/hc_tools/` and execute inside the HA Terminal:
```bash
mkdir -p /config/hc_tools
scp /Users/giovanipiasentin/dev/codex/highcountryhvac/tools/ha_dispatch_test_matrix.sh root@192.168.1.113:/config/hc_tools/
scp /Users/giovanipiasentin/dev/codex/highcountryhvac/tools/ha_dispatch_test_opportunistic.sh root@192.168.1.113:/config/hc_tools/
```

In HA Terminal:
```bash
chmod +x /config/hc_tools/ha_dispatch_test_matrix.sh
/config/hc_tools/ha_dispatch_test_matrix.sh
```
