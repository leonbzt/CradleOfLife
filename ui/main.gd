extends Control

## Phase 2 vertical slice UI. Portrait screen (720×1280, canvas_items stretch).
## All layout is code-built from content data; no hand-authored scenes to drift.
## Pure observer of Store — every label is re-read from GameState on
## state_changed; nothing here mutates state except through Store's named
## commands.

## Seconds between foraging actions while the app is open.
const ACTION_PERIOD: float = 2.5

const BG_COLOR := Color("0b1d2a")
const DIM := Color("8b9aa7")
const GOOD := Color("5fd97a")
const BAD := Color("ff7b72")
const LOCKED_COLOR := Color("44546a")

# Niche state
var _active_niche: String = "shallow_benthos"

# Widgets
var _power_value: Label
var _niche_buttons: Dictionary = {}   # niche_id -> Button
var _cards: Dictionary = {}           # node_id -> {card, name_lbl, matchup_lbl, danger_lbl}
var _doll_slot_labels: Dictionary = {} # slot -> {name_lbl, graft_lbl}
var _mat_labels: Dictionary = {}      # material_id -> Label
var _gene_rows: Dictionary = {}       # gene_id -> {row, count_lbl}
var _splice_list: VBoxContainer
var _pop_layer: Control
var _graft_sheet: Control  # modal sheet


func _ready() -> void:
	if Store.state == null:
		Store.new_game(int(Time.get_unix_time_from_system()))
	_build_ui()
	Store.state_changed.connect(_refresh)
	Store.loot_dropped.connect(_on_loot)

	var timer := Timer.new()
	timer.wait_time = ACTION_PERIOD
	timer.autostart = true
	timer.timeout.connect(func() -> void: Store.forage(_lineage().id, ACTION_PERIOD))
	add_child(timer)

	_refresh()


func _lineage() -> Lineage:
	return Store.state.lineages[0]


# -- build (once) -------------------------------------------------------------


func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 18
	theme = ui_theme

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	_build_header(col)
	_build_niche_selector(col)
	col.add_child(_section_label("THE WILD"))
	_build_node_cards(col)
	col.add_child(_section_label("THE BUILD"))
	_build_doll(col)
	col.add_child(_section_label("METABOLIZE"))
	_build_metabolize_buttons(col)
	col.add_child(_section_label("SPLICE OFFERS"))
	_splice_list = VBoxContainer.new()
	_splice_list.add_theme_constant_override("separation", 6)
	col.add_child(_splice_list)
	col.add_child(_section_label("GENE CODEX"))
	_build_gene_codex(col)
	col.add_child(_section_label("STASH"))
	col.add_child(_build_stash_row())

	_pop_layer = Control.new()
	_pop_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pop_layer)

	_graft_sheet = _build_graft_sheet()
	add_child(_graft_sheet)


func _build_header(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	col.add_child(row)

	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(who)
	var name_label := Label.new()
	name_label.text = _lineage().display_name
	name_label.add_theme_font_size_override("font_size", 30)
	who.add_child(name_label)
	var age_label := Label.new()
	age_label.text = "Age I: The Sea  ·  Cambrian meta"
	age_label.add_theme_color_override("font_color", DIM)
	age_label.add_theme_font_size_override("font_size", 15)
	who.add_child(age_label)

	var power := VBoxContainer.new()
	row.add_child(power)
	var caption := Label.new()
	caption.text = "POWER"
	caption.add_theme_color_override("font_color", DIM)
	caption.add_theme_font_size_override("font_size", 14)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power.add_child(caption)
	_power_value = Label.new()
	_power_value.add_theme_font_size_override("font_size", 36)
	_power_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power.add_child(_power_value)


func _build_niche_selector(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	for niche: Dictionary in Data.content.tables.get("niches", []):
		var niche_id := String(niche.get("id", ""))
		var btn := Button.new()
		btn.text = String(niche.get("name", niche_id))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: _select_niche(niche_id))
		row.add_child(btn)
		_niche_buttons[niche_id] = btn


func _build_node_cards(col: VBoxContainer) -> void:
	for node: Dictionary in Data.content.tables.get("nodes", []):
		var node_id := String(node.get("id", ""))
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 96)
		card.pressed.connect(func() -> void: Store.assign_node(_lineage().id, node_id))

		var pad := MarginContainer.new()
		pad.set_anchors_preset(Control.PRESET_FULL_RECT)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["margin_left", "margin_right"]:
			pad.add_theme_constant_override(side, 14)
		for side in ["margin_top", "margin_bottom"]:
			pad.add_theme_constant_override(side, 8)
		card.add_child(pad)

		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(box)

		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(top)
		var name_lbl := Label.new()
		name_lbl.text = String(node.get("name", node_id))
		name_lbl.add_theme_font_size_override("font_size", 21)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_lbl)

		var stats := HBoxContainer.new()
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(stats)
		var def_lbl := Label.new()
		def_lbl.text = "DEF %d" % int(node.get("defense", 0))
		def_lbl.add_theme_color_override("font_color", DIM)
		stats.add_child(def_lbl)
		var danger_lbl := Label.new()
		danger_lbl.add_theme_color_override("font_color", BAD)
		stats.add_child(danger_lbl)

		var matchup_lbl := Label.new()
		box.add_child(matchup_lbl)

		var flavor_lbl := Label.new()
		flavor_lbl.text = String(node.get("flavor", ""))
		flavor_lbl.add_theme_color_override("font_color", DIM)
		flavor_lbl.add_theme_font_size_override("font_size", 14)
		flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(flavor_lbl)

		_cards[node_id] = {
			"card": card,
			"name_lbl": name_lbl,
			"matchup_lbl": matchup_lbl,
			"danger_lbl": danger_lbl,
		}
		col.add_child(card)


