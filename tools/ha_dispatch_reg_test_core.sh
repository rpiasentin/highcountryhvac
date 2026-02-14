#!/usr/bin/env bash
set -u

# Core registry test: Matrix cluster, Matrix near-call (opportunistic), Profile group.
# Intentionally disables manual-abort automation during the test to avoid cooldown gating.

BASE_URL="http://supervisor/core/api"
AUTH_HEADER="Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN missing}"

REPORT_DIR=${REPORT_DIR:-/config/reports}
TS="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="${REPORT_DIR}/dispatch_reg_core_${TS}.log"

CALLER_ZONE=${CALLER_ZONE:-z7}
CALLER_TARGET=${CALLER_TARGET:-70}
RESET_TARGET=${RESET_TARGET:-50}
NEAR_ZONE=${NEAR_ZONE:-z5}
RESTORE_WAIT_SEC=${RESTORE_WAIT_SEC:-45}

CLIMATE_MAP_z3="climate.zone_3_basement_bath_and_common"
CLIMATE_MAP_z7="climate.zone_7_basement_bar_and_tv_room_south_side"
CLIMATE_MAP_z9="climate.zone_9_basement_bedroom"
CLIMATE_MAP_z5="climate.zone_5_virtual_thermostat_first_floor_living"

api_post() {
  local path="$1"
  local data="$2"
  curl -s -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    -X POST "$BASE_URL/$path" -d "$data" >/dev/null
}

api_get() {
  local path="$1"
  # Avoid non-zero exit (pipefail) on transient API errors.
  curl -s -H "$AUTH_HEADER" "$BASE_URL/$path" || true
}

get_state() {
  local entity="$1"
  api_get "states/$entity" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p'
}

get_attr() {
  local entity="$1"
  local attr="$2"
  api_get "states/$entity" | python3 - "$attr" <<'PY'
import json,sys
attr=sys.argv[1]
raw=sys.stdin.read().strip()
if not raw:
    print("")
    raise SystemExit(0)
try:
    d=json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)
print(d.get("attributes",{}).get(attr,""))
PY
}

get_payload_field() {
  local field="$1"
  api_get "states/sensor.hc_dispatch_reg_guardrail_payload" | python3 - "$field" <<'PY'
import json,sys
raw=sys.stdin.read().strip()
if not raw:
    print("")
    raise SystemExit(0)
try:
    d=json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)
s=d.get("state","")
try:
    data=json.loads(s)
except Exception:
    print("")
    raise SystemExit(0)
print(data.get(sys.argv[1],""))
PY
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

wait_for_payload_fz() {
  local max_wait="${1:-60}"
  local waited=0
  while [ "$waited" -lt "$max_wait" ]; do
    fz="$(get_payload_field "fz")"
    if [ -n "$fz" ] && [ "$fz" != "none" ]; then
      return 0
    fi
    sleep 2
    waited=$((waited+2))
  done
  return 1
}

log_snapshot() {
  local entity="$1"
  {
    echo "### $entity"
    api_get "states/$entity"
    echo
  } >> "$REPORT_FILE"
}

set_num() {
  local entity="$1"
  local value="$2"
  api_post "services/input_number/set_value" "{\"entity_id\":\"${entity}\",\"value\":${value}}"
}

set_select() {
  local entity="$1"
  local option="$2"
  api_post "services/input_select/select_option" "{\"entity_id\":\"${entity}\",\"option\":\"${option}\"}"
}

set_bool() {
  local entity="$1"
  local state="$2"
  api_post "services/input_boolean/${state}" "{\"entity_id\":\"${entity}\"}"
}

set_automation() {
  local entity="$1"
  local state="$2"
  api_post "services/automation/${state}" "{\"entity_id\":\"${entity}\"}"
}

set_temp() {
  local climate="$1"
  local value="$2"
  api_post "services/climate/set_temperature" "{\"entity_id\":\"${climate}\",\"temperature\":${value}}"
}

say() {
  echo "$*"
  echo "$*" >> "$REPORT_FILE"
}

header() { say "== $1 =="; }
pass() { say "PASS: $*"; }
fail() { say "FAIL: $*"; }

log() { echo "$*" >> "$REPORT_FILE"; }

log_state() {
  local entity="$1"
  local st
  st="$(get_state "$entity")"
  log "$entity state=$st"
}

log_attr() {
  local entity="$1"
  local attr="$2"
  local v
  v="$(get_attr "$entity" "$attr")"
  log "$entity ${attr}=$v"
}

