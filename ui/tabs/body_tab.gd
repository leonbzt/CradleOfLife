class_name BodyTab
extends VBoxContainer

## The build tab (PHASE3_5 WP3 metabolize-as-choice): one card per doll slot —
## current organ, the attribute it feeds, the choose-one metabolize options, and an
## Express shortcut — plus the gene codex. Owned genes get an Express ▸ in the codex
## so there's always an obvious place to put a gene you just earned.

var _ui: UiState
var _pop_layer: Control
var _express: ExpressSheet

# slot -> {card, attr_lbl, name_lbl, tech_lbl, express_btn, option_btns:{id->{btn,def}}}
var _slot_cards: Dictionary = {}
# gene_id -> {row, count_lbl, express_btn, slots:Array}
var _gene_rows: Dictionary = {}


func setup(ui: UiState, pop_layer: Control, express: ExpressSheet) -> void:
	_ui = ui
	_pop_layer = pop_layer
	_express = express
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)

	add_child(
		UiUtil.section_label(
			"THE BUILD  ·  choose what each organ becomes, then express genes onto it"
		)
	)
	_build_body_slots()
	add_child(UiUtil.section_label("GENE CODEX  ·  copies unlock express tiers"))
	_build_gene_codex()


func refresh() -> void:
	_refresh_body_slots()
	_refresh_gene_codex()
	# An agenda "tier up" jump pulses the organ it pointed at, once.
	if _ui.focus_slot != "" and _slot_cards.has(_ui.focus_slot):
		UiUtil.pulse(_slot_cards[_ui.focus_slot]["card"] as Control)
		_ui.focus_slot = ""


# -- per-slot cards -----------------------------------------------------------


func _build_body_slots() -> void:
	for slot: String in Lineage.SLOTS:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(card)
		var pad := MarginContainer.new()
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			pad.add_theme_constant_override(side, 12)
		card.add_child(pad)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		pad.add_child(box)

		var head := HBoxContainer.new()
		box.add_child(head)
		var slot_lbl := Label.new()
		slot_lbl.text = UiUtil.slot_label(slot)
		slot_lbl.add_theme_font_size_override("font_size", 16)
		slot_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		slot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(slot_lbl)
		var attr_lbl := Label.new()
		attr_lbl.add_theme_font_size_override("font_size", 16)
		attr_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		head.add_child(attr_lbl)

		var name_row := HBoxContainer.new()
		box.add_child(name_row)
		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 21)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.custom_minimum_size = Vector2(1, 0)
		name_row.add_child(name_lbl)
		var express_btn := Button.new()
		express_btn.text = "Express ▸"
		var slot_capture := slot
		express_btn.pressed.connect(func() -> void: _express.open(slot_capture))
		name_row.add_child(express_btn)

		var tech_lbl := Label.new()
		tech_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		tech_lbl.add_theme_font_size_override("font_size", 16)
		box.add_child(tech_lbl)

		var prompt := Label.new()
		prompt.text = "What this organ can become:"
		prompt.add_theme_color_override("font_color", UiUtil.DIM)
		prompt.add_theme_font_size_override("font_size", 16)
		box.add_child(prompt)

		var options_box := VBoxContainer.new()
		options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_box.add_theme_constant_override("separation", 4)
		box.add_child(options_box)

		var option_btns: Dictionary = {}
		for def: Dictionary in Data.content.tables.get("adaptations", []):
			if String(def.get("slot", "")) != slot:
				continue
			var adaptation_id := String(def.get("id", ""))
			var btn := Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 46)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.pressed.connect(func() -> void: _on_metabolize_pressed(adaptation_id))
			options_box.add_child(btn)
			option_btns[adaptation_id] = {"btn": btn, "def": def}

		_slot_cards[slot] = {
			"card": card,
			"attr_lbl": attr_lbl,
			"name_lbl": name_lbl,
			"tech_lbl": tech_lbl,
			"express_btn": express_btn,
			"option_btns": option_btns,
		}


func _refresh_body_slots() -> void:
	var l := _ui.active_lineage()
	var content := Data.content
	for slot: String in _slot_cards:
		var refs: Dictionary = _slot_cards[slot]
		var inst: AdaptationInstance = l.doll.get(slot)
		var name_lbl := refs["name_lbl"] as Label
		var tech_lbl := refs["tech_lbl"] as Label
		var attr_lbl := refs["attr_lbl"] as Label
		var express_btn := refs["express_btn"] as Button

		if inst == null:
			name_lbl.text = "— empty —"
			name_lbl.add_theme_color_override("font_color", UiUtil.DIM)
			tech_lbl.text = ""
			attr_lbl.text = _attr_hint(String(Resolve.SLOT_ATTRIBUTE.get(slot, "")))
			express_btn.disabled = true
			express_btn.tooltip_text = "Metabolize an organ into this slot first."
		else:
			name_lbl.text = Naming.display_name(inst, content)
			name_lbl.add_theme_color_override("font_color", RarityColors.of(inst.rarity))
			tech_lbl.text = Naming.tech_line(inst, content)
			attr_lbl.text = _attr_hint(
				Resolve.attribute_for_def(content.adaptation(inst.def_id), slot)
			)
			express_btn.disabled = false
			express_btn.tooltip_text = "Express a banked gene onto this organ."

		var option_btns: Dictionary = refs["option_btns"]
		for adaptation_id: String in option_btns:
			var entry: Dictionary = option_btns[adaptation_id]
			_refresh_option_btn(l, content, slot, inst, entry["btn"] as Button, entry["def"])


## "feeds Power" / "affix host" for the per-slot attribute hint.
func _attr_hint(attr: String) -> String:
	return "feeds %s" % attr.capitalize() if attr != "" else "affix host"