func _build_doll(col: VBoxContainer) -> void:
	for slot: String in Lineage.SLOTS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 52)
		col.add_child(row)

		var slot_btn := Button.new()
		slot_btn.text = slot.replace("_", " ").capitalize()
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.pressed.connect(func() -> void: _open_graft_sheet(slot))
		row.add_child(slot_btn)

		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var graft_lbl := Label.new()
		graft_lbl.add_theme_color_override("font_color", DIM)
		graft_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(graft_lbl)

		_doll_slot_labels[slot] = {"name_lbl": name_lbl, "graft_lbl": graft_lbl}


func _build_metabolize_buttons(col: VBoxContainer) -> void:
	for def: Dictionary in Data.content.tables.get("adaptations", []):
		var adaptation_id := String(def.get("id", ""))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.pressed.connect(func() -> void: _on_metabolize_pressed(adaptation_id))
		col.add_child(btn)
		# Store reference by slot+id for refresh
		var slot := String(def.get("slot", ""))
		if not _doll_slot_labels.has("_btn_" + adaptation_id):
			_doll_slot_labels["_btn_" + adaptation_id] = {"btn": btn, "def": def}


func _build_gene_codex(col: VBoxContainer) -> void:
	for gene: Dictionary in Data.content.tables.get("genes", []):
		var gene_id := String(gene.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = String(gene.get("name", gene_id))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", RarityColors.of(String(gene.get("rarity", "common"))))
		row.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.add_theme_color_override("font_color", DIM)
		row.add_child(count_lbl)

		_gene_rows[gene_id] = {"row": row, "count_lbl": count_lbl}


func _build_stash_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	for mat: Dictionary in Data.content.tables.get("materials", []):
		var mat_id := String(mat.get("id", ""))
		var l := Label.new()
		l.add_theme_color_override("font_color", RarityColors.of(String(mat.get("rarity", ""))))
		row.add_child(l)
		_mat_labels[mat_id] = l
	return row


func _build_graft_sheet() -> Control:
	var sheet := PanelContainer.new()
	sheet.visible = false
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.size_flags_vertical = Control.SIZE_SHRINK_END
	sheet.custom_minimum_size = Vector2(0, 400)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	sheet.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title_lbl := Label.new()
	title_lbl.text = "GRAFT"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(func() -> void: sheet.visible = false)
	header.add_child(close_btn)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	vbox.add_child(list)
	sheet.set_meta("title_lbl", title_lbl)
	sheet.set_meta("list", list)
	return sheet


# -- niche selection ----------------------------------------------------------


func _select_niche(niche_id: String) -> void:
	_active_niche = niche_id
	_refresh()


# -- refresh (every state change) ---------------------------------------------


func _refresh() -> void:
	var l := _lineage()
	var content := Data.content
	_power_value.text = "%.0f" % Resolve.effective_power(l)

	# Niche selector buttons
	for niche_id: String in _niche_buttons:
		var btn := _niche_buttons[niche_id] as Button
		var is_active := niche_id == _active_niche
		var is_locked := not Commands.meets_niche_keys(l, content, niche_id)
		if is_active:
			btn.modulate = Color.WHITE
		elif is_locked:
			btn.modulate = Color(1, 1, 1, 0.45)
		else:
			btn.modulate = Color(1, 1, 1, 0.75)
		var niche := content.niche(niche_id)
		var keys: Array = niche.get("affix_keys", [])
		if is_locked and not keys.is_empty():
			btn.tooltip_text = "Requires: an equipped %s adaptation." % String(keys[0]).capitalize()
		else:
			btn.tooltip_text = ""

	# Node cards — show only active niche
	for node_id: String in _cards:
		var node := content.node(node_id)
		var refs: Dictionary = _cards[node_id]
		var card := refs["card"] as Button
		var node_niche := String(node.get("niche", ""))
		card.visible = node_niche == _active_niche

		if not card.visible:
			continue

		var active := l.assigned_node == node_id
		(refs["name_lbl"] as Label).text = (
			String(node.get("name", node_id)) + (" · working" if active else "")
		)
		card.modulate = Color.WHITE if active else Color(1, 1, 1, 0.72)

		var danger := float(node.get("danger", 0.0))
		var danger_lbl := refs["danger_lbl"] as Label
		if danger > 0:
			danger_lbl.text = "  DANGER %d" % int(danger)
			danger_lbl.visible = true
		else:
			danger_lbl.visible = false

		var margin := Resolve.effective_power(l) - float(node.get("defense", 0.0))
		var verdict := "outgeared"
		var color := BAD
		if margin > 2.0:
			verdict = "free farm"
			color = GOOD
		elif margin > 0.0:
			verdict = "winning matchup"
			color = GOOD
		elif is_zero_approx(margin):
			verdict = "even matchup"
			color = DIM
		var matchup_lbl := refs["matchup_lbl"] as Label
		matchup_lbl.text = "%s · yield ×%.1f" % [verdict, Resolve.yield_efficiency(l, node, content)]
		matchup_lbl.add_theme_color_override("font_color", color)

	# Doll — all 6 slots
	for slot: String in _doll_slot_labels:
		if slot.begins_with("_btn_"):
			continue
		var refs: Dictionary = _doll_slot_labels[slot]
		var name_lbl := refs["name_lbl"] as Label
		var graft_lbl := refs["graft_lbl"] as Label
		var inst: AdaptationInstance = l.doll.get(slot)
		if inst == null:
			name_lbl.text = "— empty —"
			name_lbl.add_theme_color_override("font_color", DIM)
			graft_lbl.text = ""
		else:
			var def := content.adaptation(inst.def_id)
			name_lbl.text = "%s · T%d" % [String(def.get("name", inst.def_id)), inst.tier]
			name_lbl.add_theme_color_override("font_color", RarityColors.of(inst.rarity))
			# Graft chips: "Name I  Name II"
			var graft_parts: Array[String] = []
			for graft: Dictionary in inst.affixes:
				var ar := content.affix(String(graft.get("id", "")))
				var roman := _roman(int(graft.get("tier", 1)))
				graft_parts.append("%s %s" % [String(ar.get("name", "")), roman])
			graft_lbl.text = "  ".join(graft_parts)

	# Metabolize buttons
	for key: String in _doll_slot_labels:
		if not key.begins_with("_btn_"):
			continue
		var refs: Dictionary = _doll_slot_labels[key]
		var btn := refs["btn"] as Button
		var def: Dictionary = refs["def"]
		_refresh_metabolize_button(btn, def)

	# Splice offers
	_refresh_splice_offers()

	# Gene codex
	for gene_id: String in _gene_rows:
		var refs: Dictionary = _gene_rows[gene_id]
		var count := int(Store.state.genes_known.get(gene_id, 0))
		var count_lbl := refs["count_lbl"] as Label
		var row_node := refs["row"] as Control
		if count == 0:
			row_node.modulate = Color(1, 1, 1, 0.3)
			count_lbl.text = ""
		else:
			row_node.modulate = Color.WHITE
			count_lbl.text = "×%d" % count

	# Stash
	for mat_id: String in _mat_labels:
		var mat := content.material(mat_id)
		var qty := floori(float(Store.state.inventory_materials.get(mat_id, 0.0)))
		(_mat_labels[mat_id] as Label).text = "%s %d" % [String(mat.get("name", mat_id)), qty]


func _refresh_metabolize_button(btn: Button, def: Dictionary) -> void:
	var adaptation_id := String(def.get("id", ""))
	var def_name := String(def.get("name", adaptation_id))
	var tier := Commands.next_tier(_lineage(), def)
	if tier == 0:
		btn.text = "%s — maxed" % def_name
		btn.disabled = true
		return
	var cost := Commands.metabolize_cost(def, tier)
	var mat_id := String(cost.keys()[0])
	var qty := int(cost[mat_id])
	var mat_name := String(Data.content.material(mat_id).get("name", mat_id))
	var verb := "Build" if tier == 1 else "Tier %d" % tier
	btn.text = "%s %s — %d %s" % [verb, def_name, qty, mat_name]
	btn.disabled = float(Store.state.inventory_materials.get(mat_id, 0.0)) < float(qty)


func _refresh_splice_offers() -> void:
	for child in _splice_list.get_children():
		child.queue_free()

	var offers: Array = Store.state.splice_offers
	if offers.is_empty():
		var none := Label.new()
		none.text = "Splice queue empty."
		none.add_theme_color_override("font_color", DIM)
		none.add_theme_font_size_override("font_size", 14)
		_splice_list.add_child(none)
		return

	for i in range(offers.size()):
		var offer: Dictionary = offers[i]
		var gene_id := String(offer.get("gene", ""))
		var node_id := String(offer.get("node", ""))
		var gene_row := Data.content.gene(gene_id)
		var gene_name := String(gene_row.get("name", gene_id))
		var rarity := String(gene_row.get("rarity", "common"))
		var node_row := Data.content.node(node_id)
		var node_name := String(node_row.get("name", node_id))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_splice_list.add_child(row)

		var lbl := Label.new()
		lbl.text = "Splice offer: %s  ·  source: %s" % [gene_name, node_name]
		lbl.add_theme_color_override("font_color", RarityColors.of(rarity))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var idx := i  # capture for closure
		var claim_btn := Button.new()
		claim_btn.text = "Claim"
		claim_btn.pressed.connect(func() -> void: _on_claim_splice(idx))
		row.add_child(claim_btn)


# -- graft sheet --------------------------------------------------------------


var _graft_slot: String = ""


func _open_graft_sheet(slot: String) -> void:
	_graft_slot = slot
	var sheet := _graft_sheet
	var list := sheet.get_meta("list") as VBoxContainer
	var title_lbl := sheet.get_meta("title_lbl") as Label

	for child in list.get_children():
		child.queue_free()

	var l := _lineage()
	var content := Data.content
	var inst: AdaptationInstance = l.doll.get(slot)
	title_lbl.text = "GRAFT — %s" % slot.capitalize()

	if inst == null:
		var note := Label.new()
		note.text = "Slot empty — metabolize to fill."
		note.add_theme_color_override("font_color", DIM)
		list.add_child(note)
		sheet.visible = true
		return

	# Show graftable affixes: those whose unlocking gene has >= 1 copy
	var any_graftable := false
	for affix: Dictionary in content.tables.get("affixes", []):
		var affix_id := String(affix.get("id", ""))
		var gene_row := content.gene_for_affix(affix_id)
		if gene_row.is_empty():
			continue
		var gene_id := String(gene_row.get("id", ""))
		var copies := int(Store.state.genes_known.get(gene_id, 0))
		if copies == 0:
			continue

		any_graftable = true
		var current_tier := inst.graft_tier(affix_id)
		var target_tier := current_tier + 1

		var gc: Dictionary = affix.get("graft_cost", {})
		var mat := String(gc.get("material", ""))
		var cost_qty := int(roundf(
			float(gc.get("base", 0.0)) * pow(float(gc.get("growth", 1.0)), target_tier - 1)
		))
		var have_mat := int(Store.state.inventory_materials.get(mat, 0.0))
		var mat_name := String(content.material(mat).get("name", mat))

		var can_afford := have_mat >= cost_qty
		var has_copies := copies >= target_tier

		var row := HBoxContainer.new()
		list.add_child(row)
		var info_lbl := Label.new()
		var tier_str := "T%d→T%d" % [current_tier, target_tier] if current_tier > 0 else "→T1"
		info_lbl.text = "%s  %s  (%d/%d copies · %d %s)" % [
			String(affix.get("name", affix_id)), tier_str, copies, target_tier, cost_qty, mat_name
		]
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not can_afford:
			info_lbl.add_theme_color_override("font_color", DIM)
		row.add_child(info_lbl)

		var aid := affix_id  # capture
		var graft_btn := Button.new()
		graft_btn.text = "Graft"
		graft_btn.disabled = not (can_afford and has_copies)
		graft_btn.pressed.connect(func() -> void: _on_graft_pressed(_graft_slot, aid))
		row.add_child(graft_btn)

	if not any_graftable:
		var note := Label.new()
		note.text = "No genes in codex. Work the fight nodes."
		note.add_theme_color_override("font_color", DIM)
		list.add_child(note)

	sheet.visible = true


# -- event handlers -----------------------------------------------------------


func _on_metabolize_pressed(adaptation_id: String) -> void:
	var result := Store.metabolize(_lineage().id, adaptation_id)
	if not result["ok"]:
		return
	var inst: AdaptationInstance = result["instance"]
	var def := Data.content.adaptation(inst.def_id)
	# Find the button for this adaptation
	for key: String in _doll_slot_labels:
		if key == "_btn_" + adaptation_id:
			var refs: Dictionary = _doll_slot_labels[key]
			var btn := refs["btn"] as Button
			var at := btn.global_position + Vector2(btn.size.x * 0.5, 0.0)
			LootPop.spawn(
				_pop_layer,
				at,
				"%s T%d" % [String(def.get("name", inst.def_id)), inst.tier],
				RarityColors.of(inst.rarity)
			)
			_pulse(btn)
			break


func _on_claim_splice(index: int) -> void:
	var result := Store.claim_splice(index)
	if not result["ok"]:
		return
	var gene_id := String(result.get("gene", ""))
	var gene_row := Data.content.gene(gene_id)
	var rarity := String(gene_row.get("rarity", "common"))
	var at := get_viewport().get_visible_rect().size * 0.5
	LootPop.spawn(
		_pop_layer,
		at,
		"Spliced: %s" % String(gene_row.get("name", gene_id)),
		RarityColors.of(rarity)
	)


func _on_graft_pressed(slot: String, affix_id: String) -> void:
	var result := Store.graft(_lineage().id, slot, affix_id)
	if not result["ok"]:
		return
	var inst: AdaptationInstance = result["instance"]
	var affix_row := Data.content.affix(affix_id)
	var at := get_viewport().get_visible_rect().size * Vector2(0.5, 0.75)
	LootPop.spawn(
		_pop_layer,
		at,
		"Grafted: %s" % String(affix_row.get("name", affix_id)),
		RarityColors.of(inst.rarity)
	)
	_open_graft_sheet(slot)


func _on_loot(_lineage_id: String, loot: Dictionary) -> void:
	var refs: Dictionary = _cards.get(_lineage().assigned_node, {})
	if refs.is_empty():
		return
	var card := refs["card"] as Button
	if not card.visible:
		return
	var at := card.global_position + Vector2(card.size.x * 0.66, 16.0)

	var mats: Dictionary = loot["materials"]
	for mat_id: String in mats:
		var qty := float(mats[mat_id])
		var mat := Data.content.material(mat_id)
		var amount := "+%d" % roundi(qty) if qty >= 0.95 else "+%.1f" % qty
		LootPop.spawn(
			_pop_layer,
			at + Vector2(0.0, -20.0),
			"%s %s" % [amount, String(mat.get("name", mat_id))],
			RarityColors.of(String(mat.get("rarity", "common")))
		)

	var gene: Dictionary = loot["gene"]
	if not gene.is_empty():
		var gene_id := String(gene.get("id", ""))
		var gene_row := Data.content.gene(gene_id)
		LootPop.spawn(
			_pop_layer,
			at + Vector2(0.0, 30.0),
			"Gene: %s" % String(gene_row.get("name", gene_id)),
			RarityColors.of(String(gene.get("rarity", "common")))
		)

	var offer := String(loot["splice_offer"])
	if offer != "":
		var gene_row := Data.content.gene(offer)
		LootPop.spawn(
			_pop_layer,
			at + Vector2(0.0, 60.0),
			"Splice offer: %s" % String(gene_row.get("name", offer)),
			RarityColors.of(String(gene_row.get("rarity", "common")))
		)


func _pulse(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(1.3, 1.3)
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _section_label(caption: String) -> Label:
	var l := Label.new()
	l.text = caption
	l.add_theme_color_override("font_color", DIM)
	l.add_theme_font_size_override("font_size", 16)
	return l


func _roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		5: return "V"
	return str(n)
