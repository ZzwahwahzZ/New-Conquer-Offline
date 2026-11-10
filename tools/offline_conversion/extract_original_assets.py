#!/usr/bin/env python3
"""Extract original Conquer 7z payloads and stage Godot-native assets unchanged."""
from __future__ import annotations
import collections, json, pathlib, shutil, subprocess, tempfile

ROOT = pathlib.Path("assets/legacy_client")
OUT = pathlib.Path("build/original-godot-assets")
SUPPORTED = {".png",".jpg",".jpeg",".webp",".bmp",".tga",".dds",".ogg",".wav",".mp3",
             ".glb",".gltf",".obj",".dae",".fbx",".tscn",".tres",".res",".scn"}
ARCHIVES = sorted(ROOT.rglob("*.7z"))
if not ROOT.is_dir() or not ARCHIVES:
    raise SystemExit("Original 7z resource archives were not found under assets/legacy_client")
OUT.mkdir(parents=True, exist_ok=True)
manifest = []
counts = collections.Counter()
errors = []
copied_bytes = 0
with tempfile.TemporaryDirectory(prefix="conquer-original-") as tmp:
    tmp_root = pathlib.Path(tmp)
    for index, archive in enumerate(ARCHIVES, 1):
        rel_archive = archive.relative_to(ROOT)
        target = tmp_root / f"archive_{index:04d}"
        target.mkdir()
        proc = subprocess.run(["7z","x","-y",f"-o{target}",str(archive)],
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if proc.returncode:
            errors.append({"archive":rel_archive.as_posix(),"return_code":proc.returncode,
                           "log_tail":proc.stdout[-1200:]})
            continue
        archive_name = rel_archive.as_posix().replace("/","__").replace(".7z","")
        for item in target.rglob("*"):
            if not item.is_file():
                continue
            ext = item.suffix.lower()
            counts[ext or "[no-extension]"] += 1
            if ext not in SUPPORTED:
                continue
            rel = item.relative_to(target)
            destination = OUT / archive_name / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, destination)
            size = destination.stat().st_size
            copied_bytes += size
            manifest.append({"source_archive":rel_archive.as_posix(),
                             "archive_path":rel.as_posix(),
                             "staged_path":destination.as_posix(),
                             "extension":ext,"bytes":size})
data = {"archives_found":len(ARCHIVES),"archive_errors":errors,
        "godot_native_assets_copied":len(manifest),"godot_native_bytes":copied_bytes,
        "extracted_file_extension_counts":dict(sorted(counts.items())),
        "assets":manifest}
(OUT/"manifest.json").write_text(json.dumps(data,indent=2),encoding="utf-8")
lines=["# Original Conquer assets staged for Godot","",
       f"- 7z archives found: **{len(ARCHIVES)}**",
       f"- Godot-readable original assets copied: **{len(manifest)}**",
       f"- Copied bytes: **{copied_bytes}**",
       f"- Archive extraction errors: **{len(errors)}**","",
       "## Staged asset types",""]
for ext,n in sorted(counts.items(),key=lambda x:(-x[1],x[0])):
    lines.append(f"- {ext}: {n}")
lines += ["","Original files are preserved; staged files are byte-for-byte copies.",
          "Proprietary .dmap, .tpd, .scene, .pul, and .pux resources are not falsely relabeled as Godot assets; they remain in the original source tree for format-specific loading/conversion."]
(OUT/"README.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
print(f"ORIGINAL_ASSET_EXTRACTION_PASS archives={len(ARCHIVES)} staged={len(manifest)} bytes={copied_bytes} errors={len(errors)}")
if errors:
    print(json.dumps(errors[:20],indent=2))
    raise SystemExit(2)
