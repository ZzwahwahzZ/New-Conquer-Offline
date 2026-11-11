# Step 9 — Classic Classes and Archer / Oriental Assassin Gameplay

## Implemented
- Autoload order: ClassSystem, GearDatabase, GearSystem, GlobalEconomy, GameState.
- Six selectable classic base classes: Archer, Trojan, Warrior, Water Taoist, Fire Taoist and Ninja; Oriental Assassin is the Archer evolution.
- Strength, Agility, Vitality and Spirit feed derived HP, MP and Stamina. Each level awards 3 stat points.
- Promotion milestones are represented for every class at levels 15, 40, 70, 100 and 110. Archer unlocks Oriental Assassin at level 40. Path of Shadow then switches freely between Archer and Oriental Assassin combat modes; the other listed milestones remain available as class promotion-stage checkpoints.
- First-run main-scene routing opens character selection; selection calls ClassSystem.choose_class before entering the world.
- Class, level, XP, attributes, stat points, HP/MP/Stamina, XP Skill meter and skill proficiency persist in the GlobalEconomy save envelope (version 4).
- Classic Jump uses a fast ground-directed arc and Stamina cost. Stamina regenerates while moving and faster while idle.
- Fly raises the CharacterBody3D itself in world Y, maintains airborne state, displays an aura, and avoids enemy melee checks during flight.
- Path of Shadow unlocks at Archer level 40 and switches the active class stance. Separate Archer bow/arrow and Assassin dual-throwing-knife weapon loadouts are swapped and persisted. The HUD hotbar changes between Fly/Scatter and Rapid Fire/Kinetic Spark for the active stance.
- Scatter applies planar AOE damage to every enemy in range. Rapid Fire / Kinetic Spark and faster doubled basic attacks require Oriental Assassin plus dual equipped throwing knives.
- Skill proficiency increases on use and is saved. HUD buttons expose cooldown and MP/Stamina costs; XP Skill meter reads persistent ClassSystem state and gains charge on monster kills.

## Controls
- Tap/click ground: click-to-move; virtual joystick: movement; Space: basic attack. The hotbar changes by stance: Archer has Jump / Fly / Scatter / Path of Shadow / XP Mode; Oriental Assassin has Jump / Rapid Fire / Kinetic Spark / Path of Shadow / XP Mode.

## Verification boundary
- Added scripts/step9_smoke_test.gd for Godot headless checks.
- Static source and wiring were reviewed. Godot 4.3 is not installed in this execution environment, so parser/import/runtime/mobile verification is not claimed. Combat values, costs, cooldowns and derived-stat formulas are project balance defaults, not verified official-server values.
