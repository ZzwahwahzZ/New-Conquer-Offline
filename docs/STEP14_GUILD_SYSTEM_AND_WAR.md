# Step 14 — Conquer Guild System & Guild War

**Repository:** `ZzwahwahzZ/New-Conquer-Offline`  
**Branch:** `main`  
**Scope:** offline guild membership and creation, donation ranks, diplomacy, persistent Save v6, guild buffs, Guild Director NPC, Guild Hall UI, and destructible guild-war arena.

## Delivered files

| File | Change |
|---|---|
| `src/scripts/GuildSystem.gd` | New WorldManager-owned guild controller; membership, founding, recruitment, rank ladder, donations, leadership challenge, bulletin, diplomacy, buffs and war winner persistence |
| `src/scripts/GuildUI.gd` | New four-tab Guild Hall interface with responsive landscape layout |
| `src/scenes/GuildUI.tscn` | New Guild Hall scene |
| `src/scripts/GuildWarManager.gd` | New bounded guild-war director, two gates, central pole, team damage accounting, squads and winner resolution |
| `src/scripts/GuildWarTarget.gd` | New destructible gate/pole target with player and team-attributed simulated damage |
| `src/scenes/world/GuildWarArena.tscn` | New isolated arena scene |
| `src/scripts/GlobalEconomy.gd` | Save envelope upgraded from v5 to v6; stores guild data alongside existing gold, gear, character, quest and warehouse data |
| `scripts/game_state.gd` | Adds player guild identity fields and defense/XP buff support |
| `src/scripts/WorldManager.gd` | Creates GuildSystem as a scene-local child, streams the arena, restores the player at the arena entrance and exits back to Twin City |
| `src/scripts/NPCSystem.gd` | Adds Guild Director in Twin City only |
| `src/scripts/HUD.gd` | Adds Guild Hall button, G shortcut and Guild Director interaction |
| `src/scripts/AIPlayersManager.gd` | Shares the persistent guild roster, refreshes diplomacy colors, reports active guild members and routes bot donations to GuildSystem |
| `src/scripts/VirtualPlayerRoster.gd` | Preserves custom player-created guilds when rebuilding and validating the 200-player roster |
| `src/scripts/Player.gd` | Applies guild attack multiplier to basic attacks, Scatter and Rapid Fire |
| `src/scripts/ClassSystem.gd` | Applies guild defense reduction to incoming damage and guild XP multiplier to progression |
| `project.godot` | Sets Godot 4.3 Mobile renderer; existing Autoload order remains unchanged |
| `scripts/step14_smoke_test.gd` | New headless smoke test for join/create, donation ranks, exact creation cost, buffs, v6 save, diplomacy and pole destruction |

## Guild system

- Uses the eight existing guilds from Step 13 and supports additional player-created guilds.
- Joining an existing guild assigns `Member` rank and publishes its bulletin through the guild chat signal.
- Founding requires level 40+, a unique name (3–20 characters), and exactly **1,000,000 Gold**.
- A player-created guild starts with the player as `Guild Leader`; virtual members request and join gradually, one every 18 seconds, up to 26 total members (player + 25 bots).
- Donation rank thresholds: `Supervisor` at 350,000; `Honorary Deputy Leader` at 900,000; `Deputy Leader` at 2,500,000 cumulative Gold. A founder remains Guild Leader.
- Leadership challenge requires the player to exceed the current bot leader in both level and cumulative donation. The previous leader is demoted to Deputy Leader.
- Guild leaders can edit the bulletin and set symmetric Ally, Enemy or Neutral relations.
- The UI lists member level, rank, donation and actual active-world status.

## Save v6 and buffs

- The v6 envelope stores player guild name/rank/donation, all guild funds, bulletins, allies, enemies, the 200-player roster state and `war_winner_guild`.
- Existing v5 saves load with safe empty guild data, then migrate to v6 without replacing the other save sections.
- Attack buffs are applied in the player combat damage calculations.
- Defense buffs reduce damage in `ClassSystem.take_damage`.
- XP buffs increase XP awarded by `ClassSystem.add_experience` (and the legacy GameState XP path).
- Buff strength scales with player rank and guild treasury; the winning guild receives an additional 5% attack/defense/XP bonus.

## Guild Hall and war arena

- Guild Director is spawned only in Twin City and opens the Guild Hall.
- The Guild Hall has Overview, Members, Guilds & Diplomacy, and Guild War tabs. It can also be opened with **G** or the HUD button.
- The arena has left/right destructible gates and a central Guild Pole with a large HP bar. The pole is locked until both gates are destroyed.
- Up to **8** war actors are spawned (four allied and four defending), independent of the regular 40-city / 3-hunting actor caps. The arena has its own floor collision and a portal back to Twin City.
- Allied and defending squads apply bounded simulated objective damage. Player basic attacks and skills damage the real gate/pole targets through the existing player combat pipeline.
- Winner is determined by highest damage to the Guild Pole; ties go to the last guild to land damage. The winner is persisted and announced in general chat. A player in the winning guild receives the `Guild War Winner` title and victory buff.

## Autoload and renderer policy

The Autoload list is unchanged and remains:

1. `ClassSystem`
2. `GearDatabase`
3. `GearSystem`
4. `GlobalEconomy`
5. `GameState`

`GuildSystem` is instantiated under `WorldManager`; it is not an Autoload. The project rendering method is now Godot 4.3 `mobile`.

## Verification

Smoke-test command:

```bash
godot --headless --path . --script scripts/step14_smoke_test.gd
```

The smoke test checks:
- joining an existing guild as Member;
- the three donation-rank promotions and treasury totals;
- leaving and founding a guild at level 40;
- exact 1,000,000 Gold foundation cost;
- bulletin and Ally/Enemy diplomacy persistence;
- attack, defense and XP buff wiring;
- v6 guild data persistence;
- Guild Pole destruction, winner persistence and player victory title;
- Autoload preservation and required scene/script resources.

**Execution limitation:** Godot 4.3 is not installed in the current execution environment, and neither the Godot headless runner nor a GDScript parser/linter was available. Therefore the smoke test was added but **not executed** here; no Parser, scene-import, runtime, Android rendering or device-performance pass is claimed. The resource paths used by the new scenes were checked against existing repository files. A real Godot 4.3 run remains required before calling this engine-verified.

## Scope boundary

This is the offline foundation and playable systems integration, not a network MMO. Guild data is local to the save. War squads are capped at eight actors; their objective DPS is simulated by the arena manager, while player attacks use the real combat target path. No Step 15 work was started.
