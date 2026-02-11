# Test Checklist

## Constraints
- Only one Home Assistant instance should control systems at a time.
- Hubitat can post state updates to a single Home Assistant IP.
- If staging is used, prod must be isolated or Hubitat must be switched.

## Pre-Flight (Any Environment)
1. Confirm dispatcher master gate is OFF: `input_boolean.hc_dispatcher_mode_enabled`.
2. Review recent changes against `inventories/poc_compare_report.md`.
3. Run Home Assistant “Check configuration” and resolve any errors.
4. After restart, confirm `sensor.hc_dispatch_suggested_batch` is not `unknown`.
5. Run `tools/ha_entity_audit.sh`; ignore cluster average temp sensors when clusters are empty.
6. Confirm the rollback reference exists: manual backup **“tuesday feb 10 before rewrite.”**
7. If using the registry rewrite, complete `docs/DISPATCHER_REGISTRY_CUTOVER.md`.

## Cluster Prerequisites (Matrix Tests)
1. Ensure cluster assignments are restored after any helper reload.
2. Example: set Z3, Z7, Z9 to Cluster A and Z5 to Independent.
3. Ensure Z8 thermostat uses `sensor.dining_temp_temperature` as its temperature sensor.

## Prod-Only Safe Test (When Staging Is Unavailable)
1. Keep dispatcher gate OFF while loading new helpers and dashboards.
2. Validate entities appear and dashboards render correctly.
3. Temporarily enable dispatcher gate during a low-risk window.
4. Observe one full cycle and then disable the gate.

## Guardrail Verification (Prod Safe)
1. Set algorithm to Matrix.
2. Enable opportunistic toggle.
3. Set near-call margin to 1.5.
4. Induce a single call and verify guardrail status reflects opportunistic skip under min.
5. Induce a near-call for a large zone and verify opportunistic add occurs within 50–70 ft.

## Dispatcher Actuation Test (Prod Safe)
1. Confirm dispatcher gate is ON only during a low-risk window.
2. Confirm auto-approve is OFF for manual validation.
3. Induce a Matrix batch and manually approve it.
4. Verify setpoints are adjusted for the approved batch and restored afterward.
5. Confirm minimum run time is enforced (10 minutes) before shutoff.
6. Manual override abort: change a batch zone setpoint and verify batch clears, baselines restore, and dispatcher turns OFF.

## Registry Matrix Test (Rewrite)
1. Complete `docs/DISPATCHER_REGISTRY_CUTOVER.md`.
2. Run `ha_dispatch_reg_test_matrix.sh`.
3. Verify registry sensors show batch, callers, and active zones.
4. Confirm added zones are forced and restore behavior is correct.

## Registry Manual Abort Test (Rewrite)
1. Run `ha_dispatch_reg_test_manual_abort.sh`.
2. Verify dispatcher state moves to `cooldown` and gate turns OFF.
3. Verify active zones clear and baselines restore.

## Registry Stop + Restore Test (Rewrite)
1. Run `ha_dispatch_reg_test_stop_restore.sh`.
2. Verify batch clears after min-run and registry state returns to `idle`.

## Manual Change Global Abort (Post-Rearchitecture)
1. With dispatcher ON, change any thermostat setpoint manually.
2. Verify all dispatcher-touched zones restore to baseline.
3. Verify dispatcher turns OFF immediately.
4. Verify cooldown blocks re-analysis for the configured duration.

## Forced-Call Behavior
1. Select a batch with at least one added zone.
2. Ensure added zone current temperature is above its nominal target.
3. Approve the batch and verify the added zone setpoint is raised above current temp.
4. Confirm the added zone calls for heat.
5. After stop conditions, verify baseline setpoints are restored.

## Manual Caps Override
1. Enable manual caps override and set a duration.
2. Create a batch that would exceed the hard cap.
3. Verify batch is allowed only while override is active.
4. After override expiration, verify the same batch is blocked or degraded.

## Profile + Opportunistic
1. Set algorithm to Profile and enable opportunistic.
2. Confirm calling zones follow broadcast setpoints (no drift).
3. Confirm opportunistic adds occur only when enabled.
4. Disable opportunistic and verify no near-call zones are added.

## Reference
For stepwise hydronic tests and scripts, use `docs/HYDRONIC_TESTING.md`.
