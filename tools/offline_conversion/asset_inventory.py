#!/usr/bin/env python3
"""Inventory original Conquer client assets without modifying or extracting source files."""
from __future__ import annotations
import collections, json, pathlib, subprocess, sys

ROOT = pathlib.Path("assets/legacy_client")
OUT = pathlib.Path("reports/asset-audit")
OUT.mkdir(parents=True, exist_ok=True)
if not ROOT.is_dir():
    raise SystemExit(f"Missing original resource directory: {ROOT}")

def classify(path: str) -> str:
    suffix = pathlib.PurePosixPath(path.lower()).suffix
    return suffix[1:] if suffix else "[no-extension]"

raw_files = []
ext_counts = collections.Counter()
for p in ROOT.rglob("*"):
    if p.is_file():
        rel = p.relative_to(ROOT).as_posix()
        raw_files.append({"path": rel, "bytes": p.stat().st_size, "extension": classify(rel)})
        ext_counts[classify(rel)] += 1

archives = sorted(p for p in ROOT.rglob("*.7z") if p.is_file())
archive_rows = []
archive_exts = collections.Counter()
archive_errors = []
for archive in archives:
    proc = subprocess.run(["7z", "l", "-slt", str(archive)], text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    entries = []
    in_entries = False
    for line in proc.stdout.splitlines():
        if line.startswith("----------"):
            in_entries = True
            continue
        if not in_entries or " = " not in line:
            continue
        key, value = line.split(" = ", 1)
        if key == "Path" and value not in (str(archive), ""):
            entries.append(value)
    local = collections.Counter(classify(x) for x in entries if not x.endswith("/"))
    archive_exts.update(local)
    archive_rows.append({
        "archive": archive.relative_to(ROOT).as_posix(),
        "return_code": proc.returncode,
        "entry_count": len(entries),
        "extensions": dict(sorted(local.items())),
    })
    if proc.returncode:
        archive_errors.append({"archive": str(archive), "return_code": proc.returncode,
                               "output_tail": proc.stdout[-1200:]})

# Capture small binary signatures for important proprietary formats; no binary is modified.
signatures = []
for p in ROOT.rglob("*"):
    if p.is_file() and p.suffix.lower() in {".dmap", ".tpd", ".pul", ".pux", ".scene"}:
        with p.open("rb") as f:
            head = f.read(32)
        signatures.append({"path": p.relative_to(ROOT).as_posix(),
                           "bytes": p.stat().st_size, "header_hex": head.hex()})

report = {
    "source_root": str(ROOT),
    "raw_file_count": len(raw_files),
    "raw_extension_counts": dict(sorted(ext_counts.items())),
    "archive_count": len(archives),
    "archive_entry_count": sum(x["entry_count"] for x in archive_rows),
    "archive_extension_counts": dict(sorted(archive_exts.items())),
    "archive_errors": archive_errors,
    "archives": archive_rows,
    "format_samples": signatures[:1000],
}
(OUT / "asset-inventory.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
lines = [
    "# Original Conquer asset inventory",
    "",
    f"- Source files: **{len(raw_files)}**",
    f"- 7z archives inspected: **{len(archives)}**",
    f"- Archive entries listed: **{report['archive_entry_count']}**",
    f"- Archive listing errors: **{len(archive_errors)}**",
    "",
    "## Raw files by extension",
    "",
    "| Extension | Files |",
    "|---|---:|",
]
for ext, count in sorted(ext_counts.items(), key=lambda x: (-x[1], x[0])):
    lines.append(f"| {ext} | {count} |")
lines += ["", "## Contents inside 7z archives", "", "| Extension | Entries |", "|---|---:|"]
for ext, count in sorted(archive_exts.items(), key=lambda x: (-x[1], x[0])):
    lines.append(f"| {ext} | {count} |")
lines += ["", "## Conversion status", "",
          "This is a read-only inventory. It does not claim that proprietary maps, scenes, models, or textures have been converted.",
          "The next conversion stage must decode each format, validate geometry/materials, and import representative assets into Godot before bulk conversion."]
(OUT / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"ASSET_AUDIT_PASS files={len(raw_files)} archives={len(archives)} entries={report['archive_entry_count']} errors={len(archive_errors)}")
if archive_errors:
    print(json.dumps(archive_errors[:10], indent=2))
    raise SystemExit(2)
