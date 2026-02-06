#!/usr/bin/env python3
"""
Snapshot selected Home Assistant entity states to JSON.
Usage:
  HC_HA_URL="http://192.168.1.113:8123" HC_HA_TOKEN="..." python3 tools/ha_snapshot.py
Optional:
  HC_HA_ENTITIES=tools/ha_snapshot_entities.txt
  HC_HA_OUT=reports/ha_state_snapshot.json
"""
import datetime
import json
import os
import sys
import urllib.request


def read_entities(path: str) -> list[str]:
    entities: list[str] = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            entities.append(line)
    return entities


def get_state(base: str, token: str, entity_id: str) -> dict:
    req = urllib.request.Request(
        f"{base}/api/states/{entity_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read().decode("utf-8"))


def main() -> int:
    base = os.environ.get("HC_HA_URL", "http://192.168.1.113:8123").rstrip("/")
    token = os.environ.get("HC_HA_TOKEN")
    if not token:
        print("ERROR: HC_HA_TOKEN is not set", file=sys.stderr)
        return 2

    entities_path = os.environ.get("HC_HA_ENTITIES", "tools/ha_snapshot_entities.txt")
    if not os.path.exists(entities_path):
        print(f"ERROR: Entities file not found: {entities_path}", file=sys.stderr)
        return 2

    entities = read_entities(entities_path)
    snapshot = {
        "generated_at": datetime.datetime.utcnow().isoformat() + "Z",
        "base_url": base,
        "entities": {},
    }

    for entity_id in entities:
        try:
            state = get_state(base, token, entity_id)
            attrs = state.get("attributes", {})
            snapshot["entities"][entity_id] = {
                "state": state.get("state"),
                "attributes": attrs,
                "temperature": attrs.get("temperature"),
                "current_temperature": attrs.get("current_temperature"),
            }
        except Exception as exc:
            snapshot["entities"][entity_id] = {"error": str(exc)}

    out_path = os.environ.get("HC_HA_OUT")
    if out_path:
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(snapshot, f, indent=2)
        print(f"Wrote {out_path}")
    else:
        print(json.dumps(snapshot, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
