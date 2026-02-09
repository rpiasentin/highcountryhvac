# Architecture

## Overview
Dispatcher V2 is a setpoint-based batching system layered on top of existing broadcast logic. Broadcast modes (whole house, by floor, by room) are **out of scope** for this release. Dispatcher consumes the resulting zone setpoints (Z1–Z9) and determines which zones should be included together to optimize boiler efficiency.

## Core Packages and Roles
- `packages/hc_dispatcher_v2_helpers.yaml`
  - Defines clusters, guardrail inputs, force-call parameters, and debug helpers.
- `packages/hc_dispatcher_advisory.yaml`
  - Computes suggested batches, guardrail status, and near-call candidates.
- `packages/hc_dispatcher_actuator.yaml`
  - Applies suggested batches by adjusting thermostat setpoints.
- `packages/hc_dispatcher_setpoint_sync.yaml`
  - Keeps dispatcher baselines aligned with user changes.
- `packages/hc_dispatcher_manual_caps_override.yaml`
  - Manages manual caps override duration.
- `lovelace/hc_zone_setup.yaml`
  - Operator dashboards for clusters and dispatcher controls.

## Entity Flow (High Level)
1. Broadcast logic sets target setpoints for Z1–Z9 (existing system).
2. `hc_dispatcher_advisory` detects calling zones, applies Matrix/Profile rules, and emits:
   - `sensor.hc_dispatch_suggested_batch` (with attributes for guardrails, base zones, final zones)
3. `hc_dispatcher_actuator` applies setpoint overrides to batch zones:
   - Captures baselines
   - Forces added zones above current temp
   - Restores baselines after stop conditions and min-run
4. `hc_dispatcher_setpoint_sync` accepts user setpoint edits:
   - Non-batch zones update baseline immediately
   - Caller edits during batch update both baseline and target

## Modes
- Off: dispatcher does nothing.
- Matrix: clusters define relationships. Caller pulls entire cluster.
- Profile: no cluster expansion. Caller drives batch; optional opportunistic adds.
- Opportunistic: adds near-call zones when enabled and within guardrails.

## Guardrails
- Min run time: default 10 minutes.
- Hard cap: max batch length (default 85 ft).
- Ideal range: default 55–75 ft (informational).
- Opportunistic range: default 50–70 ft.
- Manual caps override: allows temporary cap violations for Matrix/Opportunistic.

## Debug and Diagnostics
Key helpers:
- `input_text.hc_dispatch_last_apply_debug`
- `input_text.hc_dispatch_loop_marker`
- `input_text.hc_dispatch_batch_callers`
- `input_text.hc_dispatch_last_batch_zones`

Key sensor:
- `sensor.hc_dispatch_suggested_batch` with guardrail attributes.

## Known Constraints
- Template output length is limited (255 chars). Use attributes for details.
- Helper reloads can reset cluster assignments; document cluster state and reapply before tests.
