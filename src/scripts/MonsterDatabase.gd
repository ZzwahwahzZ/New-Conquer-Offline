extends RefCounted
## Offline classic monster catalogue. Sanctuary creatures award double gold and materials.
const NORMAL := {
	"TwinCity":[
		{"id":"Pheasant","name":"Pheasant","level":1,"hp":35,"damage":3,"gold":5,"xp":12,"color":Color(0.72,0.42,0.22)},
		{"id":"Turtledove","name":"Turtledove","level":2,"hp":48,"damage":4,"gold":7,"xp":16,"color":Color(0.62,0.68,0.78)},
		{"id":"Apparition","name":"Apparition","level":5,"hp":75,"damage":7,"gold":12,"xp":28,"color":Color(0.58,0.82,0.9)}
	],
	"DesertLand":[
		{"id":"Bandit","name":"Bandit","level":15,"hp":240,"damage":18,"gold":28,"xp":65,"color":Color(0.68,0.42,0.2)},
		{"id":"SandMonster","name":"Sand Monster","level":22,"hp":330,"damage":24,"gold":38,"xp":88,"color":Color(0.78,0.66,0.36)},
		{"id":"DesertApe","name":"Desert Ape","level":32,"hp":510,"damage":32,"gold":55,"xp":120,"color":Color(0.52,0.36,0.22)}
	],
	"VolcanoLand":[
		{"id":"GiantApe","name":"Giant Ape","level":40,"hp":680,"damage":40,"gold":72,"xp":155,"color":Color(0.38,0.22,0.18)},
		{"id":"Birdman","name":"Birdman","level":48,"hp":790,"damage":46,"gold":85,"xp":180,"color":Color(0.62,0.3,0.18)},
		{"id":"FireRat","name":"Fire Rat","level":60,"hp":980,"damage":55,"gold":105,"xp":220,"color":Color(0.9,0.26,0.08)}
	],
	"IceLand":[
		{"id":"Snowman","name":"Snowman","level":70,"hp":1150,"damage":62,"gold":120,"xp":245,"color":Color(0.72,0.88,0.96)},
		{"id":"IceMonster","name":"Ice Monster","level":82,"hp":1420,"damage":72,"gold":145,"xp":290,"color":Color(0.34,0.68,0.9)},
		{"id":"Mammoth","name":"Mammoth","level":92,"hp":1680,"damage":82,"gold":175,"xp":340,"color":Color(0.54,0.64,0.76)}
	],
	"Waterlands":[
		{"id":"Serpent","name":"Serpent","level":95,"hp":1840,"damage":88,"gold":190,"xp":370,"color":Color(0.18,0.62,0.56)},
		{"id":"WaterDevil","name":"Water Devil","level":104,"hp":2100,"damage":98,"gold":220,"xp":420,"color":Color(0.18,0.42,0.76)},
		{"id":"Pirate","name":"Pirate","level":112,"hp":2360,"damage":108,"gold":245,"xp":470,"color":Color(0.34,0.28,0.2)}
	],
	"DarkForest":[
		{"id":"DarkElf","name":"Dark Elf","level":115,"hp":2600,"damage":118,"gold":280,"xp":520,"color":Color(0.24,0.28,0.2)},
		{"id":"Demon","name":"Demon","level":123,"hp":2950,"damage":132,"gold":320,"xp":590,"color":Color(0.46,0.12,0.18)},
		{"id":"GhostKing","name":"Ghost King","level":130,"hp":3400,"damage":150,"gold":380,"xp":680,"color":Color(0.42,0.3,0.64)}
	]
}
const SANCTUARIES := {
	"TwinCity":[{"id":"RareApparition","name":"Rare Apparition","level":12,"hp":650,"damage":20,"gold":120,"xp":260,"color":Color(0.45,0.82,0.94)},{"id":"PheasantKing","name":"Pheasant King","level":15,"hp":1600,"damage":36,"gold":250,"xp":520,"color":Color(0.82,0.48,0.12),"boss":true}],
	"DesertLand":[{"id":"DesertStalker","name":"Desert Stalker","level":35,"hp":1800,"damage":52,"gold":300,"xp":600,"color":Color(0.68,0.48,0.22)},{"id":"SandWarlord","name":"Sand Warlord","level":40,"hp":4200,"damage":72,"gold":600,"xp":1100,"color":Color(0.88,0.58,0.2),"boss":true}],
	"VolcanoLand":[{"id":"LavaGolem","name":"Lava Golem","level":65,"hp":3500,"damage":86,"gold":550,"xp":1050,"color":Color(0.68,0.2,0.08)},{"id":"FlameDragon","name":"Flame Dragon","level":70,"hp":7200,"damage":110,"gold":1100,"xp":2100,"color":Color(0.95,0.18,0.05),"boss":true}],
	"IceLand":[{"id":"IceWraith","name":"Ice Wraith","level":90,"hp":4800,"damage":110,"gold":800,"xp":1500,"color":Color(0.34,0.72,0.96)},{"id":"FrostEmperor","name":"Frost Emperor","level":95,"hp":9800,"damage":140,"gold":1600,"xp":3000,"color":Color(0.28,0.78,1.0),"boss":true}],
	"Waterlands":[{"id":"DeepSeaWitch","name":"Deep Sea Witch","level":110,"hp":6200,"damage":135,"gold":1150,"xp":2200,"color":Color(0.12,0.5,0.78)},{"id":"WaterDragon","name":"Water Dragon","level":115,"hp":13200,"damage":175,"gold":2300,"xp":4300,"color":Color(0.12,0.45,0.95),"boss":true}],
	"DarkForest":[{"id":"Nightmare","name":"Nightmare","level":125,"hp":9200,"damage":180,"gold":2000,"xp":3800,"color":Color(0.22,0.14,0.34)},{"id":"AncientDragon","name":"Ancient Dragon","level":135,"hp":19000,"damage":220,"gold":4000,"xp":7500,"color":Color(0.36,0.08,0.22),"boss":true}]
}

static func get_settlement_monsters(settlement_id: String) -> Array:
	return NORMAL.get(settlement_id,NORMAL["TwinCity"]).duplicate(true)

static func get_sanctuary_monsters(settlement_id: String) -> Array:
	return SANCTUARIES.get(settlement_id,[]).duplicate(true)
