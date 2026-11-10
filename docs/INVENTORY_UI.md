# Inventory UI — Step 7

## Files
- `src/scenes/InventoryUI.tscn`: CanvasLayer entry scene (layer 30).
- `src/scripts/InventoryUI.gd`: builds the landscape UI and preview rig at runtime.
- `src/scripts/HUD.gd`: adds the top-right inventory button and instantiates the scene.
- `scripts/main.gd`: routes the I key to the `inventory_ui` group.
- `project.godot`: requests landscape handheld orientation.

## Runtime node tree

```text
InventoryUI (CanvasLayer, layer 30)
└── InventoryRoot (Control, full rect)
    ├── DimBackground (ColorRect)
    └── InventoryFrame (PanelContainer)
        └── VBoxContainer
            ├── Header (title + close button)
            └── Content (HBoxContainer)
                ├── CharacterColumn (VBoxContainer)
                │   ├── PreviewPanel
                │   │   └── SubViewportContainer
                │   │       └── SubViewport
                │   │           ├── WorldEnvironment
                │   │           ├── Camera3D
                │   │           ├── DirectionalLight3D
                │   │           ├── OmniLight3D
                │   │           └── CharacterPivot
                │   │               ├── Skeleton3D
                │   │               │   ├── RightHandMount (BoneAttachment3D)
                │   │               │   ├── LeftHandMount (BoneAttachment3D)
                │   │               │   ├── BodyMount (BoneAttachment3D)
                │   │               │   └── HelmetMount (BoneAttachment3D)
                │   │               └── Procedural mannequin meshes
                │   ├── ATK / DEF / HP summary
                │   └── Seven equipment-slot buttons
                └── InventoryColumn (VBoxContainer)
                    ├── Bag header + page counter
                    ├── ScrollContainer
                    │   └── GridContainer (6 columns × 30 slots/page)
                    ├── Previous / Next controls
                    └── Item details + Equip / Unequip button
```

## Controls and data flow
- HUD button: `HUDRoot/InventoryToggleButton`; opens/closes the inventory.
- Keyboard: `I`; routed from `main.gd` to the `inventory_ui` group.
- Close button: calls `InventoryUI.close()`.
- Equipment/inventory are read from `GearSystem.inventory` and `GearSystem.equipment`.
- Equip and unequip use `GearSystem.equip_item()` / `GearSystem.unequip_item()`; changes refresh from GearSystem signals.
- Character class and level are read from `GameState.profile`.

## Visual integration boundary
The repository's current world player is a primitive capsule and does not yet provide a production humanoid Skeleton3D, skin, armor scenes, or weapon scenes. This screen therefore builds a self-contained preview skeleton/mannequin and representative equipment meshes. BoneAttachment3D mounts, rotation, slot updates, quality borders, socket indicators, and plus-level emission/light are wired. Replace the procedural mannequin and representative meshes with the final character/weapon/armor PackedScenes when those assets are ready. The current GearDatabase defines Normal, Refined, Unique, and Super; the UI also has an Elite color mapping for incoming item data, but no Elite item blueprints have been added.

## Validation
Files were committed to `main` and fetched back from GitHub. Godot 4.3 is not installed in the available execution environment, so editor import, parser, and runtime interaction tests have not yet been run.
