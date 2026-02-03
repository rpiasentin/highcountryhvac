import json, pathlib, datetime

ER_PATH = pathlib.Path("/config/.storage/core.entity_registry")
CE_PATH = pathlib.Path("/config/.storage/core.config_entries")

er = json.loads(ER_PATH.read_text())
ce = json.loads(CE_PATH.read_text())

# config_entry_id -> entry
ce_map = {item["entry_id"]: item for item in ce.get("data", {}).get("entries", [])}

rows = []
for e in er.get("data", {}).get("entities", []):
    if e.get("platform") != "generic_thermostat":
        continue

    entry_id = e.get("config_entry_id")
    entry = ce_map.get(entry_id, {})
    data = entry.get("data", {}) if isinstance(entry, dict) else {}

    rows.append({
        "entity_id": e.get("entity_id"),
        "platform": e.get("platform"),
        "name": e.get("name"),
        "original_name": e.get("original_name"),
        "unique_id": e.get("unique_id"),
        "disabled_by": e.get("disabled_by"),
        "config_entry_id": entry_id,

        "entry_domain": entry.get("domain"),
        "entry_title": entry.get("title"),
        "entry_source": entry.get("source"),

        # generic_thermostat config (the stuff we care about)
        "heater": data.get("heater"),
        "sensor": data.get("target_sensor") or data.get("sensor"),
        "ac_mode": data.get("ac_mode"),
        "min_cycle_duration": data.get("min_cycle_duration"),
        "keep_alive": data.get("keep_alive"),
        "cold_tolerance": data.get("cold_tolerance"),
        "hot_tolerance": data.get("hot_tolerance"),
        "target_temp_step": data.get("target_temp_step"),
        "min_temp": data.get("min_temp"),
        "max_temp": data.get("max_temp"),
        "precision": data.get("precision"),
        "initial_hvac_mode": data.get("initial_hvac_mode"),
        "away_temp": data.get("away_temp"),
    })

rows = sorted(rows, key=lambda r: r["entity_id"] or "")

out_json = {
    "generated_at": datetime.datetime.now().isoformat(timespec="seconds"),
    "count": len(rows),
    "thermostats": rows,
}

print(json.dumps(out_json, indent=2))
