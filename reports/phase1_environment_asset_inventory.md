# Phase 1 Environment Asset Inventory

Inventory checked against the current `main` tree and Hugging Face Hub on 2026-11-12.

## Existing Hugging Face sources

Dataset: `ZzwahwahzZ/clash-of-legends-terrain-assets`

| Resource | Verified inventory | Runtime use |
|---|---:|---|
| Settlement heightmaps | 5 16-bit PNGs: volcanic caldera, glacial mountains, tropical archipelago, desert dunes, dark forest valleys | Restored to `assets/environment/heightmaps/` |
| PBR ground materials | 7 ZIP archives: Ground044, Ground053, Ground061, Lava001, Rock027, Snow008C, Rock014 | Restorer extracts and normalizes maps; requires at least five |
| Curated GLB environment kits | 7: imperial China palace/garden, jungle temple/stone city, volcano/lava fields, alpine/arctic biomes, date palm, stylized trees/rocks, willow tree | Downloaded by the curated GLB restore script to the runtime asset folders |
| Unclassified GLBs | 4 files in `models/unclassified` | Explicitly excluded from automatic runtime restoration pending classification |

The dataset also contains a large `project-assets/legacy_client` tree. Those legacy client resources are not treated as redistributable environment assets and are not copied into the game's CC0 asset library.

## Direct, pinned Quaternius CC0 models

Source repository: `trebeljahr/quaternius-showcase`, pinned commit `0128ca510d653bb04d6d1e4885bd8890b5050b4f`.
Per-pack CC0-1.0 declarations and original Quaternius pack URLs are recorded in the source repository's `LICENSES.md`.

The CI downloader selects 33 individual GLB models (not whole-pack archives):

- **Buildings (10):** Houses_FirstAge_1_Level1, Houses_FirstAge_2_Level1, Houses_FirstAge_3_Level1, Houses_SecondAge_1_Level1, TowerHouse_FirstAge, WatchTower_FirstAge_Level1, Wall_FirstAge, WallTowers_FirstAge, WallTowers_Door_FirstAge, WallTowers_DoorClosed_FirstAge.
- **Modular fortifications and crossings (11):** Bridge, LargeSimpleTower, LargeSquareTower, LargeTower, PointyTower, TallWall, TallWallEntrance, Wall, WallEntrance, WatchTowerWRoof, Watchtower.
- **Nature (12):** BirchTree_1, BirchTree_Snow_1, BirchTree_Dead_1, CommonTree_1, PineTree_1, PineTree_Snow_1, PalmTree_1, Bush_1, Rock_1, Rock_2, Rock_Moss_1, Rock_Snow_1.

Every downloaded GLB is validated for the binary glTF v2 header and declared byte length, copied into the Godot runtime folders, and hashed into `assets/environment/quaternius/manifest.json`. GitHub Actions caches the pinned source assets under `~/.cache/quaternius`.

## World and camera configuration

- All six settlement terrain extents are configured to 800 x 800.
- The isometric camera default pitch is 38 degrees; its Camera3D local X rotation is -38 degrees.
- The visual proof capture uses the same 38-degree pitch and is intended to produce five views per settlement (30 total).

## Verification boundary

This is a source inventory and implementation record, not a claim that the new assets have already passed Godot import or visual QA. That requires a successful current CI run, all smoke tests, and inspection of all 30 newly captured PNGs.
