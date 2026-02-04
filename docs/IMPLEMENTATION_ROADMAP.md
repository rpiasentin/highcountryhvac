# Implementation Roadmap

## Scope
This roadmap applies the POC objectives to the canonical production configuration in this repo. The goal is to introduce Dispatcher V2 capabilities without disrupting core HVAC operation.

## Inputs
- POC objectives: `docs/POC_OBJECTIVES.md`
- POC vs canonical diff: `inventories/poc_compare_report.md`
- HVAC inventory: `inventories/hvac_entity_inventory.csv`

## Phase 1: Baseline Safety and Naming Alignment
1. Confirm dispatcher is gated by `input_boolean.hc_dispatcher_mode_enabled` in `packages/hc_dispatcher_inputs.yaml` and keep it off by default until validation is complete.
2. Review existing helper names in `packages/hc_dispatcher_inputs.yaml` and `packages/hc_dispatcher_broadcast_follow.yaml` and define the canonical naming scheme for dispatcher entities.
3. Apply naming changes consistently across dispatcher packages to avoid ambiguity before introducing new POC helpers.

## Phase 2: Introduce POC Helpers and Cluster Stats
1. Add POC helper packages to canonical config:
   - `packages/hc_dispatcher_v2_helpers.yaml`
   - `packages/hc_dispatcher_v2_zone_lengths.yaml`
   - `packages/hc_dispatcher_v2_cluster_stats.yaml`
2. Validate that new helpers do not collide with existing entities and appear in the inventory.

## Phase 3: Advisory Logic Reconciliation
1. Merge POC dispatcher advisory logic into `packages/hc_dispatcher_advisory.yaml` after aligning naming.
2. Validate advisory output against existing dispatcher inputs and cold tolerance gating (`packages/hc_cold_tolerance_gate.yaml`).

## Phase 4: Actuator Integration
1. Add actuator automation from `packages/hc_dispatcher_actuator.yaml` with explicit gating:
   - Must respect `input_boolean.hc_dispatcher_mode_enabled`.
   - Must respect cold tolerance and system control constraints.
2. Confirm actuator does not run in auto mode unless explicitly enabled.

## Phase 5: Dashboard and Operator Workflow
1. Add the POC dashboard to `lovelace/hc_zone_setup.yaml` and register it in `configuration.yaml` if needed.
2. Update operator notes and usage instructions for the new dashboard and dispatcher controls.

## Phase 6: Release and Test Workflow
1. Use `docs/TEST_CHECKLIST.md` for validation.
2. Document a minimal “safe mode” procedure for prod-only testing when staging is unavailable.
3. Tag releases after successful prod validation.