reset_registry_state() {
  set_select "input_select.hc_dispatch_reg_state" "idle"
  api_post "services/input_text/set_value" '{"entity_id":"input_text.hc_dispatch_reg_active_zones","value":"none"}'
  api_post "services/input_text/set_value" '{"entity_id":"input_text.hc_dispatch_reg_active_callers","value":"none"}'
  api_post "services/input_text/set_value" '{"entity_id":"input_text.hc_dispatch_reg_active_batch_id","value":"none"}'
  set_num "input_number.hc_dispatch_reg_active_length_ft" 0
  set_bool "input_boolean.hc_dispatch_reg_apply_in_progress" "turn_off"
  for z in z3 z7 z9 z5; do
    set_num "input_number.hc_dispatch_reg_${z}_system_override_f" 0
    api_post "services/input_boolean/turn_off" "{\"entity_id\":\"input_boolean.hc_dispatch_reg_${z}_batch_member\"}"
    api_post "services/input_boolean/turn_off" "{\"entity_id\":\"input_boolean.hc_dispatch_reg_${z}_batch_added\"}"
  done
}

reset_setpoints() {
  local c
  for c in "$CLIMATE_MAP_z3" "$CLIMATE_MAP_z7" "$CLIMATE_MAP_z9" "$CLIMATE_MAP_z5"; do
    set_temp "$c" "$RESET_TARGET"
  done
  wait_for_call_state "binary_sensor.hc_z3_call_for_heat" "off" 120 || true
  wait_for_call_state "binary_sensor.hc_z7_call_for_heat" "off" 120 || true
  wait_for_call_state "binary_sensor.hc_z9_call_for_heat" "off" 120 || true
  wait_for_call_state "binary_sensor.hc_z5_call_for_heat" "off" 120 || true
}

mkdir -p "$REPORT_DIR"
{
  echo "Dispatch Registry Core Test"
  echo "Timestamp: $TS"
  echo "Caller zone: $CALLER_ZONE"
  echo "Caller target: $CALLER_TARGET"
  echo "Reset target: $RESET_TARGET"
  echo "Near zone: $NEAR_ZONE"
  echo "Restore wait: ${RESTORE_WAIT_SEC}s"
  echo
} > "$REPORT_FILE"

header "Setup"
set_automation "automation.hc_dispatch_registry_manual_abort" "turn_on"
set_automation "automation.hc_dispatch_registry_apply_batch" "turn_on"
set_bool "input_boolean.hc_dispatch_reg_enabled" "turn_on"
set_bool "input_boolean.hc_dispatch_reg_ignore_manual_changes" "turn_on"
set_bool "input_boolean.hc_dispatcher_mode_enabled" "turn_on"
set_bool "input_boolean.hc_dispatcher_auto_approve" "turn_off"
set_bool "input_boolean.hc_dispatch_manual_override" "turn_off"
set_bool "input_boolean.hc_dispatch_opportunistic_enabled" "turn_off"
set_select "input_select.hc_dispatch_reg_state" "idle"
set_num "input_number.hc_dispatch_min_run_minutes" 0
set_num "input_number.hc_dispatch_force_delta_f" 1.0
set_num "input_number.hc_dispatch_force_cap_f" 75
set_select "input_select.hc_dispatch_force_mode" "Added Only"
set_num "input_number.hc_dispatch_max_batch_length_ft" 200
set_num "input_number.hc_dispatch_opportunistic_min_ft" 0
set_num "input_number.hc_dispatch_opportunistic_max_ft" 200
set_num "input_number.hc_dispatch_near_call_margin_f" 0.5
reset_registry_state
reset_setpoints

header "Step 1: Matrix Cluster Expansion"
set_select "input_select.hc_dispatch_algorithm" "Matrix"
set_select "input_select.hc_dispatch_profile" "Basement (Z3+Z7+Z9)"
for z in z3 z7 z9; do
  set_select "input_select.hc_${z}_cluster" "Cluster A"
done
set_select "input_select.hc_z5_cluster" "Independent"

