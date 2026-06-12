class_name Naming
extends RefCounted

## Composes the player-facing name of an equipped adaptation from its build, so
## the organ visibly *evolves* as you tier it and express genes onto it
## (VISION.md §7: an adaptation carries a tier weak→super, affixes, and a rarity
## colour). Pure and Node-free — the UI reads THIS, never re-derives the string.
##
## display_name -> "Venomous Great Frontal Appendage"  (the evolved read)
## tech_line    -> "T3 · Venom I · epic"               (the precise read below it)


## The evolved name: affix adjectives + the tier-graded prefix + the base name.
static func display_name(inst: AdaptationInstance, content: Content) -> String:
	var def := content.adaptation(inst.def_id)
	var base := String(def.get("name", inst.def_id))
	var parts: Array[String] = []
	for express: Dictionary in inst.affixes:
		var adj := String(content.affix(String(express.get("id", ""))).get("adjective", ""))
		if adj != "":
			parts.append(adj)
	var prefix := _tier_prefix(def, inst.tier)
	if prefix != "":
		parts.append(prefix)
	parts.append(base)
	return " ".join(parts)


## The precise read kept beneath the evolved name: tier, each express's roman
## tier, and the rarity word. e.g. "T3 · Venom I · epic".
static func tech_line(inst: AdaptationInstance, content: Content) -> String:
	var parts: Array[String] = ["T%d" % inst.tier]
	for express: Dictionary in inst.affixes:
		var aff := content.affix(String(express.get("id", "")))
		parts.append("%s %s" % [String(aff.get("name", "")), _roman(int(express.get("tier", 1)))])
	parts.append(inst.rarity)
	return " · ".join(parts)


static func _tier_prefix(def: Dictionary, tier: int) -> String:
	var prefixes: Array = def.get("tier_prefix", [])
	if prefixes.is_empty():
		return ""
	return String(prefixes[clampi(tier - 1, 0, prefixes.size() - 1)])


static func _roman(n: int) -> String:
	match n:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
	return str(n)
