# POC Objectives and Next Steps

## Purpose
This document captures the intent of the `homeassistantantigravity` proof-of-concept (POC) and maps it onto the canonical production configuration now stored in this repo. The POC is treated as objectives and next steps, not as the current source of truth.

## POC Objectives (What the POC Adds)
- Introduce Dispatcher V2 with a Matrix-style cluster model for zone batching.
- Add helpers to assign zones to clusters A–E or keep them independent.
- Compute cluster stats (average temp, total loop length) to guide efficiency (target 45–75 ft per cluster).
- Provide advisory logic for suggested batches and near-call zones.
- Provide an actuator path for auto/manual batch approval.
- Provide a Zone Setup dashboard for cluster assignment and loop lengths.
- Maintain an inventory and changelog for releases.

## Canonical Baseline (What Production Already Has)
Production already includes core HVAC packages and helpers that the POC expects, including:
- Call-for-heat detection and zone delta sensors.
- Setpoints and setpoint automations.
- Cold tolerance control and gatekeeping.
- Dispatcher inputs and broadcast-follow logic.
- Hydronic kick and observability packages.

These are represented in the canonical config here and are treated as the current, authoritative system.

## Dispatcher V2 Decisions (Current)
### Operating Model
- Modes: `Off`, `Matrix`, `Profile`. Opportunistic is a toggle that augments the active mode.
- Off: dispatcher does nothing; thermostats control switches directly.
- Matrix: clusters define relationships. When any zone in a cluster calls, the dispatcher batches the full cluster (plus opportunistic adds if enabled).
- Profile: no cluster relationships. The dispatcher respects broadcast setpoints (profile lock) and only batches calling zones unless opportunistic adds are enabled.
- Opportunistic: adds near-call zones to the current mode when guardrails allow it.

### Baseline + Override Setpoints
- At batch start, the dispatcher captures baseline setpoints for **all zones included in the batch**, including the original calling zone.
- To ensure batch members actually fire, the dispatcher temporarily raises setpoints above current temperature for **added zones** (matrix followers or opportunistic adds), even if they would not normally call.
- When stop conditions are met, all affected zones are restored to their baseline setpoints.
- User edits to thermostat setpoints while dispatcher is ON are treated as the new baseline immediately.

### Stop Behavior
- A batch begins when one or more real thermostats call for heat.
- Stop conditions: the **original calling zone** reaches its desired setpoint **and** minimum run time has elapsed.
- At stop, the dispatcher restores baseline setpoints for all batch zones.

### Guardrails
- Minimum run time: 10 minutes. No minimum off time.
- Hard cap: default 85 ft and always applies **unless manual caps override is enabled**.
  - If base exceeds hard cap, degrade to callers-only.
  - If callers-only exceeds hard cap, block the batch (idle).
- Opportunistic range defaults to 50–70 ft (user-tunable).
- Manual caps override: allows temporary cap violations for Matrix/Opportunistic batches.
  - Controlled by a toggle plus a user-selectable duration (minutes, up to 24 hours).
  - Intended for manual approval only.

### Near-Call Detection
- Near-call detection: delta within `(cold_tolerance - near_call_margin)` and `< cold_tolerance`. Near-call margin is adjustable.

## Validation Snapshot (February 6, 2026)
- Guardrail sensor computes correctly and emits non-idle output when a zone is calling.
- Opportunistic skip is enforced when total length is below 50 ft.
- Opportunistic add is applied when near-call zones bring the batch into the 50–70 ft range (example: Z1 + Z7 = 61 ft).

## Home Assistant Constraints and Learnings
- Sensor state length is limited (255 chars). Longer template output becomes `unknown`. Use compact payloads or attributes for structured data.
- Template sensors only update when referenced entities change. Avoid relying on derived template sensors for core logic unless dependencies are explicit.
- Complex logic is more reliable when broken into small, inspectable sensors with clear inputs and outputs.
- When troubleshooting template output, use the Template editor or `/api/template` to validate results and limits.
- YAML indentation errors are easy to introduce in large template blocks; keep template blocks tightly indented and avoid nested YAML structures.

## Gaps Between POC and Canonical
From the POC vs canonical comparison, the key gaps are:
- POC-only packages not yet in production.
- Canonical-only packages not represented in POC.
- `hc_dispatcher_advisory.yaml` differs between POC and production.
- POC-only dashboard `hc_zone_setup.yaml` is not yet in production.

See `inventories/poc_compare_report.md` for the exact file-level diff.

## Recommended Next Steps
1. Run dispatcher actuation tests in prod-safe mode using `docs/TEST_CHECKLIST.md`.
2. Confirm operator defaults for guardrails and near-call margin in Dispatcher Ops.
3. Update inventory artifacts and tag a release after validation passes.

## Notes
This repo is the canonical HVAC configuration and will be used to implement the long-term control strategy. The POC repo remains the reference for intended capabilities and next-step design decisions.

### Staging Constraints
- Home Assistant does not tolerate two instances controlling the same systems in parallel.
- The Hubitat-backed infrastructure can post state updates to only one Home Assistant IP at a time.
- Any staging validation must ensure prod is isolated or the Hubitat target is switched, otherwise entity states and control signals will conflict.
