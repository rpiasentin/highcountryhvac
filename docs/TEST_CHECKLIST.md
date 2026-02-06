# Test Checklist

## Constraints
- Only one Home Assistant instance should control systems at a time.
- Hubitat can post state updates to a single Home Assistant IP.
- If staging is used, prod must be isolated or Hubitat must be switched to target staging.

## Pre-Flight (Any Environment)
1. Confirm the dispatcher master gate is OFF: `input_boolean.hc_dispatcher_mode_enabled`.
2. Review recent changes against `inventories/poc_compare_report.md`.
3. Run Home Assistant “Check configuration” and resolve any errors.
4. After restart, confirm `sensor.hc_dispatch_guardrail_payload` is not `unknown`.

## Staging Test (If Staging Is Active and Hubitat Is Routed)
1. Confirm Hubitat is sending updates to staging and prod is isolated.
2. Enable dispatcher gate and verify advisory outputs change as expected.
3. Validate that near-call zones only join batches when a batch already exists.
4. Exercise manual approve and auto-approve paths.
5. Verify actuator turns only intended zone switches on and off.

## Prod-Only Safe Test (When Staging Is Unavailable)
1. Keep dispatcher gate OFF while loading new helpers and dashboards.
2. Validate entities appear and dashboards render correctly.
3. Temporarily enable dispatcher gate during a low-risk window.
4. Observe one full cycle and then disable the gate.

## Guardrail Verification (Prod Safe)
1. Set `input_select.hc_dispatch_algorithm` to `Matrix`.
2. Set `input_boolean.hc_dispatch_opportunistic_enabled` to `on`.
3. Set `input_number.hc_dispatch_near_call_margin_f` to `1.5`.
4. Induce a single call (Z1) and verify `sensor.hc_dispatch_guardrail` reports `opportunistic_skipped_under_min` and the suggested batch matches the calling zone.
5. Induce a near-call for a large zone (Z7) and verify `sensor.hc_dispatch_near_call_zones` includes Z7, guardrail status is `opportunistic_applied`, and the suggested batch total length is 50–70 ft.

## Dispatcher Actuation Test (Prod Safe)
1. Confirm dispatcher gate is ON only during a low-risk window.
2. Confirm auto-approve is OFF for manual validation.
3. Induce a Matrix batch and manually approve it.
4. Verify setpoints are adjusted for the approved batch and restored afterward.
5. Confirm minimum run time is enforced (10 minutes) before shutoff.
6. If a zone fails to actuate:
   - Check `input_text.hc_dispatch_last_apply_debug` to confirm the actuator computed the zone as ON and which setpoint it tried to apply.
   - Compare `desired_temp` vs current temperature; if `desired_temp <= current`, the thermostat will not call.
   - Temporarily disable `input_boolean.hc_enable_setpoint_broadcast` to rule out broadcast overrides from `packages/high_country_setpoints.yaml`.

## Post-Validation
1. Update `inventories/entity_inventory.csv` and `inventories/hvac_entity_inventory.csv`.
2. Record release notes and tag the release.
