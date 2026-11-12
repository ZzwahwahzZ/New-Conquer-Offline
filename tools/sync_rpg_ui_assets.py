#!/usr/bin/env python3
"""Fetch verified Kenney CC0 RPG UI packs, classify PNGs, publish to HF and restore to Godot."""
from __future__ import annotations

import hashlib
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
SOURCE_VERSION = "kenney-cc0-rpg-ui-2026-11"
MINIMUM_PNG_FILES = 51

# Official Kenney download endpoints are tried first. If Kenney's dynamic
# download route is unavailable, use the pinned public GitHub CC0 mirror.
PACKS = {
    "ui-pack": {
        "official_url": "https://kenney.nl/assets/ui-pack/download",
        "mirror_url": "https://raw.githubusercontent.com/bill2432/kenney-2d-mirror/main/packs/ui-pack.zip",
        "mirror_sha256": "a8a14a234911eb648c062622915c93e79e94e97cb7f9f375a70f6617f1174318",
        "page": "https://kenney.nl/assets/ui-pack",
        "license": "CC0-1.0",
    },
    "roguelike-rpg-pack": {
        "official_url": "https://kenney.nl/assets/roguelike-rpg-pack/download",
        "mirror_url": "https://raw.githubusercontent.com/bill2432/kenney-2d-mirror/main/packs/roguelike-rpg-pack.zip",
        "mirror_sha256": "8e7d2378f8f794245645f6d7dc7aeeb246791410a7e512293c594b46a5a9524b",
        "page": "https://kenney.nl/assets/roguelike-rpg-pack",
        "license": "CC0-1.0",
    },
}
IMAGE_EXTS = {".png"}
ALLOWED_EXTRACT_EXTS = IMAGE_EXTS | {".txt", ".md", ".json", ".license"}

def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def download(url: str, target: Path) -> None:
    request = urllib.request.Request(
        url, headers={"User-Agent": "New-Conquer-Offline-KenneyCC0Sync/2.0"}
    )
    with urllib.request.urlopen(request, timeout=180) as response, target.open("wb") as output:
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status} while downloading {url}")
        shutil.copyfileobj(response, output)
    if target.stat().st_size < 20_000 or not zipfile.is_zipfile(target):
        raise RuntimeError(f"Not a valid Kenney ZIP archive: {url}")

def download_pack(pack_name: str, metadata: dict, target: Path) -> dict:
    errors = []
    try:
        download(metadata["official_url"], target)
        return {
            "source": "official",
            "download_url": metadata["official_url"],
            "archive_bytes": target.stat().st_size,
            "sha256": sha256_file(target),
        }
    except Exception as exc:
        errors.append(f"official: {type(exc).__name__}: {exc}")
        target.unlink(missing_ok=True)

    try:
        download(metadata["mirror_url"], target)
        actual = sha256_file(target)
        if actual != metadata["mirror_sha256"]:
            raise RuntimeError(
                f"GitHub mirror SHA256 mismatch for {pack_name}: {actual}"
            )
        print(f"KENNEY_GITHUB_MIRROR_PASS: {pack_name} sha256={actual}")
        return {
            "source": "verified-github-mirror",
            "download_url": metadata["mirror_url"],
            "archive_bytes": target.stat().st_size,
            "sha256": actual,
            "mirror_repository": "https://github.com/bill2432/kenney-2d-mirror",
        }
    except Exception as exc:
        errors.append(f"GitHub mirror: {type(exc).__name__}: {exc}")
        target.unlink(missing_ok=True)
    raise RuntimeError(f"All download sources failed for {pack_name}: " + " | ".join(errors))

