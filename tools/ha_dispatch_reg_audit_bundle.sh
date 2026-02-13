#!/usr/bin/env bash
set -euo pipefail

# Dispatcher registry audit bundle.
# Creates a timestamped tarball under /config/reports with filtered HA states
# and relevant config snapshots for offline review.

BASE_URL="${BASE_URL:-http://supervisor/core/api}"
AUTH_HEADER="Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN missing}"
TS="$(date +%Y%m%d_%H%M%S)"
OUTDIR="/config/reports/dispatch_reg_audit_${TS}"
TARBALL="/config/reports/dispatch_reg_audit_${TS}.tar.gz"

mkdir -p "$OUTDIR"

echo "[1/5] Fetch HA states"
curl -s -H "$AUTH_HEADER" "$BASE_URL/states" > "$OUTDIR/all_states.json"

echo "[2/5] Filter relevant entities"
python3 - <<'PY' "$OUTDIR"
import json,sys,re
outdir=sys.argv[1]
states=json.load(open(f"{outdir}/all_states.json","r"))

patterns = [
    r"^input_boolean\.hc_dispatch",
    r"^input_select\.hc_dispatch",
    r"^input_text\.hc_dispatch",
    r"^input_number\.hc_dispatch",
    r"^input_datetime\.hc_dispatch",
    r"^sensor\.hc_dispatch",
    r"^automation\.hc_dispatch",
    r"^input_boolean\.hc_disp_",
    r"^input_number\.hc_disp_",
    r"^input_select\.hc_z[1-9]_cluster$",
    r"^input_number\.hc_z[1-9]_length_feet$",
    r"^binary_sensor\.hc_z[1-9]_call_for_heat$",
    r"^sensor\.hc_z[1-9]_delta$",
    r"^climate\.zone_[1-9]_",
    r"^climate\.z1_",
    r"^binary_sensor\.system_control_active$",
]

compiled=[re.compile(p) for p in patterns]
def match(eid):
    return any(c.search(eid) for c in compiled)

filtered=[s for s in states if match(s.get("entity_id",""))]

with open(f"{outdir}/filtered_states.json","w") as f:
    json.dump(filtered,f,indent=2,sort_keys=True)

def summarize_state(s):
    eid=s.get("entity_id","")
    st=s.get("state","")
    attrs=s.get("attributes",{}) or {}
    if eid.startswith("climate."):
        parts=[
            f"temp={attrs.get('temperature')}",
            f"current={attrs.get('current_temperature')}",
            f"action={attrs.get('hvac_action')}",
            f"mode={s.get('state')}",
        ]
        return " ".join(parts)
    if eid.startswith("input_number.") or eid.startswith("input_text.") or eid.startswith("input_select.") or eid.startswith("input_boolean."):
        return f"state={st}"
    if eid.startswith("sensor."):
        return f"state={st}"
    if eid.startswith("binary_sensor."):
        return f"state={st}"
    return f"state={st}"

with open(f"{outdir}/summary.txt","w") as f:
    for s in sorted(filtered, key=lambda x: x.get("entity_id","")):
        eid=s.get("entity_id","")
        f.write(f"{eid} :: {summarize_state(s)}\n")
PY

echo "[3/5] Capture config snapshots"
mkdir -p "$OUTDIR/config"
for f in /config/packages/hc_dispatcher_registry*.yaml; do
  [ -f "$f" ] && cp "$f" "$OUTDIR/config/"
done
for f in /config/hc_tools/ha_dispatch_reg_test_*.sh; do
  [ -f "$f" ] && cp "$f" "$OUTDIR/config/"
done
[ -f /config/lovelace/hc_zone_setup.yaml ] && cp /config/lovelace/hc_zone_setup.yaml "$OUTDIR/config/"

echo "[4/5] Write metadata"
python3 - <<'PY' "$OUTDIR"
import json,sys,hashlib,glob,os
outdir=sys.argv[1]
meta={
  "timestamp": os.path.basename(outdir).replace("dispatch_reg_audit_",""),
  "files": {},
}
for path in glob.glob(outdir + "/config/*"):
  h=hashlib.sha256()
  with open(path,"rb") as f:
    while True:
      b=f.read(8192)
      if not b: break
      h.update(b)
  meta["files"][os.path.basename(path)] = h.hexdigest()
with open(outdir + "/meta.json","w") as f:
  json.dump(meta,f,indent=2,sort_keys=True)
PY

echo "[5/5] Create tarball"
tar -C "$OUTDIR" -czf "$TARBALL" .

echo "Audit bundle created: $TARBALL"
