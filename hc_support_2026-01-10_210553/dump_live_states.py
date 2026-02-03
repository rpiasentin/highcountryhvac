import os, json, pathlib, urllib.request, urllib.error

DIR = os.environ.get("DIR", "/config")
GT_PATH = pathlib.Path(DIR) / "generic_thermostats.json"
OUT_PATH = pathlib.Path(DIR) / "live_states_related.json"

if not GT_PATH.exists():
    raise SystemExit(f"Missing {GT_PATH}. Run the generic thermostat dump first.")

data = json.loads(GT_PATH.read_text())
therms = data.get("thermostats", [])

# Build a unique set of entities: climates + their heater + their sensor
entities = set()
for t in therms:
    if t.get("entity_id"): entities.add(t["entity_id"])
    if t.get("heater"): entities.add(t["heater"])
    if t.get("sensor"): entities.add(t["sensor"])

entities = sorted(entities)

token = os.environ.get("SUPERVISOR_TOKEN")
if not token:
    raise SystemExit("SUPERVISOR_TOKEN not set in this shell. Run this from the HA Terminal/SSH add-on (or a shell that has SUPERVISOR_TOKEN).")

base = "http://supervisor/core/api/states/"
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

out = {"count": len(entities), "entities": {}}
fail = []

for eid in entities:
    try:
        req = urllib.request.Request(base + eid, headers=headers, method="GET")
        with urllib.request.urlopen(req, timeout=10) as r:
            payload = json.loads(r.read().decode("utf-8"))
        # Keep full payload (state + attributes + last_changed/updated)
        out["entities"][eid] = payload
    except Exception as e:
        fail.append({"entity_id": eid, "error": str(e)})

out["failed"] = fail

OUT_PATH.write_text(json.dumps(out, indent=2))
print(f"Wrote: {OUT_PATH} (entities={len(entities)}, failed={len(fail)})")
