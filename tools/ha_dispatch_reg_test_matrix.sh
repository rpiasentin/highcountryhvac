#!/usr/bin/env bash
set -euo pipefail

# Registry-mode Matrix test.
# NOTE: Manual setpoint changes trigger global abort + cooldown in registry mode.
# This script waits for cooldown before enabling dispatcher.

BASE_URL="http://supervisor/core/api"
AUTH_HEADER="Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN missing}"

TARGET_F=${TARGET_F:-70}
CALLER_ZONE=${CALLER_ZONE:-z7}
BASE_ZONES=("z3" "z7" "z9")
COOLDOWN_WAIT_SEC=${COOLDOWN_WAIT_SEC:-360}
RESTORE_CALLER=${RESTORE_CALLER:-0}
REPORT_DIR=${REPORT_DIR:-/config/reports}
TS="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="${REPORT_DIR}/dispatch_reg_matrix_${TS}.log"

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

assert_not_unavailable() {
  local entity="$1"
  local st
  st="$(get_state "$entity")"
  if [ "$st" = "unavailable" ] || [ -z "$st" ]; then
    echo "ERROR: ${entity} is unavailable. Fix config/reload before testing."
    exit 1
  fi
}

wait_for_call_state() {
  local entity="$1"
  local target="$2"
  local max_wait="${3:-120}"
  local waited=0
  while [ "$waited" -lt "$max_wait" ]; do
    st="$(get_state "$entity")"
    if [ "$st" = "$target" ]; then
      return 0
    fi
    sleep 2
    waited=$((waited+2))
  done
  return 1
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

wait_for_reg_state() {
  local target="$1"
  local max_wait="${2:-60}"
  local waited=0
  while [ "$waited" -lt "$max_wait" ]; do
    st="$(get_state "input_select.hc_dispatch_reg_state")"
    if [ "$st" = "$target" ]; then
      return 0
    fi
    sleep 2
    waited=$((waited+2))
  done
  return 1
}

write_snapshot() {
  local path="$1"
  {
    echo "### $path"
    api_get "states/$path"
    echo
  } >> "$REPORT_FILE"
}

short_state() {
  local entity="$1"
  local st
  st="$(get_state "$entity")"
  printf "%-55s %s\n" "$entity" "$st"
}

assert_state() {
  local entity="$1"
  local expected="$2"
  local st
  st="$(get_state "$entity")"
  if [ "$st" != "$expected" ]; then
    echo "ERROR: ${entity} expected ${expected}, got ${st}"
    exit 1
  fi
}

extract_guardrail_template() {
  awk '
    /name: "HC Dispatch Reg Guardrail Payload"/ {in=1}
    in && /state: >/ {state=1; next}
    state {
      if ($0 ~ /^        attributes:/) {exit}
      sub(/^          /,"")
      print
    }
  ' /config/packages/hc_dispatcher_registry_guardrail.yaml
}

diag_guardrail_template() {
  local tmpl_file="${REPORT_DIR}/guardrail_template_${TS}.j2"
  local json_file="${REPORT_DIR}/guardrail_template_${TS}.json"
  local resp_file="${REPORT_DIR}/guardrail_template_${TS}.out"
  extract_guardrail_template > "$tmpl_file"
  python3 - <<'PY' "$tmpl_file" "$json_file"
import json,sys
tmpl=open(sys.argv[1]).read()
open(sys.argv[2],'w').write(json.dumps({"template": tmpl}))
PY
  curl -s -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    -X POST "$BASE_URL/template" -d @"$json_file" > "$resp_file"
  echo "Guardrail template eval saved to: $resp_file"
}

echo "[1/6] Disable registry + dispatcher, set modes (avoids manual-abort during config)"
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
for z in z3 z7 z9; do
  api_post "services/input_select/select_option" "{\"entity_id\":\"input_select.hc_${z}_cluster\",\"option\":\"Cluster A\"}"
done
api_post "services/input_select/select_option" '{"entity_id":"input_select.hc_z5_cluster","option":"Independent"}'
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatch_reg_enabled"}'

assert_not_unavailable "automation.hc_dispatch_registry_apply_batch"
assert_state "input_boolean.hc_dispatch_reg_enabled" "on"
mkdir -p "$REPORT_DIR"
{
  echo "Dispatch Registry Matrix Test"
  echo "Timestamp: $TS"
  echo "Caller zone: $CALLER_ZONE"
  echo "Target temp: $TARGET_F"
  echo
} > "$REPORT_FILE"

echo "[2/6] Create a caller by setting thermostat (will trigger cooldown)"
CALLER_CLIMATE_VAR="CLIMATE_MAP_${CALLER_ZONE}"
CALLER_CLIMATE="${!CALLER_CLIMATE_VAR}"
CALLER_BASELINE="$(get_attr_temperature "${CALLER_CLIMATE}")"
CALLER_CURRENT="$(get_attr_temperature "${CALLER_CLIMATE}")"
LOW_F="$(awk -v curr="${CALLER_CURRENT:-0}" 'BEGIN{low=curr-5; if(low<55) low=55; printf "%.1f", low}')"
echo "  - step: drop setpoint to ${LOW_F} to clear call (if any)"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${LOW_F}}"
wait_for_call_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat" "off" 90 || echo "  - warning: call did not clear in 90s"
echo "  - step: raise setpoint to ${TARGET_F} to create call"
api_post "services/climate/set_temperature" \
  "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${TARGET_F}}"
