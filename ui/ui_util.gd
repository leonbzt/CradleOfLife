class_name UiUtil
extends RefCounted

## Shared UI constants and pure helpers, so the per-tab scripts (and the shell)
## don't duplicate them or reference each other. Leaf class — depends only on
## content/sim types, never on the tabs or the shell.

const BG := Color("0b1d2a")
const DIM := Color("8b9aa7")
const GOOD := Color("5fd97a")
const BAD := Color("ff7b72")


## A dim, small section caption.
static func section_label(caption: String) -> Label:
	var l := Label.new()
	l.text = caption
	l.add_theme_color_override("font_color", DIM)
	l.add_theme_font_size_override("font_size", 16)
	return l


## The juice budget: a quick scale punch that settles back to 1.0.
static func pulse(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(1.3, 1.3)
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


## Rarity → sort rank (higher is rarer). Used to lead with the best drop.
static func rarity_rank(rarity: String) -> int:
	match rarity:
		"legendary":
			return 5
		"epic":
			return 4
		"rare":
			return 3
		"uncommon":
			return 2
		"common":
			return 1
	return 0


static func slot_label(slot: String) -> String:
	return slot.replace("_", " ").capitalize()


## The class whose unlock grants `category` (for "requires X" hints), or a
## prettified category name if none claims it.
static func class_for_category(category: String, content: Content) -> String:
	for row: Dictionary in content.tables.get("class_tree", []):
		if (row.get("unlocks_categories", []) as Array).has(category):
			return String(row.get("name", category))
	return category.replace("_", " ").capitalize()


## "drops at A, B · splice from C" for a gene, for the key/codex panels.
static func gene_source_text(content: Content, gene_id: String) -> String:
	var drops: Array[String] = []
	var splices: Array[String] = []
	for src: Dictionary in content.sources_for_gene(gene_id):
		var node_name := String(src.get("name", ""))
		if (src.get("via", []) as Array).has("drop"):
			drops.append(node_name)
		if (src.get("via", []) as Array).has("splice"):
			splices.append(node_name)
	var parts: Array[String] = []
	if not drops.is_empty():
		parts.append("drops at " + ", ".join(drops))
	if not splices.is_empty():
		parts.append("splice from " + ", ".join(splices))
	return " · ".join(parts) if not parts.is_empty() else "no known source yet"


## A valid slot to express `affix` onto: prefer one already holding an organ with
## room; else any organ-bearing valid slot; else the first valid slot.
static func first_expressible_slot(l: Lineage, slots: Array) -> String:
	var fallback := String(slots[0]) if not slots.is_empty() else ""
	var has_organ := ""
	for s: Variant in slots:
		var slot := String(s)
		var inst: AdaptationInstance = l.doll.get(slot)
		if inst != null:
			if has_organ == "":
				has_organ = slot
			if inst.affixes.size() < Commands.slot_express_cap(slot):
				return slot
	return has_organ if has_organ != "" else fallback
