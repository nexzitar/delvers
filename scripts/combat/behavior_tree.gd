class_name BehaviorTree

## One engine, three interfaces (spec: 2026-07-07-recovered-knowledge-
## progression.md). Built-in tactics are pre-authored trees; the future
## Scratch blocks and Engineer's Python compile to exactly this shape.
##
## A tree is an ordered Array of rules, first match wins per channel:
##   {"when": [conditions], "target": selector}   - targeting channel
##   {"when": [conditions], "cast": skill_id}     - casting channel
## A condition: {"cond": name, ...args}. Everything is plain JSON-able
## data, ready for editors and save files.

## The built-in tactics, expressed as the trees they always were.
const TACTIC_TREES := {
	"nearest": [{"when": [], "target": "nearest"}],
	"lowest": [{"when": [], "target": "lowest"}],
	"priority": [{"when": [], "target": "priority"}],
	"spread": [{"when": [], "target": "spread"}],
	"guard": [{"when": [], "target": "least_threat"}],
	"protect": [
		{"when": [{"cond": "healer_threatened"}], "target": "healer_attacker"},
		{"when": [], "target": "nearest"},
	],
}

static func tree_for(entity) -> Array:
	if not entity.behavior_tree.is_empty():
		return entity.behavior_tree
	return TACTIC_TREES.get(entity.tactic, TACTIC_TREES.nearest)

# --- Conditions -----------------------------------------------------------

static func check(state, hero, condition: Dictionary) -> bool:
	match condition.get("cond", "always"):
		"always":
			return true
		"enemy_count_gte":
			return _living_opponents(state, hero).size() >= int(condition.get("n", 1))
		"health_below":
			return hero.current_health < hero.max_health * float(condition.get("pct", 0.5))
		"mana_gte":
			return hero.current_mana >= int(condition.get("n", 0))
		"enemies_within":
			var near := 0
			for foe in _living_opponents(state, hero):
				if hero.position.distance_to(foe.position) <= float(condition.get("range", 90.0)):
					near += 1
			return near >= int(condition.get("n", 1))
		"healer_threatened":
			return _healer_attacker(state, hero) != -1
	return false

static func passes(state, hero, conditions: Array) -> bool:
	for condition in conditions:
		if not check(state, hero, condition):
			return false
	return true

# --- Targeting channel ----------------------------------------------------

static func pick_target(state, hero) -> int:
	for rule in tree_for(hero):
		if not rule.has("target"):
			continue
		if passes(state, hero, rule.get("when", [])):
			var picked = _select(state, hero, rule.target)
			if picked != -1:
				return picked
	return _select(state, hero, "nearest")

## Selectors score living opponents; lowest key wins.
static func _select(state, hero, selector: String) -> int:
	if selector == "healer_attacker":
		return _healer_attacker(state, hero)
	var best_id := -1
	var best_key := []
	for foe in _living_opponents(state, hero):
		var dist = hero.position.distance_to(foe.position)
		var key := []
		match selector:
			"lowest":
				key = [foe.current_health, dist]
			"priority":
				key = [_priority_rank(state, foe), dist]
			"spread":
				var covered := 0
				for status in foe.statuses:
					if status.kind == StatusEffect.Kind.POISON \
							and status.source_id == hero.entity_id \
							and status.remaining > 0.0:
						covered = 1
				key = [covered, _priority_rank(state, foe), dist]
			"least_threat":
				key = [foe.threat_table.get(hero.entity_id, 0.0), dist]
			_:
				key = [dist]
		if best_id == -1 or _key_less(key, best_key):
			best_id = foe.entity_id
			best_key = key
	return best_id

# --- Casting channel ------------------------------------------------------

## Skills referenced by cast rules fire only when a matching rule
## passes; unreferenced skills keep their built-in triggers.
static func allows_cast(state, hero, skill_id: String) -> bool:
	var referenced := false
	for rule in tree_for(hero):
		if rule.get("cast", "") != skill_id:
			continue
		referenced = true
		if passes(state, hero, rule.get("when", [])):
			return true
	return not referenced

# --- Helpers ---------------------------------------------------------------

static func _living_opponents(state, hero) -> Array:
	var pool = state.enemies if hero.team == CombatEntity.Team.HERO else state.heroes
	return pool.filter(func(e): return e.alive)

static func _priority_rank(state, foe) -> int:
	var idx = state.enemy_priority.find(foe.template.enemy_id)
	return idx if idx >= 0 else state.enemy_priority.size()

static func _key_less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false

## The ally who heals (heal/renew carried), and whoever hunts them.
static func _healer_attacker(state, hero) -> int:
	var allies = state.heroes if hero.team == CombatEntity.Team.HERO else state.enemies
	var healer_ids := []
	for ally in allies:
		if not ally.alive or ally == hero:
			continue
		for skill in ally.skills:
			if skill is SkillDefinition and skill.skill_id in ["heal", "renew"]:
				healer_ids.append(ally.entity_id)
				break
	if healer_ids.is_empty():
		return -1
	var best_id := -1
	var best_dist := INF
	for foe in _living_opponents(state, hero):
		if not healer_ids.has(foe.target_id):
			continue
		var dist = hero.position.distance_to(foe.position)
		if dist < best_dist:
			best_dist = dist
			best_id = foe.entity_id
	return best_id
