extends Node

## Autoloaded game state: the heroes the player has unlocked and the
## party's progress. Shared by the camp scenes and the battle theater.

const DEFAULT_DELVER = preload("res://resources/heroes/default_delver.tres")
const RANGER_DELVER = preload("res://resources/heroes/ranger_delver.tres")

var heroes: Array = [
	DEFAULT_DELVER,
	DEFAULT_DELVER,
	RANGER_DELVER,
]

var battles_fought := 0
var adventures_completed := 0
var last_battle_won := false

## How lively the camp fire burns, 0..1. Starts as smoldering coals
## and grows with the party's size and completed adventures.
func fire_intensity() -> float:
	return clampf(
		0.08 + heroes.size() * 0.03 + adventures_completed * 0.08,
		0.0,
		1.0
	)
