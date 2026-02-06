#!/usr/bin/env bash
set -euo pipefail

# Matrix-mode dispatcher stop test.
# Validates: batch start -> min-run wait -> caller stops -> batch idle -> restore baselines.

BASE_URL="http://supervisor/core/api"
AUTH_HEADER="Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN missing}"

TARGET_F=${TARGET_F:-70}
CALLER_ZONE=${CALLER_ZONE:-z3}
BASE_ZONES=("z3" "z7" "z9")
WAIT_MINUTES=${WAIT_MINUTES:-10}
RESTORE_WAIT_SECONDS=${RESTORE_WAIT_SECONDS:-120}

CLIMATE_MAP_z3="climate.zone_3_basement_bath_and_common"
CLIMATE_MAP_z7="climate.zone_7_basement_bar_and_tv_room_south_side"
CLIMATE_MAP_z9="climate.zone_9_basement_bedroom"

api_post() {
  local path="$1"
  local data="$2"
  curl -s -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    -X POST "$BASE_URL/$path" -d "$data" >/dev/null
}

api_get() {
  local path="$1"
  curl -s -H "$AUTH_HEADER" "$BASE_URL/$path"
}

get_state() {
  local entity="$1"
  api_get "states/$entity" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p'
}

get_attr_temperature() {
  local entity="$1"
  api_get "states/$entity" | sed -n 's/.*"temperature":\([^,}]*\).*/\1/p'
}

echo "[1/7] Set dispatcher gates and modes"
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatcher_mode_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatcher_auto_approve"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_opportunistic_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_enable_setpoint_broadcast"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_manual_override"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_algorithm","option":"Matrix"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_profile","option":"Basement (Z3+Z7+Z9)"}'
api_post "services/input_number/set_value" '{"entity_id":"input_number.hc_dispatch_near_call_margin_f","value":1.5}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_force_mode","option":"Added Only"}'
api_post "services/input_number/set_value" '{"entity_id":"input_number.hc_dispatch_force_delta_f","value":1.0}'
api_post "services/input_number/set_value" '{"entity_id":"input_number.hc_dispatch_force_cap_f","value":75}'

echo "[2/7] Set dispatcher target setpoints"
for z in "${BASE_ZONES[@]}"; do
  api_post "services/input_number/set_value" \
    "{\"entity_id\":\"input_number.hc_disp_${z}_setpoint_f\",\"value\":${TARGET_F}}"
done

echo "[3/7] Force a caller zone setpoint to create an active call"
CALLER_CLIMATE_VAR="CLIMATE_MAP_${CALLER_ZONE}"
CALLER_CLIMATE="${!CALLER_CLIMATE_VAR}"
CALLER_BASELINE="$(get_attr_temperature "${CALLER_CLIMATE}")"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${TARGET_F}}"

echo "[4/7] Wait for suggested batch"
for i in $(seq 1 30); do
  sb="$(get_state "sensor.hc_dispatch_suggested_batch")"
  if [ -n "$sb" ] && [ "$sb" != "idle" ] && [ "$sb" != "unknown" ] && [ "$sb" != "unavailable" ] && [ "$sb" != "none" ]; then
    echo "suggested_batch=$sb"
    break
  fi
  sleep 2
done

echo "[5/7] Manual approve"
api_post "services/input_button/press" '{"entity_id":"input_button.hc_dispatch_approve_batch"}'

min_wait=$((WAIT_MINUTES * 60))
echo "[6/7] Wait min-run (${WAIT_MINUTES} min)"
sleep "$min_wait"

echo "[6.5/7] Drop caller back to baseline (${CALLER_BASELINE})"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${CALLER_BASELINE}}"

for i in $(seq 1 30); do
  sb="$(get_state "sensor.hc_dispatch_suggested_batch")"
  if [ -n "$sb" ] && [ "$sb" = "idle" ]; then
    echo "suggested_batch=idle"
    break
  fi
  sleep 2
done

echo "[7/7] Wait for restore (${RESTORE_WAIT_SECONDS}s) + snapshot"
sleep "$RESTORE_WAIT_SECONDS"

api_get "states/sensor.hc_dispatch_suggested_batch"
echo
api_get "states/input_text.hc_dispatch_batch_callers"
echo
api_get "states/input_text.hc_dispatch_last_batch_zones"
echo
api_get "states/input_text.hc_dispatch_last_apply_debug"
echo
api_get "states/input_text.hc_dispatch_loop_marker"
echo
api_get "states/input_number.hc_disp_z3_baseline_setpoint_f"
echo
api_get "states/input_number.hc_disp_z7_baseline_setpoint_f"
echo
api_get "states/input_number.hc_disp_z9_baseline_setpoint_f"
echo
api_get "states/climate.zone_7_basement_bar_and_tv_room_south_side"
echo
api_get "states/climate.zone_3_basement_bath_and_common"
echo
api_get "states/climate.zone_9_basement_bedroom"
echo
