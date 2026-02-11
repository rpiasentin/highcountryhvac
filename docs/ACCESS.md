# Access and Test Bridge

Direct network access to Home Assistant from the Codex environment is blocked, so live tests must be executed from a local terminal (your Mac) or the HA Terminal add-on.

## HA Terminal Add-on (Preferred)
Use raw GitHub pulls to update packages and scripts, then run tests inside HA Terminal.

Example (repo is public):
```bash
BASE="https://raw.githubusercontent.com/rpiasentin/highcountryhvac/main"

# Packages
curl -L "$BASE/packages/hc_dispatcher_v2_helpers.yaml" -o /config/packages/hc_dispatcher_v2_helpers.yaml
curl -L "$BASE/packages/hc_dispatcher_advisory.yaml" -o /config/packages/hc_dispatcher_advisory.yaml
curl -L "$BASE/packages/hc_dispatcher_actuator.yaml" -o /config/packages/hc_dispatcher_actuator.yaml
curl -L "$BASE/packages/hc_dispatcher_setpoint_sync.yaml" -o /config/packages/hc_dispatcher_setpoint_sync.yaml

# Scripts
curl -L "$BASE/tools/ha_dispatch_test_matrix.sh" -o /config/hc_tools/ha_dispatch_test_matrix.sh
curl -L "$BASE/tools/ha_dispatch_test_opportunistic.sh" -o /config/hc_tools/ha_dispatch_test_opportunistic.sh
curl -L "$BASE/tools/ha_dispatch_test_matrix_stop.sh" -o /config/hc_tools/ha_dispatch_test_matrix_stop.sh

chmod +x /config/hc_tools/ha_dispatch_test_*.sh
```

Restart Home Assistant after package changes.

## Change Control Note
Before the dispatcher rearchitecture, a manual backup labeled **“tuesday feb 10 before rewrite”** was taken as a rollback reference. Keep this note in sync with future release markers.

## Registry Cutover
If you are enabling the registry-based dispatcher, follow:
- `docs/DISPATCHER_REGISTRY_CUTOVER.md`

## Local Snapshot Script (Mac)
If you prefer to snapshot from the Mac:

1. Export your local token (do not commit it):
   ```bash
   export HC_HA_URL="http://192.168.1.113:8123"
   export HC_HA_TOKEN="PASTE_TOKEN_HERE"
   ```

2. Run the snapshot:
   ```bash
   python3 tools/ha_snapshot.py
   ```

3. Optional: write to file the repo can read:
   ```bash
   HC_HA_OUT=reports/ha_state_snapshot.json python3 tools/ha_snapshot.py
   ```

The entities are controlled by `tools/ha_snapshot_entities.txt`.

## HA Terminal Snapshot (Fallback)
If Python is not available, use the HA Terminal add-on to dump all states, then extract the dispatcher subset locally.

1. In HA Terminal:
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
