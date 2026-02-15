# Dispatcher Registry Debug Guide

This guide explains how to interpret registry helpers and debug the new dispatcher core.

## Key Registry Helpers (Global)
- `input_select.hc_dispatch_reg_state`
  - `idle`: no batch running.
  - `batch_active`: batch applied and being maintained.
  - `cooldown`: manual change detected; dispatcher paused.
- `input_text.hc_dispatch_reg_active_zones`
  - Comma list of zones in the current batch (or `none`).
- `input_text.hc_dispatch_reg_active_callers`
  - Frozen callers at batch start (or `none`).
- `input_text.hc_dispatch_reg_active_batch_id`
  - Unique ID per batch; helps correlate logs.
- `input_datetime.hc_dispatch_reg_cooldown_until`
  - Time when dispatcher can resume.
- `input_text.hc_dispatch_reg_guardrail_status`
  - `ok`, `degraded_to_callers`, `blocked_over_max`, `manual_abort`, etc.
- `input_boolean.hc_dispatch_reg_apply_in_progress`
  - True while dispatcher applies setpoints (suppresses false manual-change detection).

## Key Registry Helpers (Per‑Zone)
For each zone `zX`:
- `input_number.hc_dispatch_reg_zX_user_baseline_f`
  - User intent at batch start.
- `input_number.hc_dispatch_reg_zX_system_override_f`
  - Dispatcher override (0 = none).
- `input_number.hc_dispatch_reg_zX_effective_setpoint_f`
  - Current climate target setpoint.
- `input_boolean.hc_dispatch_reg_zX_calling`
  - Registry call state.
- `input_boolean.hc_dispatch_reg_zX_batch_member`
  - True if zone in batch.
- `input_boolean.hc_dispatch_reg_zX_batch_added`
  - True if zone was added (not a caller).

## Guardrail Sensors
- `sensor.hc_dispatch_reg_guardrail_payload`
  - JSON payload with `bz`, `fz`, `g`, `fl`, etc.
- `sensor.hc_dispatch_reg_guardrail`
  - Human‑friendly guardrail state and attributes.
- `sensor.hc_dispatch_reg_suggested_batch`
  - User-facing suggested batch string.

## Common Failure Modes
1. **Batch never clears**
   - Check `input_boolean.hc_dispatch_reg_zX_calling` for callers still ON.
   - Check `input_number.hc_dispatch_min_run_minutes` and `input_datetime.hc_dispatch_reg_zX_last_on`.
   - Verify the climate entity state is `heat`; if it is `off`, the
     `binary_sensor.hc_zX_call_for_heat` must be `off` or callers will never clear.

2. **Manual change triggers unexpected cooldown**
   - Check `input_text.hc_dispatch_reg_manual_change_entity`.
   - Verify `input_boolean.hc_dispatch_reg_apply_in_progress` state.
   - For testing, temporarily enable `input_boolean.hc_dispatch_reg_ignore_manual_changes`.

3. **Guardrail blocked**
   - Inspect `sensor.hc_dispatch_reg_guardrail_payload` (`g`, `ml`, `fl`, `cl`).
   - Verify external callers (non‑batch live calls) are counted.

## Quick Snapshot (HA Terminal)
```bash
for e in \
  input_select.hc_dispatch_reg_state \
  input_text.hc_dispatch_reg_active_zones \
  input_text.hc_dispatch_reg_active_callers \
  input_text.hc_dispatch_reg_guardrail_status \
  input_datetime.hc_dispatch_reg_cooldown_until \
  sensor.hc_dispatch_reg_suggested_batch \
  sensor.hc_dispatch_reg_guardrail; do
  echo "--- $e"
  curl -s -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
    http://supervisor/core/api/states/$e | sed -n 's/.*"state":"\([^"]*\)".*/\1/p'
done
```

## Interpretation Tips
- If `suggested_batch` is `idle` but callers are ON, check guardrail status and cluster config.
- If `active_zones` differs from guardrail `final_zones`, check for cooldown or apply‑in‑progress.
- Always correlate batch behavior with `manual_change_entity` when unexpected aborts occur.
