#!/usr/bin/env python3
"""Seed or restore CC0 RPG UI and icon packs from Hugging Face for Godot CI."""
from __future__ import annotations
import json
import os
import shutil
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath
from huggingface_hub import HfApi, snapshot_download

REPO_ID = "ZzwahwahzZ/clash-of-legends-terrain-assets"
REPO_TYPE = "dataset"
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "ui"
CACHE = Path("/tmp/hf-rpg-ui-cache")
STAGE = Path("/tmp/rpg-ui-stage")
PACKS = {
    "dark-fantasy-ui-hud": {
        "url": "https://annomotion.studio/packs/dark-fantasy-ui-hud-kit/download",
        "page": "https://annomotion.studio/packs/dark-fantasy-ui-hud-kit",
        "license": "CC0-1.0",
    },
    "fantasy-rpg-item-icons": {
        "url": "https://annomotion.studio/packs/fantasy-rpg-item-icons/download",
        "page": "https://annomotion.studio/packs/fantasy-rpg-item-icons",
        "license": "CC0-1.0",
    },
}
IMAGE_EXTS = {".png", ".svg", ".webp"}
ALLOWED_EXTRACT_EXTS = IMAGE_EXTS | {".jpg", ".jpeg", ".txt", ".md", ".json", ".license", ".zip", ".psd"}

