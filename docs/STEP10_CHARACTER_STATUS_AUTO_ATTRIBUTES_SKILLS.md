# Step 10 — Character Status, Automatic Attributes & Classic Skills

## Delivered
- Automatic attribute allocation runs synchronously for every level gained. All earned points are consumed; the manual `spend_stat_points` API is disabled.
- Archer / Oriental Assassin prioritizes weapon `required_strength` and `required_agility` metadata for currently level-eligible equipped/inventory weapons, then follows a persisted 60/40 Agility/Vitality cycle.
- Trojan, Warrior, Taoist and Ninja use class-oriented weighted cycles. Allocation cursor is persisted so fractional ratios remain balanced across level-ups.
- Level-up chat message reports the actual STR / AGI / VIT / SPI increments.
- CharacterStatusUI shows character identity, class, promotion title, level, HP/MP, PK points, attributes, physical/magic attack and defense, dodge and computed Battle Power/Potency.
- Equipment totals use GearSystem's final item stats (base stats, quality and plus) and gem bonuses, including percentage effects.
- Promote becomes available at 15 / 40 / 70 / 100 / 110, saves the promotion stage/title/reward claim, grants 3 automatically allocated attribute points and restores 100 HP / 50 MP.
- SkillsUI lists skills by current class and displays proficiency level and Skill XP percentage. Double Slash proficiency and Player skill action were added for classes that use it.
- HUD opens Character Status with C and Skills with K, or their on-screen buttons.

## Files changed
- `src/scripts/ClassSystem.gd`
- `src/scripts/Player.gd`
- `src/scripts/HUD.gd`
- `src/scripts/CharacterStatusUI.gd`
- `src/scripts/SkillsUI.gd`
- `src/scenes/CharacterStatusUI.tscn`
- `src/scenes/SkillsUI.tscn`
- `scripts/step10_smoke_test.gd`

## Persistence and project boundaries
- Attribute allocation cursor, promotion stage, title and claimed rewards are saved in the existing `GlobalEconomy.save_character_data` envelope (local `user://` save).
- `GlobalEconomy.gd`, gold logic and `project.godot` Autoload entries/order were not modified.

## Important implementation note
- The current GearDatabase weapon blueprints expose level requirements but do not currently define Strength/Agility requirements. The allocator reads those fields when present; it does not invent missing weapon requirements. Existing blueprints therefore proceed directly to the weighted class allocation until their real stat requirements are defined.

## Validation boundary
- The smoke test file is included and its source assertions are designed for Godot 4.3 headless execution.
- No Godot 4.3 runtime/parser execution or in-game visual test was available during this commit, so no runtime PASS is claimed.
