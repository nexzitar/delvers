extends Resource
class_name LoreDefinition

## A recovered fragment of the world's history — an expedition log, a
## letter, a warning scratched into a wall. No gameplay effect: pure
## memory, shelved in the camp library. Recovered in `order`, so the
## story assembles the way a trail of evidence would.

@export var lore_id: String
@export var title: String
@export_multiline var body: String
@export var order: int = 0
