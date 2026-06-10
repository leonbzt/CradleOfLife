class_name RarityColors
extends RefCounted

## The one rarity → colour map (VISION.md §7, §9: everything dropped or built is
## rarity-coloured). Tuned for legibility on the dark sea background.

const COLORS: Dictionary = {
	"common": Color("c8d1d9"),
	"uncommon": Color("5fd97a"),
	"rare": Color("58a6ff"),
	"epic": Color("c792ea"),
	"legendary": Color("ffa657"),
}


static func of(rarity: String) -> Color:
	return COLORS.get(rarity, COLORS["common"])
