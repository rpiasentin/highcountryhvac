# Hydronic Testing Guide

This document provides stepwise testing to isolate dispatcher issues and verify safe hydronic behavior.

## Preconditions
- Only one Home Assistant instance controls systems.
- Dispatcher gate is OFF before loading updates.
- Cluster assignments are restored after helper reloads.
  - Example: Z3, Z7, Z9 in Cluster A; Z5 Independent.
- Ensure Z8 thermostat uses `sensor.dining_temp_temperature` as its temperature sensor.

## Feb 10, 2026 Rearchitecture Note
Dispatcher core logic is slated for rewrite. Upcoming behavior changes:
- Any **manual change** to any thermostat or dispatcher control will abort all batches.
- Dispatcher will restore **all** zones touched by batching to baseline.
- A configurable cooldown (default 5 minutes) will block re-analysis after a manual change.
When the rewrite lands, update tests here to reflect the new global-abort behavior.

## Scripts
Scripts are in `tools/` and should be copied to `/config/hc_tools/` in HA.

### Registry Cutover Checklist
Before using the registry rewrite, follow:
- `docs/DISPATCHER_REGISTRY_CUTOVER.md`

### Registry Matrix Test (New Dispatcher)
Script: `ha_dispatch_reg_test_matrix.sh`
Purpose: confirm registry-based Matrix batching and manual-approval flow.

Steps:
1. Run:
   ```bash
   /config/hc_tools/ha_dispatch_reg_test_matrix.sh
   ```
2. The script will:
   - Enable registry helpers.
   - Set Matrix mode.
   - Create a manual call (triggers cooldown).
   - Wait for cooldown to expire.
   - Enable dispatcher gate and approve batch.

Expected:
- `sensor.hc_dispatch_reg_suggested_batch` shows Z3 + Z7 + Z9.
- `input_text.hc_dispatch_reg_active_zones` reflects the batch.
- Added zones receive forced setpoints.

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
Note:
- If manual override abort is enabled, any manual setpoint change during a batch will immediately abort the batch, restore baselines, and turn dispatcher OFF.

## Debug Checklist
If a test fails, inspect:
- `sensor.hc_dispatch_suggested_batch` (state + attributes)
- `input_text.hc_dispatch_last_apply_debug`
- `input_text.hc_dispatch_loop_marker`
- `input_text.hc_dispatch_batch_callers`
- `input_text.hc_dispatch_last_batch_zones`
- `sensor.hc_cluster_a_average_temp` (should be numeric when Cluster A has members)
- `input_boolean.hc_dispatcher_mode_enabled` (manual override abort turns this OFF)

Common issues:
- Cluster assignments reset after helper reload.
- Caller setpoint changes not reflected in baseline helpers.
- Non-callers already calling at batch start.
- Broadcast setpoints overriding dispatcher setpoints.
- Cluster average temp sensors show `unavailable` when a cluster is empty (expected).

## Safe Testing Notes
- Use low-risk windows when testing in production.
- Disable dispatcher gate when not actively testing.
