#!/usr/bin/env bash
set -euo pipefail

TS="$(date '+%Y-%m-%d_%H%M%S')"
OUT="/config/backup_trigger_evidence_${TS}"
mkdir -p "$OUT"

echo "Writing to: $OUT"

# 1) Capture the canonical lists
ha addons list > "$OUT/addons_list.yaml" 2>&1 || true
ha backups list > "$OUT/backups_list.yaml" 2>&1 || true
ha supervisor info > "$OUT/supervisor_info.txt" 2>&1 || true
ha core info > "$OUT/core_info.txt" 2>&1 || true

# 2) Extract add-on slugs safely by parsing YAML (no column parsing issues)
python3 - <<'PY' "$OUT/addons_list.yaml" "$OUT/addon_slugs.txt"
import sys, yaml
src, dst = sys.argv[1], sys.argv[2]
data = yaml.safe_load(open(src, "r", encoding="utf-8", errors="replace"))
slugs = [a.get("slug") for a in (data.get("addons") or []) if a.get("slug")]
with open(dst, "w") as f:
    f.write("\n".join(slugs) + "\n")
print(f"Slugs: {slugs}")
PY

# 3) Pull logs for each add-on
while IFS= read -r slug; do
  [ -z "$slug" ] && continue
  echo "Collecting logs for add-on: $slug"
  ha addons logs "$slug" > "$OUT/addon_${slug}_logs.txt" 2>&1 || true
done < "$OUT/addon_slugs.txt"

# 4) Supervisor logs (CLI) + filter for backup/freeze/thaw
ha supervisor logs > "$OUT/supervisor_logs_full.txt" 2>&1 || true

# Keep a small focused file we can scan quickly
grep -E "supervisor\.backups|Freeze starting stage|Thaw starting stage|Creating new .* backup|Backup [a-f0-9]{8}" \
  "$OUT/supervisor_logs_full.txt" > "$OUT/supervisor_backup_activity_filtered.txt" 2>&1 || true

# 5) Create a "backup frequency report" from backups_list.yaml
python3 - <<'PY' "$OUT/backups_list.yaml" "$OUT/backups_frequency_report.txt"
import sys, yaml
from datetime import datetime
src, dst = sys.argv[1], sys.argv[2]
data = yaml.safe_load(open(src, "r", encoding="utf-8", errors="replace")) or {}
bks = data.get("backups") or []

def parse_dt(s):
    # Example: 2026-01-11T11:53:43.007018+00:00
    return datetime.fromisoformat(s.replace("Z","+00:00"))

rows = []
for b in bks:
    try:
        rows.append((parse_dt(b["date"]), b.get("slug"), b.get("type"), b.get("name")))
    except Exception:
        pass

rows.sort()
with open(dst, "w") as f:
    f.write(f"Total backups listed: {len(rows)}\n\n")
    for i,(t,slug,typ,name) in enumerate(rows):
        f.write(f"{t.isoformat()}  slug={slug}  type={typ}  name={name}\n")
        if i > 0:
            dt_min = (t - rows[i-1][0]).total_seconds()/60
            f.write(f"  Δ from previous: {dt_min:.2f} minutes\n")
PY

# 6) Search config for ANY backup/snapshot service triggers (automations/scripts/packages)
# BusyBox grep supports -R -n -E; avoid GNU-only flags.
TARGETS=(
  "/config/automations.yaml"
  "/config/scripts.yaml"
  "/config/configuration.yaml"
  "/config/packages"
)

PATTERN='backup|snapshot|hassio\.backup|hassio\.snapshot|backup\.create|/backups/new|ha backups|supervisor/backups'

for t in "${TARGETS[@]}"; do
  if [ -e "$t" ]; then
    echo "Searching: $t"
    grep -RInE "$PATTERN" "$t" >> "$OUT/config_backup_trigger_refs.txt" 2>/dev/null || true
  fi
done

# 7) Search .storage for automations/scripts that call backup services
# (This is where UI-created automations live.)
if [ -d /config/.storage ]; then
  find /config/.storage -maxdepth 1 -type f \( -name "automation*" -o -name "script*" -o -name "core.config_entries" -o -name "hassio*" \) \
    -print > "$OUT/storage_files_scanned.txt" 2>/dev/null || true

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    grep -nE "$PATTERN" "$f" >> "$OUT/storage_backup_trigger_refs.txt" 2>/dev/null || true
  done < "$OUT/storage_files_scanned.txt"
fi

# 8) Bundle it
TAR="/config/backup_trigger_evidence_${TS}.tar.gz"
tar -czf "$TAR" -C /config "$(basename "$OUT")"
echo "Created: $TAR"
