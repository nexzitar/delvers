class_name ActorFactory3D

## Maps combat templates/loadouts to 3D rigs. Heroes read their gear
## straight off the equipped dictionary (same data the paper-doll used);
## enemies map by id to a bespoke rig or a palette-swapped delver.

const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")
const SlimeRig = preload("res://scripts/theater3d/slime_rig.gd")
const SpiderRig = preload("res://scripts/theater3d/spider_rig.gd")

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

static func build_from_spawn(event) -> Node3D:
	if event.team == CombatEntity.Team.HERO:
		return build_hero(event.equipped)
	return build_enemy(event.template)

static func build_hero(equipped: Dictionary) -> Node3D:
	return DelverRig.new(hero_opts(equipped))

static func hero_opts(equipped: Dictionary) -> Dictionary:
	var opts := {}
	var main = equipped.get(Equip.Position.MAIN_HAND)
	if main:
		if main.weapon_type == GearDefinition.WeaponType.BOW:
			opts["bow"] = true
		else:
			opts["sword"] = true
	var off = equipped.get(Equip.Position.OFF_HAND)
	if off:
		if off.attack_speed > 0.0:
			opts["off_sword"] = true
		else:
			opts["shield"] = true
	if equipped.get(Equip.Position.HEAD):
		opts["helmet"] = true
	return opts

static func build_enemy(template) -> Node3D:
	match template.enemy_id:
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
		"broodmother":
			var brood = SpiderRig.new({
				"chitin": Color("3a2438"), "chitin_dark": Color("281627"),
				"marking": Color("a06fd0"), "eyes": Color("d84a9a"),
			})
			brood.scale = Vector3.ONE * 2.1
			return brood
	return DelverRig.new({})
