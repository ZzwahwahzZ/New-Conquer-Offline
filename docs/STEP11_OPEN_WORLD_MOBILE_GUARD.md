# Step 11 — Open World, Six Settlements, Monster Sanctuaries & Mobile Guard

## Commit scope
This step adds a local, offline world layer without changing the Autoload list/order or the gold-only currency rules.

## Six open-world settlement scenes
| Scene | Classic level band | Environment |
|---|---:|---|
| TwinCity | 1–15 | Green meadow / temperate fog |
| DesertLand | 15–40 | Sand / warm haze |
| VolcanoLand | 40–70 | Dark volcanic ground / warm ash fog |
| IceLand | 70–95 | Snow and ice / cold fog |
| Waterlands | 95–115 | Water-country palette / blue fog |
| DarkForest | 115–130+ | Dark forest / dense green-grey fog |

Each scene has a 180×180 walkable terrain shell, its own WorldEnvironment and directional light, twelve boundary landmarks, named future asset attachment slots (terrain, architecture, foliage, ambient FX), and named spawn/sanctuary/portal anchors. These are intentionally asset-ready placeholders, not claims that final production terrain meshes or art textures have already been integrated.

## Monster catalogue and animation rig slot
- Added an offline MonsterDatabase with classic field creatures including Pheasant, Turtledove, Apparition, Bandit, Sand Monster, Giant Ape and Birdman, plus region-specific monsters.
- Each spawned monster uses Monster.tscn / Monster.gd, a CharacterBody3D collider, Skeleton3D parent, HighDetailRigSlot, AnimationPlayer, and Idle / Run / Attack / Hit / Death animation clips.
- The rig slot currently contains a capsule proxy. It is a stable attachment point for the high-detail character meshes and real skeletal animation assets in a later art integration pass; it is not represented as a finished high-detail character model.

## Open monster sanctuaries
- Two geographically separated open sanctuary anchors are present in every settlement at world positions (66, 0, 62) and (-68, 0, -60).
- Sanctuary rings and four emissive pillars mark the locations without enclosing them behind gates.
- Each settlement has rare sanctuary creatures and a boss. Sanctuary kills grant double gold and two units of class-compatible weapon gear, plus double monster material compared with a normal kill.

## Portals, quick travel and minimap
- A luminous portal at (0, 0, -78) connects each settlement to the next in the progression loop.
- The HUD includes an M-key / on-screen quick-travel panel with all six local destinations.
- MiniMapUI draws the player, nearby monsters and portal, and displays classic-style X/Y coordinates derived from world X/Z (origin 500, scale 4 coordinate units per world unit).
- WorldTeleporter validates destination IDs and performs local scene transitions; no server or network calls are involved.

## Mobile performance and memory guard
- WorldManager maintains bounded pools: up to 24 monsters, 32 gold pickups and 12 hit-effect meshes.
- Monsters outside a 58-world-unit camera radius are put into sleep mode; physics and their AnimationPlayer stop until they return to range.
- Health-bar SubViewport rendering is set to UPDATE_WHEN_VISIBLE.
- On settlement change, active drops/monsters/effects are recycled and the previous scene is freed. The next settlement is loaded with Godot's `ResourceLoader.CACHE_MODE_IGNORE_DEEP`, avoiding retention of its scene and subresources in the global resource cache; the old node tree is allowed one frame to leave the scene tree before the new map is instantiated.
- These are conservative mobile safeguards, not a measured FPS or thermal benchmark. Device profiling is still required.

## Mobile auto-save
- GlobalEconomy listens for NOTIFICATION_APPLICATION_PAUSED and NOTIFICATION_WM_CLOSE_REQUEST.
- The save guard snapshots character progression, serialized equipment/inventory, settlement ID and player world position, then writes the existing local save envelope. Gold remains the sole currency and the existing save format is retained.

## Files added / changed
- Added: `src/scripts/WorldManager.gd`, `MonsterDatabase.gd`, `Monster.gd`, `SettlementWorld.gd`, `WorldTeleporter.gd`, `MiniMapUI.gd`
- Added six scenes under `src/scenes/world/`, plus `src/scenes/Monster.tscn` and `src/scenes/CPDrop.tscn`
- Updated: `scripts/main.gd`, `src/scripts/HUD.gd`, `src/scripts/Enemy.gd`, `src/scripts/CPDrop.gd`, `src/scripts/GlobalEconomy.gd`, `src/scripts/GearDatabase.gd`
- Added: `scripts/step11_smoke_test.gd`

## Validation boundary
- Source and resource wiring are checked in the included Godot 4.3 headless smoke test.
- Godot is not installed in the current execution environment. Therefore the parser/import/runtime smoke test, scene traversal, mobile FPS/thermal profiling, and on-device pause/close save test have not been executed here. The commit report does not claim those runtime checks passed.
