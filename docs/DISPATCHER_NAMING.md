# Dispatcher Naming Standard (Phase 1)

## Goal
Standardize dispatcher entity naming without breaking core operation. We will **not rename entity IDs** in this phase. This document defines the canonical target naming and the migration map for later.

## Current Naming (Observed)
- `hc_dispatcher_*`: master and advisory toggles (e.g., `input_boolean.hc_dispatcher_mode_enabled`, `input_boolean.hc_dispatcher_advisory_enabled`).
- `hc_dispatch_*`: advisory sensors/counters and batch helpers (e.g., `sensor.hc_dispatch_suggested_batch`, `input_number.hc_dispatch_batch_window_sec`).
- `hc_disp_*`: per-zone dispatcher helper setpoints and follow toggles (e.g., `input_number.hc_disp_z1_setpoint_f`, `input_boolean.hc_disp_z1_follow_broadcast`).
- `hc_z{n}_cluster`, `hc_z{n}_length_feet`: zone metadata for clusters and loop lengths.

## Canonical Target Naming (Future)
1. **Global dispatcher controls and state**: `hc_dispatch_*`
   - Example: `hc_dispatch_mode_enabled`, `hc_dispatch_auto_approve`, `hc_dispatch_suggested_batch`
2. **Per-zone dispatcher helpers**: `hc_dispatch_z{n}_*`
   - Example: `hc_dispatch_z1_setpoint_f`, `hc_dispatch_z1_hot_tolerance_f`, `hc_dispatch_z1_follow_broadcast`
3. **Cluster metadata and stats**:
   - Keep `hc_z{n}_cluster` and `hc_z{n}_length_feet` as zone metadata.
   - Keep `hc_cluster_*` for cluster stats (avg temp, total length).

## Migration Map (Deferred)
The following would be renamed **later** in a controlled migration. We keep existing entity IDs for now.

### Per-Zone Dispatcher Helpers
- `hc_disp_follow_sync_enabled` → `hc_dispatch_follow_sync_enabled`
- `hc_disp_z{n}_follow_broadcast` → `hc_dispatch_z{n}_follow_broadcast`
- `hc_disp_z{n}_setpoint_f` → `hc_dispatch_z{n}_setpoint_f`
- `hc_disp_z{n}_hot_tolerance_f` → `hc_dispatch_z{n}_hot_tolerance_f`
- `hc_disp_z{n}_cold_tolerance_f` → `hc_dispatch_z{n}_cold_tolerance_f`

### Automation IDs (Optional)
- `hc_disp_follow_*` → `hc_dispatch_follow_*`

## Phase 1 Policy
- **No entity ID changes** in production until a dedicated migration window exists.
- New dispatcher entities added from the POC should either:
  - Follow the **existing** pattern for compatibility, or
  - Follow the **canonical target naming** if they are new and unreferenced.

## Validation
Before any rename:
- Ensure `input_boolean.hc_dispatcher_mode_enabled` remains OFF by default.
- Confirm no changes affect call-for-heat detection or zone control paths.
