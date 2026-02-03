import json, pathlib

def load(p):
    try:
        return json.loads(pathlib.Path(p).read_text())
    except Exception:
        return None

def contains(obj, needle):
    if isinstance(obj, dict):
        return any(contains(v, needle) for v in obj.values())
    if isinstance(obj, list):
        return any(contains(v, needle) for v in obj)
    if isinstance(obj, str):
        return needle in obj
    return False

out = {"automations": [], "scripts": []}

auto = load("/config/.storage/automations")
if auto:
    for it in auto.get("data", {}).get("items", []):
        if contains(it, "climate.set_temperature"):
            out["automations"].append({"id": it.get("id"), "alias": it.get("alias"), "item": it})

scr = load("/config/.storage/scripts")
if scr:
    for it in scr.get("data", {}).get("items", []):
        if contains(it, "climate.set_temperature"):
            out["scripts"].append({"id": it.get("id"), "alias": it.get("alias"), "item": it})

print(json.dumps(out, indent=2))
