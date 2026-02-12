#!/usr/bin/env bash
set -euo pipefail

# Registry-mode Matrix test.
# NOTE: Manual setpoint changes trigger global abort + cooldown in registry mode.
# This script waits for cooldown before enabling dispatcher.

BASE_URL="http://supervisor/core/api"
AUTH_HEADER="Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN missing}"

TARGET_F=${TARGET_F:-70}
CALLER_ZONE=${CALLER_ZONE:-z3}
BASE_ZONES=("z3" "z7" "z9")
COOLDOWN_WAIT_SEC=${COOLDOWN_WAIT_SEC:-360}
RESTORE_CALLER=${RESTORE_CALLER:-0}

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

wait_for_reg_idle() {
  local waited=0
  while [ "$waited" -lt "$COOLDOWN_WAIT_SEC" ]; do
    st="$(get_state "input_select.hc_dispatch_reg_state")"
    if [ "$st" = "idle" ]; then
      return 0
    fi
    sleep 5
    waited=$((waited+5))
  done
  return 1
}

echo "[1/6] Disable registry, set modes (avoids manual-abort during config)"
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_reg_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatcher_mode_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatcher_auto_approve"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_opportunistic_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_manual_override"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_algorithm","option":"Matrix"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_profile","option":"Basement (Z3+Z7+Z9)"}'
api_post "services/input_number/set_value" '{"entity_id":"input_number.hc_dispatch_near_call_margin_f","value":1.5}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_force_mode","option":"Added Only"}'
api_post "services/input_number/set_value" '{"entity_id":"input_number.hc_dispatch_force_delta_f","value":1.0}'
api_post "services/input_number/set_value" '{"entity_id":"input_number.hc_dispatch_force_cap_f","value":75}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_reg_state","option":"idle"}'
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatcher_mode_enabled"}'
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatch_reg_enabled"}'

echo "[2/6] Create a caller by setting thermostat (will trigger cooldown)"
CALLER_CLIMATE_VAR="CLIMATE_MAP_${CALLER_ZONE}"
CALLER_CLIMATE="${!CALLER_CLIMATE_VAR}"
CALLER_BASELINE="$(get_attr_temperature "${CALLER_CLIMATE}")"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${TARGET_F}}"

echo "[3/6] Wait for cooldown to expire"
if ! wait_for_reg_idle; then
  echo "Cooldown did not expire in ${COOLDOWN_WAIT_SEC}s"
  exit 1
fi

echo "[4/6] Dispatcher gate already enabled"

echo "[5/6] Wait for registry suggested batch"
for i in $(seq 1 20); do
  sb="$(get_state "sensor.hc_dispatch_reg_suggested_batch")"
  if [ -n "$sb" ] && [ "$sb" != "idle" ] && [ "$sb" != "unknown" ] && [ "$sb" != "unavailable" ] && [ "$sb" != "none" ]; then
    echo "suggested_batch=$sb"
    break
  fi
  sleep 2
done

echo "[5.5/6] Manual approve"
api_post "services/input_button/press" '{"entity_id":"input_button.hc_dispatch_approve_batch"}'
sleep 6

echo "[6/6] Debug snapshot"
api_get "states/sensor.hc_dispatch_reg_suggested_batch"
echo
api_get "states/sensor.hc_dispatch_reg_guardrail"
echo
api_get "states/input_text.hc_dispatch_reg_active_zones"
echo
api_get "states/input_text.hc_dispatch_reg_active_callers"
echo
api_get "states/input_select.hc_dispatch_reg_state"
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
