#!/usr/bin/env python3
"""Fetch verified Kenney CC0 RPG UI packs, classify PNGs, publish to HF and restore to Godot."""
from __future__ import annotations

import concurrent.futures
import hashlib
import json
import os
import shutil
import urllib.request
import zipfile
from urllib.parse import quote
from pathlib import Path, PurePosixPath

from huggingface_hub import HfApi, snapshot_download

REPO_ID = "ZzwahwahzZ/clash-of-legends-terrain-assets"
REPO_TYPE = "dataset"
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "ui"
CACHE = Path("/tmp/hf-rpg-ui-cache")
STAGE = Path("/tmp/rpg-ui-stage")
PUBLISH = Path("/tmp/rpg-ui-publish")
SOURCE_VERSION = "kenney-cc0-rpg-ui-2026-11-v3"
MIRROR_REPO = "shorepine/kenney"
MIRROR_COMMIT = "3694c6879e487c108f55677be7dd2ca75b07cc3b"
_MIRROR_TREE = None
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
    "ui-pack-rpg-expansion": {
        "official_url": "https://kenney.nl/assets/ui-pack-rpg-expansion/download",
        "page": "https://kenney.nl/assets/ui-pack-rpg-expansion",
        "license": "CC0-1.0",
    },
    "game-icons": {
        "official_url": "https://kenney.nl/assets/game-icons/download",
        "page": "https://kenney.nl/assets/game-icons",
        "license": "CC0-1.0",
    },
    "roguelike-rpg-pack": {
        "official_url": "https://kenney.nl/assets/roguelike-rpg-pack/download",
        "mirror_url": "https://raw.githubusercontent.com/bill2432/kenney-2d-mirror/main/packs/roguelike-rpg-pack.zip",
        "mirror_sha256": "8e7d2378f8f794245645f6d7dc7aeeb246791410a7e512293c594b46a5a9524b",
        "page": "https://kenney.nl/assets/roguelike-rpg-pack",
        "license": "CC0-1.0",
    },
    "fantasy-ui-borders": {
        "official_url": "https://kenney.nl/assets/fantasy-ui-borders/download",
        "mirror_prefix": "ui/Fantasy UI Borders/",
        "page": "https://kenney.nl/assets/fantasy-ui-borders",
        "license": "CC0-1.0",
    },
    "rune-pack": {
        "official_url": "https://kenney.nl/assets/rune-pack/download",
        "mirror_prefix": "2d/Rune Pack/",
        "page": "https://kenney.nl/assets/rune-pack",
        "license": "CC0-1.0",
    },
    "scribble-dungeons": {
        "official_url": "https://kenney.nl/assets/scribble-dungeons/download",
        "mirror_prefix": "2d/Scribble Dungeons/",
        "page": "https://kenney.nl/assets/scribble-dungeons",
        "license": "CC0-1.0",
    },
    "abstract-platformer": {
        "official_url": "https://kenney.nl/assets/abstract-platformer/download",
        "mirror_prefix": "2d/Abstract Platformer/",
        "page": "https://kenney.nl/assets/abstract-platformer",
        "license": "CC0-1.0",
    },
    "new-platformer-pack": {
        "official_url": "https://kenney.nl/assets/new-platformer-pack/download",
        "mirror_prefix": "2d/New Platformer Pack/",
        "page": "https://kenney.nl/assets/new-platformer-pack",
        "license": "CC0-1.0",
    },
    "board-game-icons": {
        "official_url": "https://kenney.nl/assets/board-game-icons/download",
        "mirror_prefix": "icons/Board Game Icons/",
        "page": "https://kenney.nl/assets/board-game-icons",
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

def get_mirror_tree() -> list[dict]:
    global _MIRROR_TREE
    if _MIRROR_TREE is None:
        url = f"https://api.github.com/repos/{MIRROR_REPO}/git/trees/{MIRROR_COMMIT}?recursive=1"
        request = urllib.request.Request(url, headers={"User-Agent": "New-Conquer-Offline-KenneyCC0Sync/2.0"})
        with urllib.request.urlopen(request, timeout=90) as response:
            payload = json.loads(response.read().decode("utf-8"))
        if payload.get("truncated"):
            raise RuntimeError("Pinned Kenney mirror tree was truncated")
        _MIRROR_TREE = payload.get("tree", [])
    return _MIRROR_TREE

def include_mirror_asset(pack_name: str, path: str) -> bool:
    lower = path.lower()
    filename = PurePosixPath(path).name.lower()
    if pack_name == "fantasy-ui-borders":
        return filename.endswith(".png")
    if pack_name == "rune-pack":
        return filename.endswith(".png")
    if pack_name == "scribble-dungeons":
        return "/double (128px)/items/" in lower and (
            filename.startswith("weapon_") or filename.startswith("shield_")
        )
    if pack_name == "abstract-platformer":
        return "/items/" in lower and any(token in filename for token in ("gem", "jewel", "crystal"))
    if pack_name == "new-platformer-pack":
        return "/double/" in lower and filename.startswith("gem_")
    if pack_name == "board-game-icons":
        return "/double (128px)/" in lower and filename.startswith("flask_")
    return filename.endswith(".png")

def fetch_mirror_file(path: str) -> tuple[str, bytes]:
    url = f"https://raw.githubusercontent.com/{MIRROR_REPO}/{MIRROR_COMMIT}/{quote(path, safe='/')}"
    request = urllib.request.Request(url, headers={"User-Agent": "New-Conquer-Offline-KenneyCC0Sync/2.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(f"Mirror item is not a PNG: {path}")
    return path, data

def download_mirror_subset(pack_name: str, metadata: dict, target: Path) -> dict:
    prefix = metadata["mirror_prefix"]
    entries = [
        item["path"] for item in get_mirror_tree()
        if item.get("type") == "blob"
        and item["path"].startswith(prefix)
        and include_mirror_asset(pack_name, item["path"])
    ]
    if not entries:
        raise RuntimeError(f"No pinned mirror PNGs found for {pack_name}")
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
            futures = [pool.submit(fetch_mirror_file, path) for path in entries]
            for future in concurrent.futures.as_completed(futures):
                path, data = future.result()
                relative = path[len(prefix):]
                archive.writestr(relative, data)
        provenance = (
            f"Kenney CC0 mirror subset\\n"
            f"Repository: https://github.com/{MIRROR_REPO}\\n"
            f"Pinned commit: {MIRROR_COMMIT}\\n"
            f"Official source page: {metadata['page']}\\n"
            f"License: {metadata['license']}\\n"
        )
        archive.writestr("MIRROR_PROVENANCE.md", provenance)
    actual = sha256_file(target)
    print(f"KENNEY_PINNED_GITHUB_MIRROR_PASS: {pack_name} png={len(entries)} sha256={actual}")
    return {
        "source": "verified-pinned-github-mirror-subset",
        "download_url": f"https://github.com/{MIRROR_REPO}/tree/{MIRROR_COMMIT}",
        "mirror_repository": f"https://github.com/{MIRROR_REPO}",
        "mirror_commit": MIRROR_COMMIT,
        "mirror_png_files": len(entries),
        "archive_bytes": target.stat().st_size,
        "sha256": actual,
    }

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
        if metadata.get("mirror_prefix"):
            return download_mirror_subset(pack_name, metadata, target)
        download(metadata["mirror_url"], target)
        actual = sha256_file(target)
        if actual != metadata["mirror_sha256"]:
            raise RuntimeError(f"GitHub mirror SHA256 mismatch for {pack_name}: {actual}")
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
    relative = source.relative_to(STAGE / "source")
    parent_hint = "__".join(part for part in relative.parts[1:-1] if part not in (".", ".."))
    prefix = pack_name.replace("-", "_") + ("__" + parent_hint if parent_hint else "") + "__"
    target = destination_dir / (prefix + source.name)
    if target.exists():
        raise RuntimeError(f"Duplicate categorized asset name: {target}")
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
    classified_count = 0
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
        filename = image_path.name.lower()
        target_dir = None

        if pack_name == "ui-pack":
            if any(token in normalized for token in ("button", "btn", "checkbox", "check_")):
                target_dir = stage / "buttons"
            elif any(token in normalized for token in ("bar", "slider", "slide", "progress", "health", "mana")):
                target_dir = stage / "bars"
            elif any(token in normalized for token in ("panel", "frame", "window", "border", "dialog", "slot", "input")):
                target_dir = stage / "frames"
            else:
                target_dir = stage / "icons" / "misc"
        elif pack_name == "ui-pack-rpg-expansion":
            if any(token in normalized for token in ("button", "btn", "checkbox", "check_")):
                target_dir = stage / "buttons"
            elif any(token in normalized for token in ("bar", "slider", "progress", "health", "mana")):
                target_dir = stage / "bars"
            elif any(token in normalized for token in ("panel", "frame", "window", "border", "dialog", "slot")):
                target_dir = stage / "frames"
            else:
                target_dir = stage / "icons" / "misc"
        elif pack_name == "game-icons":
            target_dir = stage / "icons" / "misc"
        elif pack_name == "fantasy-ui-borders":
            target_dir = stage / "frames"
        elif pack_name == "rune-pack":
            target_dir = stage / "icons" / "skills"
        elif pack_name == "scribble-dungeons":
            if "/items/" in normalized and filename.startswith("weapon_"):
                target_dir = stage / "icons" / "weapons"
            elif "/items/" in normalized and filename.startswith("shield_"):
                target_dir = stage / "icons" / "armor"
        elif pack_name == "abstract-platformer":
            if "/items/" in normalized and any(token in filename for token in ("gem", "jewel", "crystal")):
                target_dir = stage / "icons" / "gems"
        elif pack_name == "new-platformer-pack":
            if "/double/" in normalized and filename.startswith("gem_"):
                target_dir = stage / "icons" / "gems"
        elif pack_name == "board-game-icons":
            if "double_(128px)" in normalized and filename.startswith("flask_"):
                target_dir = stage / "icons" / "potions"
        elif pack_name == "roguelike-rpg-pack":
            # Keep the source tilesheet for later world work; do not mislabel it as item icons.
            continue
        else:
            for category, tokens in category_rules:
                if any(token in normalized for token in tokens):
                    target_dir = stage / "icons" / category
                    break

        if target_dir is None:
            continue
        safe_copy(image_path, target_dir, pack_name)
        counts[target_dir.relative_to(stage).as_posix()] += 1
        classified_count += 1

    required_minimums = {
        "frames": 20,
        "buttons": 20,
        "bars": 10,
        "icons/weapons": 10,
        "icons/armor": 2,
        "icons/gems": 10,
        "icons/skills": 30,
        "icons/potions": 3,
    }
    missing = {
        category: {"actual": counts.get(category, 0), "required": minimum}
        for category, minimum in required_minimums.items()
        if counts.get(category, 0) < minimum
    }
    if classified_count < MINIMUM_PNG_FILES or missing:
        raise RuntimeError(
            "Kenney PNG category quality gate failed: "
            + json.dumps({"classified_png": classified_count, "required_total": MINIMUM_PNG_FILES, "missing_categories": missing}, sort_keys=True)
        )

    manifest = {
        "title": "Kenney CC0 RPG UI and categorized item icon library",
        "source_version": SOURCE_VERSION,
        "repository": REPO_ID,
        "license": "CC0-1.0",
        "sources": provenance,
        "image_format": "PNG only; PSD files are never extracted or parsed",
        "source_png_count": len(images),
        "image_count": classified_count,
        "category_counts": counts,
        "category_quality_gate": required_minimums,
        "godot_destination": "res://assets/ui/",
        "notes": [
            "UI Pack provides separate PNG buttons, sliders/bars and UI glyphs.",
            "UI Pack (RPG Expansion) contributes its official 85-file CC0 UI extension.",
            "Game Icons contributes its official 105-file CC0 icon set.",
            "Fantasy UI Borders supplies ornamental RPG panel frames.",
            "Scribble Dungeons weapon and shield icons are selected from its 128px set.",
            "Rune Pack PNGs are classified as skill/rune icons.",
            "Abstract Platformer and New Platformer Pack gem/crystal assets are selected by filename and source folder.",
            "Board Game Icons flask states are used as potion/flask icons.",
            "Roguelike/RPG source tilesheets are retained only in the temporary audit stage, never mislabeled as item icons.",
            "Unmatched files are not forced into a semantic category.",
        ],
    }
    (stage / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest

def restore_from_hf(api: HfApi, token: str) -> bool:
    existing = api.list_repo_files(repo_id=REPO_ID, repo_type=REPO_TYPE)
    if not any(path.startswith("ui_and_icons/") for path in existing):
        return False
    if CACHE.exists():
        shutil.rmtree(CACHE)
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
    category_counts = manifest.get("category_counts", {})
    required_categories = manifest.get("category_quality_gate", {})
    if any(int(category_counts.get(name, 0)) < int(minimum) for name, minimum in required_categories.items()):
        return False
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True, exist_ok=True)
    for folder_name in ("frames", "buttons", "bars", "icons"):
        source_folder = source / folder_name
        if source_folder.is_dir():
            shutil.copytree(source_folder, DEST / folder_name)
    if manifest_path.is_file():
        shutil.copy2(manifest_path, DEST / "manifest.json")
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
        expected_pack_minimums = {"ui-pack-rpg-expansion": 85, "game-icons": 105}
        expected_minimum = expected_pack_minimums.get(pack_name)
        if expected_minimum is not None and png_count < expected_minimum:
            raise RuntimeError(
                f"Kenney pack {pack_name} has only {png_count} PNG files; "
                f"expected at least {expected_minimum}"
            )
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
        f"KENNEY_PNG_QUALITY_PASS: {manifest['image_count']} categorized PNG files "
        f"(required >50); PSD_IGNORED={ignored_psd_total}"
    )
    if PUBLISH.exists():
        shutil.rmtree(PUBLISH)
    PUBLISH.mkdir(parents=True)
    for folder_name in ("frames", "buttons", "bars", "icons"):
        shutil.copytree(STAGE / folder_name, PUBLISH / folder_name)
    shutil.copy2(STAGE / "manifest.json", PUBLISH / "manifest.json")

    # Remove the previous incomplete bundle so obsolete thumbnails and sprite sheets
    # cannot remain beside the new curated category structure.
    try:
        existing = api.list_repo_files(repo_id=REPO_ID, repo_type=REPO_TYPE)
        if any(path.startswith("ui_and_icons/") for path in existing):
            api.delete_folder(
                path_in_repo="ui_and_icons",
                repo_id=REPO_ID,
                repo_type=REPO_TYPE,
                commit_message="Remove superseded incomplete UI bundle before Kenney refresh",
            )
            print("HF_OLD_UI_BUNDLE_CLEANUP_PASS")
    except Exception as exc:
        print(f"HF_OLD_UI_BUNDLE_CLEANUP_WARNING: {type(exc).__name__}: {exc}")

    api.upload_folder(
        folder_path=str(PUBLISH),
        path_in_repo="ui_and_icons",
        repo_id=REPO_ID,
        repo_type=REPO_TYPE,
        commit_message="Publish categorized Kenney CC0 RPG UI and item icons",
    )
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PUBLISH, DEST)
    print(
        f"HF_KENNEY_RPG_UI_SEED_PASS: images={manifest['image_count']} "
        f"categories={json.dumps(manifest['category_counts'], sort_keys=True)}"
    )
    print(f"Godot destination: {DEST}")

if __name__ == "__main__":
    main()
