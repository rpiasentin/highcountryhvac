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

## Gaps Between POC and Canonical
From the POC vs canonical comparison, the key gaps are:
- POC-only packages not yet in production.
- Canonical-only packages not represented in POC.
- `hc_dispatcher_advisory.yaml` differs between POC and production.
- POC-only dashboard `hc_zone_setup.yaml` is not yet in production.

See `inventories/poc_compare_report.md` for the exact file-level diff.

## Recommended Next Steps
1. Reconcile Dispatcher V2 logic with existing production dispatcher helpers and inputs.
2. Introduce the POC Zone Setup dashboard into production after validating it against existing entities.
3. Merge the POC actuator logic with production safety gates and call-for-heat constraints.
4. Standardize entity naming across the dispatcher packages to remove ambiguity.
5. Add explicit release steps and a lightweight test checklist for Dev → Stage → Prod.

## Notes
This repo is the canonical HVAC configuration and will be used to implement the long-term control strategy. The POC repo remains the reference for intended capabilities and next-step design decisions.
