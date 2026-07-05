extends Resource
class_name RecipeDefinition

## A piece of permanent knowledge: once learned, the camp can craft
## this item forever, given the materials.

@export var recipe_id: String
@export var recipe_name: String
## What the recipe produces, built through LootTable.materialize.
@export var result_gear_id: String
@export var result_item_level: int = 4
@export var result_quality: ItemQuality.Tier = ItemQuality.Tier.UNCOMMON
## material_id -> count consumed per craft.
@export var costs: Dictionary = {}
