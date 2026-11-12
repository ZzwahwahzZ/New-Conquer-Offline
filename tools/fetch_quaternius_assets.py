#!/usr/bin/env python3
"""Fetch a pinned, public CC0 Quaternius GLB subset from GitHub; no Google Drive."""
from __future__ import annotations
import hashlib, json, os, shutil, struct, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = Path(os.environ.get("QUATERNIUS_CACHE", str(Path.home()/".cache"/"quaternius")))
DEST = ROOT / "assets" / "environment" / "quaternius"
SOURCE_REPO = "trebeljahr/quaternius-showcase"
SOURCE_COMMIT = "0128ca510d653bb04d6d1e4885bd8890b5050b4f"
RAW = f"https://raw.githubusercontent.com/{SOURCE_REPO}/{SOURCE_COMMIT}/public/glb"

# Only files whose pack-level CC0 status is documented in the source repository's
# LICENSES.md. These are individual, engine-ready GLB models, not whole-pack mirrors.
ASSETS = {
    "ultimate_fantasy_rts": [
        "real_time_strategy_pack/Houses_FirstAge_1_Level1.glb",
        "real_time_strategy_pack/Houses_FirstAge_2_Level1.glb",
        "real_time_strategy_pack/Houses_FirstAge_3_Level1.glb",
        "real_time_strategy_pack/Houses_SecondAge_1_Level1.glb",
        "real_time_strategy_pack/TowerHouse_FirstAge.glb",
        "real_time_strategy_pack/WatchTower_FirstAge_Level1.glb",
        "real_time_strategy_pack/Wall_FirstAge.glb",
        "real_time_strategy_pack/WallTowers_FirstAge.glb",
        "real_time_strategy_pack/WallTowers_Door_FirstAge.glb",
        "real_time_strategy_pack/WallTowers_DoorClosed_FirstAge.glb",
    ],
    "modular_medieval_buildings": [
        "modular_medieval_buildings_pack/Bridge.glb",
        "modular_medieval_buildings_pack/LargeSimpleTower.glb",
        "modular_medieval_buildings_pack/LargeSquareTower.glb",
        "modular_medieval_buildings_pack/LargeTower.glb",
        "modular_medieval_buildings_pack/PointyTower.glb",
        "modular_medieval_buildings_pack/TallWall.glb",
        "modular_medieval_buildings_pack/TallWallEntrance.glb",
        "modular_medieval_buildings_pack/Wall.glb",
        "modular_medieval_buildings_pack/WallEntrance.glb",
        "modular_medieval_buildings_pack/WatchTowerWRoof.glb",
        "modular_medieval_buildings_pack/Watchtower.glb",
    ],
    "ultimate_stylized_nature": [
        "nature_pack/BirchTree_1.glb",
        "nature_pack/BirchTree_Snow_1.glb",
        "nature_pack/BirchTree_Dead_1.glb",
        "nature_pack/CommonTree_1.glb",
        "nature_pack/PineTree_1.glb",
        "nature_pack/PineTree_Snow_1.glb",
        "nature_pack/PalmTree_1.glb",
        "nature_pack/Bush_1.glb",
        "nature_pack/Rock_1.glb",
        "nature_pack/Rock_2.glb",
        "nature_pack/Rock_Moss_1.glb",
        "nature_pack/Rock_Snow_1.glb",
    ],
}

def fetch(url: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "New-Conquer-Offline-AssetSync/2.0"})
    with urllib.request.urlopen(request, timeout=90) as response, target.open("wb") as out:
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status}: {url}")
        shutil.copyfileobj(response, out)
    data = target.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF":
        target.unlink(missing_ok=True)
        raise RuntimeError(f"Invalid GLB payload: {url}")
    version, declared = struct.unpack_from("<II", data, 4)
    if version != 2 or declared != len(data):
        target.unlink(missing_ok=True)
        raise RuntimeError(f"Invalid GLB header/length: {url} ({version}, {declared}, {len(data)})")

def main() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {
        "source_repository": f"https://github.com/{SOURCE_REPO}",
        "source_commit": SOURCE_COMMIT,
        "license_reference": f"https://github.com/{SOURCE_REPO}/blob/{SOURCE_COMMIT}/LICENSES.md",
        "asset_license": "CC0-1.0 per individual pack entries in LICENSES.md",
        "policy": "Pinned direct GitHub raw downloads; local game integration; no Google Drive; no standalone pack mirroring.",
        "assets": [],
    }
    total = 0
    for pack, paths in ASSETS.items():
        for source_path in paths:
            name = Path(source_path).name
            cached = CACHE / pack / name
            if not cached.is_file() or cached.stat().st_size < 20 or cached.read_bytes()[:4] != b"glTF":
                fetch(f"{RAW}/{source_path}", cached)
            target = DEST / pack / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(cached, target)
            digest = hashlib.sha256(target.read_bytes()).hexdigest()
            size = target.stat().st_size
            total += size
            manifest["assets"].append({"pack": pack, "source_path": source_path, "path": str(target.relative_to(ROOT)).replace("\\","/"), "bytes": size, "sha256": digest, "license": "CC0-1.0"})
            print(f"QUATERNIUS_GITHUB_CC0_READY: {pack}/{name} bytes={size}")
    (DEST / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    expected = sum(map(len, ASSETS.values()))
    if len(manifest["assets"]) != expected:
        raise SystemExit("Quaternius asset count mismatch")
    print(f"QUATERNIUS_GITHUB_CC0_PASS: models={expected} bytes={total} source_commit={SOURCE_COMMIT}")

if __name__ == "__main__":
    main()
