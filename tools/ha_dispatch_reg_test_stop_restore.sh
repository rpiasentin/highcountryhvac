#!/usr/bin/env bash
set -euo pipefail

# Registry-mode stop/restore test.
# Creates a short caller, lets it stop naturally, and verifies batch clears.
# Note: Any manual setpoint changes during an active batch will trigger abort/cooldown.

BASE_URL="http://supervisor/core/api"
AUTH_HEADER="Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN missing}"

CALLER_ZONE=${CALLER_ZONE:-z3}
TARGET_DELTA=${TARGET_DELTA:-1.0}
WAIT_MINUTES=${WAIT_MINUTES:-5}
COOLDOWN_WAIT_SEC=${COOLDOWN_WAIT_SEC:-360}
STOP_WAIT_SEC=${STOP_WAIT_SEC:-1800}

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

get_attr() {
  local entity="$1"
  local attr="$2"
  api_get "states/$entity" | sed -n "s/.*\"${attr}\":\([^,}]*\).*/\1/p"
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

wait_for_batch_clear() {
  local waited=0
  while [ "$waited" -lt "$STOP_WAIT_SEC" ]; do
    az="$(get_state "input_text.hc_dispatch_reg_active_zones")"
    if [ "$az" = "none" ] || [ -z "$az" ]; then
      return 0
    fi
    sleep 10
    waited=$((waited+10))
  done
  return 1
}

echo "[1/7] Enable registry + set modes"
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatch_reg_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatcher_mode_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatcher_auto_approve"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_opportunistic_enabled"}'
api_post "services/input_boolean/turn_off" '{"entity_id":"input_boolean.hc_dispatch_manual_override"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_algorithm","option":"Matrix"}'
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_dispatch_profile","option":"Basement (Z3+Z7+Z9)"}'
api_post "services/input_number/set_value" "{\"entity_id\":\"input_number.hc_dispatch_min_run_minutes\",\"value\":${WAIT_MINUTES}}"

CALLER_CLIMATE_VAR="CLIMATE_MAP_${CALLER_ZONE}"
CALLER_CLIMATE="${!CALLER_CLIMATE_VAR}"

current_temp="$(get_attr "${CALLER_CLIMATE}" "current_temperature")"
if [ -z "$current_temp" ]; then
  current_temp="$(get_attr "${CALLER_CLIMATE}" "temperature")"
fi

TARGET_F=$(python3 - <<PY
ct=float("${current_temp}") if "${current_temp}" not in ["", "null"] else 60.0
print(round(ct + float("${TARGET_DELTA}"), 1))
PY
)

set_caller_temp() {
  api_post "services/climate/set_temperature" \
    "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${TARGET_F}}"
}

echo "[2/7] Create short caller (triggers cooldown) target=${TARGET_F}"
set_caller_temp

if ! wait_for_reg_idle; then
  echo "Cooldown did not expire in ${COOLDOWN_WAIT_SEC}s"
  exit 1
fi

echo "[3/7] Enable dispatcher gate"
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatcher_mode_enabled"}'

for i in $(seq 1 20); do
  sb="$(get_state "sensor.hc_dispatch_reg_suggested_batch")"
  if [ -n "$sb" ] && [ "$sb" != "idle" ] && [ "$sb" != "unknown" ] && [ "$sb" != "unavailable" ] && [ "$sb" != "none" ]; then
    break
  fi
  sleep 2
done

echo "[4/7] Manual approve"
api_post "services/input_button/press" '{"entity_id":"input_button.hc_dispatch_approve_batch"}'

wait_sec=$((WAIT_MINUTES*60))
echo "[5/7] Wait ${WAIT_MINUTES} min for min-run"
sleep "${wait_sec}"

echo "[6/7] Wait for batch to clear"
if ! wait_for_batch_clear; then
  echo "Batch did not clear in ${STOP_WAIT_SEC}s"
  exit 1
fi

echo "[7/7] Snapshot"
api_get "states/input_select.hc_dispatch_reg_state"
echo
api_get "states/input_text.hc_dispatch_reg_active_zones"
echo
api_get "states/input_text.hc_dispatch_reg_active_callers"
echo
api_get "states/sensor.hc_dispatch_reg_suggested_batch"
echo
api_get "states/climate.zone_7_basement_bar_and_tv_room_south_side"
echo
api_get "states/climate.zone_3_basement_bath_and_common"
echo
api_get "states/climate.zone_9_basement_bedroom"
echo
