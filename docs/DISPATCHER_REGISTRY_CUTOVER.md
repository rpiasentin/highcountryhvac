# Dispatcher Registry Cutover Checklist

This checklist enables the registry-based dispatcher safely and provides rollback steps. Rollback reference: manual backup **“tuesday feb 10 before rewrite.”**

## Preconditions
- Dispatcher master gate is OFF: `input_boolean.hc_dispatcher_mode_enabled`.
- Registry is OFF: `input_boolean.hc_dispatch_reg_enabled`.
- Registry packages are deployed:
  - `packages/hc_dispatcher_registry.yaml`
  - `packages/hc_dispatcher_registry_engine.yaml`
  - `packages/hc_dispatcher_registry_guardrail.yaml`
  - `packages/hc_dispatcher_registry_control.yaml`
- Home Assistant has been restarted or helpers reloaded.

## Cutover Steps
1. **Enable registry bootstrap**
   - Turn ON: `input_boolean.hc_dispatch_reg_enabled`.
   - Expected:
     - `input_select.hc_dispatch_reg_state` = `idle`.
     - `input_text.hc_dispatch_reg_active_zones` = `none`.
     - Per‑zone `user_baseline_f` populated from current thermostat setpoints.

2. **Confirm registry guardrail output**
   - Check: `sensor.hc_dispatch_reg_guardrail` and `sensor.hc_dispatch_reg_suggested_batch`.
   - Ensure values are not `unknown`.

3. **Enable dispatcher master gate** (if ready to test)
   - Turn ON: `input_boolean.hc_dispatcher_mode_enabled`.
   - Registry controller now applies batches.

4. **Manual change abort test**
   - Manually change any thermostat setpoint.
   - Expected:
     - `input_select.hc_dispatch_reg_state` → `cooldown`.
     - Dispatcher master gate turns OFF.
     - Active batch cleared and zones restored to baseline.

5. **Cooldown expiration**
   - After cooldown minutes, state returns to `idle`.
   - Dispatcher remains OFF until re‑enabled by operator.

## Rollback (Immediate)
1. Turn OFF: `input_boolean.hc_dispatch_reg_enabled`.
2. Legacy dispatcher logic resumes (actuator + setpoint sync).
3. If needed, restore from backup **“tuesday feb 10 before rewrite.”**

## Notes
- Registry enabled **disables** legacy actuator and setpoint sync.
- Manual changes to guardrails or dispatcher controls trigger global abort + cooldown.
