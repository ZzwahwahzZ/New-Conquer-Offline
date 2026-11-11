# Step 12 — NPCs, classic quests, gold shops and shared warehouse

- Five NPC roles spawn in each settlement with BotInteractionSpot markers.
- QuestSystem is a WorldManager child, not an Autoload. It includes promotion milestones 15/40/70/100/110, regional hunting contracts and a treasure quest. Level-40 reward evolves Archer into Oriental Assassin and awards paired throwing knives.
- Quest tracking moves the player toward the matching trainer or currently spawned target monster. This is direct target movement; obstacle-aware navmesh routing is not yet included.
- Merchant and Shopping Mall UIs use gold only. Mall catalogue includes meteors, Dragon Balls, plus stones, drills, seven gem families and grades, garments, weapon accessories, steeds, Exp Balls, Double Exp and Megaphones.
- Warehouse has 80 shared item slots in two pages of 40 and an integer gold balance. Empty slots deposit one inventory stack; occupied slots withdraw it.
- Save envelope v5 includes quest progress, warehouse items and warehouse gold. Existing Autoload order is unchanged.
- Run: godot --headless --path . --script res://scripts/step12_smoke_test.gd
