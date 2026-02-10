# Dispatcher Registry Spec (v0.1)

## Purpose
This spec defines the **dispatcher state registry** that replaces the current ad‑hoc dispatcher core. The registry is the single source of truth for user intent, batch decisions, overrides, and timers. It is designed to make dispatcher behavior deterministic, inspectable, and resilient to timing/network instability.

This document is the authoritative reference for the rewrite starting **Feb 10, 2026**. Rollback reference: manual backup **“tuesday feb 10 before rewrite.”**

## Goals
- Clear separation between **user intent** and **dispatcher overrides**.
- Global manual‑change abort with a configurable cooldown.
- Deterministic batch evaluation with explicit exit conditions.
- Full visibility into per‑zone state, batch membership, and overrides.

## Non‑Goals
- Replace broadcast/deployer logic or dashboards.
- Change physical wiring or Hubitat integrations.

## Registry Model Overview
The registry is implemented as Home Assistant helpers. It consists of:
- Global dispatcher state (mode, batch, cooldown, manual change tracking).
- Per‑zone records (baseline, override, call state, batch membership, timestamps).

All batch logic reads/writes the registry. Any state derived from live entities is written into the registry so that **behavior is driven by registry values, not transient state**.

## Global Registry Fields
- `hc_dispatch_reg_state`: `idle`, `evaluating`, `batch_active`, `cooldown`.
- `hc_dispatch_reg_enabled`: master enable for the new dispatcher core.
- `hc_dispatch_reg_cooldown_until`: timestamp when evaluation can resume.
- `hc_dispatch_reg_active_batch_id`: unique ID per batch.
- `hc_dispatch_reg_active_zones`: comma list of zones (e.g. `z3,z7,z9`).
- `hc_dispatch_reg_active_callers`: frozen caller set at batch start.
- `hc_dispatch_reg_active_mode`: `Matrix` or `Profile`.
- `hc_dispatch_reg_guardrail_status`: `ok`, `degraded_to_callers`, `blocked_over_max`, etc.
- `hc_dispatch_reg_active_length_ft`: total length in batch.
- `hc_dispatch_reg_active_started_at`: timestamp for batch start.
- `hc_dispatch_reg_manual_change_at`: last manual change timestamp.
- `hc_dispatch_reg_manual_change_entity`: entity ID of last manual change.
- `hc_dispatch_reg_manual_change_type`: `thermostat_setpoint`, `cluster_change`, `guardrail_change`, `toggle_change`, `other`.
- `hc_dispatch_reg_cooldown_minutes`: cooldown duration (default 5).
- `hc_dispatch_reg_version`: string marker (default `v0.1`).

## Per‑Zone Registry Fields (Z1–Z9)
Per zone `zX`, the registry stores:
- `hc_dispatch_reg_zX_user_baseline_f`: user intent setpoint (baseline).
- `hc_dispatch_reg_zX_system_override_f`: dispatcher override setpoint (0 when none).
- `hc_dispatch_reg_zX_effective_setpoint_f`: current climate setpoint.
- `hc_dispatch_reg_zX_last_user_setpoint_f`: last manually set value.
- `hc_dispatch_reg_zX_calling`: whether zone is calling.
- `hc_dispatch_reg_zX_batch_member`: whether zone is in current batch.
- `hc_dispatch_reg_zX_batch_added`: true if zone was added (not a caller).
- `hc_dispatch_reg_zX_last_on`: last time zone started calling.
- `hc_dispatch_reg_zX_last_off`: last time zone stopped calling.
- `hc_dispatch_reg_zX_last_user_change`: last time user changed this thermostat.
- `hc_dispatch_reg_zX_entities`: text mapping (climate/temp/switch) for inspectability.

The registry **reuses existing** helper sources for lengths and clusters:
- `input_number.hc_zX_length_feet`
- `input_select.hc_zX_cluster`

## Manual Change Global Reset (Core Requirement)
Any manual change to any thermostat or dispatcher control triggers a global reset:
1. Abort all dispatcher‑initiated batches.
2. Restore **all** dispatcher‑touched thermostats to baselines.
3. Turn dispatcher OFF (or set registry to cooldown).
4. Enforce a configurable cooldown before analysis resumes.

Manual change applies to:
- Any thermostat setpoint edit (any zone).
- Any dispatcher config edit (clusters, lengths, guardrails, caps, toggles).

## Batch Evaluation (High Level)
1. **Collect callers** from registry `calling` fields.
2. **Matrix or Profile** expansion to base batch.
3. **Opportunistic adds** within caps.
4. **Guardrails** enforce max length with total active calls included.
5. Freeze callers at batch start; write active batch to registry.

## Batch Execution (High Level)
- Capture baselines for all batch zones at batch start.
- Apply overrides only to added zones.
- Keep caller zones at baseline setpoints.
- Stop when caller(s) satisfy setpoints and min‑run elapsed.
- Restore baselines and clear batch registry.

## Cooldown
Cooldown prevents re‑analysis after a manual change.
- `hc_dispatch_reg_cooldown_until` blocks evaluation.
- Default duration: 5 minutes (configurable).

## Invariants
- If `state = idle`, `active_batch_zones` must be `none`.
- If `system_override_f > 0`, zone must be `batch_member = on`.
- Manual change must clear `batch_member` and `system_override_f`.
- `user_baseline_f` only changes at batch start or manual change.

## Implementation Plan (Phase 1)
1. Add registry helpers and scaffolding automations.
2. Implement registry updates (calling, effective setpoints, manual changes).
3. Build batch evaluation and execution based solely on registry values.
4. Enable global manual change abort and cooldown.
5. Decommission legacy batch tracking logic.
