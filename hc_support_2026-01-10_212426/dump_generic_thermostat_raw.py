import json, pathlib, datetime

ER_PATH = pathlib.Path("/config/.storage/core.entity_registry")
CE_PATH = pathlib.Path("/config/.storage/core.config_entries")

er = json.loads(ER_PATH.read_text())
ce = json.loads(CE_PATH.read_text())

# Map entry_id -> full entry record
entries = {e["entry_id"]: e for e in ce.get("data", {}).get("entries", [])}

# Find all entity_registry items that are generic_thermostat climates
gt_entities = [
    e for e in er.get("data", {}).get("entities", [])
    if e.get("platform") == "generic_thermostat" and (e.get("entity_id","").startswith("climate."))
]

out = {
    "generated_at": datetime.datetime.now().isoformat(timespec="seconds"),
    "count": len(gt_entities),
    "items": []
}

for ent in sorted(gt_entities, key=lambda x: x["entity_id"]):
    entry_id = ent.get("config_entry_id")
    entry = entries.get(entry_id, {})
    out["items"].append({
        "climate_entity_id": ent.get("entity_id"),
        "original_name": ent.get("original_name"),
        "config_entry_id": entry_id,
        "config_entry_domain": entry.get("domain"),
        "config_entry_title": entry.get("title"),

        # IMPORTANT: capture BOTH data and options as stored
        "data": entry.get("data", {}),
        "options": entry.get("options", {}),
    })

print(json.dumps(out, indent=2))
