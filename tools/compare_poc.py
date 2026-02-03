import hashlib
import os
from pathlib import Path

POC_BASE = Path("/Users/giovanipiasentin/dev/codex/homeassistantantigravity/hvac/config")
CAN_BASE = Path("/Users/giovanipiasentin/dev/codex/ha-config-canonical")
OUT_PATH = CAN_BASE / "inventories" / "poc_compare_report.md"

COMPARE_DIRS = [
    ("packages", POC_BASE / "packages", CAN_BASE / "packages"),
    ("lovelace", POC_BASE / "lovelace", CAN_BASE / "lovelace"),
]


def sha256(path: Path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def list_files(root: Path):
    if not root.exists():
        return {}
    files = {}
    for p in root.rglob("*"):
        if p.is_file():
            rel = p.relative_to(root).as_posix()
            files[rel] = p
    return files


def compare_dir(label, poc_dir: Path, can_dir: Path):
    poc_files = list_files(poc_dir)
    can_files = list_files(can_dir)

    only_poc = sorted(set(poc_files) - set(can_files))
    only_can = sorted(set(can_files) - set(poc_files))

    both = sorted(set(poc_files) & set(can_files))
    diff = []
    same = []
    for rel in both:
        if sha256(poc_files[rel]) == sha256(can_files[rel]):
            same.append(rel)
        else:
            diff.append(rel)

    return {
        "label": label,
        "only_poc": only_poc,
        "only_can": only_can,
        "diff": diff,
        "same": same,
        "poc_count": len(poc_files),
        "can_count": len(can_files),
    }


def main():
    results = [compare_dir(label, poc, can) for label, poc, can in COMPARE_DIRS]

    lines = ["# POC vs Canonical Comparison", ""]
    lines.append("This compares the POC repo (`homeassistantantigravity`) to the canonical config.")
    lines.append("")

    for r in results:
        lines.append(f"## {r['label']}")
        lines.append(f"POC files: {r['poc_count']}")
        lines.append(f"Canonical files: {r['can_count']}")
        lines.append("")

        lines.append("### Only in POC")
        if r["only_poc"]:
            for rel in r["only_poc"]:
                lines.append(f"- {rel}")
        else:
            lines.append("- (none)")
        lines.append("")

        lines.append("### Only in Canonical")
        if r["only_can"]:
            for rel in r["only_can"]:
                lines.append(f"- {rel}")
        else:
            lines.append("- (none)")
        lines.append("")

        lines.append("### In Both, Different Content")
        if r["diff"]:
            for rel in r["diff"]:
                lines.append(f"- {rel}")
        else:
            lines.append("- (none)")
        lines.append("")

        lines.append("### In Both, Same Content")
        if r["same"]:
            for rel in r["same"]:
                lines.append(f"- {rel}")
        else:
            lines.append("- (none)")
        lines.append("")

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote: {OUT_PATH}")


if __name__ == "__main__":
    main()
