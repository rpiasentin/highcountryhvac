# Dispatcher Stability Report (2026-02-14)

## Summary
Testing of the registry-based dispatcher has not produced reliable, repeatable results. Multiple hours of effort were spent without a clean pass. This report captures the observed failures, likely causes, and a path forward so we can reset from first principles and stop repeating non-deterministic tests.

## Observed Failures (From Core Test + Live Debug)
1. **Matrix expansion test flagged as failed while payload shows correct `fz`**
   - Guardrail payload shows `bz`/`fz` including `z3,z7,z9`.
   - Test script prints `payload.fz=` blank, then fails with “Matrix cluster expansion missing.”
   - Conclusion: the script’s payload parsing is unreliable and can produce false negatives.

2. **Near-call opportunistic not added**
   - The test used a negative delta (`delta(z5)=-6.0` with `tol=-5.8`).
   - This is not a valid “near-call” condition for opportunistic adds.
   - Conclusion: near-call setup in the test is invalid; test should fail fast when delta and tolerance are not consistent.

3. **Restore after caller stops did not clear overrides**
   - Overrides remained non-zero after caller shutdown.
   - Follow-up checks showed call-for-heat sensors staying ON despite thermostats showing OFF in the UI.
   - Root cause was call-for-heat logic using `hvac_mode` attribute (stale/missing) rather than the climate entity state.

4. **Clusters drifted to Independent**
   - Live state showed `hc_z3_cluster`, `hc_z7_cluster`, `hc_z9_cluster` = Independent.
   - Matrix expansion cannot be validated while clusters are unset.
   - Conclusion: helper reloads are resetting clusters; tests must enforce cluster assignment before running.

5. **Manual change detection interference**
   - Registry state often entered cooldown due to config changes or toggle adjustments.
   - Manual-change ignore toggle was sometimes OFF during tests.
   - Conclusion: tests must explicitly disable manual-change detection or they will abort.

## Root Causes (Primary)
1. **Call-for-heat signal was wrong**
   - Template used `state_attr(..., 'hvac_mode')`, which can remain stale.
   - When climate entity state is `off`, call-for-heat should be `off`.
   - Fix: read the climate entity state directly (now implemented in `packages/high_country_call_for_heat.yaml`).

2. **Test script parsing is brittle**
   - The core script is parsing JSON payloads from a string field; parsing can fail and create false negatives.
   - Fix: parse the payload using a single JSON decode path and fail fast if parsing fails.

3. **Test assumptions not enforced**
   - Cluster assignments, dispatcher mode, and registry ignore-manual toggle are not forced prior to tests.
   - Fix: preflight step must set and verify all assumptions.

4. **Opportunistic “near-call” setup inconsistent**
   - Delta and tolerance must be configured so a near-call is actually in-range without a call.
   - Fix: compute target values from real sensor readings and validate them before testing.

## Path Forward (Recommended)
### Phase 0: Stabilize Inputs and State
1. **Enforce call-for-heat invariants**
   - If climate state is `off`, call-for-heat must be `off`.
   - Verify via template reload before any tests.
2. **Force cluster assignments for tests**
   - Always set `z3,z7,z9` to Cluster A and verify before Matrix testing.
3. **Disable manual-change detection during core tests**
   - Enable `input_boolean.hc_dispatch_reg_ignore_manual_changes` for test runs.

### Phase 1: Replace Fragile Tests
1. Build a **new preflight + core test** that:
   - Fails fast on missing prerequisites (clusters, registry enabled, manual-change ignore).
   - Logs all raw JSON to a file (no terminal scroll issues).
   - Uses a single JSON parser for payload extraction (no regex).
2. Keep tests focused on three behaviors only:
   - Matrix cluster expansion.
   - Opportunistic near-call add.
   - Restore after caller stop.

### Phase 2: Reduce Moving Parts
1. Use a single caller zone and keep opportunistic disabled unless explicitly testing it.
2. Avoid changing guardrails or toggles during the test (these trigger manual abort).

### Phase 3: Re-architecture (If Stability Still Fails)
1. Implement the registry as the sole source of truth.
2. Remove legacy actuator/setpoint sync during registry tests.
3. Rebuild the batch execution loop with explicit exit conditions and a single batch owner.

## Immediate Actions (Next Session)
1. Confirm call-for-heat fix is pushed and pulled to HA.
2. Commit the guardrail external-callers fix (if not already).
3. Replace the current core test script with a deterministic, preflight-enforced version.

## References
- Core test logs from Feb 14, 2026:
  - `dispatch_reg_core_20260214_171930.log`
- Guardrail payload shown to be correct, but parsing failed.
- Cluster state drifted to Independent during tests.
