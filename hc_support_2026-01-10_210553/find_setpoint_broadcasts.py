import json, pathlib, re

paths = [
    pathlib.Path("/config/.storage/automations"),
    pathlib.Path("/config/.storage/scripts"),
]

def walk(obj, needle):
    """Return True if needle string appears anywhere in obj (deep)."""
    if isinstance(obj, dict):
        return any(walk(v, needle) for v in obj.values())
    if isinstance(obj, list):
        return any(walk(v, needle) for v in obj)
    if isinstance(obj, str):
        return needle in obj
    return False

hits = []

for p in paths:
    if not p.exists():
        continue
    data = json.loads(p.read_text())
    items = data.get("data", {}).get("items", [])
    for it in items:
        if walk(it, "climate.set_temperature") or walk(it, "climate.set_hvac_mode"):
            hits.append({
                "source": p.name,
                "id": it.get("id"),
                "alias": it.get("alias") or it.get("name"),
                "description": it.get("description"),
                "item": it,
            })

out = {"count": len(hits), "hits": hits}
print(json.dumps(out, indent=2))
