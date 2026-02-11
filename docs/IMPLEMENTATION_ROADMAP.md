# Implementation Roadmap

## Scope
This roadmap applies the POC objectives to the canonical production configuration in this repo. The goal is to introduce Dispatcher V2 capabilities without disrupting core HVAC operation.

## Inputs
- POC objectives: `docs/POC_OBJECTIVES.md`
- POC vs canonical diff: `inventories/poc_compare_report.md`
- HVAC inventory: `inventories/hvac_entity_inventory.csv`

## Current Status (As Of Feb 2026)
- Dispatcher V2 helpers, advisory logic, guardrails, and actuator are implemented.
- Manual caps override duration, min-run enforcement, and force-call logic are implemented.
- Dispatcher Ops and Zone Setup dashboards are updated.
- Test scripts exist for matrix, opportunistic, and stop behavior.
- Entity audit updated and clean (no missing entities).
- Hubitat switch renames mapped in packages and dashboards.
- Zone delta sensors are explicit (with fallback temp sensors when climate temps are null).
- Cluster average temp sensors now fall back to zone temp sensors when needed.
- Cluster defaults set for Z3/Z7/Z9 to Cluster A in config; helper state still persists across reloads.
- Manual override abort: manual setpoint changes during an active batch immediately restore baselines and turn dispatcher OFF.
- Open work: verify end-to-end stop/restore behavior across modes and edge cases.
- **Decision (Feb 10, 2026):** re-architect dispatcher core due to accumulated organic fixes and timing instability.
- Rollback reference: manual backup **“tuesday feb 10 before rewrite.”**
- Rearchitecture progress: registry helpers, registry engine, registry guardrail, and registry controller added; legacy actuator/setpoint sync gated off when registry is enabled.
- Registry control now includes manual abort + cooldown logic and bootstrap baseline capture on enable.

## Target Operating Model (Behavior)
- Batch starts when one or more real thermostats call.
- Matrix expands to cluster members; Profile does not.
- Opportunistic adds near-call zones when enabled and within guardrails.
- Baselines captured at batch start for all batch zones; non-batch zones are untouched.
- Added zones receive forced setpoints above current temp to induce calls.
- Stop when original caller hits its setpoint and min-run has elapsed.
- Restore baselines to all batch zones.
- Caller setpoint changes during batch are accepted as new baseline.
- Any manual change to any thermostat or dispatcher control triggers a **global abort**, restores all zones to baseline, turns dispatcher OFF, and enforces a cooldown before resuming analysis.

## Phase 1: Baseline Safety and Naming Alignment
1. Confirm dispatcher gate (`input_boolean.hc_dispatcher_mode_enabled`) is OFF by default until validation passes.
2. Verify core HVAC operation remains unchanged with dispatcher disabled.
3. Align helper naming across dispatcher packages and dashboards.

## Phase 2: Helpers and Guardrails
1. Add V2 helpers, guardrail controls, and manual caps override duration.
2. Validate that new helpers do not collide with existing entities.

## Phase 3: Advisory Logic
1. Merge POC advisory logic and confirm guardrail outputs.
2. Validate near-call detection and guardrail statuses.

## Phase 4: Actuator Integration
1. Enforce gating by dispatcher master switch.
2. Implement force-call overrides for added zones (delta and cap).
3. Enforce min-run time before restore.
4. Freeze caller set during batch to avoid forced zones extending the batch.
5. Accept caller setpoint changes during batch (baseline updates).

## Phase 5: Dashboards and Operator Workflow
1. Update Dispatcher Ops with all guardrail controls and force parameters.
2. Update Zone Setup dashboard for cluster assignment and loop lengths.
3. Add operator guidance in `docs/HYDRONIC_TESTING.md`.

## Phase 6: Validation and Release
1. Run `docs/HYDRONIC_TESTING.md` stepwise tests.
2. Complete `docs/TEST_CHECKLIST.md`.
3. Update inventories and tag a release.

## Phase 7: Dispatcher Rearchitecture (Planned)
1. Build a dispatcher state registry (per-zone records for baseline, override, call state, run time, cluster, loop length).
2. Rebind dispatcher logic to generic thermostats (temp sensor + switch) as the canonical control surface.
3. Implement global manual-change detection with configurable cooldown.
4. Rework batching to always account for non-batch calls in total loop length.
5. Replace or simplify batch call tracking and restore logic using the registry as the source of truth.
6. Update tests and dashboards to the new model.

## Feature Requests (Post-Rewrite)
1. Add a **Manual Change Detection Bypass** toggle in Dispatcher Ops:
   - When enabled, guardrail/dispatcher config changes do **not** trigger global abort/cooldown.
   - Must be time‑boxed with a user‑selectable duration (minutes) before auto‑reverting to normal detection.
   - Intended for safe tuning sessions without forced resets.

## Blockers and Risks
- Cluster assignments may be reset when helper packages are reloaded; ensure cluster state is explicitly restored in tests.
- Cluster average temp sensors will be unavailable for empty clusters; audit ignores those by design.
- Caller baseline updates must be honored to avoid the dispatcher re-starting a finished batch.
- Profile/opportunistic edge cases must be validated separately after matrix stop/restore is confirmed.
