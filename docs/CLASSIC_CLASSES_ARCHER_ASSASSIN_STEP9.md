# Step 9 — Classic Classes and Archer / Oriental Assassin Gameplay

## Autoload order

The project uses this order in `project.godot`:

1. `ClassSystem` — character class, level, XP, attributes, stamina, skill proficiency.
2. `GearDatabase` — item and weapon definitions.
3. `GearSystem` — inventory, equipment and class/level validation.
4. `GlobalEconomy` — gold plus gear and character persistence.
5. `GameState` — world quest and display state.

`ClassSystem` connects to `GlobalEconomy.economy_ready`; its character record is loaded after the save envelope is ready. The class record is stored alongside gear in `user://conquer_offline_save.dat`.

## Classes and progression

Defined classes: Archer, Oriental Assassin, Trojan, Warrior, Water Taoist, Fire Taoist and Ninja. Archer can evolve to Oriental Assassin at the configured milestones 15, 40, 70, 100 and 110 by calling `ClassSystem.evolve_to("Oriental_Assassin")`. The other classic classes are represented as selectable base classes with the same milestone progression-stage API; additional class-specific promotions can be attached without changing save structure.

Attributes are stored as Strength, Agility, Vitality and Spirit (lowercase keys). Vitality contributes to HP and Stamina, Spirit contributes to MP, and Agility contributes to Stamina. Strength and Agility contribute to physical attack through `get_physical_attack_bonus()`. Each level grants 3 spendable stat points.

## Player controls

- Mouse/tap ground: click-to-move.
- Virtual joystick: continuous movement.
- Space: basic attack.
- 1: Classic Jump.
- 2: Fly (Archer family).
- 3: Scatter (Archer family, area damage).
- 4: Rapid Fire (Oriental Assassin with dual throwing knives).
- 5: XP Mode (available when the XP skill meter reaches 100; 10-second damage boost).

The jump uses a short interpolated arc toward the selected ground point or forward direction. Fly lifts the rendered player visual while keeping the collision body grounded; nearby enemy melee attacks check `is_airborne()` and do not damage the flying player. Stamina regenerates while moving and faster while stationary. Monster kills add 20 XP-skill meter points.

Skill proficiency is tracked per skill, levels up every `current_level * 20` proficiency XP, and is saved with the character. Skill cooldowns and remaining time appear on the HUD buttons. The HUD shows both character XP and XP-skill meters.

## Gear integration

`GearSystem.can_character_equip()` reads `ClassSystem.current_class` and `ClassSystem.level` when checking equipment, preserving the Archer-to-Oriental-Assassin bow inheritance and dual throwing-knife restriction.

## Validation boundary

The files were fetched back from GitHub and checked for expected APIs, Autoload registration, unique function names, and key integration points. Godot 4.3 is not installed in the execution environment, so no Godot parser, scene import, physics runtime, save/reload, or mobile device test is claimed. Values such as attribute scaling, damage, stamina costs, cooldowns and XP gain are configurable gameplay defaults, not verified official historical server values.
