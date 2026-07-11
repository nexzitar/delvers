class_name ActorFactory3D

## Maps combat templates/loadouts to 3D rigs. Heroes read their gear
## straight off the equipped dictionary (same data the paper-doll used);
## enemies map by id to a bespoke rig or a palette-swapped delver.

const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")
const SlimeRig = preload("res://scripts/theater3d/slime_rig.gd")
const SpiderRig = preload("res://scripts/theater3d/spider_rig.gd")

## Constructs: the old guild's machines, built from the delver frame
## in brass and gunmetal - the worn-gear boxes read as plating.
const SENTINEL_OPTS := {
	"hair": null, "skin": Color(0.45, 0.42, 0.38),
	"tunic": Color(0.4, 0.34, 0.24),
	"chest_plate": Color(0.55, 0.42, 0.25),
	"shoulders": Color(0.5, 0.38, 0.22),
	"gauntlets": Color(0.42, 0.4, 0.36), "greaves": Color(0.42, 0.4, 0.36),
	"sword": true,
}
const THROWER_OPTS := {
	"hair": null, "skin": Color(0.5, 0.47, 0.42),
	"tunic": Color(0.32, 0.3, 0.28),
	"chest_plate": Color(0.5, 0.4, 0.26), "bracers": Color(0.55, 0.42, 0.25),
}
const FOREMAN_OPTS := {
	"hair": null, "skin": Color(0.4, 0.36, 0.3),
	"tunic": Color(0.45, 0.36, 0.2),
	"chest_plate": Color(0.62, 0.47, 0.26), "shoulders": Color(0.6, 0.45, 0.24),
	"gauntlets": Color(0.5, 0.46, 0.4), "greaves": Color(0.5, 0.46, 0.4),
	"belt_trim": Color(0.6, 0.5, 0.3), "sword": true,
}

const GOBLIN_OPTS := {
	"bow": true, "ears": true, "hair": null,
	"skin": Color("7aa54e"), "tunic": Color("8a4b3a"),
	"sleeve": Color("6f3d30"), "pants": Color("4a4a3a"),
	"eyes": Color("b03030"),
}
const GOBLIN_WARRIOR_OPTS := {
	"sword": true, "shield": true, "helmet": true, "ears": true, "hair": null,
	"skin": Color("6e9a46"), "tunic": Color("5a4632"),
	"sleeve": Color("46362a"), "pants": Color("3c3c30"),
	"eyes": Color("b03030"),
}
const GOBLIN_SCALE := 0.85

## Per-model import tuning: facing, scale, and the clip map for
## exports that lose animation names.
const MODEL_CONFIGS := {
	"res://resources/models/delver_female.glb": {
		"facing_fix": -PI / 2,
		"model_scale": 1.17,
		"walk_cycle_scale": 1.5,
		"garment_suffix": "_f",
		"animation_donor": "res://resources/models/delver_male.glb",
		"hair_tail": {"color": Color(0.23, 0.17, 0.11), "segment_length": 0.085,
			"offset": Vector3(0, 0.12, 0.1)},
		"clip_ranges": {"idle": [0.2, 4.2]},
		"clip_map": {
			"death": "NlaTrack",
			"idle": "NlaTrack_001",
			"run": "NlaTrack_002",
			"swing": "NlaTrack_003",
			"walk": "NlaTrack_004",
			"cast": "NlaTrack_005",
		},
	},
	"res://resources/models/goblin_warrior_m.glb": {
		"facing_fix": -PI / 2,
		"model_scale": 0.95,
		"walk_cycle_scale": 1.5,
		"sword": true, "shield": true,
		"hair": null,
		"clip_map": {
			"idle": "NlaTrack",
			"walk": "NlaTrack_001",
			"run": "NlaTrack_002",
			"swing": "NlaTrack_003",
			"death": "NlaTrack_004",
		},
	},
	"res://resources/models/goblin_archer_m.glb": {
		"facing_fix": -PI / 2,
		"model_scale": 0.9,
		"walk_cycle_scale": 1.5,
		"bow": true,
		"hair": null,
		"clip_map": {
			"idle": "NlaTrack",
			"walk": "NlaTrack_001",
			"run": "NlaTrack_002",
			"swing": "NlaTrack_003",
			"death": "NlaTrack_004",
		},
	},
	"res://resources/models/goblin_scout_m.glb": {
		"facing_fix": -PI / 2,
		"model_scale": 0.85,
		"walk_cycle_scale": 1.5,
		"dagger": true,
		"hair": null,
		"clip_map": {
			"idle": "NlaTrack", "walk": "NlaTrack_001", "run": "NlaTrack_002",
			"swing": "NlaTrack_003", "death": "NlaTrack_004",
		},
	},
	"res://resources/models/goblin_shaman_m.glb": {
		"facing_fix": -PI / 2,
		"model_scale": 0.9,
		"walk_cycle_scale": 1.5,
		"hair": null,
		"clip_map": {
			"idle": "NlaTrack", "walk": "NlaTrack_001", "run": "NlaTrack_002",
			"swing": "NlaTrack_003", "death": "NlaTrack_004",
		},
	},
	"res://resources/models/goblin_chief_m.glb": {
		"facing_fix": -PI / 2,
		"model_scale": 1.12,
		"walk_cycle_scale": 1.5,
		"sword": true, "shield": true,
		"hair": null,
		"clip_map": {
			"idle": "NlaTrack", "walk": "NlaTrack_001", "run": "NlaTrack_002",
			"swing": "NlaTrack_003", "death": "NlaTrack_004",
		},
	},
	"res://resources/models/delver_male.glb": {
		"facing_fix": -PI / 2,
		"model_scale": 1.2,
		"walk_cycle_scale": 1.5,
		"clip_ranges": {"idle": [0.2, 4.2]},
		"clip_map": {
			"death": "NlaTrack",
			"idle": "NlaTrack_001",
			"run": "NlaTrack_002",
			"swing": "NlaTrack_003",
			"walk": "NlaTrack_004",
			"cast": "NlaTrack_005",
		},
	},
}

