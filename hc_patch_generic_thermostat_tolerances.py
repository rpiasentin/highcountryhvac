import json, pathlib, shutil, datetime

PATH = pathlib.Path("/config/.storage/core.config_entries")
bak = PATH.parent / f"{PATH.name}.bak_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"

data = json.loads(PATH.read_text())
entries = data.get("data", {}).get("entries", [])

patched = 0
details = []

for e in entries:
    if e.get("domain") != "generic_thermostat":
        continue

    opt = e.get("options")
    if not isinstance(opt, dict):
        opt = {}
        e["options"] = opt

    old_cold = opt.get("cold_tolerance")
    old_hot = opt.get("hot_tolerance")
    old_keep = opt.get("keep_alive")

    # rollback tuning: make it responsive again
    opt["cold_tolerance"] = 0.5
    opt["hot_tolerance"] = 0.0
    opt["keep_alive"] = {"hours": 0, "minutes": 1, "seconds": 0}

    patched += 1
    details.append((e.get("title"), old_cold, old_hot, old_keep))

shutil.copy2(PATH, bak)
PATH.write_text(json.dumps(data, indent=2))

print(f"Backed up: {bak}")
print(f"Patched generic_thermostat entries: {patched}")
for title, old_cold, old_hot, old_keep in details:
    print(f"- {title}: cold {old_cold} -> 0.5, hot {old_hot} -> 0.0, keep_alive {old_keep} -> 00:01:00")
