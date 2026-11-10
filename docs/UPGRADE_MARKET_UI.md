# Step 8 — Upgrade Market UI

## Added and updated files
- `src/scripts/GearDatabase.gd`: five item qualities, level tiers through 130, two-socket capacity, seven gem families with Normal / Refined / Super grades.
- `src/scripts/GearSystem.gd`: item-id-based level and quality upgrades, safe +1/+2 composition stones, socket opening and gem replacement, save and UI signals.
- `src/scenes/UpgradeMarketUI.tscn`: market CanvasLayer entry scene.
- `src/scripts/UpgradeMarketUI.gd`: three-tab landscape market interface.
- `src/scripts/HUD.gd`: Market / Upgrade button.
- `scripts/main.gd`: U shortcut.
- `src/scripts/InventoryUI.gd`: socket circles distinguish filled, open-empty, and locked sockets.

## UpgradeMarketUI runtime node tree

```text
UpgradeMarketUI (CanvasLayer, layer 31)
└── MarketDim (ColorRect)
    └── UpgradeMarketFrame (PanelContainer)
        └── VBoxContainer
            ├── Header (title + gold wallet + close)
            ├── UpgradeTabs (TabContainer)
            │   ├── MagicArtisan (VBoxContainer)
            │   │   ├── Level Upgrade Panel
            │   │   │   ├── Item selector
            │   │   │   ├── Success / cost / next-tier details
            │   │   │   └── Level Up button
            │   │   └── Quality Upgrade Panel
            │   │       ├── Item selector
            │   │       ├── Quality / chance / cost details
            │   │       └── Quality Up button
            │   ├── Composition (VBoxContainer)
            │   │   ├── Main Item selector
            │   │   ├── Minor Item 1 selector
            │   │   ├── Minor Item 2 selector
            │   │   ├── Buy +1 Stone / Buy +2 Stone
            │   │   ├── Compose ProgressBar
            │   │   └── Compose button
            │   └── ArtisanWind (VBoxContainer)
            │       ├── Target Item selector
            │       ├── Socket status (0 / 1 / 2)
            │       ├── Open Socket button
            │       ├── Socket index selector
            │       ├── Gem inventory selector
            │       └── Install / Replace Gem button
            └── Operation Status (Label)
```

## Rules implemented
- Gold is the only currency. Level and quality attempts charge gold before rolling; a failed attempt leaves the item's level/quality unchanged.
- Quality progression is strictly Normal → Refined → Unique → Elite → Super.
- Level progression is 15 → 40 → 70 → 100 → 110 → 120 → 130.
- Composition consumes up to two +1 / +2 stones and a gold fee. Points carry forward; each completed threshold increases + level by one, never breaks the item.
- Socket opening is sequential: first socket 100,000 gold, second 200,000 gold. Gem installation/replacement costs 3,000 gold; replaced gems are destroyed.
- Gem families: Dragon, Phoenix, Rainbow, Violet, Moon, Fury, Kylin; each has Normal, Refined, and Super tiers.
- Archer Bow + Arrows definitions and the Oriental_Assassin dual ThrowingKnife rules are retained. Oriental_Assassin still inherits Archer gear eligibility; ThrowingKnife remains exclusive to Oriental_Assassin.
- GearSystem emits inventory_changed / equipment_changed after successful mutation. InventoryUI listens to these signals and rebuilds its paperdoll, equipment and socket display. GearSystem persists updated gear through GlobalEconomy.save_gear_data; gold changes are saved through GlobalEconomy.save_gold.

## Balance data and authenticity note
The project does not contain a verified official Conquer server data table for every upgrade fee, probability, and gem effect. The current chances, fees, multipliers, and gem stat values are explicit project balance defaults in GearDatabase.gd / GearSystem.gd. They are configurable and should not be described as verified 100% official-server values. The functional flow and ordering are implemented, but exact historical parity needs a trusted reference table.

## Validation boundary
The changed files were fetched back from the GitHub main branch after commits and inspected for expected functions, paths, and connections. Godot 4.3 is not installed in the current execution environment; no engine parser, import, runtime, UI, or save/restart test has been run yet.
