#!/usr/bin/env python3
"""
Extract a focused entity snapshot from a full Home Assistant states dump.

Usage:
  python3 tools/ha_extract_snapshot.py /path/to/ha_states_all.json

Outputs:
  reports/ha_state_snapshot.json (default)
"""
import json
import os
import sys


def read_entities(path: str) -> list[str]:
    entities: list[str] = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            entities.append(line)
    return entities


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python3 tools/ha_extract_snapshot.py /path/to/ha_states_all.json", file=sys.stderr)
        return 2

    src = sys.argv[1]
    if not os.path.exists(src):
        print(f"ERROR: File not found: {src}", file=sys.stderr)
        return 2

    entities_path = "tools/ha_snapshot_entities.txt"
    if not os.path.exists(entities_path):
        print(f"ERROR: Entities file not found: {entities_path}", file=sys.stderr)
        return 2

    entities = set(read_entities(entities_path))
    with open(src, "r", encoding="utf-8") as f:
        all_states = json.load(f)

    snapshot = {
        "source": os.path.basename(src),
        "entities": {},
    }

    for state in all_states:
        entity_id = state.get("entity_id")
        if entity_id in entities:
            attrs = state.get("attributes", {})
            snapshot["entities"][entity_id] = {
                "state": state.get("state"),
                "attributes": attrs,
                "temperature": attrs.get("temperature"),
                "current_temperature": attrs.get("current_temperature"),
            }

    out_path = "reports/ha_state_snapshot.json"
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(snapshot, f, indent=2)

    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
