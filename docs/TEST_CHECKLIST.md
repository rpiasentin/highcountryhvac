# Test Checklist

## Constraints
- Only one Home Assistant instance should control systems at a time.
- Hubitat can post state updates to a single Home Assistant IP.
- If staging is used, prod must be isolated or Hubitat must be switched to target staging.

## Pre-Flight (Any Environment)
1. Confirm the dispatcher master gate is OFF: `input_boolean.hc_dispatcher_mode_enabled`.
2. Review recent changes against `inventories/poc_compare_report.md`.
3. Run Home Assistant “Check configuration” and resolve any errors.

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

## Post-Validation
1. Update `inventories/entity_inventory.csv` and `inventories/hvac_entity_inventory.csv`.
2. Record release notes and tag the release.