## One metabolize option: its name + the attribute it grows + build/tier cost, or a
## replace note. Tapping metabolizes it.
func _refresh_option_btn(
	l: Lineage,
	content: Content,
	slot: String,
	inst: AdaptationInstance,
	btn: Button,
	def: Dictionary
) -> void:
	var def_name := String(def.get("name", def.get("id", "")))
	var attr := Resolve.attribute_for_def(def, slot)
	var attr_tag := attr.capitalize() if attr != "" else "affix host"
	btn.modulate = Color.WHITE

	var is_current := inst != null and inst.def_id == String(def.get("id", ""))
	if is_current:
		var tier := Commands.next_tier(l, def)
		if tier == 0:
			btn.text = "%s · %s — maxed (T%d)" % [def_name, attr_tag, int(def.get("max_tier", 1))]
			btn.disabled = true
			btn.tooltip_text = ""
			return
		var cost := Commands.metabolize_cost(def, tier)
		var mat_id := String(cost.keys()[0])
		var qty := int(cost[mat_id])
		var mat_name := String(content.material(mat_id).get("name", mat_id))
		btn.text = "Tier %d  ·  %s — %d %s" % [tier, def_name, qty, mat_name]
		btn.disabled = float(Store.state.inventory_materials.get(mat_id, 0.0)) < float(qty)
		btn.tooltip_text = ""
		return

	# A different organ for this slot: build (empty) or switch (replace).
	var cost := Commands.metabolize_cost(def, 1)
	var mat_id := String(cost.keys()[0])
	var qty := int(cost[mat_id])
	var mat_name := String(content.material(mat_id).get("name", mat_id))
	var verb := "Build" if inst == null else "Switch to"
	btn.text = "%s %s · %s — %d %s" % [verb, def_name, attr_tag, qty, mat_name]
	btn.disabled = float(Store.state.inventory_materials.get(mat_id, 0.0)) < float(qty)
	if inst == null:
		btn.tooltip_text = ""
	else:
		btn.tooltip_text = (
			"Replaces %s and rebuilds from T1. Expressed genes return to your codex (copies kept)."
			% Naming.display_name(inst, content)
		)


func _on_metabolize_pressed(adaptation_id: String) -> void:
	var result := Store.metabolize(_ui.active_lineage().id, adaptation_id)
	if not result["ok"]:
		return
	var inst: AdaptationInstance = result["instance"]
	var def := Data.content.adaptation(inst.def_id)
	var slot := String(def.get("slot", ""))
	var option_btns: Dictionary = (_slot_cards.get(slot, {}) as Dictionary).get("option_btns", {})
	var entry: Dictionary = option_btns.get(adaptation_id, {})
	if entry.has("btn"):
		var btn := entry["btn"] as Button
		var at := btn.global_position + Vector2(btn.size.x * 0.5, 0.0)
		LootPop.spawn(
			_pop_layer,
			at,
			"%s T%d" % [String(def.get("name", inst.def_id)), inst.tier],
			RarityColors.of(inst.rarity)
		)
		UiUtil.pulse(btn)


# -- gene codex ---------------------------------------------------------------


func _build_gene_codex() -> void:
	for gene: Dictionary in Data.content.tables.get("genes", []):
		var gene_id := String(gene.get("id", ""))
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		add_child(cell)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		cell.add_child(row)

		# Tap the name to reveal description + source (touch-first inspect, §16).
		var name_btn := Button.new()
		name_btn.flat = true
		name_btn.text = String(gene.get("name", gene_id))
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_btn.add_theme_color_override(
			"font_color", RarityColors.of(String(gene.get("rarity", "common")))
		)
		row.add_child(name_btn)

		var count_lbl := Label.new()
		count_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		row.add_child(count_lbl)

		# Where to PUT a gene you own: the affix this gene unlocks declares its
		# organs; jump straight to a valid slot's express sheet.
		var affix := Data.content.affix(
			String((gene.get("unlocks", {}) as Dictionary).get("id", ""))
		)
		var slots: Array = affix.get("slots", [])
		var express_btn := Button.new()
		express_btn.text = "Express ▸"
		express_btn.visible = false
		express_btn.pressed.connect(
			func() -> void:
				_express.open(UiUtil.first_expressible_slot(_ui.active_lineage(), slots))
		)
		row.add_child(express_btn)

		var desc_lbl := Label.new()
		desc_lbl.visible = false
		desc_lbl.text = (
			"   %s\n   Source: %s"
			% [String(gene.get("flavor", "")), UiUtil.gene_source_text(Data.content, gene_id)]
		)
		desc_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(1, 0)
		cell.add_child(desc_lbl)
		name_btn.pressed.connect(func() -> void: desc_lbl.visible = not desc_lbl.visible)

		_gene_rows[gene_id] = {
			"row": cell, "count_lbl": count_lbl, "express_btn": express_btn, "slots": slots
		}


func _refresh_gene_codex() -> void:
	for gene_id: String in _gene_rows:
		var refs: Dictionary = _gene_rows[gene_id]
		var count := int(Store.state.genes_known.get(gene_id, 0))
		var count_lbl := refs["count_lbl"] as Label
		var row_node := refs["row"] as Control
		var express_btn := refs["express_btn"] as Button
		var has_target := not (refs["slots"] as Array).is_empty()
		if count == 0:
			row_node.modulate = Color(1, 1, 1, 0.3)
			count_lbl.text = ""
			express_btn.visible = false
		else:
			row_node.modulate = Color.WHITE
			count_lbl.text = "×%d" % count
			express_btn.visible = has_target
