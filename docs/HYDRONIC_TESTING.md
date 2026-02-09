# Hydronic Testing Guide

This document provides stepwise testing to isolate dispatcher issues and verify safe hydronic behavior.

## Preconditions
- Only one Home Assistant instance controls systems.
- Dispatcher gate is OFF before loading updates.
- Cluster assignments are restored after helper reloads.
  - Example: Z3, Z7, Z9 in Cluster A; Z5 Independent.

## Scripts
Scripts are in `tools/` and should be copied to `/config/hc_tools/` in HA.

### 1) Matrix Start Test
Script: `ha_dispatch_test_matrix.sh`
Purpose: confirm Matrix batching and forced-call behavior.

Steps:
1. Ensure cluster assignments are correct.
2. Run:
   ```bash
   /config/hc_tools/ha_dispatch_test_matrix.sh
   ```
Expected:
- Suggested batch includes Z3 + Z7 + Z9.
- Added zones receive setpoint above current temp.
- Added zones call for heat.

### 2) Opportunistic Test
Script: `ha_dispatch_test_opportunistic.sh`
Purpose: verify near-call detection and opportunistic adds within guardrails.

Steps:
1. Ensure a near-call condition exists (delta within tolerance margin).
2. Run:
   ```bash
   /config/hc_tools/ha_dispatch_test_opportunistic.sh
   ```
Expected:
- `sensor.hc_dispatch_suggested_batch` includes near-call zones.
- Guardrail status reflects opportunistic add.

### 3) Matrix Stop + Restore Test
Script: `ha_dispatch_test_matrix_stop.sh`
Purpose: confirm min-run enforcement and baseline restore.

Steps:
1. Run:
   ```bash
   WAIT_MINUTES=10 TARGET_F=70 CALLER_ZONE=z3 /config/hc_tools/ha_dispatch_test_matrix_stop.sh
   ```
2. The script resets batch tracking, enforces non-callers below current temp, starts a batch, waits min-run, drops caller to baseline, and snapshots state.

Expected:
- Suggested batch goes idle after caller hits baseline.
- `input_text.hc_dispatch_batch_callers` clears to `none`.
- Batch zones restore to baseline setpoints.

## Debug Checklist
If a test fails, inspect:
- `sensor.hc_dispatch_suggested_batch` (state + attributes)
- `input_text.hc_dispatch_last_apply_debug`
- `input_text.hc_dispatch_loop_marker`
- `input_text.hc_dispatch_batch_callers`
- `input_text.hc_dispatch_last_batch_zones`

Common issues:
- Cluster assignments reset after helper reload.
- Caller setpoint changes not reflected in baseline helpers.
- Non-callers already calling at batch start.
- Broadcast setpoints overriding dispatcher setpoints.

## Safe Testing Notes
- Use low-risk windows when testing in production.
- Disable dispatcher gate when not actively testing.
