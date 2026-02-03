#!/usr/bin/env bash
set -euo pipefail

TS="$(date '+%Y-%m-%d_%H%M%S')"
OUTDIR="/config/support_bundle_${TS}"
mkdir -p "$OUTDIR"

logcmd () {
  local name="$1"; shift
  ( "$@" ) > "$OUTDIR/${name}.txt" 2>&1 || true
}

# Timestamp + basic environment
logcmd date date
logcmd uname uname -a
logcmd ha_cli_version ha --version

# HA/Supervisor/Host/OS state
logcmd core_info ha core info
logcmd supervisor_info ha supervisor info
logcmd host_info ha host info
logcmd os_info ha os info
logcmd network_info ha network info
logcmd resolution_info ha resolution info

# Lists
logcmd addons_list ha addons list
logcmd backups_list ha backups list

# Logs
logcmd core_logs ha core logs
logcmd supervisor_logs ha supervisor logs
logcmd host_logs ha host logs

# Copy persistent HA logs if present
for f in /config/home-assistant.log /config/home-assistant.log.1 /config/home-assistant.log.fault; do
  if [ -f "$f" ]; then
    cp -a "$f" "$OUTDIR/" || true
  fi
done

# Resource snapshots (best effort)
logcmd df_h df -h
logcmd free_h free -h
logcmd top_snapshot sh -c 'top -b -n 1'

# --- Add-on logs (fixed parsing) ---
# We only want the SLUG column from `ha addons list`.
# Format looks like: slug | name | version | state | ...
# So take everything before the first " | ".
ADDON_SLUGS_FILE="$OUTDIR/addon_slugs.txt"
ha addons list 2>/dev/null \
  | sed -e '1d' \
  | sed -E 's/[[:space:]]*\|.*$//' \
  | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
  | grep -vE '^(slug|SlUG|)$' \
  > "$ADDON_SLUGS_FILE" || true

while IFS= read -r slug; do
  [ -z "$slug" ] && continue
  (ha addons logs "$slug" || true) > "$OUTDIR/addon_${slug}_logs.txt" 2>&1 || true
done < "$ADDON_SLUGS_FILE"

TAR="/config/support_bundle_${TS}.tar.gz"
tar -czf "$TAR" -C /config "$(basename "$OUTDIR")"

echo "Created: $TAR"