def download(url: str, target: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "New-Conquer-Offline-AssetSync/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response, target.open("wb") as output:
        if response.status != 200:
            raise RuntimeError(f"Asset download returned HTTP {response.status}: {url}")
        shutil.copyfileobj(response, output)
    if target.stat().st_size < 1000 or not zipfile.is_zipfile(target):
        raise RuntimeError(f"Downloaded asset is not a valid ZIP archive: {url}")

def safe_extract(archive_path: Path, destination: Path, depth: int = 0) -> list[Path]:
    if depth > 3:
        raise RuntimeError(f"Nested UI archive depth exceeds safety limit: {archive_path}")
    extracted: list[Path] = []
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        members = [item.filename for item in archive.infolist() if not item.is_dir()]
        print(f"UI_ARCHIVE_MEMBERS depth={depth} {archive_path.name}: " + " | ".join(members[:40]))
        for item in archive.infolist():
            if item.is_dir():
                continue
            rel = PurePosixPath(item.filename)
            if rel.is_absolute() or ".." in rel.parts:
                raise RuntimeError(f"Unsafe UI pack archive path: {item.filename}")
            if Path(rel.name).suffix.lower() not in ALLOWED_EXTRACT_EXTS:
                continue
            target = destination.joinpath(*rel.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(item) as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            extracted.append(target)
    nested_archives = [p for p in extracted if p.suffix.lower() == ".zip"]
    for nested in nested_archives:
        nested_destination = nested.parent / nested.stem
        extracted.extend(safe_extract(nested, nested_destination, depth + 1))
    return extracted


def export_psd_assets(source_root: Path) -> int:
    psd_files = list(source_root.rglob("*.psd")) + list(source_root.rglob("*.PSD"))
    if not psd_files:
        return 0
    try:
        from psd_tools import PSDImage
    except ImportError:
        import subprocess
        import sys
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--disable-pip-version-check", "psd-tools"])
        from psd_tools import PSDImage
    exported = 0
    for psd_path in psd_files:
        document = PSDImage.open(psd_path)
        output_dir = psd_path.parent / (psd_path.stem + "_layers")
        output_dir.mkdir(parents=True, exist_ok=True)
        composite = document.composite()
        if composite is not None:
            composite_path = output_dir / (psd_path.stem + "_composite.png")
            composite.save(composite_path)
            exported += 1
        for index, layer in enumerate(document.descendants()):
            try:
                if layer.is_group() or not layer.is_visible():
                    continue
                image = layer.composite()
                if image is None or image.getbbox() is None:
                    continue
                safe_name = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in str(layer.name)).strip("_")
                if not safe_name:
                    safe_name = f"layer_{index:03d}"
                target = output_dir / f"{index:03d}_{safe_name[:64]}.png"
                image.save(target)
                exported += 1
            except Exception as error:
                print(f"PSD_LAYER_SKIP: {psd_path.name} layer={index} name={getattr(layer, 'name', '')!r} error={error}")
        print(f"PSD_TO_PNG: {psd_path.name} layers_exported={exported} canvas={document.width}x{document.height}")
    return exported

def classify_assets(stage: Path, provenance: dict) -> dict:
    source_root = stage / "source"
    icons_root = stage / "icons"
    frames_root = stage / "frames"
    buttons_root = stage / "buttons"
    bars_root = stage / "bars"
    for folder in (icons_root, frames_root, buttons_root, bars_root):
        folder.mkdir(parents=True, exist_ok=True)
    images = [p for p in source_root.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTS]
    aliases = {
        "bag": ("inventory", "bag"),
        "equip": ("equipment", "armor", "armour"),
        "skills": ("skill", "magic", "spell"),
        "mall": ("shop", "store", "mall"),
        "jianghu": ("guild", "jianghu"),
        "hp": ("health", "hp"),
        "mp": ("mana", "mp"),
        "xp": ("experience", "xp"),
    }
    alias_hits = {}
    for path in images:
        name = relative.as_posix().lower().replace(" ", "_").replace("-", "_")
        relative = path.relative_to(source_root)
        if any(token in name for token in ("button", "btn")):
            shutil.copy2(path, buttons_root / path.name)
        elif any(token in name for token in ("bar", "health", "mana", "stamina")):
            shutil.copy2(path, bars_root / path.name)
        elif any(token in name for token in ("panel", "frame", "window", "border", "dialog", "slot")):
            shutil.copy2(path, frames_root / path.name)
        else:
            shutil.copy2(path, icons_root / path.name)
        for alias, tokens in aliases.items():
            if alias not in alias_hits and any(token in name for token in tokens):
                alias_hits[alias] = path
    for alias, source in alias_hits.items():
        suffix = source.suffix.lower()
        shutil.copy2(source, icons_root / f"{alias}{suffix}")
    manifest = {
        "title": "RPG UI and Crystal Icons",
        "repository": REPO_ID,
        "license": "CC0-1.0",
        "sources": provenance,
        "image_count": len(images),
        "aliases": {key: str(value.relative_to(source_root)) for key, value in alias_hits.items()},
        "godot_destination": "res://assets/ui/",
        "notes": [
            "Original source files are retained under source/.",
            "UI pieces are categorized into frames/, buttons/, bars/ and icons/.",
            "Only source files carrying the CC0-1.0 license statement on their publisher page are included.",
            "The classic HUD draws HP/MP radial orbs from Godot textures when no dedicated orb art exists.",
        ],
    }
    (stage / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest

def main() -> None:
    token = os.environ.get("HF_TOKEN", "").strip()
    if not token:
        raise SystemExit("HF_TOKEN is required to seed or restore the UI asset library.")
    api = HfApi(token=token)
    existing = api.list_repo_files(repo_id=REPO_ID, repo_type=REPO_TYPE)
    if any(path.startswith("ui_and_icons/") for path in existing):
        snapshot = Path(snapshot_download(
            repo_id=REPO_ID, repo_type=REPO_TYPE, token=token,
            allow_patterns=["ui_and_icons/**"], local_dir=str(CACHE),
        ))
        source = snapshot / "ui_and_icons"
        if not source.is_dir():
            raise SystemExit("HF reports UI assets but the ui_and_icons folder is missing locally.")
        if DEST.exists():
            shutil.rmtree(DEST)
        DEST.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, DEST)
        print(f"HF_RPG_UI_RESTORE_PASS: {sum(1 for p in DEST.rglob('*') if p.is_file())} files")
        return

    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)
    provenance = {}
    archive_dir = STAGE / "source_archives"
    archive_dir.mkdir()
    for pack_name, metadata in PACKS.items():
        archive = archive_dir / f"{pack_name}.zip"
        download(metadata["url"], archive)
        extracted = safe_extract(archive, STAGE / "source" / pack_name)
        provenance[pack_name] = {
            "source_page": metadata["page"],
            "download_url": metadata["url"],
            "license": metadata["license"],
            "archive_bytes": archive.stat().st_size,
            "extracted_files": len(extracted),
        }
        print(f"RPG_UI_PACK_EXTRACTED: {pack_name} files={len(extracted)} bytes={archive.stat().st_size}")
    psd_exports = export_psd_assets(STAGE / "source")
    print(f"PSD_LAYER_EXPORT_TOTAL: {psd_exports}")
    manifest = classify_assets(STAGE, provenance)
    if manifest["image_count"] < 20:
        raise SystemExit(f"UI pack extraction yielded too few images: {manifest['image_count']}")
    api.upload_folder(
        folder_path=str(STAGE),
        path_in_repo="ui_and_icons",
        repo_id=REPO_ID,
        repo_type=REPO_TYPE,
        commit_message="Add CC0 RPG UI frames, buttons, status bars and item icons",
    )
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(STAGE, DEST)
    print(f"HF_RPG_UI_SEED_PASS: images={manifest['image_count']} aliases={len(manifest['aliases'])}")
    print(f"Godot destination: {DEST}")

if __name__ == "__main__":
    main()
