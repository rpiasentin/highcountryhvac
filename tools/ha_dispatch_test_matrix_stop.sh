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
RESET_TRACKING=${RESET_TRACKING:-1}
STOP_SETPOINT_MODE=${STOP_SETPOINT_MODE:-baseline} # baseline | safe

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

get_attr_current_temp() {
  local entity="$1"
  api_get "states/$entity" | sed -n 's/.*"current_temperature":\([^,}]*\).*/\1/p'
}

safe_setpoint() {
  local ct="$1"
  if [ -z "$ct" ]; then
    echo "50"
    return
  fi
  awk -v ct="$ct" 'BEGIN{v=ct-1; if(v<50)v=50; printf "%.1f", v}'
}

caller_stop_setpoint() {
  local ct="$1"
  local baseline="$2"
  if [ "$STOP_SETPOINT_MODE" = "safe" ]; then
    safe_setpoint "$ct"
    return
  fi
  if [ -n "$baseline" ]; then
    echo "$baseline"
  else
    safe_setpoint "$ct"
  fi
}

echo "[1/9] Set dispatcher gates and modes"
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

if [ "$RESET_TRACKING" = "1" ]; then
  echo "[1.5/9] Reset batch tracking"
  api_post "services/input_text/set_value" '{"entity_id":"input_text.hc_dispatch_batch_callers","value":"none"}'
  api_post "services/input_text/set_value" '{"entity_id":"input_text.hc_dispatch_last_batch_zones","value":"none"}'
fi

echo "[2/9] Snapshot original setpoints"
ORIG_Z3="$(get_attr_temperature "${CLIMATE_MAP_z3}")"
ORIG_Z7="$(get_attr_temperature "${CLIMATE_MAP_z7}")"
ORIG_Z9="$(get_attr_temperature "${CLIMATE_MAP_z9}")"

CT_Z7="$(get_attr_current_temp "${CLIMATE_MAP_z7}")"
CT_Z9="$(get_attr_current_temp "${CLIMATE_MAP_z9}")"
CT_Z3="$(get_attr_current_temp "${CLIMATE_MAP_z3}")"
SAFE_Z7="$(safe_setpoint "$CT_Z7")"
SAFE_Z9="$(safe_setpoint "$CT_Z9")"
STOP_Z3="$(caller_stop_setpoint "$CT_Z3" "$ORIG_Z3")"

echo "[2.5/9] Ensure non-callers are below current temp"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CLIMATE_MAP_z7}\",\"temperature\":${SAFE_Z7}}"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CLIMATE_MAP_z9}\",\"temperature\":${SAFE_Z9}}"

sleep 3

echo "[3/9] Set dispatcher target setpoints"
for z in "${BASE_ZONES[@]}"; do
  api_post "services/input_number/set_value" \
    "{\"entity_id\":\"input_number.hc_disp_${z}_setpoint_f\",\"value\":${TARGET_F}}"
done

echo "[4/9] Force a caller zone setpoint to create an active call"
CALLER_CLIMATE_VAR="CLIMATE_MAP_${CALLER_ZONE}"
CALLER_CLIMATE="${!CALLER_CLIMATE_VAR}"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${TARGET_F}}"


echo "[5/9] Wait for suggested batch"
for i in $(seq 1 30); do
  sb="$(get_state "sensor.hc_dispatch_suggested_batch")"
  if [ -n "$sb" ] && [ "$sb" != "idle" ] && [ "$sb" != "unknown" ] && [ "$sb" != "unavailable" ] && [ "$sb" != "none" ]; then
    echo "suggested_batch=$sb"
    break
  fi
  sleep 2
done

echo "[6/9] Manual approve"
api_post "services/input_button/press" '{"entity_id":"input_button.hc_dispatch_approve_batch"}'

min_wait=$((WAIT_MINUTES * 60))
echo "[7/9] Wait min-run (${WAIT_MINUTES} min)"
sleep "$min_wait"

echo "[7.5/9] Drop caller to stop setpoint (${STOP_Z3})"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${STOP_Z3}}"

for i in $(seq 1 30); do
  sb="$(get_state "sensor.hc_dispatch_suggested_batch")"
  if [ -n "$sb" ] && [ "$sb" = "idle" ]; then
    echo "suggested_batch=idle"
    break
  fi
  sleep 2
done

echo "[8/9] Wait for restore (${RESTORE_WAIT_SECONDS}s) + snapshot"
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


echo "[9/9] Return original setpoints"
if [ -n "${ORIG_Z7}" ]; then
  api_post "services/climate/set_temperature" \
    "{\"entity_id\":\"${CLIMATE_MAP_z7}\",\"temperature\":${ORIG_Z7}}"
fi
if [ -n "${ORIG_Z9}" ]; then
  api_post "services/climate/set_temperature" \
    "{\"entity_id\":\"${CLIMATE_MAP_z9}\",\"temperature\":${ORIG_Z9}}"
fi
if [ -n "${ORIG_Z3}" ]; then
  api_post "services/climate/set_temperature" \
    "{\"entity_id\":\"${CLIMATE_MAP_z3}\",\"temperature\":${ORIG_Z3}}"
fi
