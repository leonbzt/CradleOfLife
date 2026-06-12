class_name AdaptationInstance
extends RefCounted

## One equipped adaptation = one gear item in a body-part slot (VISION.md §7).
## Carries a tier (weak → super), expressed affixes, and a rarity colour
## (common → legendary). Swapping and expressing these IS the build.

var def_id: String  # -> data/adaptations.json
var tier: int = 1
var affixes: Array[Dictionary] = []  # expressed affixes: [{id: String, tier: int}]
var rarity: String = "common"


func _init(p_def_id: String = "", p_tier: int = 1) -> void:
	def_id = p_def_id
	tier = p_tier


## The tier of a expressed affix on this instance, or 0 if not expressed.
func express_tier(affix_id: String) -> int:
	for express: Dictionary in affixes:
		if String(express.get("id", "")) == affix_id:
			return int(express.get("tier", 0))
	return 0


func to_dict() -> Dictionary:
	return {
		"def_id": def_id,
		"tier": tier,
		"affixes": affixes.duplicate(true),
		"rarity": rarity,
	}


static func from_dict(d: Dictionary) -> AdaptationInstance:
	var a := AdaptationInstance.new(String(d.get("def_id", "")), int(d.get("tier", 1)))
	for x: Variant in d.get("affixes", []):
		if x is Dictionary:
			a.affixes.append((x as Dictionary).duplicate())
		elif x is String:
			# Tolerate bare string entries from older saves (pre-v2 expresses were
			# never persisted, so this branch is defensive, not load-bearing).
			a.affixes.append({"id": String(x), "tier": 1})
	a.rarity = String(d.get("rarity", "common"))
	return a