def safe_extract(archive_path: Path, destination: Path) -> tuple[list[Path], int]:
    extracted: list[Path] = []
    ignored_psd = 0
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        members = [item for item in archive.infolist() if not item.is_dir()]
        print(
            f"KENNEY_ARCHIVE: {archive_path.name} members={len(members)} "
            f"png={sum(Path(item.filename).suffix.lower() == '.png' for item in members)}"
        )
        for item in members:
            rel = PurePosixPath(item.filename)
            if rel.is_absolute() or ".." in rel.parts:
                raise RuntimeError(f"Unsafe archive path: {item.filename}")
            suffix = Path(rel.name).suffix.lower()
            if suffix == ".psd":
                ignored_psd += 1
                continue
            if suffix not in ALLOWED_EXTRACT_EXTS:
                continue
            target = destination.joinpath(*rel.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(item) as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            extracted.append(target)
    return extracted, ignored_psd

def safe_copy(source: Path, destination_dir: Path, pack_name: str) -> Path:
    destination_dir.mkdir(parents=True, exist_ok=True)
    prefix = pack_name.replace("-", "_") + "__"
    target = destination_dir / (prefix + source.name)
    if target.exists():
        target = destination_dir / (prefix + str(abs(hash(source.as_posix()))) + "__" + source.name)
    shutil.copy2(source, target)
    return target

def classify_assets(stage: Path, provenance: dict) -> dict:
    source_root = stage / "source"
    category_dirs = [
        stage / "frames", stage / "buttons", stage / "bars",
        stage / "icons" / "weapons", stage / "icons" / "armor",
        stage / "icons" / "gems", stage / "icons" / "skills",
        stage / "icons" / "potions", stage / "icons" / "misc",
    ]
    for folder in category_dirs:
        folder.mkdir(parents=True, exist_ok=True)

    counts = {folder.relative_to(stage).as_posix(): 0 for folder in category_dirs}
    images = sorted(
        (p for p in source_root.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTS),
        key=lambda p: p.as_posix().lower(),
    )
    if len(images) < MINIMUM_PNG_FILES:
        raise RuntimeError(
            f"Kenney PNG quality gate failed: {len(images)} PNG files; "
            f"at least {MINIMUM_PNG_FILES} are required"
        )

    category_rules = [
        ("weapons", ("weapon", "sword", "bow", "dagger", "axe", "staff", "arrow", "spear")),
        ("armor", ("armor", "armour", "shield", "helmet", "boots", "glove", "robe", "chestplate")),
        ("gems", ("gem", "crystal", "jewel", "diamond", "ruby", "sapphire", "emerald")),
        ("skills", ("skill", "spell", "magic", "rune", "scroll", "wand")),
        ("potions", ("potion", "flask", "elixir", "health", "mana", "hp_", "mp_")),
    ]
    for image_path in images:
        relative = image_path.relative_to(source_root)
        normalized = relative.as_posix().lower().replace(" ", "_").replace("-", "_")
        pack_name = relative.parts[0] if relative.parts else "unknown"
        if pack_name == "ui-pack":
            if any(token in normalized for token in ("button", "btn", "checkbox", "check_")):
                target_dir = stage / "buttons"
            elif any(token in normalized for token in ("bar", "slider", "progress", "health", "mana")):
                target_dir = stage / "bars"
            elif any(token in normalized for token in ("panel", "frame", "window", "border", "dialog", "slot", "input")):
                target_dir = stage / "frames"
            else:
                target_dir = stage / "icons" / "misc"
        else:
            target_dir = stage / "icons" / "misc"
            for category, tokens in category_rules:
                if any(token in normalized for token in tokens):
                    target_dir = stage / "icons" / category
                    break
        safe_copy(image_path, target_dir, pack_name)
        key = target_dir.relative_to(stage).as_posix()
        counts[key] += 1

    manifest = {
        "title": "Kenney CC0 RPG UI and item icon library",
        "source_version": SOURCE_VERSION,
        "repository": REPO_ID,
        "license": "CC0-1.0",
        "sources": provenance,
        "image_format": "PNG only; PSD files are never extracted or parsed",
        "image_count": len(images),
        "category_counts": counts,
        "godot_destination": "res://assets/ui/",
        "notes": [
            "UI Pack provides individual UI PNG sprites for frames, buttons and bars.",
            "Roguelike/RPG Pack supplies RPG item and environment sprites; filename-based categories are conservative.",
            "Unmatched sprites remain in icons/misc rather than being mislabeled.",
            "Kenney asset pages identify both packs as Creative Commons CC0.",
            "HP and MP orbs are rendered by the project's Godot circular glow shader.",
        ],
    }
    (stage / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest

def restore_from_hf(api: HfApi, token: str) -> bool:
    existing = api.list_repo_files(repo_id=REPO_ID, repo_type=REPO_TYPE)
    if not any(path.startswith("ui_and_icons/") for path in existing):
        return False
    snapshot = Path(snapshot_download(
        repo_id=REPO_ID, repo_type=REPO_TYPE, token=token,
        allow_patterns=["ui_and_icons/**"], local_dir=str(CACHE),
    ))
    source = snapshot / "ui_and_icons"
    manifest_path = source / "manifest.json"
    if not manifest_path.is_file():
        return False
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception:
        return False
    if manifest.get("source_version") != SOURCE_VERSION:
        return False
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, DEST)
    count = sum(1 for path in DEST.rglob("*.png") if path.is_file())
    if count < MINIMUM_PNG_FILES:
        raise RuntimeError(f"HF Kenney restore has only {count} PNG files")
    print(f"HF_KENNEY_RPG_UI_RESTORE_PASS: png={count}")
    return True

def main() -> None:
    token = os.environ.get("HF_TOKEN", "").strip()
    if not token:
        raise SystemExit("HF_TOKEN is required to seed or restore the Kenney UI asset library.")
    api = HfApi(token=token)
    if restore_from_hf(api, token):
        return

    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)
    archive_dir = Path("/tmp/kenney-rpg-ui-archives")
    if archive_dir.exists():
        shutil.rmtree(archive_dir)
    archive_dir.mkdir(parents=True)
    provenance = {}
    ignored_psd_total = 0

    for pack_name, metadata in PACKS.items():
        archive = archive_dir / f"{pack_name}.zip"
        source_info = download_pack(pack_name, metadata, archive)
        extracted, ignored_psd = safe_extract(archive, STAGE / "source" / pack_name)
        ignored_psd_total += ignored_psd
        png_count = sum(
            1 for path in extracted if path.is_file() and path.suffix.lower() == ".png"
        )
        if png_count == 0:
            raise RuntimeError(f"Kenney pack {pack_name} contains no extracted PNG files")
        provenance[pack_name] = {
            **source_info,
            "source_page": metadata["page"],
            "license": metadata["license"],
            "extracted_files": len(extracted),
            "png_files": png_count,
            "ignored_psd_files": ignored_psd,
        }
        print(f"KENNEY_PACK_EXTRACTED: {pack_name} png={png_count} files={len(extracted)}")

    manifest = classify_assets(STAGE, provenance)
    print(
        f"KENNEY_PNG_QUALITY_PASS: {manifest['image_count']} PNG files "
        f"(required >50); PSD_IGNORED={ignored_psd_total}"
    )
    api.upload_folder(
        folder_path=str(STAGE),
        path_in_repo="ui_and_icons",
        repo_id=REPO_ID,
        repo_type=REPO_TYPE,
        commit_message="Replace incomplete UI assets with verified Kenney CC0 PNG packs",
    )
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(STAGE, DEST)
    print(
        f"HF_KENNEY_RPG_UI_SEED_PASS: images={manifest['image_count']} "
        f"categories={json.dumps(manifest['category_counts'], sort_keys=True)}"
    )
    print(f"Godot destination: {DEST}")

if __name__ == "__main__":
    main()
