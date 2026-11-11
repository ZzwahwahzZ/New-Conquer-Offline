# Full Code Audit & Stabilization — Steps 1–12

**Repository:** `ZzwahwahzZ/New-Conquer-Offline`  
**Branch audited:** `main`  
**Baseline:** Step 12 HEAD before this audit: `e03544f50c119277bc6569938dc9e9896cdfc9ce`  
**Scope:** Godot project configuration, GDScript sources, scene resources, save architecture, UI wiring, and mobile runtime lifecycle.

## Executive result

A static review covered the 58 project code/config/scene files under `scripts/`, `src/`, and `project.godot`. All literal `res://` references found in GDScript and TSCN resources matched an exact, case-sensitive path in the repository tree. No Godot 3 API markers (`instance()`, `yield`, `File.`, `PoolStringArray`) were found. The `@onready` annotation found in CharacterSelection is valid Godot 4 syntax.

The review found and repaired save-schema, inventory synchronization, UI initialization, dynamic-node typing, and pooled-object lifecycle defects. **Godot 4.3 itself was not installed in this execution environment, so the project has not been parsed or run by the actual engine here.** The new smoke test is prepared to load every listed script and scene under Godot 4.3; its result remains pending an engine run.

## Findings and fixes

| Area | Finding | Stabilization |
|---|---|---|
| Save v5 | Invalid/corrupt/older save envelopes could leave the warehouse array empty or contain invalid slot values. | Added unconditional safe normalization: quest dictionary, exactly 80 dictionary slots, and non-negative warehouse gold. |
| GameState JSON | `load_local()` did not close the file on malformed JSON and replaced the entire profile with a potentially incomplete dictionary. | Close immediately after reading; merge saved fields over safe defaults; validate inventory, quests, world position, level, XP, HP, and MP. |
| Inventory ownership | GearSystem mirrored its gear inventory over `GameState.profile.inventory`, which could erase potions, monster materials, and other general items whenever inventory signals fired. | Separated gear storage from general inventory; added one-time legacy gear migration and removal of duplicated legacy gear entries while preserving general items. |
| Dynamic node typing | Several values returned by `get_node_or_null()` were inferred as base `Node` while custom Autoload members were accessed directly. | Changed those dynamic references to Variant inference; kept explicit `Node3D` typing for the HUD player and used `call()` for script-defined methods where appropriate. |
| UI startup | Quest, merchant, mall, and warehouse panels were visible immediately after HUD construction. | All four panels now start hidden and open only through their intended controls/interactions. |
| Warehouse | Plus stones could be deposited but were routed into the general inventory on withdrawal, making them unavailable to GearSystem composition. | Both gems and plus stones now return to GearSystem inventory. Gold deposit/withdraw paths now restore the balance if the wallet write fails. |
| Inventory/upgrade UI | Cross-UI calls used direct custom methods on nodes obtained from groups. | Use `call("close")` after method checks to avoid base-Node static method resolution issues. |
| Gold drop pooling | An asynchronous pickup sound could finish after a drop had been recycled and reused, then recycle the newly active drop. | Added a generation token around the awaited audio completion; failed wallet writes leave the drop collectible. |
| Monster pooling | A delayed death timer could fire after a monster was recycled and reused, potentially recycling a living monster. | Added a death-generation token invalidated on configure/recycle and checked after the delay. |
| Promotion gear | Assassin throwing knives required level 70 although the promotion/evolution quest unlocks the Oriental Assassin at level 40. | Corrected the throwing-knife blueprint requirement to level 40. |

## Required checklist

### 1. Godot 4.3 syntax / parser risks
- Static scan: no `instance()`, `yield`, `File.`, or `PoolStringArray` occurrences.
- `@onready` is used in Godot 4 form.
- Dynamic custom-script references identified in the reviewed Autoload/UI paths were adjusted to avoid relying on a base `Node` static type.
- Added `scripts/step12_smoke_test.gd` to load every project script and PackedScene, which will surface GDScript parse/resource-load failures when run with Godot 4.3.
- **Not engine-confirmed:** no Godot 4.3 executable was available, so a successful engine parser result cannot honestly be claimed yet.

### 2. Resource paths / case sensitivity / dependency graph
- Reviewed 58 code/config/scene files and scanned literal `res://` references in GDScript and TSCN files.
- Missing or case-mismatched literal resource paths found: **0**.
- Direct preload/extends relationships reviewed: Monster extends Enemy; WorldManager preloads MonsterDatabase; scene/UI scripts load their corresponding resources. No circular preload/extends cycle was identified.
- Runtime Autoload references remain intentionally coordinated by the existing startup order; they are not cyclic preload dependencies.

### 3. Autoloads and Save v5
The order in `project.godot` remains unchanged:

1. ClassSystem
2. GearDatabase
3. GearSystem
4. GlobalEconomy
5. GameState

WorldManager, QuestSystem, and NPCSystem remain scene-local and were not added to Autoloads. GlobalEconomy now normalizes v5 save state before GearSystem initialization. GameState tolerates missing legacy fields. Gear and general inventory are separate stores, preventing loss of consumables/materials. Quest progress, warehouse slots, warehouse gold, character data, gear data, and wallet gold remain part of the local save design.

### 4. UI / node paths / controls
- CharacterSelection's onready paths match the nodes in CharacterSelection.tscn.
- HUD-created nodes referenced by name (OrbHUD, HotbarFrame, VirtualJoystick, etc.) are created before layout access.
- HUD loads InventoryUI, UpgradeMarketUI, CharacterStatusUI, SkillsUI, MiniMapUI, QuestUI, ShopUI, ShoppingMallUI, and WarehouseUI from exact existing paths.
- Keyboard routing: I/U are created by main.gd; C/K/M are handled by HUD.gd. Touch buttons are wired for the corresponding UI and NPC interaction.
- Interactive UI panels start hidden; controls remain separate from the lower-left joystick area.

### 5. Mobile performance / pooling
- Pool bounds remain 24 monsters, 32 gold drops, and 12 impact effects.
- Monster sleep/culling remains camera-distance based (58 world units, 0.8-second checks).
- Settlement transition still recycles active pooled objects, releases the old settlement scene, yields a frame, and loads the next scene with `CACHE_MODE_IGNORE_DEEP`.
- Added generation guards for asynchronous monster-death and gold-pickup callbacks to prevent stale callbacks from recycling reused objects.

## Verification status

| Check | Result |
|---|---|
| Exact literal resource-path scan | PASS — 0 missing paths |
| Godot 3 API marker scan | PASS — 0 matches |
| Autoload order comparison | PASS — unchanged |
| Save v5 / 80-slot normalization review | PASS — source corrected |
| Inventory ownership / migration review | PASS — source corrected |
| UI initial visibility and wiring review | PASS — source corrected |
| Pool bounds / culling / transition review | PASS — retained and race-guarded |
| Godot 4.3 script/scene parser execution | **PENDING — engine unavailable** |
| Android runtime / touch / FPS profiling | **PENDING — requires device build/run** |

## Run the engine-backed audit when Godot 4.3 is available

```bash
godot --headless --path . --script scripts/step12_smoke_test.gd
```

The test exits non-zero on a script/scene load failure or a failed architecture invariant. This report deliberately does not label the project as engine-tested until that command completes successfully.
