# Twin City — Imperial China visual prototype

Isolated Godot 4.3 project. It does not modify the existing TwinCity scene or any of the other five city scenes.

- Reads the approved asset list at assets/wuxia_imperial_pack/imperial_approved_assets.json.
- Restores selected Imperial China, approved nature and PBR files from the private Hugging Face dataset into ignored asset_cache/.
- Architectural structures are approved GLB instances only. No BoxMesh is used for buildings, walls, gates, bridges, stairs or palace.
- 260 m organic circular/irregular walled core inside an 800 m × 800 m world, with a central circular engraved-paving plaza, a raised imperial palace on the city-front axis, 10 dense radial mixed-use blocks, 80 district buildings, 40 shopfronts with shopkeeper spawn markers, 4 gates, 4 bridges and 350 MultiMesh tree instances. Four shops frame each block while taller residences fill its interior.
- Lighting exposure and directional energy are reduced to prevent washed-out surfaces while retaining the current asset materials. The exact palette must be checked against the original generated concept reference before any further color/material edits.
- GitHub Actions runs Godot 4.3 under Xvfb at 1920 × 1080 and commits only the two screenshots and compact report to the review branch after all validations pass.
- Downloaded assets and Godot import cache are never committed.
