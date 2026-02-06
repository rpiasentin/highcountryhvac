#!/usr/bin/env bash
set -euo pipefail

# Matrix-mode dispatcher test (deterministic, no near-call required).
# Run inside the HA Terminal add-on (SUPERVISOR_TOKEN is available there).

BASE_URL="http://supervisor/core/api"
AUTH_HEADER="Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN missing}"

# Test parameters
TARGET_F=70
BASE_ZONES=("z3" "z7" "z9")

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

echo "[1/5] Set dispatcher gates and modes"
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatcher_mode_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatcher_auto_approve"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_opportunistic_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_enable_setpoint_broadcast"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_algorithm","option":"Matrix"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_profile","option":"Basement (Z3+Z7+Z9)"}'
api_post "services/input_number/set_value" '{"entity_id":"input_number.hc_dispatch_near_call_margin_f","value":1.5}'

echo "[2/5] Set dispatcher target setpoints"
for z in "${BASE_ZONES[@]}"; do
  api_post "services/input_number/set_value" \
    "{\"entity_id\":\"input_number.hc_disp_${z}_setpoint_f\",\"value\":${TARGET_F}}"
done

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
sleep 2

echo "[5/5] Debug and climate snapshot"
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
