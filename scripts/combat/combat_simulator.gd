extends Node
const SIMULATION_STEP = 0.1

var default_delver = preload(
    "res://resources/heroes/default_delver.tres"
)

var green_slime = preload(
    "res://resources/enemies/green_slime.tres"
)

func _ready():

	var combat = CombatState.new()

	combat.setup_combat(
		[default_delver],
		[green_slime, green_slime]
	)

	while not combat.combat_over:
		combat.update(SIMULATION_STEP)
	print("Combat Finished")
	var result = combat.build_result()
	print(CombatResultFormatter.format(result))
