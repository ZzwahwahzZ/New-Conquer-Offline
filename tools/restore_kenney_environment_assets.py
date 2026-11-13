#!/usr/bin/env python3
"""Restore official Kenney CC0 environment packs directly into the Godot project.

Only each pack's GLTF-format directory and its license notice are copied.
Archives are hash-pinned, path traversal is rejected, and every model is inventoried.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import struct
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "environment" / "kenney"
PACKS = {
    "nature-kit": {
        "title": "Kenney Nature Kit",
        "url": "https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip",
        "source": "https://kenney.nl/assets/nature-kit",
        "sha256": "fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d",
        "minimum_models": 250,
    },
    "fantasy-town-kit": {
        "title": "Kenney Fantasy Town Kit 2.0",
        "url": "https://kenney.nl/media/pages/assets/fantasy-town-kit/efe948d309-1754222374/kenney_fantasy-town-kit_2.0.zip",
        "source": "https://kenney.nl/assets/fantasy-town-kit",
        "sha256": "1a7530c09f4d2fa2cdee259876f089334f8b1f27fa86a0c4f54ef86cdd8676ef",
        "minimum_models": 120,
    },
    "castle-kit": {
        "title": "Kenney Castle Kit",
        "url": "https://kenney.nl/media/pages/assets/castle-kit/a395102d20-1711543616/kenney_castle-kit.zip",
        "source": "https://kenney.nl/assets/castle-kit",
        "sha256": "921f3f73927bb23106cae34bc21d5ab4b033a9fc120475e96f714a406e3169df",
        "minimum_models": 55,
    },
    "retro-fantasy-kit": {
        "title": "Kenney Retro Fantasy Kit",
        "url": "https://kenney.nl/media/pages/assets/retro-fantasy-kit/cf3f41b752-1774770658/kenney_retro-fantasy-kit.zip",
        "source": "https://kenney.nl/assets/retro-fantasy-kit",
        "sha256": "d3462b453018d0d150406d85af3c4ae1322ceef8f1754c4eb4e6355adfeaab0f",
        "minimum_models": 80,
    },
}
LICENSE_URL = "https://creativecommons.org/publicdomain/zero/1.0/"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, target: Path, referer: str) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (compatible; New-Conquer-Offline-KenneySync/1.0)",
            "Referer": referer,
            "Accept": "application/zip, application/octet-stream;q=0.9, */*;q=0.8",
        },
    )
    with urllib.request.urlopen(request, timeout=120) as response, target.open("wb") as output:
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status} while downloading {url}")
        shutil.copyfileobj(response, output)


def safe_member(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    if path.is_absolute() or any(part in ("..", "") for part in path.parts):
        raise RuntimeError(f"Unsafe archive member: {name}")
    return path


def restore_pack(pack_id: str, metadata: dict) -> dict:
    archive = Path("/tmp") / "kenney-environment-downloads" / f"{pack_id}.zip"
    print(f"KENNEY_PACK_DOWNLOAD_START: {pack_id} url={metadata['url']}", flush=True)
    download(metadata["url"], archive, metadata["source"])
    archive_size = archive.stat().st_size
    with archive.open("rb") as stream:
        archive_magic = stream.read(16)
    digest = sha256(archive)
    print(f"KENNEY_PACK_DOWNLOAD_RESULT: {pack_id} bytes={archive_size} magic={archive_magic.hex()} sha256={digest}", flush=True)
    if digest != metadata["sha256"]:
        raise RuntimeError(f"{pack_id} archive hash mismatch: expected {metadata['sha256']}, got {digest}")

    if not zipfile.is_zipfile(archive):
        raise RuntimeError(f"{pack_id} downloaded file is not a ZIP: url={metadata['url']} bytes={archive_size} magic={archive_magic!r} sha256={digest}")

    target = DEST / pack_id
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True, exist_ok=True)
    model_paths: list[str] = []
    license_found = False

    with zipfile.ZipFile(archive) as package:
        bad = package.testzip()
        if bad:
            raise RuntimeError(f"{pack_id} ZIP integrity failure at {bad}")
        for item in package.infolist():
            if item.is_dir():
                continue
            relative = safe_member(item.filename)
            normalized = relative.as_posix()
            lower = normalized.lower()
            is_gltf_asset = ("/models/gltf format/" in ("/" + lower) or "/models/glb format/" in ("/" + lower)) and lower.endswith((".glb", ".gltf", ".bin", ".png", ".jpg", ".jpeg"))
            is_license = relative.name.lower() in {"license.txt", "license"}
            if not (is_gltf_asset or is_license):
                continue
            destination = target.joinpath(*relative.parts)
            destination.parent.mkdir(parents=True, exist_ok=True)
            with package.open(item) as source, destination.open("wb") as output:
                shutil.copyfileobj(source, output)
            if lower.endswith((".glb", ".gltf")):
                model_paths.append(destination.relative_to(ROOT).as_posix())
            if is_license:
                license_found = True

    if len(model_paths) < metadata["minimum_models"]:
        raise RuntimeError(f"{pack_id} contains only {len(model_paths)} GLTF models; expected at least {metadata['minimum_models']}")
    if not license_found:
        raise RuntimeError(f"{pack_id} archive did not include its License.txt")

    for model in model_paths:
        path = ROOT / model
        if path.suffix.lower() == ".glb":
            data = path.read_bytes()[:12]
            if len(data) != 12 or data[:4] != b"glTF":
                raise RuntimeError(f"Invalid GLB header: {model}")
            version, declared_length = struct.unpack_from("<II", data, 4)
            if version != 2 or declared_length != path.stat().st_size:
                raise RuntimeError(f"Invalid GLB length/version: {model}")

    return {
        "id": pack_id,
        "title": metadata["title"],
        "source": metadata["source"],
        "download_url": metadata["url"],
        "license": "CC0-1.0",
        "license_url": LICENSE_URL,
        "archive_sha256": digest,
        "model_count": len(model_paths),
        "models": model_paths,
    }


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    packs = [restore_pack(pack_id, metadata) for pack_id, metadata in PACKS.items()]
    manifest = {
        "version": 1,
        "license_policy": "Official Kenney packs, CC0-1.0; retain included License.txt files.",
        "packs": packs,
        "model_count": sum(pack["model_count"] for pack in packs),
    }
    path = DEST / "kenney_environment_manifest.json"
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"KENNEY_CC0_ENVIRONMENT_RESTORED: packs={len(packs)} models={manifest['model_count']}")
    for pack in packs:
        print(f"KENNEY_PACK_PASS: {pack['id']} models={pack['model_count']} sha256={pack['archive_sha256']}")


if __name__ == "__main__":
    main()
