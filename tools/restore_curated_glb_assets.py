#!/usr/bin/env python3
"""Fetch curated CC0 GLB environment kits for local integration only; never mirror model files to Hugging Face."""
from __future__ import annotations
import hashlib
import json
import struct
import urllib.request
from pathlib import Path

DEST = Path(__file__).resolve().parents[1] / "assets" / "environment"
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
    "biomes/volcano_and_lava_fields.glb": {
        "url": "https://cdn.3dassets.dev/assets/37488/v1/model.glb",
        "title": "Volcano and Lava Fields starter scene",
        "license": "CC0 1.0 Universal",
        "source": "https://3dassets.dev/packs/volcano-and-lava-fields",
    },
    "biomes/jungle_temple_and_stone_city.glb": {
        "url": "https://cdn.3dassets.dev/assets/36160/v1/model.glb",
        "title": "Jungle Temple and Stone City starter scene",
        "license": "CC0 1.0 Universal",
        "source": "https://3dassets.dev/packs/jungle-temple-and-stone-city",
    },
    "nature/date_palm.glb": {
        "url": "https://cdn.3dassets.dev/assets/38136/v1/model.glb",
        "title": "Date Palm",
        "license": "CC0 1.0 Universal",
        "source": "https://3dassets.dev/assets/desert-mosque-and-madrasa-courtyard-date-palm-c311e205",
    },
    "nature/willow_tree.glb": {
        "url": "https://cdn.3dassets.dev/assets/28780/v1/model.glb",
        "title": "Willow Tree",
        "license": "CC0 1.0 Universal",
        "source": "https://3dassets.dev/assets/medieval-mmo-starter-realm-willow-tree-e1efef2c",
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
    manifest = {"license_policy": "CC0 1.0 only; local game integration; no standalone asset redistribution.", "assets": []}
    for relative, metadata in SOURCES.items():
        target = DEST / relative
        download(metadata["url"], target)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        manifest["assets"].append({
            **metadata, "path": relative, "bytes": target.stat().st_size,
            "sha256": digest, "glb_version": 2,
        })
        print(f"CC0_GLB_READY: {relative} bytes={target.stat().st_size} sha256={digest}")
    manifest_path = DEST / "curated_glb_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"CURATED_CC0_GLB_LOCAL_PASS: {len(manifest['assets'])} assets; Hugging Face untouched")

if __name__ == "__main__":
    main()
