#!/usr/bin/env python3
import sys
import re
from pathlib import Path

def main():
    if len(sys.argv) != 3:
        print("Usage: apply_cold_tolerance.py <packages_dir> <tolerance>")
        return 2

    packages_dir = Path(sys.argv[1])
    tol_raw = sys.argv[2].strip()

    try:
        tol = float(tol_raw)
    except ValueError:
        print(f"Invalid tolerance: {tol_raw}")
        return 2

    if not packages_dir.exists():
        print(f"Packages dir not found: {packages_dir}")
        return 2

    pattern = re.compile(r'^(\s*)cold_tolerance:\s*.*$', re.MULTILINE)

    changed_files = 0
    changed_lines = 0

    for p in sorted(packages_dir.rglob("*.yaml")) + sorted(packages_dir.rglob("*.yml")):
        txt = p.read_text(encoding="utf-8", errors="replace")
        if "cold_tolerance:" not in txt:
            continue

        def repl(m):
            nonlocal changed_lines
            changed_lines += 1
            return f"{m.group(1)}cold_tolerance: {tol}"

        new = pattern.sub(repl, txt)
        if new != txt:
            p.write_text(new, encoding="utf-8")
            changed_files += 1
            print(f"UPDATED {p}")

    print(f"Done. changed_files={changed_files}, changed_lines={changed_lines}, tolerance={tol}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
