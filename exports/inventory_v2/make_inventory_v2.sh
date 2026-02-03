#!/bin/sh
set -eu

TS="$(date +%F_%H%M%S)"
OUT="/config/exports/inventory_v2/hc_inventory_v2_${TS}"
mkdir -p "$OUT"

# Core info
ha core info > "$OUT/ha_core_info.txt" 2>&1 || true
ha supervisor info > "$OUT/ha_supervisor_info.txt" 2>&1 || true
ha os info > "$OUT/ha_os_info.txt" 2>&1 || true
ha host info > "$OUT/ha_host_info.txt" 2>&1 || true
ha addons list > "$OUT/ha_addons_list.txt" 2>&1 || true

# Primary YAMLs
cp -a /config/configuration.yaml "$OUT/" 2>/dev/null || true
cp -a /config/automations.yaml "$OUT/" 2>/dev/null || true
cp -a /config/scripts.yaml "$OUT/" 2>/dev/null || true
cp -a /config/scenes.yaml "$OUT/" 2>/dev/null || true
cp -a /config/templates.yaml "$OUT/" 2>/dev/null || true

# INCLUDE packages + dashboards (this is what we need)
cp -a /config/packages "$OUT/" 2>/dev/null || true
cp -a /config/dashboards "$OUT/" 2>/dev/null || true
cp -a /config/high-country-hvac.yaml "$OUT/" 2>/dev/null || true
cp -a /config/dashboards/hc_hvac_admin_verify.yaml "$OUT/" 2>/dev/null || true

# .storage (targeted)
mkdir -p "$OUT/storage"
cp -a /config/.storage/core.entity_registry "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/core.device_registry "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/core.area_registry "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/core.config_entries "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/lovelace* "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/automation* "$OUT/storage/" 2>/dev/null || true
cp -a /config/.storage/script* "$OUT/storage/" 2>/dev/null || true

# States dump
if [ -n "${SUPERVISOR_TOKEN:-}" ]; then
  curl -sS -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
    http://supervisor/core/api/states > "$OUT/all_states.json" || true
fi

# Explicitly exclude secrets
rm -f "$OUT/secrets.yaml" 2>/dev/null || true

# Tarball
TAR="/config/exports/hc_inventory_v2_${TS}.tgz"
tar -czf "$TAR" -C "$OUT" .
echo "$TAR"
