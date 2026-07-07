class_name Doctrines

## Battlefield doctrines: the tactics are recovered knowledge, not
## menu options. A fresh guild knows only how to hit the nearest foe;
## the rest is doctrine, recovered from those who practice it.

const ALL := {
	"lowest": {
		"name": "Finish the Wounded",
		"tome": "Doctrine of the Culling Shot",
		"lore": "The old guild's archers never wasted an arrow on the hale while the hurt still stood.",
	},
	"priority": {
		"name": "Focus Order",
		"tome": "Doctrine of the Marked Prey",
		"lore": "Kill by the list. The list is written before the fight.",
	},
	"spread": {
		"name": "Spread the Venom",
		"tome": "Doctrine of the Creeping Venom",
		"lore": "One drop in every cup. The nest taught us that.",
	},
	"protect": {
		"name": "Protect the Healer",
		"tome": "Doctrine of the Warding Hand",
		"lore": "The one who mends is the one they hunt. Stand where the hunt must pass.",
	},
	"guard": {
		"name": "Guard the Line",
		"tome": "Doctrine of the Shield-Line",
		"lore": "Strike the one who is not looking at you, until every one of them is.",
	},
}

## Doctrine complexity: how many nodes a custom battlefield doctrine
## may hold. Recovered knowledge, like everything else.
const CAPACITY := {
	"doctrine_capacity_1": {
		"nodes": 4,
		"tome": "Battlefield Doctrine I",
		"lore": "Four marks on the field slate. The old guild started every recruit here.",
	},
	"doctrine_capacity_2": {
		"nodes": 8,
		"tome": "Battlefield Doctrine II",
		"lore": "Eight marks. Enough for a plan with a second thought in it.",
	},
	"doctrine_capacity_3": {
		"nodes": 16,
		"tome": "Battlefield Doctrine III",
		"lore": "Sixteen marks, annotated in three hands. The war room remembered everything.",
	},
}

## Guild engineering tools: the Slate turns the doctrine editor into
## snap-together blocks; the Annotations reveal the code the blocks
## have been writing all along. Their teachers wait in dungeons not
## yet mapped.
const TOOLS := {
	"engineers_slate": {
		"tome": "The Engineer's Slate",
		"lore": "The old guild's engineers drew their doctrine as fitted blocks. The slate still remembers the shapes.",
	},
	"engineers_annotations": {
		"tome": "The Engineer's Annotations",
		"lore": "In the margins, the same doctrine again - written as the machine reads it. The blocks were always words.",
	},
}