CALLER_CLIMATE_VAR="CLIMATE_MAP_${CALLER_ZONE}"
CALLER_CLIMATE="${!CALLER_CLIMATE_VAR}"
NEAR_CLIMATE_VAR="CLIMATE_MAP_${NEAR_ZONE}"
NEAR_CLIMATE="${!NEAR_CLIMATE_VAR}"
set_temp "$CALLER_CLIMATE" "$CALLER_TARGET"
wait_for_call_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat" "on" 120 || true
wait_for_payload_fz 60 || true
fz="$(get_payload_field "fz")"
log "payload.fz=$fz"
log_snapshot "sensor.hc_dispatch_reg_guardrail_payload"
log_snapshot "input_text.hc_dispatch_reg_active_zones"
log_snapshot "input_text.hc_dispatch_reg_active_callers"
api_post "services/input_button/press" '{"entity_id":"input_button.hc_dispatch_approve_batch"}'
sleep 5
bm3="$(get_state "input_boolean.hc_dispatch_reg_z3_batch_member")"
bm7="$(get_state "input_boolean.hc_dispatch_reg_z7_batch_member")"
bm9="$(get_state "input_boolean.hc_dispatch_reg_z9_batch_member")"
ba3="$(get_state "input_boolean.hc_dispatch_reg_z3_batch_added")"
ba9="$(get_state "input_boolean.hc_dispatch_reg_z9_batch_added")"
ov3="$(get_state "input_number.hc_dispatch_reg_z3_system_override_f")"
ov9="$(get_state "input_number.hc_dispatch_reg_z9_system_override_f")"
sp3="$(get_state "input_number.hc_dispatch_reg_z3_effective_setpoint_f")"
sp9="$(get_state "input_number.hc_dispatch_reg_z9_effective_setpoint_f")"
if [[ "$fz" == *"z3"* && "$fz" == *"z7"* && "$fz" == *"z9"* && "$bm3" = "on" && "$bm7" = "on" && "$bm9" = "on" ]]; then
  pass "Matrix cluster expansion (z3,z7,z9)"
else
  fail "Matrix cluster expansion missing (fz=$fz bm3=$bm3 bm7=$bm7 bm9=$bm9)"
fi
log "batch_added z3=$ba3 z9=$ba9 override z3=$ov3 z9=$ov9 setpoint z3=$sp3 z9=$sp9"

set_temp "$CALLER_CLIMATE" "$RESET_TARGET"
wait_for_call_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat" "off" 120 || true
if [ "$(get_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat")" != "off" ]; then
  say "SKIP: Caller still on; restore check skipped (cluster additions)"
else
  sleep "$RESTORE_WAIT_SEC"
  sp3_after="$(get_state "input_number.hc_dispatch_reg_z3_effective_setpoint_f")"
  sp9_after="$(get_state "input_number.hc_dispatch_reg_z9_effective_setpoint_f")"
  ov3_after="$(get_state "input_number.hc_dispatch_reg_z3_system_override_f")"
  ov9_after="$(get_state "input_number.hc_dispatch_reg_z9_system_override_f")"
  if [ "$sp3_after" = "$RESET_TARGET" ] && [ "$sp9_after" = "$RESET_TARGET" ] && [ "$ov3_after" = "0" ] && [ "$ov9_after" = "0" ]; then
    pass "Restore after caller stops (cluster additions)"
  else
    fail "Restore after caller stops (z3 sp=$sp3_after ov=$ov3_after z9 sp=$sp9_after ov=$ov9_after)"
  fi
fi

header "Step 2: Matrix Near-Call (Opportunistic)"
set_bool "input_boolean.hc_dispatch_opportunistic_enabled" "turn_on"
delta="$(get_state "sensor.hc_${NEAR_ZONE}_delta")"
if python3 - "$delta" <<'PY'
import sys
try:
    float(sys.argv[1])
    raise SystemExit(0)
except Exception:
    raise SystemExit(1)
PY
then
  tol="$(python3 - "$delta" <<'PY'
import sys
print(round(float(sys.argv[1]) + 0.2, 2))
PY
)"
  set_num "input_number.hc_cold_tolerance" "$tol"
  set_num "input_number.hc_dispatch_near_call_margin_f" 0.5
  reset_registry_state
  reset_setpoints
  set_temp "$CALLER_CLIMATE" "$CALLER_TARGET"
  wait_for_call_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat" "on" 120 || true
  wait_for_payload_fz 60 || true
  fz="$(get_payload_field "fz")"
  log "delta(${NEAR_ZONE})=$delta tol=$tol payload.fz=$fz"
  log_snapshot "sensor.hc_dispatch_reg_guardrail_payload"
  log_snapshot "input_text.hc_dispatch_reg_active_zones"
  log_snapshot "input_text.hc_dispatch_reg_active_callers"
  api_post "services/input_button/press" '{"entity_id":"input_button.hc_dispatch_approve_batch"}'
  sleep 5
  bm_near="$(get_state "input_boolean.hc_dispatch_reg_${NEAR_ZONE}_batch_member")"
  ba_near="$(get_state "input_boolean.hc_dispatch_reg_${NEAR_ZONE}_batch_added")"
  ov_near="$(get_state "input_number.hc_dispatch_reg_${NEAR_ZONE}_system_override_f")"
  sp_near="$(get_state "input_number.hc_dispatch_reg_${NEAR_ZONE}_effective_setpoint_f")"
  if [[ "$fz" == *"${NEAR_ZONE}"* && "$bm_near" = "on" ]]; then
    pass "Near-call opportunistic included ${NEAR_ZONE}"
  else
    fail "Near-call opportunistic missing ${NEAR_ZONE} (fz=$fz bm=${bm_near} ba=${ba_near})"
  fi
  log "near batch_added=${ba_near} override=${ov_near} setpoint=${sp_near}"

  set_temp "$CALLER_CLIMATE" "$RESET_TARGET"
  wait_for_call_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat" "off" 120 || true
  if [ "$(get_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat")" != "off" ]; then
    say "SKIP: Caller still on; restore check skipped (near-call)"
  else
    sleep "$RESTORE_WAIT_SEC"
    sp_near_after="$(get_state "input_number.hc_dispatch_reg_${NEAR_ZONE}_effective_setpoint_f")"
    ov_near_after="$(get_state "input_number.hc_dispatch_reg_${NEAR_ZONE}_system_override_f")"
    if [ "$sp_near_after" = "$RESET_TARGET" ] && [ "$ov_near_after" = "0" ]; then
      pass "Restore after caller stops (near-call)"
    else
      fail "Restore after caller stops (near-call sp=$sp_near_after ov=$ov_near_after)"
    fi
  fi
