# POC Objectives and Operating Model

## Purpose
This document maps the `homeassistantantigravity` proof-of-concept (POC) into the canonical production configuration in this repo. The POC is treated as objectives and next steps, not as the current source of truth.

This release focuses on **Dispatcher V2**: taking existing broadcast setpoints (Z1–Z9) and batching zone inclusion to optimize boiler efficiency. It does **not** change how broadcasts are created.

## User Mental Model (Broadcast Modes, Out of Scope for This Release)
Users typically set desired temperatures via existing broadcast logic:
- Mode A: Master setpoint for the entire house.
- Mode B: Floor-by-floor setpoints.
- Mode C: Individual room/zone setpoints.

Those broadcasts are already implemented in the canonical system and set the thermostat setpoints for Z1–Z9. Dispatcher V2 consumes those setpoints and decides **which zones should be included together** to improve efficiency.

## Dispatcher V2 Objectives (What This Release Adds)
- Matrix-style cluster batching.
- Profile mode batching that respects existing setpoints.
- Opportunistic adds of near-call zones within guardrails.
- Guardrail enforcement (length caps, min run time, manual caps override).
- Actuation by **setpoint adjustment** rather than direct switch toggles.
- Operator dashboards for cluster assignment, guardrails, and approval flow.

## Operating Modes and When to Use Them
Dispatcher modes are separate from broadcast modes.

### Off
If you want default thermostat behavior only.
- Use when: you are changing core HVAC settings or want no batching.
- Expect: only native thermostat calls control zones.

### Matrix
If you want strict cluster batching.
- Use when: you have defined clusters (A–E) and want any member to pull the whole cluster.
- Expect: when **any zone in cluster A calls**, all of cluster A is brought online until the original caller reaches its setpoint and min-run is satisfied.
- Example: you want Z3, Z7, Z9 to run together because the combined loop length is efficient. Put them in Cluster A.

### Profile
If you want to respect existing broadcast setpoints, but still allow dispatcher optimization.
- Use when: you want the current broadcast setpoints to drive calls, but still want guardrails, approvals, and optional opportunistic adds.
- Expect: the dispatcher does **not** impose cluster relationships; it only reacts to which zones are calling and can add near-call zones if the opportunistic toggle is on.
- Example: you are running floor-by-floor setpoints and want dispatcher safety and opportunistic efficiency, without forcing clusters.

### Opportunistic Toggle (Applies to Matrix or Profile)
If you want near-call zones added when it improves efficiency and stays within guardrails.
- Use when: you are comfortable adding near-call zones to an existing batch.
- Expect: dispatcher adds near-call zones **only if** guardrails allow it (length caps, min run, manual override rules).

## How Batch Behavior Works
### Start
- A batch begins when one or more **real thermostats** call for heat.
- In Matrix: base batch = calling zones + all zones in their cluster(s).
- In Profile: base batch = calling zones only (no cluster expansion).
- Opportunistic: near-call zones may be added if enabled and guardrails allow.

### Baseline and Override Setpoints
- At batch start, dispatcher captures **baseline setpoints** for all zones in the batch.
- Added zones (matrix followers or opportunistic adds) have their setpoints temporarily raised above current temperature to force a call.
- Non-batch zones are never modified.

### Stop
- Stop condition: the **original caller** reaches its desired setpoint **and** min-run is satisfied.
- Dispatcher restores all batch zones to their captured baselines.
- User edits to thermostat setpoints while dispatcher is ON are treated as new baselines immediately.

## Guardrails and Controls
All controls are in Dispatcher Ops:
- Min run time (default 10 min).
- Hard cap: max batch length (default 85 ft).
- Ideal range (default 55–75 ft), informational.
- Opportunistic range (default 50–70 ft).
- Manual caps override toggle + duration (minutes, up to 24 hours).
- Force-call parameters (delta and cap) for added zones.

### Suggested Batch + Guardrail Attributes
- `sensor.hc_dispatch_suggested_batch` is the operator-facing summary.
- Attributes include:
  - `base_zones` and `final_zones`
  - `batch_length_ft`, `base_length_ft`, `callers_length_ft`
  - guardrail status and cap values
  - opportunistic enabled and limits

## Example Scenarios
### Example 1: Matrix Efficiency
You want basement zones to always run together for stable boiler load.
- Broadcast setpoints already target each basement zone.
- Set Z3, Z7, Z9 to Cluster A.
- Dispatcher mode: Matrix. Opportunistic: off.
- Result: any call from Z3/Z7/Z9 pulls all three until the original caller satisfies.

### Example 2: Profile with Opportunistic
You want floor setpoints to drive calls, but want near-call adds to smooth load.
- Broadcast sets floor setpoints.
- Dispatcher mode: Profile. Opportunistic: on.
- Result: only calling zones run, but near-call zones can join if guardrails allow.

### Example 3: Manual Caps Override
You want to allow a large batch temporarily.
- Enable manual caps override and set duration to 60 minutes.
- Dispatcher allows cap violations during that window.
- After expiration, cap is enforced again.

## Home Assistant Constraints and Learnings
- Template sensor outputs are limited to 255 chars. Put structured data in attributes.
- Template sensors only update when referenced entities change; keep dependencies explicit.
- Large template logic is fragile. Prefer multiple small, inspectable sensors.
- Re-applying helper packages can reset cluster assignments; keep a record of desired cluster state.

## Staging Constraints
- Home Assistant does not tolerate two instances controlling the same systems in parallel.
- Hubitat can post state updates to only one Home Assistant IP at a time.
- Any staging validation must ensure prod is isolated or Hubitat is switched, otherwise entity states and control signals will conflict.
