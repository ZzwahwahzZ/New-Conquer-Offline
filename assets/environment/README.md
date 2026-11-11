# Environment Asset Library

Canonical runtime root for environment assets.

- `materials/<pack>/albedo.jpg`
- `materials/<pack>/normal.jpg`
- `materials/<pack>/roughness.jpg`
- `heightmaps/*.png`
- `models/*.glb`

The current CI fetcher pulls the existing public Hugging Face terrain dataset:
`ZzwahwahzZ/clash-of-legends-terrain-assets`.

Initial verified source inventory: five 16-bit settlement heightmaps, seven PBR source archives, and four general-purpose GLB models. These are terrain/landform sources, not a complete Chinese architecture library. Only assets with explicit CC0/MIT or compatible redistribution terms should be added. Do not copy proprietary client assets into this directory.

Target biomes: TwinCity, DesertLand, VolcanoLand, IceLand, Waterlands, DarkForest.
