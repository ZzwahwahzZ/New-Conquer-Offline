# Step 13 — Simulated MMO & Conquer Guild Foundation

**Repository:** `ZzwahwahzZ/New-Conquer-Offline`  
**Branch:** `main`  
**Scope:** offline virtual-player roster, eight guild records, world-local actor director, low-cost pooled 3D actors, simulated chat, guild donations, and player milestone announcements.  
**Autoload policy:** unchanged. No new Autoload was added.

## Delivered files

| File | Purpose |
|---|---|
| `src/scripts/VirtualPlayerRoster.gd` | RefCounted in-memory database for 200 player records and eight guilds; guild lookup, membership, fund, diplomacy, donation, rank and milestone APIs |
| `src/scripts/AIPlayersManager.gd` | WorldManager-owned director; staged spawning, caps, actor pool, NPC congregation, hunting targeting, distance/idle LOD, virtual gold, guild donations and chat |
| `src/scripts/AIPlayer.gd` | Lightweight pooled CharacterBody3D actor with billboard identity, guild/rank, diplomacy tint, arc jump, flight/wings, visual attack and virtual-gold counter |
| `src/scenes/AIPlayer.tscn` | Minimal actor scene; no imported character rig or heavyweight assets |
| `src/scripts/WorldManager.gd` | Creates one scene-local AI director and reuses its actor pool across settlement transitions; initializes it after NPC markers and monsters are present |
| `src/scripts/HUD.gd` | Public simulated-chat entry point and congratulations for Oriental Assassin promotion and +9/+12 equipment milestones |
| `scripts/step13_smoke_test.gd` | Godot 4.3 headless smoke test for roster/guild invariants, required fields, actor scene/API, density caps, spawn cadence, pool/LOD, chat and Autoload order |

## Roster and guild data

- Exactly **200** dictionary-only virtual player records are generated in memory; no 3D node is created by the roster.
- Exactly **8** guilds: Pharaohs, Dragons, ShadowKnights, Titans, Legends, Wolves, Kings and Vipers.
- Exactly **25** members per guild, with one Guild Leader per guild.
- Every guild includes `guild_name`, `guild_fund`, `bulletin`, `allies` and `enemies`.
- Player records include all requested identity, class, level, plus, quality, wings, guild, donation and rank fields.
- Leaders are generated at level 125, Elite +12, with a 12,000,000-gold simulated donation. Two deputies are assigned per guild. Donation thresholds determine Honorary Deputy Leader and Supervisor ranks for other members.
- Class weighting favors Archer (38%) and Oriental Assassin (30%); the remaining 32% is selected from the other supported classes.
- Wings are assigned only to level-40+ Archers/Oriental Assassins with +8 or better gear.
- The roster exposes `get_all_players`, `get_player`, `get_guild`, `get_guild_names`, `get_guild_members`, `get_guild_fund`, `get_guild_diplomacy`, `get_player_rank`, `donate_to_guild` and `record_player_milestone` for the future Guild Director / Guild War layer.

## Mobile density and lifecycle

- Twin City safe-zone cap: **40 active bots**.
- Other current maps are treated as hunting zones: **3 active bots maximum**.
- Safe-zone selection targets 20 beginner/intermediate, 14 geared veterans (+5 to +8), and 6 high-tier (+12/wings) actors.
- Spawn cadence is two actors per 0.1-second process interval, not all at once.
- The AI manager is a child of the existing scene-local WorldManager, not an Autoload. Its actor pool survives settlement changes; actors are deactivated and reused after the old world is released.
- City actors navigate to existing `BotInteractionSpot_*` Marker3D locations. Some use the Conquer-style arc jump. Eligible high-level Archer/Assassin actors display wings and hover.
- Hunting actors select the nearest enemy and perform a repeating visual attack animation. Bot-only virtual gold drops magnet toward a bot and increment its `simulated_gold` counter; they never alter the player's Gold wallet or consume the player's real CPDrop.
- Distance LOD checks run every 0.8 seconds against the camera/player at 58 world units. Idle city actors stop their own process/physics work; distant actors sleep.
- General chat includes trade/party/hunting messages. Guild donations are announced in the guild channel. HUD milestones announce the player's Oriental Assassin promotion and +9/+12 equipment upgrades.

## Verification and limitations

The source-level smoke test is committed and ready:

```bash
godot --headless --path . --script scripts/step13_smoke_test.gd
```

**Important:** the Godot 4.3 executable is not available in the current execution environment. Therefore this smoke test has **not** been executed here; no parser/runtime pass is claimed. The report and source have been statically reviewed, and the existing Autoload order was re-read from `project.godot` and left unchanged.

The combat action is intentionally visual-only at this foundation stage: bots do not reduce live monster HP or award the human player XP. Their gold pickups are bot-only simulated loot, separate from the player's real drops and wallet. Guild balances/donations live in memory and are not persisted to the player's save file; the roster is regenerated deterministically on launch. Player guild membership and actual Guild Director / Guild War interactions remain for the next guild-integration step.

No Step 14 work was started.