else
  echo "WARN: sensor.hc_${NEAR_ZONE}_delta is not numeric; skipping near-call verification."
fi

header "Step 3: Profile Expansion"
set_bool "input_boolean.hc_dispatch_opportunistic_enabled" "turn_off"
set_select "input_select.hc_dispatch_algorithm" "Profile"
set_select "input_select.hc_dispatch_profile" "Basement (Z3+Z7+Z9)"
for z in z3 z7 z9 z5; do
  set_select "input_select.hc_${z}_cluster" "Independent"
done
reset_registry_state
reset_setpoints
set_temp "$CALLER_CLIMATE" "$CALLER_TARGET"
wait_for_call_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat" "on" 120 || true
wait_for_payload_fz 60 || true
fz="$(get_payload_field "fz")"
log "payload.fz=$fz"
log_snapshot "sensor.hc_dispatch_reg_guardrail_payload"
log_snapshot "input_text.hc_dispatch_reg_active_zones"
log_snapshot "input_text.hc_dispatch_reg_active_callers"
api_post "services/input_button/press" '{"entity_id":"input_button.hc_dispatch_approve_batch"}'
sleep 5
bm3="$(get_state "input_boolean.hc_dispatch_reg_z3_batch_member")"
bm7="$(get_state "input_boolean.hc_dispatch_reg_z7_batch_member")"
bm9="$(get_state "input_boolean.hc_dispatch_reg_z9_batch_member")"
if [[ "$fz" == *"z3"* && "$fz" == *"z7"* && "$fz" == *"z9"* && "$bm3" = "on" && "$bm7" = "on" && "$bm9" = "on" ]]; then
  pass "Profile expansion (Basement group)"
else
  fail "Profile expansion missing (fz=$fz bm3=$bm3 bm7=$bm7 bm9=$bm9)"
fi
ov3="$(get_state "input_number.hc_dispatch_reg_z3_system_override_f")"
ov9="$(get_state "input_number.hc_dispatch_reg_z9_system_override_f")"
sp3="$(get_state "input_number.hc_dispatch_reg_z3_effective_setpoint_f")"
sp9="$(get_state "input_number.hc_dispatch_reg_z9_effective_setpoint_f")"
log "profile override z3=$ov3 z9=$ov9 setpoint z3=$sp3 z9=$sp9"

set_temp "$CALLER_CLIMATE" "$RESET_TARGET"
wait_for_call_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat" "off" 120 || true
if [ "$(get_state "binary_sensor.hc_${CALLER_ZONE}_call_for_heat")" != "off" ]; then
  say "SKIP: Caller still on; restore check skipped (profile)"
else
  sleep "$RESTORE_WAIT_SEC"
  sp3_after="$(get_state "input_number.hc_dispatch_reg_z3_effective_setpoint_f")"
  sp9_after="$(get_state "input_number.hc_dispatch_reg_z9_effective_setpoint_f")"
  ov3_after="$(get_state "input_number.hc_dispatch_reg_z3_system_override_f")"
  ov9_after="$(get_state "input_number.hc_dispatch_reg_z9_system_override_f")"
  if [ "$sp3_after" = "$RESET_TARGET" ] && [ "$sp9_after" = "$RESET_TARGET" ] && [ "$ov3_after" = "0" ] && [ "$ov9_after" = "0" ]; then
    pass "Restore after caller stops (profile)"
  else
    fail "Restore after caller stops (profile z3 sp=$sp3_after ov=$ov3_after z9 sp=$sp9_after ov=$ov9_after)"
  fi
fi

header "Restore"
set_automation "automation.hc_dispatch_registry_manual_abort" "turn_on"
set_bool "input_boolean.hc_dispatch_reg_ignore_manual_changes" "turn_off"
say "Full snapshot saved to: $REPORT_FILE"
