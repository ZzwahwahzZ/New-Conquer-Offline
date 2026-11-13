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
        "required_models": ["bridge_wood.glb", "bridge_stone.glb"],
    },
    "fantasy-town-kit": {
        "title": "Kenney Fantasy Town Kit 2.0",
        "url": "https://kenney.nl/media/pages/assets/fantasy-town-kit/efe948d309-1754222374/kenney_fantasy-town-kit_2.0.zip",
        "source": "https://kenney.nl/assets/fantasy-town-kit",
        "sha256": "1a7530c09f4d2fa2cdee259876f089334f8b1f27fa86a0c4f54ef86cdd8676ef",
        "required_models": ["stall-red.glb", "stall-green.glb", "fountain-square.glb", "windmill.glb", "watermill.glb"],
    },
    "castle-kit": {
        "title": "Kenney Castle Kit",
        "url": "https://kenney.nl/media/pages/assets/castle-kit/a395102d20-1711543616/kenney_castle-kit.zip",
        "source": "https://kenney.nl/assets/castle-kit",
        "sha256": "921f3f73927bb23106cae34bc21d5ab4b033a9fc120475e96f714a406e3169df",
        "required_models": ["gate.glb", "tower-square.glb", "wall.glb"],
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
        members = {safe_member(item.filename).as_posix(): item for item in package.infolist() if not item.is_dir()}
        expected_models = set(metadata["required_models"])
        selected: set[str] = set()
        model_member_paths: dict[str, str] = {}
        for member_name, item in members.items():
            relative = PurePosixPath(member_name)
            lower = member_name.lower()
            is_model_directory = "/models/gltf format/" in ("/" + lower) or "/models/glb format/" in ("/" + lower)
            if is_model_directory and relative.name in expected_models and lower.endswith(".glb"):
                selected.add(member_name)
                model_member_paths[relative.name] = member_name
            if relative.name.lower() in {"license.txt", "license"}:
                selected.add(member_name)
                license_found = True
        if set(model_member_paths) != expected_models:
            missing = sorted(expected_models - set(model_member_paths))
            raise RuntimeError(f"{pack_id} is missing required models: {missing}")
        # Resolve only the external resources explicitly referenced by selected GLBs.
        for model_name, member_name in model_member_paths.items():
            item = members[member_name]
            with package.open(item) as source:
                header = source.read(20)
                if len(header) < 20 or header[:4] != b"glTF":
                    raise RuntimeError(f"Invalid GLB header in archive: {member_name}")
                version, declared_length = struct.unpack_from("<II", header, 4)
                json_length, json_kind = struct.unpack_from("<II", header, 12)
                if version != 2 or json_kind != 0x4E4F534A or declared_length != item.file_size or 20 + json_length > item.file_size:
                    raise RuntimeError(f"Invalid GLB JSON chunk in archive: {member_name}")
                json_bytes = source.read(json_length)
            document = json.loads(json_bytes.rstrip(b" \\t\\r\\n\\0").decode("utf-8"))
            for resource in document.get("images", []) + document.get("buffers", []):
                uri = resource.get("uri")
                if not uri or uri.startswith("data:"):
                    continue
                if uri.startswith("/") or "\\\\" in uri:
                    raise RuntimeError(f"Unsafe external GLB resource URI: {member_name}: {uri}")
                dependency = (PurePosixPath(member_name).parent / PurePosixPath(uri)).as_posix()
                dependency_path = safe_member(dependency)
                if dependency_path.as_posix() not in members:
                    raise RuntimeError(f"Missing referenced GLB resource: {member_name} -> {uri}")
                selected.add(dependency_path.as_posix())
        for member_name in sorted(selected):
            item = members[member_name]
            relative = safe_member(member_name)
            destination = target.joinpath(*relative.parts)
            destination.parent.mkdir(parents=True, exist_ok=True)
            with package.open(item) as source, destination.open("wb") as output:
                shutil.copyfileobj(source, output)
            if relative.name in expected_models and relative.suffix.lower() == ".glb":
                model_paths.append(destination.relative_to(ROOT).as_posix())
    expected_models = set(metadata["required_models"])
    extracted_names = {Path(model).name for model in model_paths}
    missing_models = sorted(expected_models - extracted_names)
    if missing_models:
        raise RuntimeError(f"{pack_id} is missing required models: {missing_models}")
    if extracted_names != expected_models:
        raise RuntimeError(f"{pack_id} extracted unexpected models: {sorted(extracted_names - expected_models)}")
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
