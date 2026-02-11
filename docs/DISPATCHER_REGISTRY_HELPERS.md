# Dispatcher Registry Helpers (v0.1)

This file enumerates all helpers used by the dispatcher registry. These are the **single source of truth** for the rewrite. Rollback reference: manual backup **“tuesday feb 10 before rewrite.”**

## Global Helpers
- `input_boolean.hc_dispatch_reg_enabled`
  - Master enable for the rewrite (kept OFF until cutover).
- `input_boolean.hc_dispatch_reg_apply_in_progress`
  - Suppresses false manual-change detection while dispatcher applies setpoints.
- `input_select.hc_dispatch_reg_state`
  - `idle`, `evaluating`, `batch_active`, `cooldown`.
- `input_number.hc_dispatch_reg_cooldown_minutes`
  - Cooldown duration after manual change (default 5).
- `input_datetime.hc_dispatch_reg_cooldown_until`
  - Absolute timestamp when evaluation can resume.
- `input_text.hc_dispatch_reg_active_batch_id`
  - Unique ID for the active batch.
- `input_text.hc_dispatch_reg_active_zones`
  - Comma list of batch zones, e.g. `z3,z7,z9`.
- `input_text.hc_dispatch_reg_active_callers`
  - Frozen callers at batch start.
- `input_select.hc_dispatch_reg_active_mode`
  - `Matrix` or `Profile`.
- `input_text.hc_dispatch_reg_guardrail_status`
  - `ok`, `degraded_to_callers`, `blocked_over_max`, etc.
- `input_number.hc_dispatch_reg_active_length_ft`
  - Total batch length at activation.
- `input_datetime.hc_dispatch_reg_active_started_at`
  - Timestamp for batch start.
- `input_datetime.hc_dispatch_reg_manual_change_at`
  - Last manual change time.
- `input_text.hc_dispatch_reg_manual_change_entity`
  - Entity ID of last manual change.
- `input_select.hc_dispatch_reg_manual_change_type`
  - `thermostat_setpoint`, `cluster_change`, `guardrail_change`, `toggle_change`, `other`.
- `input_text.hc_dispatch_reg_version`
  - Registry version marker (default `v0.1`).

## Per‑Zone Helpers (Pattern)
For each zone `z1`..`z9`:
- `input_number.hc_dispatch_reg_zX_user_baseline_f`
- `input_number.hc_dispatch_reg_zX_system_override_f`
- `input_number.hc_dispatch_reg_zX_effective_setpoint_f`
- `input_number.hc_dispatch_reg_zX_last_user_setpoint_f`
- `input_boolean.hc_dispatch_reg_zX_calling`
- `input_boolean.hc_dispatch_reg_zX_batch_member`
- `input_boolean.hc_dispatch_reg_zX_batch_added`
- `input_datetime.hc_dispatch_reg_zX_last_on`
- `input_datetime.hc_dispatch_reg_zX_last_off`
- `input_datetime.hc_dispatch_reg_zX_last_user_change`
- `input_text.hc_dispatch_reg_zX_entities`

### Per‑Zone Entity Mapping (current canonical)
- `z1`: climate `climate.z1_first_floor_bedroom_and_bath`, temp `sensor.1f_fr_n_t_fp3001_temperature`, switch `switch.z1`
- `z2`: climate `climate.zone_2_second_floor_office_and_upper_guest`, temp `sensor.2nd_floor_office_temperature_temperature`, switch `switch.z2`
- `z3`: climate `climate.zone_3_basement_bath_and_common`, temp `sensor.basement_bath_and_utility_temperature`, switch `switch.z3`
- `z4`: climate `climate.zone_4_garage`, temp `sensor.new_garage_motion_sensor_temperature`, switch `switch.z4`
- `z5`: climate `climate.zone_5_virtual_thermostat_first_floor_living`, temp `sensor.1f_gr_s_z_temperature`, switch `switch.z5`
- `z6`: climate `climate.zone_6_master_thermostat`, temp `sensor.2f_mb_c_z_temperature`, switch `switch.z6`
- `z7`: climate `climate.zone_7_basement_bar_and_tv_room_south_side`, temp `sensor.b1_tv_c_z_temperature`, switch `switch.z7`
- `z8`: climate `climate.zone_8_dining_room`, temp `sensor.dining_temp_temperature`, switch `switch.z8`
- `z9`: climate `climate.zone_9_basement_bedroom`, temp `sensor.b1_bguestroom_temperature`, switch `switch.z9`

## Reused Existing Helpers (Source of Truth)
These already exist and will be used by the registry without duplication:
- Cluster assignments: `input_select.hc_z1_cluster` … `input_select.hc_z9_cluster`.
- Loop lengths: `input_number.hc_z1_length_feet` … `input_number.hc_z9_length_feet`.
- Guardrails and controls: `input_number.hc_dispatch_*`, `input_boolean.hc_dispatch_*`.

## Notes
- The registry does not change HVAC behavior by itself; it records state.
- Actuation logic will be rewritten to read/write the registry and then apply setpoints.