wait_for_call_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat" "on" 90 || echo "  - warning: call did not start in 90s"

echo "[3/6] Wait for cooldown to start"
wait_for_reg_state "cooldown" 60 || echo "Cooldown did not start within 60s (continuing)"

echo "[3.5/6] Wait for cooldown to expire"
if ! wait_for_reg_idle; then
  echo "Cooldown did not expire in ${COOLDOWN_WAIT_SEC}s"
  exit 1
fi

echo "[4/6] Enable dispatcher gate (after cooldown)"
api_post "services/input_boolean/turn_on" '{"entity_id":"input_boolean.hc_dispatcher_mode_enabled"}'

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
for entity in \
  sensor.hc_dispatch_reg_suggested_batch \
  sensor.hc_dispatch_reg_guardrail_payload \
  sensor.hc_dispatch_reg_guardrail \
  input_boolean.hc_dispatch_reg_enabled \
  input_boolean.hc_dispatcher_mode_enabled \
  input_text.hc_dispatch_reg_active_zones \
  input_text.hc_dispatch_reg_active_callers \
  input_select.hc_dispatch_reg_state \
  input_datetime.hc_dispatch_reg_cooldown_until \
  input_text.hc_dispatch_reg_manual_change_entity \
  input_select.hc_dispatch_reg_manual_change_type \
  input_datetime.hc_dispatch_reg_manual_change_at \
  automation.hc_dispatch_registry_apply_batch \
  binary_sensor.hc_${CALLER_ZONE}_call_for_heat \
  input_boolean.hc_dispatch_reg_${CALLER_ZONE}_calling \
  climate.zone_7_basement_bar_and_tv_room_south_side \
  climate.zone_3_basement_bath_and_common \
  climate.zone_9_basement_bedroom; do
  write_snapshot "$entity"
done

echo "Summary:"
short_state "input_select.hc_dispatch_reg_state"
short_state "input_boolean.hc_dispatch_reg_enabled"
short_state "input_boolean.hc_dispatcher_mode_enabled"
short_state "input_text.hc_dispatch_reg_manual_change_entity"
short_state "input_select.hc_dispatch_reg_manual_change_type"
short_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat"
short_state "input_boolean.hc_dispatch_reg_${CALLER_ZONE}_calling"
short_state "automation.hc_dispatch_registry_apply_batch"
echo "Full snapshot saved to: $REPORT_FILE"

if [ "$(get_state "sensor.hc_dispatch_reg_guardrail_payload")" = "unknown" ]; then
  echo "Guardrail payload is unknown; running template eval..."
  diag_guardrail_template
fi

if [ "${RESTORE_CALLER}" = "1" ] && [ -n "${CALLER_BASELINE}" ]; then
  echo "[restore] Reset caller zone setpoint to baseline (${CALLER_BASELINE})"
  api_post "services/climate/set_temperature" \
    "{\"entity_id\":\"${CALLER_CLIMATE}\",\"temperature\":${CALLER_BASELINE}}"
fi
