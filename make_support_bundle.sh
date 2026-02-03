#!/usr/bin/env bash
set -euo pipefail

TS="$(date '+%Y-%m-%d_%H%M%S')"
OUTDIR="/config/support_bundle_${TS}"
mkdir -p "$OUTDIR"

# Timestamp + basic environment
date > "$OUTDIR/date.txt" 2>&1 || true
uname -a > "$OUTDIR/uname.txt" 2>&1 || true
(ha --version || true) > "$OUTDIR/ha_cli_version.txt" 2>&1 || true

# HA/Supervisor/Host/OS state
(ha core info || true) > "$OUTDIR/core_info.txt" 2>&1 || true
(ha supervisor info || true) > "$OUTDIR/supervisor_info.txt" 2>&1 || true
(ha host info || true) > "$OUTDIR/host_info.txt" 2>&1 || true
(ha os info || true) > "$OUTDIR/os_info.txt" 2>&1 || true
(ha network info || true) > "$OUTDIR/network_info.txt" 2>&1 || true
(ha resolution info || true) > "$OUTDIR/resolution_info.txt" 2>&1 || true

# Lists
(ha addons list || true) > "$OUTDIR/addons_list.txt" 2>&1 || true
(ha backups list || true) > "$OUTDIR/backups_list.txt" 2>&1 || true

# Logs (CLI)
(ha core logs || true) > "$OUTDIR/core_logs.txt" 2>&1 || true
(ha supervisor logs || true) > "$OUTDIR/supervisor_logs.txt" 2>&1 || true
(ha host logs || true) > "$OUTDIR/host_logs.txt" 2>&1 || true

# Copy persistent HA logs if present
for f in /config/home-assistant.log /config/home-assistant.log.1 /config/home-assistant.log.fault; do
  if [ -f "$f" ]; then
    cp -a "$f" "$OUTDIR/" || true
  fi
done

# Resource snapshots (best effort)
(df -h || true) > "$OUTDIR/df_h.txt" 2>&1 || true
(free -h || true) > "$OUTDIR/free_h.txt" 2>&1 || true
(top -b -n 1 || true) > "$OUTDIR/top_snapshot.txt" 2>&1 || true

# Add-on logs (can be big, but very useful)
# This collects logs for every installed add-on.
if command -v awk >/dev/null 2>&1; then
  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    (ha addons logs "$slug" || true) > "$OUTDIR/addon_${slug}_logs.txt" 2>&1 || true
  done < <(ha addons list 2>/dev/null | awk -F'|' 'NR>1 {gsub(/^[ \t]+|[ \t]+$/,"",$1); if($1!="") print $1}')
fi

TAR="/config/support_bundle_${TS}.tar.gz"
tar -czf "$TAR" -C /config "$(basename "$OUTDIR")"

echo "Created: $TAR"
