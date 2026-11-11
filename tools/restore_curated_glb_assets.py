#!/usr/bin/env python3
"""Fetch curated CC0 GLB environment kits, validate them, and mirror them to the HF dataset."""
from __future__ import annotations
import hashlib
import json
import os
import struct
import urllib.request
from pathlib import Path
from huggingface_hub import HfApi

REPO_ID = "ZzwahwahzZ/clash-of-legends-terrain-assets"
DEST = Path(__file__).resolve().parents[1] / "assets" / "environment"
HF_PREFIX = "settlement-terrain-source/curated-glb"
SOURCES = {
    "architecture/imperial_china_palace_and_garden.glb": {
        "url": "https://cdn.3dassets.dev/assets/36222/v1/model.glb",
        "title": "Imperial China Palace and Garden starter scene",
        "license": "CC0 1.0 Universal",
        "source": "https://3dassets.dev/packs/imperial-china-palace-and-garden",
    },
    "nature/stylized_trees_and_rocks.glb": {
        "url": "https://cdn.3dassets.dev/assets/38765/v1/model.glb",
        "title": "Stylized Trees and Rocks Kit starter scene",
        "license": "CC0 1.0 Universal",
        "source": "https://3dassets.dev/packs/stylized-trees-and-rocks-kit",
    },
    "nature/alpine_and_arctic_biomes.glb": {
        "url": "https://cdn.3dassets.dev/assets/21062/v1/model.glb",
        "title": "Snow, Ice and Mountain Nature starter scene",
        "license": "CC0 1.0 Universal",
        "source": "https://3dassets.dev/packs/alpine-and-arctic-biomes",
    },
}

def download(url: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "New-Conquer-Offline-AssetSync/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response, target.open("wb") as out:
        if response.status != 200:
            raise RuntimeError(f"Download failed ({response.status}): {url}")
        while True:
            block = response.read(1024 * 1024)
            if not block:
                break
            out.write(block)
    data = target.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        raise RuntimeError(f"Not a binary glTF/GLB file: {target}")
    version, declared_length = struct.unpack_from("<II", data, 4)
    if version != 2 or declared_length != len(data):
        raise RuntimeError(f"Invalid GLB header/length: {target} version={version} declared={declared_length} actual={len(data)}")

def main() -> None:
    token = os.environ.get("HF_TOKEN", "").strip()
    if not token:
        raise SystemExit("HF_TOKEN is required to mirror curated CC0 GLB files to Hugging Face.")
    api = HfApi(token=token)
    manifest = {"repo_id": REPO_ID, "license_policy": "Only CC0 1.0 assets are admitted.", "assets": []}
    for relative, metadata in SOURCES.items():
        target = DEST / relative
        download(metadata["url"], target)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        path_in_repo = f"{HF_PREFIX}/{relative}"
        api.upload_file(
            path_or_fileobj=str(target),
            path_in_repo=path_in_repo,
            repo_id=REPO_ID,
            repo_type="dataset",
            commit_message=f"Add CC0 environment asset: {Path(relative).name}",
        )
        manifest["assets"].append({
            **metadata,
            "path": relative,
            "hf_path": path_in_repo,
            "bytes": target.stat().st_size,
            "sha256": digest,
            "glb_version": 2,
        })
        print(f"CC0_GLB_READY: {relative} bytes={target.stat().st_size} sha256={digest}")
    manifest_path = DEST / "curated_glb_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    api.upload_file(
        path_or_fileobj=str(manifest_path),
        path_in_repo=f"{HF_PREFIX}/curated_glb_manifest.json",
        repo_id=REPO_ID,
        repo_type="dataset",
        commit_message="Add curated CC0 GLB asset manifest",
    )
    print(f"CURATED_CC0_GLB_SYNC_PASS: {len(manifest['assets'])} assets mirrored to HF")

if __name__ == "__main__":
    main()
