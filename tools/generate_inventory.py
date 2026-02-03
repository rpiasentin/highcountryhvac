import csv
import json
import os
from collections import Counter

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
STORAGE_DIR = os.path.join(BASE_DIR, ".storage")
OUT_DIR = os.path.join(BASE_DIR, "inventories")

ENTITY_REGISTRY = os.path.join(STORAGE_DIR, "core.entity_registry")
DEVICE_REGISTRY = os.path.join(STORAGE_DIR, "core.device_registry")
AREA_REGISTRY = os.path.join(STORAGE_DIR, "core.area_registry")
CONFIG_ENTRIES = os.path.join(STORAGE_DIR, "core.config_entries")


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def safe_get(d, *keys, default=None):
    cur = d
    for k in keys:
        if not isinstance(cur, dict) or k not in cur:
            return default
        cur = cur[k]
    return cur


def build_area_map():
    if not os.path.exists(AREA_REGISTRY):
        return {}
    data = load_json(AREA_REGISTRY)
    areas = safe_get(data, "data", "areas", default=[])
    return {a.get("id"): a.get("name") for a in areas}


def build_device_map():
    if not os.path.exists(DEVICE_REGISTRY):
        return {}
    data = load_json(DEVICE_REGISTRY)
    devices = safe_get(data, "data", "devices", default=[])
    out = {}
    for d in devices:
        out[d.get("id")] = {
            "name": d.get("name_by_user") or d.get("name"),
            "name_by_user": d.get("name_by_user"),
            "name_original": d.get("name"),
            "manufacturer": d.get("manufacturer"),
            "model": d.get("model"),
            "sw_version": d.get("sw_version"),
            "hw_version": d.get("hw_version"),
            "via_device_id": d.get("via_device_id"),
            "identifiers": d.get("identifiers"),
        }
    return out


def build_config_entry_map():
    if not os.path.exists(CONFIG_ENTRIES):
        return {}
    data = load_json(CONFIG_ENTRIES)
    entries = safe_get(data, "data", "entries", default=[])
    out = {}
    for e in entries:
        out[e.get("entry_id")] = {
            "domain": e.get("domain"),
            "title": e.get("title"),
            "source": e.get("source"),
            "disabled_by": e.get("disabled_by"),
        }
    return out


def generate_entity_inventory():
    if not os.path.exists(ENTITY_REGISTRY):
        raise FileNotFoundError(f"Missing entity registry: {ENTITY_REGISTRY}")

    areas = build_area_map()
    devices = build_device_map()
    config_entries = build_config_entry_map()

    data = load_json(ENTITY_REGISTRY)
    entities = safe_get(data, "data", "entities", default=[])

    rows = []
    domain_counts = Counter()
    integration_counts = Counter()

    for e in entities:
        entity_id = e.get("entity_id")
        domain = entity_id.split(".")[0] if entity_id else None
        domain_counts[domain] += 1

        area_name = areas.get(e.get("area_id"))
        device = devices.get(e.get("device_id"), {}) if e.get("device_id") else {}
        entry = config_entries.get(e.get("config_entry_id"), {}) if e.get("config_entry_id") else {}
        integration = entry.get("domain")
        if integration:
            integration_counts[integration] += 1

        rows.append({
            "entity_id": entity_id,
            "domain": domain,
            "name": e.get("name"),
            "original_name": e.get("original_name"),
            "platform": e.get("platform"),
            "area": area_name,
            "device_name": device.get("name"),
            "device_manufacturer": device.get("manufacturer"),
            "device_model": device.get("model"),
            "integration_domain": integration,
            "integration_title": entry.get("title"),
            "integration_source": entry.get("source"),
            "disabled_by": e.get("disabled_by"),
            "hidden_by": e.get("hidden_by"),
            "entity_category": e.get("entity_category"),
            "unique_id": e.get("unique_id"),
        })

    return rows, domain_counts, integration_counts


def generate_device_inventory():
    if not os.path.exists(DEVICE_REGISTRY):
        return []
    data = load_json(DEVICE_REGISTRY)
    devices = safe_get(data, "data", "devices", default=[])

    rows = []
    for d in devices:
        rows.append({
            "device_id": d.get("id"),
            "name": d.get("name_by_user") or d.get("name"),
            "name_by_user": d.get("name_by_user"),
            "name_original": d.get("name"),
            "manufacturer": d.get("manufacturer"),
            "model": d.get("model"),
            "sw_version": d.get("sw_version"),
            "hw_version": d.get("hw_version"),
            "via_device_id": d.get("via_device_id"),
            "identifiers": d.get("identifiers"),
            "config_entries": d.get("config_entries"),
            "disabled_by": d.get("disabled_by"),
        })
    return rows


def generate_area_inventory():
    if not os.path.exists(AREA_REGISTRY):
        return []
    data = load_json(AREA_REGISTRY)
    areas = safe_get(data, "data", "areas", default=[])

    rows = []
    for a in areas:
        rows.append({
            "area_id": a.get("id"),
            "name": a.get("name"),
            "aliases": a.get("aliases"),
            "icon": a.get("icon"),
            "picture": a.get("picture"),
        })
    return rows


def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_summary(path, entity_count, domain_counts, integration_counts, device_count, area_count):
    lines = []
    lines.append("# Home Assistant Inventory Summary")
    lines.append("")
    lines.append(f"Entities: {entity_count}")
    lines.append(f"Devices: {device_count}")
    lines.append(f"Areas: {area_count}")
    lines.append("")
    lines.append("## Entities by Domain")
    for domain, count in domain_counts.most_common():
        lines.append(f"- {domain}: {count}")
    lines.append("")
    lines.append("## Entities by Integration (Config Entries)")
    for domain, count in integration_counts.most_common():
        lines.append(f"- {domain}: {count}")
    lines.append("")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    entity_rows, domain_counts, integration_counts = generate_entity_inventory()
    device_rows = generate_device_inventory()
    area_rows = generate_area_inventory()

    entity_csv = os.path.join(OUT_DIR, "entity_inventory.csv")
    device_csv = os.path.join(OUT_DIR, "device_inventory.csv")
    area_csv = os.path.join(OUT_DIR, "area_inventory.csv")
    summary_md = os.path.join(OUT_DIR, "inventory_summary.md")

    if entity_rows:
        write_csv(entity_csv, entity_rows, list(entity_rows[0].keys()))
    if device_rows:
        write_csv(device_csv, device_rows, list(device_rows[0].keys()))
    if area_rows:
        write_csv(area_csv, area_rows, list(area_rows[0].keys()))

    write_summary(
        summary_md,
        entity_count=len(entity_rows),
        domain_counts=domain_counts,
        integration_counts=integration_counts,
        device_count=len(device_rows),
        area_count=len(area_rows),
    )

    print(f"Wrote: {entity_csv}")
    print(f"Wrote: {device_csv}")
    print(f"Wrote: {area_csv}")
    print(f"Wrote: {summary_md}")


if __name__ == "__main__":
    main()
