#!/usr/bin/env python3
"""Restore only the seven curated PBR packs and five heightmaps from Hugging Face."""
from __future__ import annotations
import hashlib
import os
import shutil
import zipfile
from pathlib import Path
from huggingface_hub import snapshot_download

REPO_ID = "ZzwahwahzZ/clash-of-legends-terrain-assets"
SOURCE = "settlement-terrain-source"
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "environment"
CACHE = Path(os.environ.get("HF_ASSET_CACHE", "/tmp/hf-settlement-assets"))
MATERIAL_ZIPS = {
    "Ground044_2K-JPG.zip": "Ground044_2K-JPG",
    "Ground053_2K-JPG.zip": "Ground053_2K-JPG",
    "Ground061_2K-JPG.zip": "Ground061_2K-JPG",
    "Rock027_2K-JPG.zip": "Rock027_2K-JPG",
    "Snow008C_2K-JPG.zip": "Snow008C_2K-JPG",
    "Lava001_2K-JPG.zip": "Lava001_2K-JPG",
    "Rock014_2K-JPG.zip": "Rock014_2K-JPG",
}
MAP_HINTS = {
    "albedo": ("_color", "_albedo", "basecolor", "base_color"),
    "normal": ("_normalgl", "_normaldx", "_normal"),
    "roughness": ("_roughness",),
    "emission": ("_emission", "_emissive"),
}

def safe_extract(zip_path: Path, destination: Path) -> list[Path]:
    extracted: list[Path] = []
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as archive:
        for item in archive.infolist():
            if item.is_dir():
                continue
            target = (destination / item.filename).resolve()
            if destination.resolve() not in target.parents:
                raise RuntimeError(f"Unsafe archive member: {item.filename}")
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(item) as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            extracted.append(target)
    return extracted

def normalize_material(folder: Path, files: list[Path]) -> None:
    image_files = [p for p in files if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")]
    for target_name, hints in MAP_HINTS.items():
        match = next((p for p in image_files if any(hint in p.stem.lower() for hint in hints)), None)
        if match:
            suffix = ".jpg" if match.suffix.lower() in (".jpg", ".jpeg") else match.suffix.lower()
            shutil.copy2(match, folder / (target_name + suffix))
    if not (folder / "albedo.jpg").exists() and not (folder / "albedo.png").exists():
        raise RuntimeError(f"No albedo/color map found in extracted material: {folder}")

def main() -> None:
    token = os.environ.get("HF_TOKEN", "").strip()
    if not token:
        raise SystemExit("HF_TOKEN secret is required to restore the private terrain dataset.")
    # Explicit allow-list: models/unclassified is not downloaded at all.
    snapshot = Path(snapshot_download(
        repo_id=REPO_ID,
        repo_type="dataset",
        token=token,
        allow_patterns=[
            f"{SOURCE}/heightmaps/png/*.png",
            f"{SOURCE}/materials/*.zip",
            f"{SOURCE}/materials/**/*.zip",
        ],
        local_dir=str(CACHE),
    ))
    source = snapshot / SOURCE
    if not source.is_dir():
        raise SystemExit(f"Expected Hugging Face folder is missing: {source}")

    heightmaps = source / "heightmaps" / "png"
    height_dest = ASSETS / "heightmaps"
    if heightmaps.is_dir():
        height_dest.mkdir(parents=True, exist_ok=True)
        for path in heightmaps.glob("*.png"):
            shutil.copy2(path, height_dest / path.name)

    material_source = source / "materials"
    material_dest = ASSETS / "materials"
    material_dest.mkdir(parents=True, exist_ok=True)
    restored = 0
    for archive_name, folder_name in MATERIAL_ZIPS.items():
        candidates = list(material_source.rglob(archive_name))
        if not candidates:
            continue
        target = material_dest / folder_name
        if target.exists():
            shutil.rmtree(target)
        target.mkdir(parents=True, exist_ok=True)
        extracted = safe_extract(candidates[0], target)
        normalize_material(target, extracted)
        restored += 1

    required_heightmaps = [
        "01_volcanic_caldera_heightmap_16bit.png",
        "02_glacial_mountains_heightmap_16bit.png",
        "03_tropical_archipelago_heightmap_16bit.png",
        "04_desert_dunes_heightmap_16bit.png",
        "05_dark_forest_valleys_heightmap_16bit.png",
    ]
    missing = [name for name in required_heightmaps if not (height_dest / name).is_file()]
    if missing:
        raise SystemExit("Missing restored heightmaps: " + ", ".join(missing))
    if restored < 5:
        raise SystemExit(f"Only {restored} PBR material archives restored; at least five are required.")
    print(f"HF_TERRAIN_ASSETS_RESTORED: {restored} PBR material packs")
    print(f"Heightmaps: {len(required_heightmaps)}")
    print("UNCLASSIFIED_GLB_DOWNLOAD: SKIPPED (models/unclassified excluded by allow-list)")
    print(f"Godot destination: {ASSETS}")

if __name__ == "__main__":
    main()