static func build_from_spawn(event) -> Node3D:
	if event.team == CombatEntity.Team.HERO:
		if event.model_path != "":
			var config = MODEL_CONFIGS.get(event.model_path, {})
			var opts = hero_opts(event.equipped)
			opts.merge(config, true)
			return AnimatedActor.new(load(event.model_path), opts)
		return build_hero(event.equipped)
	if event.model_path != "":
		# A modeled enemy: its weapons and scale ride the model config.
		var config = MODEL_CONFIGS.get(event.model_path, {}).duplicate(true)
		return AnimatedActor.new(load(event.model_path), config)
	return build_enemy(event.template)

static func build_hero(equipped: Dictionary, model_path := "") -> Node3D:
	if model_path != "":
		var config = MODEL_CONFIGS.get(model_path, {})
		var opts = hero_opts(equipped)
		opts.merge(config, true)
		return AnimatedActor.new(load(model_path), opts)
	return DelverRig.new(hero_opts(equipped))

## Worn-gear palette by family; slot fallbacks below.
const WORN_COLORS := {
	"wardens_pauldrons": Color(0.6, 0.63, 0.68),
	"iron_greaves": Color(0.6, 0.63, 0.68),
	"iron_shod_boots": Color(0.32, 0.26, 0.18),
	"goblin_work_gauntlets": Color(0.54, 0.42, 0.26),
	"studded_belt": Color(0.42, 0.31, 0.19),
	"silk_bracers": Color(0.87, 0.84, 0.74),
	"weavers_cloak": Color(0.74, 0.72, 0.8),
	"chitin_armor": Color(0.38, 0.29, 0.2),
	"starter_armor": Color(0.5, 0.36, 0.22),
}
const SLOT_WORN := {
	GearDefinition.Slot.SHOULDER: ["shoulders", Color(0.55, 0.5, 0.42)],
	GearDefinition.Slot.BACK: ["cloak", Color(0.6, 0.58, 0.64)],
	GearDefinition.Slot.CHEST: ["chest_plate", Color(0.5, 0.4, 0.28)],
	GearDefinition.Slot.WAIST: ["belt_trim", Color(0.42, 0.31, 0.19)],
	GearDefinition.Slot.HANDS: ["gauntlets", Color(0.5, 0.4, 0.28)],
	GearDefinition.Slot.WRIST: ["bracers", Color(0.6, 0.55, 0.45)],
	GearDefinition.Slot.LEGS: ["greaves", Color(0.55, 0.55, 0.6)],
	GearDefinition.Slot.FEET: ["boots_gear", Color(0.32, 0.26, 0.18)],
}

