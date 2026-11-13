# Twin City — Imperial China visual prototype

Isolated Godot 4.3 project. It does not modify the existing TwinCity scene or any of the other five city scenes.

- Reads the approved asset list at assets/wuxia_imperial_pack/imperial_approved_assets.json.
- Restores selected Imperial China, approved nature and PBR files from the private Hugging Face dataset into ignored asset_cache/.
- Architectural structures are approved GLB instances only. No BoxMesh is used for buildings, walls, gates, bridges, stairs or palace.
- 170 m × 170 m walled core inside an 800 m × 800 m world; 71 building instances across six approved Chinese/Korean architectural asset types and 350 MultiMesh tree instances. The central palace occupies a two-tier raised stone terrace with broad stair access; mixed residential and market blocks surround the imperial axis.
- GitHub Actions runs Godot 4.3 under Xvfb at 1920 × 1080 and commits only the two screenshots and compact report to the review branch.
- Downloaded assets and Godot import cache are never committed.
