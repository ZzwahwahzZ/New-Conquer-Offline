#!/usr/bin/env python3
"""Download Quaternius packs from their official public folders for local game integration.

The upstream pack pages explicitly mark these historical packs CC0. Downloads are cached
between CI runs and are never uploaded to Hugging Face or redistributed as standalone packs.
"""
from __future__ import annotations
import hashlib, json, os, shutil, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = Path(os.environ.get("QUATERNIUS_CACHE", str(Path.home()/".cache"/"quaternius")))
DEST = ROOT / "assets" / "environment" / "quaternius"
PACKS = {
    "ultimate_fantasy_rts": {
        "folder": "1h7sztlZyavWla-JDk3jp6KiWDdMh08yd",
        "page": "https://quaternius.com/packs/ultimatefantasyrts.html",
    },
    "ultimate_stylized_nature": {
        "folder": "1IV3bXHzkNvuNWFHPi4KPx-G4ghuxIuT-",
        "page": "https://quaternius.com/packs/ultimatestylizednature.html",
    },
    "modular_medieval_buildings": {
        "folder": "1WCmnrS1fYQLYfRwztVErgAOyWXdJiVIo",
        "page": "https://quaternius.com/packs/modularmedievalbuildings.html",
    },
}

def main() -> None:
    import urllib.request
    import re
    CACHE.mkdir(parents=True, exist_ok=True)
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {"source": "Quaternius official pack pages", "redistribution": "not mirrored to Hugging Face", "packs": []}
    for name, item in PACKS.items():
        page = urllib.request.urlopen(item["page"], timeout=45).read().decode("utf-8", "replace")
        if "creativecommons.org/publicdomain/zero/1.0/" not in page:
            raise SystemExit(f"CC0 license link missing on official page: {item['page']}")
        folder = CACHE / name
        marker = folder / ".download_complete"
        if not marker.exists():
            if folder.exists():
                shutil.rmtree(folder)
            folder.mkdir(parents=True)
            subprocess.run(["gdown", "--folder", f"https://drive.google.com/drive/folders/{item['folder']}", "-O", str(folder), "--remaining-ok"], check=True)
            supported = [p for p in folder.rglob("*") if p.is_file() and p.suffix.lower() in {".gltf",".glb",".fbx",".obj",".blend",".bin",".png",".jpg",".jpeg",".webp"}]
            if not supported:
                raise SystemExit(f"No supported model/texture files downloaded for {name}")
            marker.write_text("ok", encoding="utf-8")
        target = DEST / name
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(folder, target, ignore=shutil.ignore_patterns(".download_complete"))
        files=[]
        for p in sorted(target.rglob("*")):
            if p.is_file() and p.suffix.lower() in {".gltf",".glb",".bin",".png",".jpg",".jpeg",".webp"}:
                files.append({"path":str(p.relative_to(ROOT)).replace("\\","/"),"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()})
        if not files:
            raise SystemExit(f"Copied pack has no importable content: {name}")
        manifest["packs"].append({"name":name,"official_page":item["page"],"license":"CC0 (verified from official page at download time)","files":files})
        print(f"QUATERNIUS_PACK_READY: {name} files={len(files)}")
    (DEST/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    print("QUATERNIUS_LOCAL_ASSET_DOWNLOAD_PASS")

if __name__ == "__main__":
    main()
