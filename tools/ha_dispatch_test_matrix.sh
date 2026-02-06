#!/usr/bin/env bash
set -euo pipefail

# Matrix-mode dispatcher test (deterministic, no near-call required).
# Run inside the HA Terminal add-on (SUPERVISOR_TOKEN is available there).

BASE_URL="http://supervisor/core/api"
AUTH_HEADER="Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN missing}"

# Test parameters
TARGET_F=70
CALLER_ZONE="z3"
BASE_ZONES=("z3" "z7" "z9")
RESTORE_CALLER=${RESTORE_CALLER:-1}

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
  api_get "states/$entity" | sed -n 's/.*"state":"\\([^"]*\\)".*/\\1/p'
}

get_attr_temperature() {
  local entity="$1"
  api_get "states/$entity" | sed -n 's/.*"temperature":\\([^,}]*\\).*/\\1/p'
}

echo "[1/5] Set dispatcher gates and modes"
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

echo "[2/5] Set dispatcher target setpoints"
for z in "${BASE_ZONES[@]}"; do
  api_post "services/input_number/set_value" \
    "{\"entity_id\":\"input_number.hc_disp_${z}_setpoint_f\",\"value\":${TARGET_F}}"
done

echo "[2.5/5] Force a caller zone setpoint to create an active call"
CALLER_CLIMATE_VAR="CLIMATE_MAP_${CALLER_ZONE}"
CALLER_CLIMATE="${!CALLER_CLIMATE_VAR}"
CALLER_BASELINE="$(get_attr_temperature "${CALLER_CLIMATE}")"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${TARGET_F}}"

echo "[3/5] Wait for suggested batch"
for i in $(seq 1 20); do
  sb="$(get_state "sensor.hc_dispatch_suggested_batch")"
  if [ -n "$sb" ] && [ "$sb" != "idle" ] && [ "$sb" != "unknown" ] && [ "$sb" != "unavailable" ] && [ "$sb" != "none" ]; then
    echo "suggested_batch=$sb"
    break
  fi
  sleep 2
done

echo "[4/5] Manual approve"
api_post "services/input_button/press" '{"entity_id":"input_button.hc_dispatch_approve_batch"}'
sleep 6

echo "[5/5] Debug and climate snapshot"
api_get "states/automation.hc_dispatch_v2_apply_batch"
echo
api_get "states/sensor.hc_dispatch_suggested_batch"
echo
api_get "states/input_text.hc_dispatch_last_suggested_batch"
echo
api_get "states/input_text.hc_dispatch_last_apply_debug"
echo
api_get "states/input_text.hc_dispatch_loop_marker"
echo
api_get "states/input_number.hc_disp_z3_setpoint_f"
echo
api_get "states/input_number.hc_disp_z7_setpoint_f"
echo
api_get "states/input_number.hc_disp_z9_setpoint_f"
echo
api_get "states/climate.zone_7_basement_bar_and_tv_room_south_side"
echo
api_get "states/climate.zone_3_basement_bath_and_common"
echo
api_get "states/climate.zone_9_basement_bedroom"
echo

if [ "${RESTORE_CALLER}" = "1" ] && [ -n "${CALLER_BASELINE}" ]; then
  echo "[restore] Reset caller zone setpoint to baseline (${CALLER_BASELINE})"
  api_post "services/climate/set_temperature" \
    "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${CALLER_BASELINE}}"
fi
