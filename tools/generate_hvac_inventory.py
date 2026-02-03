import csv
import json
import os
import re
from collections import Counter

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
STORAGE_DIR = os.path.join(BASE_DIR, ".storage")
OUT_DIR = os.path.join(BASE_DIR, "inventories")
ENTITY_REGISTRY = os.path.join(STORAGE_DIR, "core.entity_registry")

STRICT_PATTERNS = [
    ("domain:climate", re.compile(r"^climate\.")),
    ("contains:hc_", re.compile(r"\.hc_")),
    ("switch:z1-9", re.compile(r"^switch\.z[1-9]$")),
]

EXTENDED_KEYWORDS = [
    "hvac", "hydronic", "boiler", "radiant", "thermostat", "heat", "heating",
    "setpoint", "cold_tolerance", "dispatch", "minisplit", "zone_",
]


def load_entity_registry():
    with open(ENTITY_REGISTRY, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data.get("data", {}).get("entities", [])


def classify(entity_id: str):
    reasons = []
    for label, pattern in STRICT_PATTERNS:
        if pattern.search(entity_id):
            reasons.append(label)
    extended = any(k in entity_id for k in EXTENDED_KEYWORDS)
    if extended and "extended:keyword" not in reasons:
        reasons.append("extended:keyword")
    return reasons


def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    entities = load_entity_registry()

    strict_rows = []
    extended_rows = []
    strict_domains = Counter()
    extended_domains = Counter()

    for e in entities:
        entity_id = e.get("entity_id")
        if not entity_id:
            continue
        reasons = classify(entity_id)
        if not reasons:
            continue

        domain = entity_id.split(".")[0]
        row = {
            "entity_id": entity_id,
            "domain": domain,
            "name": e.get("name"),
            "original_name": e.get("original_name"),
            "platform": e.get("platform"),
            "reason": ";".join(reasons),
        }

        is_strict = any(r.startswith("domain:climate") or r.startswith("contains:hc_") or r.startswith("switch:z1-9") for r in reasons)
        if is_strict:
            strict_rows.append(row)
            strict_domains[domain] += 1

        # Extended includes all strict + keyword hits
        extended_rows.append(row)
        extended_domains[domain] += 1

    strict_csv = os.path.join(OUT_DIR, "hvac_entity_inventory.csv")
    extended_csv = os.path.join(OUT_DIR, "hvac_entity_inventory_extended.csv")

    if strict_rows:
        write_csv(strict_csv, strict_rows, list(strict_rows[0].keys()))
    if extended_rows:
        write_csv(extended_csv, extended_rows, list(extended_rows[0].keys()))

    # Write a small summary
    summary_path = os.path.join(OUT_DIR, "hvac_inventory_summary.md")
    lines = ["# HVAC Inventory Summary", ""]
    lines.append(f"Strict entities: {len(strict_rows)}")
    lines.append(f"Extended entities: {len(extended_rows)}")
    lines.append("")
    lines.append("## Strict Entities by Domain")
    for d, c in strict_domains.most_common():
        lines.append(f"- {d}: {c}")
    lines.append("")
    lines.append("## Extended Entities by Domain")
    for d, c in extended_domains.most_common():
        lines.append(f"- {d}: {c}")
    lines.append("")

    with open(summary_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"Wrote: {strict_csv}")
    print(f"Wrote: {extended_csv}")
    print(f"Wrote: {summary_path}")


if __name__ == "__main__":
    main()
