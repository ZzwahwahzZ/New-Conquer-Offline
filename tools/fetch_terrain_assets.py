#!/usr/bin/env python3
"""Fetch and mobile-optimize terrain assets from the project's public HF dataset.
Missing remote assets are non-fatal in CI: deterministic procedural fallbacks remain usable.
"""
from __future__ import annotations
import io, json, os, re, sys, zipfile
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

REPO = "ZzwahwahzZ/clash-of-legends-terrain-assets"
API = f"https://huggingface.co/api/datasets/{REPO}/tree/main"
RAW = f"https://huggingface.co/datasets/{REPO}/resolve/main/"
ROOT = Path("assets/terrain")
HEIGHTS = [
 "01_volcanic_caldera_heightmap_16bit.png","02_glacial_mountains_heightmap_16bit.png",
 "03_tropical_archipelago_heightmap_16bit.png","04_desert_dunes_heightmap_16bit.png",
 "05_dark_forest_valleys_heightmap_16bit.png"]
ZIPS = ["Ground044_2K-JPG.zip","Ground053_2K-JPG.zip","Ground061_2K-JPG.zip",
 "Lava001_2K-JPG.zip","Rock027_2K-JPG.zip","Snow008C_2K-JPG.zip","Rock014_2K-JPG.zip"]
MODELS = ["tropical-island.glb","model.glb","model (1).glb","model (3).glb"]

def get(url):
    req=Request(url,headers={"User-Agent":"New-Conquer-Offline-Asset-Fetch/1.0"})
    with urlopen(req,timeout=90) as r: return r.read()

def tree():
    out=[]; url=API+"?recursive=true&expand=false"
    while url:
        req=Request(url,headers={"User-Agent":"New-Conquer-Offline"})
        with urlopen(req,timeout=60) as r:
            out.extend(json.loads(r.read().decode()))
            link=r.headers.get("Link","")
        m=re.search(r'<([^>]+)>;\s*rel="next"',link); url=m.group(1) if m else None
    return [x["path"] for x in out if x.get("type")=="file"]

def optimize_zip(data,dest):
    try:
        from PIL import Image
    except ImportError:
        print("Pillow unavailable; keeping JPG ZIP for deterministic fallback:",dest.name); return
    dest.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for name in z.namelist():
            base=Path(name).name.lower()
            if not base.endswith((".jpg",".jpeg")): continue
            if not any(k in base for k in ("color","albedo","normalgl","roughness")): continue
            try:
                im=Image.open(io.BytesIO(z.read(name))).convert("RGB")
                im.thumbnail((1024,1024),Image.Resampling.LANCZOS)
                stem=Path(name).stem.lower()
                role="albedo" if ("color" in stem or "albedo" in stem) else ("normal" if "normalgl" in stem else "roughness")
                im.save(dest/f"{role}.jpg",quality=88,optimize=True)
            except Exception as e: print("Texture skipped:",name,e)

def convert_glb(source: Path, clean_path: Path) -> bool:
    """Re-export quantized GLB geometry through trimesh's float32 glTF writer."""
    try:
        import trimesh
        scene = trimesh.load(str(source), force="scene", process=True)
        if not isinstance(scene, trimesh.Scene) or not scene.geometry:
            raise ValueError("GLB contains no scene geometry")
        clean_path.parent.mkdir(parents=True, exist_ok=True)
        scene.export(str(clean_path), file_type="glb")
        check = trimesh.load(str(clean_path), force="scene", process=False)
        if not isinstance(check, trimesh.Scene) or not check.geometry or clean_path.stat().st_size < 128:
            raise ValueError("Converted GLB failed validation")
        print("GLB_DEQUANTIZED", source.name, "geometry=", len(check.geometry), "bytes=", clean_path.stat().st_size)
        return True
    except Exception as exc:
        print("GLB_CONVERSION_FAILED", source.name, repr(exc), "-- procedural fallback remains active")
        return False

def fetch_arabic_font() -> None:
    """Fetch a local Arabic-capable font for offline runtime UI rendering."""
    font_dir = Path("assets/fonts")
    font_dir.mkdir(parents=True, exist_ok=True)
    target = font_dir / "NotoSansArabic-Bold.ttf"
    if target.exists() and target.stat().st_size > 100_000:
        return
    urls = [
        "https://raw.githubusercontent.com/google/fonts/main/ofl/notosansarabic/NotoSansArabic%5Bwdth%2Cwght%5D.ttf",
        "https://raw.githubusercontent.com/google/fonts/main/ofl/notosansarabic/NotoSansArabic%5Bwdth%2Cwght%5D.ttf",
    ]
    for url in urls:
        try:
            data = get(url)
            if len(data) > 100_000:
                target.write_bytes(data)
                print("FETCHED_ARABIC_FONT", target, len(data))
                return
        except Exception as exc:
            print("Arabic font fetch retry:", repr(exc))
    print("Arabic font unavailable; engine fallback font remains active")

def main():
    ROOT.mkdir(parents=True,exist_ok=True)
    try: paths=tree()
    except Exception as e:
        print("HF API unavailable; continuing with procedural fallback:",e); return 0
    wanted=HEIGHTS+ZIPS+MODELS
    for filename in wanted:
        matches=[p for p in paths if Path(p).name==filename]
        if not matches:
            print("Optional asset missing:",filename); continue
        # Prefer the canonical settlement source folder when duplicate basenames exist.
        matches.sort(key=lambda p:(0 if p.startswith("settlement-terrain-source/") else 1,len(p)))
        path=matches[0]
        try:
            data=get(RAW+path.replace(" ","%20"))
            if filename in HEIGHTS:
                (ROOT/"heightmaps").mkdir(exist_ok=True)
                (ROOT/"heightmaps"/filename).write_bytes(data)
            elif filename in ZIPS:
                (ROOT/"source_zips"/filename).parent.mkdir(parents=True,exist_ok=True)
                (ROOT/"source_zips"/filename).write_bytes(data)
                optimize_zip(data,ROOT/"materials"/Path(filename).stem)
            else:
                model_dir = ROOT/"models"
                model_dir.mkdir(exist_ok=True)
                source_path = model_dir/"source"/filename
                source_path.parent.mkdir(parents=True, exist_ok=True)
                (source_path.parent/".gdignore").write_text("# Preserve raw source GLBs without importing them into Godot.\n")
                source_path.write_bytes(data)
                clean_path = model_dir/filename
                if not convert_glb(source_path, clean_path):
                    if clean_path.exists(): clean_path.unlink()
            print("FETCHED",path,len(data))
        except Exception as e: print("Asset download failed (fallback enabled):",path,e)
    fetch_arabic_font()
    print("Terrain asset preparation complete.")
    return 0
if __name__=="__main__": sys.exit(main())
