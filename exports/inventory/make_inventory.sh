#!/bin/sh
set -eu

TS="$(date +%F_%H%M%S)"
OUT="/config/exports/inventory/hc_inventory_${TS}"
mkdir -p "$OUT"

echo "== Basic HA CLI info =="
ha core info > "$OUT/ha_core_info.txt" 2>&1 || true
ha supervisor info > "$OUT/ha_supervisor_info.txt" 2>&1 || true
ha os info > "$OUT/ha_os_info.txt" 2>&1 || true
ha host info > "$OUT/ha_host_info.txt" 2>&1 || true
ha addons list > "$OUT/ha_addons_list.txt" 2>&1 || true

echo "== Config file inventory =="
cp -a /config/configuration.yaml "$OUT/" 2>/dev/null || true
cp -a /config/automations.yaml "$OUT/" 2>/dev/null || true
cp -a /config/scripts.yaml "$OUT/" 2>/dev/null || true
cp -a /config/scenes.yaml "$OUT/" 2>/dev/null || true
cp -a /config/groups.yaml "$OUT/" 2>/dev/null || true
cp -a /config/templates.yaml "$OUT/" 2>/dev/null || true

# Lovelace YAML dashboards (if any)
ls -la /config | sed -n '1,200p' > "$OUT/config_dir_listing.txt"
cp -a /config/ui-lovelace.yaml "$OUT/" 2>/dev/null || true
cp -a /config/lovelace*.yaml "$OUT/" 2>/dev/null || true

echo "== .storage (registries, dashboards, automations if stored there) =="
mkdir -p "$OUT/storage"
cp -a /config/.storage/core.entity_registry "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/core.device_registry "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/core.area_registry "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/core.config_entries "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/lovelace* "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/automation* "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/script* "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/scene* "$OUT/storage/" 2>/dev/null || true

echo "== Custom components + HACS storage (no secrets) =="
mkdir -p "$OUT/custom"
cp -a /config/custom_components "$OUT/custom/" 2>/dev/null || true
cp -a /config/.storage/hacs "$OUT/storage/" 2>/dev/null || true

echo "== Entity states dump (API) =="
# Uses Supervisor token available in HAOS / add-on environment
if [ -n "${SUPERVISOR_TOKEN:-}" ]; then
  curl -sS -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
    http://supervisor/core/api/states > "$OUT/all_states.json" || true
else
  echo "SUPERVISOR_TOKEN not set; skipping /api/states dump" > "$OUT/all_states_error.txt"
fi

echo "== Focused hydronic filters (quick grep helpers) =="
# These help me jump straight to your hydronic entities fast
if [ -f "$OUT/all_states.json" ]; then
  python3 - <<'PY' "$OUT/all_states.json" "$OUT/hydronic_entities.txt" 2>/dev/null || true
import json, sys
src, out = sys.argv[1], sys.argv[2]
data = json.load(open(src))
keep = []
for e in data:
    eid = e.get("entity_id","")
    if eid.startswith(("climate.zone_","switch.z","sensor.hc_","binary_sensor.hc_","input_","timer.hc_")):
        keep.append(eid)
open(out,"w").write("\n".join(sorted(set(keep)))+"\n")
PY
fi

echo "== Redact secrets (best effort) =="
# Do NOT copy secrets.yaml by default
# If it already got included, remove it
rm -f "$OUT/secrets.yaml" 2>/dev/null || true

echo "== Create tarball =="
TAR="/config/exports/hc_inventory_${TS}.tgz"
tar -czf "$TAR" -C "$OUT" .
echo "$TAR"