static func hero_opts(equipped: Dictionary) -> Dictionary:
	var opts := {}
	var main = equipped.get(Equip.Position.MAIN_HAND)
	if main:
		opts["main_gear"] = main.gear_id
		if main.weapon_type == GearDefinition.WeaponType.BOW:
			opts["bow"] = true
		else:
			opts["sword"] = true
	var off = equipped.get(Equip.Position.OFF_HAND)
	if off:
		opts["off_gear"] = off.gear_id
		if off.attack_speed > 0.0:
			opts["off_sword"] = true
		else:
			opts["shield"] = true
	if equipped.get(Equip.Position.HEAD):
		opts["helmet"] = true
		opts["helmet_gear"] = equipped[Equip.Position.HEAD].gear_id
	if equipped.get(Equip.Position.CHEST):
		opts["chest_gear"] = equipped[Equip.Position.CHEST].gear_id
	if equipped.get(Equip.Position.WAIST):
		opts["belt_gear"] = equipped[Equip.Position.WAIST].gear_id
	if equipped.get(Equip.Position.SHOULDER):
		opts["shoulder_gear"] = equipped[Equip.Position.SHOULDER].gear_id
	# Everything worn shows: shoulders, cloak, plate, belt, and the rest.
	# gear_ids carries every worn id so fitted models mount by id; the
	# color opts remain the procedural fallback for unfitted gear.
	for pos in equipped:
		var item = equipped[pos]
		if item == null:
			continue
		# Weapons mount through main_gear/off_gear with their own timing.
		if item.slot in [GearDefinition.Slot.MAIN_HAND, GearDefinition.Slot.OFF_HAND]:
			continue
		if not opts.has("gear_ids"):
			opts["gear_ids"] = []
		opts["gear_ids"].append(item.gear_id)
		if not SLOT_WORN.has(item.slot):
			continue
		var entry = SLOT_WORN[item.slot]
		opts[entry[0]] = WORN_COLORS.get(item.gear_id, entry[1])
	return opts

static func build_enemy(template) -> Node3D:
	match template.enemy_id:
		"scrap_sentinel":
			var sentinel = DelverRig.new(SENTINEL_OPTS)
			sentinel.scale = Vector3.ONE * 1.15
			return sentinel
		"cog_thrower":
			return DelverRig.new(THROWER_OPTS)
		"foreman":
			var foreman = DelverRig.new(FOREMAN_OPTS)
			foreman.scale = Vector3.ONE * 1.5
			return foreman
		"oil_slick":
			return SlimeRig.new({
				"body": Color(0.14, 0.13, 0.12),
				"body_dark": Color(0.08, 0.08, 0.09),
			})
		"rust_mite":
			var mite = SpiderRig.new({
				"chitin": Color(0.52, 0.3, 0.16),
				"chitin_dark": Color(0.36, 0.2, 0.1),
				"eyes": Color(0.95, 0.7, 0.2),
			})
			mite.scale = Vector3.ONE * 0.62
			return mite
		"green_slime":
			return SlimeRig.new()
		"slime_king":
			var king = SlimeRig.new({"king": true})
			king.scale = Vector3.ONE * 1.7
			return king
		"goblin_archer":
			var rig = DelverRig.new(GOBLIN_OPTS)
			rig.scale = Vector3.ONE * GOBLIN_SCALE
			return rig
		"goblin_warrior":
			var warrior = DelverRig.new(GOBLIN_WARRIOR_OPTS)
			warrior.scale = Vector3.ONE * 0.95
			return warrior
		"venomous_spider":
			var spider = SpiderRig.new()
			spider.scale = Vector3.ONE * 0.9
			return spider
		"nest_spiderling":
			var spiderling = SpiderRig.new({
				"chitin": Color("4a3a2c"), "chitin_dark": Color("332619"),
				"marking": Color("c8b98a"),
			})
			spiderling.scale = Vector3.ONE * 0.55
			return spiderling
		"web_weaver":
			var weaver = SpiderRig.new({
				"chitin": Color("8f8878"), "chitin_dark": Color("6b6456"),
				"marking": Color("e8e4d8"), "eyes": Color("3c68b0"),
			})
			weaver.scale = Vector3.ONE * 0.95
			return weaver
		"chitin_crawler":
			var crawler = SpiderRig.new({
				"chitin": Color("5e4426"), "chitin_dark": Color("402d18"),
				"marking": Color("8a6a3a"), "bulky": true,
			})
			crawler.scale = Vector3.ONE * 1.2
			return crawler
		"brood_tender":
			var tender = SpiderRig.new({
				"chitin": Color("6a6a46"), "chitin_dark": Color("4a4a30"),
				"marking": Color("d8e0a0"), "eyes": Color("d87a3a"),
				"bulky": true,
			})
			tender.scale = Vector3.ONE * 1.15
			return tender
		"broodmother":
			var brood = SpiderRig.new({
				"chitin": Color("3a2438"), "chitin_dark": Color("281627"),
				"marking": Color("a06fd0"), "eyes": Color("d84a9a"),
			})
			brood.scale = Vector3.ONE * 2.1
			return brood
	return DelverRig.new({})
