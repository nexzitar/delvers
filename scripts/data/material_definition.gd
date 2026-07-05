extends Resource
class_name MaterialDefinition

## A crafting material: consumed by recipes (and later by camp
## buildings). Each monster family drops its own materials.

@export var material_id: String
@export var material_name: String
## Display tier — colors the name like gear rarity does.
@export var tier: ItemQuality.Tier = ItemQuality.Tier.COMMON
@export var icon: Texture2D
