# Twin City — House & Shop Asset Research Queue

This file tracks source-original candidates only. A candidate is **not** part of the downloaded asset library until its original archive is obtained and verified. No paid assets are approved.

## CGTrader

| Asset | Model ID | License / use | Formats and quality | Status |
|---|---:|---|---|---|
| Chinese Ancient house (reference sample) | 3589754 | Royalty Free; personal and commercial use | FBX (2 files, 95.7 MB), OBJ (542 KB), textures (112 MB); 7,328 polygons / 4,076 vertices; verified FBX; 2K PBR; non-overlapping UVs | Download page requires a signed-in CGTrader session; not downloaded here |
| Ancient Traditional Chinese Building | 3328346 | Royalty Free; personal and commercial use | OBJ 49.8 MB; low-poly, PBR, textures, materials, UV mapping; UVs reported overlapping | Free candidate; needs file download and visual/UV QA; not downloaded |
| Chinese Arch | 4718834 | Royalty Free; personal and commercial use | FBX 230 KB; low-poly; UV status unknown | Architectural accent only, not a house/shop; not downloaded |
| Chinese Wooden Ancient House | 7571512 | Paid listing ($60), despite a misleading free-model URL | FBX 15.7 MB, GLTF 28.2 MB, JPG textures 68.4 MB; verified FBX, PBR maps, non-overlapping UVs; 225,151 polygons / 200,609 vertices | Excluded — paid |

CGTrader download access: its documented free-download flow redirects to a preparation/download page. Its developer API uses OAuth 2.0; file listing and file download endpoints are authenticated. No session cookie, OAuth secret, or API token is stored in this repository or available to this workflow. Do not attempt to bypass CGTrader access controls.

## Sketchfab — free downloadable CC BY candidates

| Asset | License | Geometry / notes | Status |
|---|---|---|---|
| Chinese ancient house — https://sketchfab.com/3d-models/chinese-ancient-house-48555048c4c540a78d23f055ca55a569 | CC BY | 7.6k triangles / 4.4k vertices; author says Blender source and FBX included | Candidate; Sketchfab download authorization required; not downloaded |
| Ancient Chinese House — https://sketchfab.com/3d-models/ancient-chinese-house-bcb41894d1b5451b9c4f6489d50766d4 | CC BY | 4k triangles / 2.6k vertices; uploaded with Substance Painter | Candidate; download authorization required; not downloaded |
| Chinese ancient building_H26 — https://sketchfab.com/3d-models/chinese-ancient-building-h26-99d2ab2816914c46949b3f6a1bc7ae4d | CC BY | 6.5k triangles / 4.4k vertices | Candidate; download authorization required; not downloaded |
| Chinese hut — https://sketchfab.com/3d-models/chinese-hut-1b9c99b0fa9d49b88c4aa5b8c9c097da | CC BY | 40k triangles; pagoda-style building, curved tiled roofs and red pillars | Candidate; download authorization required; not downloaded |
| Chinese old house — https://sketchfab.com/3d-models/chinese-old-house-f757baa75e8f4db68cc048acc0c1a69e | CC BY-NC | 73.6k triangles; high-quality textured scene | Excluded — non-commercial license |
| Traditional Chinese House (Low Poly / Stylized) — https://sketchfab.com/3d-models/traditional-chinese-house-low-poly-stylized-0f5fbcbf1489432a81e372e6d38699dd | CC BY | 236.9k triangles; curved tiled roof, wooden windows, raised stone platform | Candidate, but relatively heavy for mobile; download authorization required |
| Small Chinese imperial style building — https://sketchfab.com/3d-models/small-chinese-imperial-style-building-631615777ba4421a98814559dc2d4c5a | CC BY | 681.6k triangles / 346.1k vertices; Forbidden City-inspired hip-and-gable roof | Excluded from mobile shortlist unless a lighter original LOD is available |

## Existing downloaded originals

- `chinese-historical-houses/courtyard-residence-342ac2.glb`
- `chinese-historical-shops/market-stall-9d0b29.glb`

These are the only models represented as downloaded in the current collection manifest. Research candidates above must not be counted as downloaded assets.

## Next acquisition requirements

1. Obtain CGTrader files through an authorized signed-in account/download flow or approved OAuth API credentials.
2. Obtain Sketchfab files through an authorized download token/account.
3. Preserve original archive contents, textures, metadata, and required attribution.
4. Verify archive integrity, model format, texture references, UVs, polygon counts, and mobile suitability before adding any candidate to the downloaded collection.
