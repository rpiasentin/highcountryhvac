#!/usr/bin/env bash
set -euo pipefail

# Registry-mode manual abort test.
# Creates a batch, then changes a thermostat setpoint to trigger abort/cooldown.

BASE_URL="http://supervisor/core/api"
AUTH_HEADER="Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN missing}"

TARGET_F=${TARGET_F:-70}
CALLER_ZONE=${CALLER_ZONE:-z3}
BASE_ZONES=("z3" "z7" "z9")
COOLDOWN_WAIT_SEC=${COOLDOWN_WAIT_SEC:-360}
ABORT_ZONE=${ABORT_ZONE:-z3}

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

echo "[1/6] Enable registry + set modes"
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatch_reg_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatcher_mode_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatcher_auto_approve"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_opportunistic_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_manual_override"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_algorithm","option":"Matrix"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_profile","option":"Basement (Z3+Z7+Z9)"}'

CALLER_CLIMATE_VAR="CLIMATE_MAP_${CALLER_ZONE}"
CALLER_CLIMATE="${!CALLER_CLIMATE_VAR}"

ABORT_CLIMATE_VAR="CLIMATE_MAP_${ABORT_ZONE}"
ABORT_CLIMATE="${!ABORT_CLIMATE_VAR}"

CALLER_BASELINE="$(get_attr_temperature "${CALLER_CLIMATE}")"
ABORT_BASELINE="$(get_attr_temperature "${ABORT_CLIMATE}")"

set_caller_temp() {
  api_post "services/climate/set_temperature" \
    "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${TARGET_F}}"
}

set_abort_temp() {
  api_post "services/climate/set_temperature" \
    "{\"entity_id\":\"${ABORT_CLIMATE}\",\"temperature\":$1}"
}

echo "[2/6] Create caller (triggers cooldown)"
set_caller_temp

if ! wait_for_reg_idle; then
  echo "Cooldown did not expire in ${COOLDOWN_WAIT_SEC}s"
  exit 1
fi

echo "[3/6] Enable dispatcher gate"
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatcher_mode_enabled"}'

# wait for batch suggestion
for i in $(seq 1 20); do
  sb="$(get_state "sensor.hc_dispatch_reg_suggested_batch")"
  if [ -n "$sb" ] && [ "$sb" != "idle" ] && [ "$sb" != "unknown" ] && [ "$sb" != "unavailable" ] && [ "$sb" != "none" ]; then
    break
  fi
  sleep 2
done

echo "[4/6] Manual approve"
api_post "services/input_button/press" '{"entity_id":"input_button.hc_dispatch_approve_batch"}'
sleep 6

echo "[5/6] Trigger manual abort on ${ABORT_ZONE}"
# lower by 2°F or to 66 default if baseline empty
if [ -n "$ABORT_BASELINE" ]; then
  new_temp=$(python3 - <<PY
b=float("${ABORT_BASELINE}")
print(b-2 if b-2 >= 55 else 66)
PY
)
else
  new_temp=66
fi
set_abort_temp "$new_temp"

sleep 5

echo "[6/6] Snapshot"
api_get "states/input_select.hc_dispatch_reg_state"
echo
api_get "states/input_text.hc_dispatch_reg_active_zones"
echo
api_get "states/input_text.hc_dispatch_reg_active_callers"
echo
api_get "states/input_datetime.hc_dispatch_reg_cooldown_until"
echo
api_get "states/input_boolean.hc_dispatcher_mode_enabled"
echo
api_get "states/climate.zone_3_basement_bath_and_common"
echo
api_get "states/climate.zone_7_basement_bar_and_tv_room_south_side"
echo
api_get "states/climate.zone_9_basement_bedroom"
echo

# restore caller baseline if available
if [ -n "${CALLER_BASELINE}" ]; then
  api_post "services/climate/set_temperature" \
    "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${CALLER_BASELINE}}"
fi
