class_name AdaptationInstance
extends RefCounted

## One equipped adaptation = one gear item in a body-part slot (VISION.md §7).
## Carries a tier (weak -> super), affixes (frost, venom, ...), and a rarity
## colour (common -> legendary). Swapping these IS the build.

var def_id: String  # -> data/adaptations.json
var tier: int = 1
var affixes: Array[String] = []  # affix ids -> data/affixes.json
var rarity: String = "common"


func _init(p_def_id: String = "", p_tier: int = 1) -> void:
	def_id = p_def_id
	tier = p_tier


func to_dict() -> Dictionary:
	return {
		"def_id": def_id,
		"tier": tier,
		"affixes": affixes.duplicate(),
		"rarity": rarity,
	}


static func from_dict(d: Dictionary) -> AdaptationInstance:
	var a := AdaptationInstance.new(String(d.get("def_id", "")), int(d.get("tier", 1)))
	for x: Variant in d.get("affixes", []):
		a.affixes.append(String(x))
	a.rarity = String(d.get("rarity", "common"))
	return a
