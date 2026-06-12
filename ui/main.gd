extends Control

## Phase 3 UI. Portrait screen (720×1280, canvas_items stretch).
## All layout is code-built from content data; no hand-authored scenes to drift.
## Pure observer of Store — every label is re-read from GameState on
## state_changed; nothing here mutates state except through Store's named
## commands.

const ACTION_PERIOD: float = 2.5

const BG_COLOR := Color("0b1d2a")
const DIM := Color("8b9aa7")
const GOOD := Color("5fd97a")
const BAD := Color("ff7b72")

# Active lineage and pending class-commit state
var _active_lineage_idx: int = 0
var _pending_class_id: String = ""

# Niche state
var _active_niche: String = "shallow_benthos"

# Widgets
var _roster_chips: Array[Button] = []
var _branch_btn: Button
var _header_name_label: Label
var _power_value: Label
var _niche_buttons: Dictionary = {}  # niche_id -> Button
var _cards: Dictionary = {}  # node_id -> {card, btn, name_lbl, matchup_lbl, danger_lbl}
var _doll_slot_labels: Dictionary = {}  # slot -> {name_lbl, graft_lbl}; also "_btn_<id>" -> {btn, def}
var _class_panel_list: VBoxContainer
var _mat_labels: Dictionary = {}  # material_id -> Label
var _gene_rows: Dictionary = {}  # gene_id -> {row, count_lbl}
var _splice_list: VBoxContainer
var _pop_layer: Control
var _graft_sheet: Control
var _graft_slot: String = ""


func _ready() -> void:
	if Store.state == null:
		Store.new_game(int(Time.get_unix_time_from_system()))
	_build_ui()
	Store.state_changed.connect(_refresh)
	Store.loot_dropped.connect(_on_loot)

	var timer := Timer.new()
	timer.wait_time = ACTION_PERIOD
	timer.autostart = true
	timer.timeout.connect(func() -> void: Store.forage_all(ACTION_PERIOD))
	add_child(timer)

	_refresh()


func _lineage() -> Lineage:
	var lineages: Array = Store.state.lineages
	return lineages[clampi(_active_lineage_idx, 0, lineages.size() - 1)]


func _switch_lineage(idx: int) -> void:
	_active_lineage_idx = idx
	_pending_class_id = ""
	_refresh()


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
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	_build_roster_bar(col)
	_build_header(col)
	_build_niche_selector(col)
	col.add_child(_section_label("THE WILD"))
	_build_node_cards(col)
	col.add_child(_section_label("THE BUILD  ·  tap a slot to graft genes"))
	_build_doll(col)
	col.add_child(_section_label("CLASS"))
	_build_class_panel_container(col)
	col.add_child(_section_label("METABOLIZE"))
	_build_metabolize_buttons(col)
	col.add_child(_section_label("SPLICE OFFERS"))
	_splice_list = VBoxContainer.new()
	_splice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_splice_list.add_theme_constant_override("separation", 6)
	col.add_child(_splice_list)
	col.add_child(_section_label("GENE CODEX  ·  copies unlock graft tiers"))
	_build_gene_codex(col)
	col.add_child(_section_label("STASH"))
	col.add_child(_build_stash_row())

	_pop_layer = Control.new()
	_pop_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pop_layer)

	_graft_sheet = _build_graft_sheet()
	add_child(_graft_sheet)


func _build_roster_bar(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	for i in range(2):
		var chip := Button.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		chip.pressed.connect(func() -> void: _switch_lineage(idx))
		row.add_child(chip)
		_roster_chips.append(chip)
	_branch_btn = Button.new()
	_branch_btn.text = "Branch"
	_branch_btn.pressed.connect(_on_branch_pressed)
	row.add_child(_branch_btn)


func _build_header(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	col.add_child(row)

	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(who)
	_header_name_label = Label.new()
	_header_name_label.add_theme_font_size_override("font_size", 30)
	who.add_child(_header_name_label)
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
	var empty_style := StyleBoxEmpty.new()
	for node: Dictionary in Data.content.tables.get("nodes", []):
		var node_id := String(node.get("id", ""))

		var card_frame := PanelContainer.new()
		card_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(card_frame)

		var pad := MarginContainer.new()
		for side in ["margin_left", "margin_right"]:
			pad.add_theme_constant_override(side, 14)
		for side in ["margin_top", "margin_bottom"]:
			pad.add_theme_constant_override(side, 8)
		card_frame.add_child(pad)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		pad.add_child(box)

		var top := HBoxContainer.new()
		box.add_child(top)
		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 21)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_lbl)

		var stats := HBoxContainer.new()
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
		flavor_lbl.custom_minimum_size = Vector2(1, 0)
		box.add_child(flavor_lbl)

		var click_btn := Button.new()
		click_btn.flat = true
		click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		for style in ["normal", "hover", "pressed", "disabled", "focus"]:
			click_btn.add_theme_stylebox_override(style, empty_style)
		click_btn.pressed.connect(func() -> void: Store.assign_node(_lineage().id, node_id))
		card_frame.add_child(click_btn)

		_cards[node_id] = {
			"card": card_frame,
			"btn": click_btn,
			"name_lbl": name_lbl,
			"matchup_lbl": matchup_lbl,
			"danger_lbl": danger_lbl,
		}


func _build_doll(col: VBoxContainer) -> void:
	for slot: String in Lineage.SLOTS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_FILL
		row.custom_minimum_size = Vector2(0, 52)
		col.add_child(row)

		var attr := String(Resolve.SLOT_ATTRIBUTE.get(slot, ""))
		var attr_hint := ("  [%s]" % attr) if attr != "" else "  [—]"
		var slot_btn := Button.new()
		slot_btn.text = slot.replace("_", " ").capitalize() + attr_hint
		slot_btn.tooltip_text = "Tap to graft a gene onto this slot."
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


func _build_class_panel_container(col: VBoxContainer) -> void:
	_class_panel_list = VBoxContainer.new()
	_class_panel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_panel_list.add_theme_constant_override("separation", 8)
	col.add_child(_class_panel_list)


func _build_metabolize_buttons(col: VBoxContainer) -> void:
	for def: Dictionary in Data.content.tables.get("adaptations", []):
		var adaptation_id := String(def.get("id", ""))
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_FILL
		btn.custom_minimum_size = Vector2(0, 52)
		btn.pressed.connect(func() -> void: _on_metabolize_pressed(adaptation_id))
		col.add_child(btn)
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
		name_lbl.add_theme_color_override(
			"font_color", RarityColors.of(String(gene.get("rarity", "common")))
		)
		row.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.add_theme_color_override("font_color", DIM)
		row.add_child(count_lbl)

		_gene_rows[gene_id] = {"row": row, "count_lbl": count_lbl}


func _build_stash_row() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for mat: Dictionary in Data.content.tables.get("materials", []):
		var mat_id := String(mat.get("id", ""))
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", RarityColors.of(String(mat.get("rarity", ""))))
		grid.add_child(l)
		_mat_labels[mat_id] = l
	return grid


func _build_graft_sheet() -> Control:
	var sheet := PanelContainer.new()
	sheet.visible = false
	sheet.z_index = 10

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 16)
	sheet.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)

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

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(list_scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	list_scroll.add_child(list)

	sheet.set_meta("title_lbl", title_lbl)
	sheet.set_meta("list", list)
	return sheet


# -- niche / lineage selection ------------------------------------------------


func _select_niche(niche_id: String) -> void:
	_active_niche = niche_id
	_refresh()


# -- refresh (every state change) ---------------------------------------------


func _refresh() -> void:
	var l := _lineage()
	var content := Data.content

	# Header
	_header_name_label.text = l.display_name

	# Power readout — show soft-cap cue when raw power exceeds the knee
	var raw_power := float(Resolve.effective_attributes(l, content).get("power", 0.0))
	var eff_power := Resolve.effective_power(l, content)
	if raw_power > Resolve.SOFT_CAP_KNEE:
		_power_value.text = "~%.0f" % eff_power
		_power_value.tooltip_text = (
			"Near soft cap — raw %.1f, effective %.1f" % [raw_power, eff_power]
		)
	else:
		_power_value.text = "%.0f" % eff_power
		_power_value.tooltip_text = ""

	# Roster
	_refresh_roster_bar()

	# Niche selector
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
		var card: Control = refs["card"]
		var click_btn := refs["btn"] as Button
		var node_niche := String(node.get("niche", ""))
		card.visible = node_niche == _active_niche

		if not card.visible:
			continue

		var niche_locked := not Commands.meets_niche_keys(l, content, node_niche)
		click_btn.disabled = niche_locked
		if niche_locked:
			var niche_row := content.niche(node_niche)
			var keys: Array = niche_row.get("affix_keys", [])
			card.tooltip_text = (
				"Locked — equip a %s adaptation to enter this niche." % String(keys[0]).capitalize()
				if not keys.is_empty()
				else ""
			)
		else:
			card.tooltip_text = ""

		var active := l.assigned_node == node_id
		(refs["name_lbl"] as Label).text = (
			String(node.get("name", node_id)) + (" · working" if active else "")
		)
		card.modulate = (
			Color(1, 1, 1, 0.45)
			if niche_locked
			else (Color.WHITE if active else Color(1, 1, 1, 0.72))
		)

		var danger := float(node.get("danger", 0.0))
		var danger_lbl := refs["danger_lbl"] as Label
		if danger > 0:
			danger_lbl.text = "  DANGER %d" % int(danger)
			danger_lbl.visible = true
		else:
			danger_lbl.visible = false

		var margin := Resolve.effective_power(l, content) - float(node.get("defense", 0.0))
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
		matchup_lbl.text = (
			"%s · yield ×%.1f" % [verdict, Resolve.yield_efficiency(l, node, content)]
		)
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
			var graft_parts: Array[String] = []
			for graft: Dictionary in inst.affixes:
				var ar := content.affix(String(graft.get("id", "")))
				var roman := _roman(int(graft.get("tier", 1)))
				graft_parts.append("%s %s" % [String(ar.get("name", "")), roman])
			graft_lbl.text = "  ".join(graft_parts)

	# Class panel
	_refresh_class_panel()

	# Metabolize buttons
	for key: String in _doll_slot_labels:
		if not key.begins_with("_btn_"):
			continue
		var refs: Dictionary = _doll_slot_labels[key]
		_refresh_metabolize_button(refs["btn"] as Button, refs["def"] as Dictionary)

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


func _refresh_roster_bar() -> void:
	var lineages: Array = Store.state.lineages
	for i in range(_roster_chips.size()):
		var chip := _roster_chips[i]
		if i < lineages.size():
			var lin := lineages[i] as Lineage
			if lin.graduated:
				chip.text = "%s · graduated" % lin.display_name
				chip.disabled = true
				chip.modulate = Color(1, 1, 1, 0.35)
			else:
				var cls_row := Data.content.class_node(lin.class_node)
				var cls_name := String(cls_row.get("name", lin.class_node))
				chip.text = "%s · %s" % [lin.display_name, cls_name]
				chip.disabled = false
				chip.modulate = Color.WHITE if i == _active_lineage_idx else Color(1, 1, 1, 0.65)
		else:
			chip.text = "— empty slot —"
			chip.disabled = true
			chip.modulate = Color(1, 1, 1, 0.3)

	var active_count := 0
	for lin: Lineage in Store.state.lineages:
		if not lin.graduated:
			active_count += 1
	var can_branch := active_count < Store.state.slots_active
	_branch_btn.disabled = not can_branch
	if can_branch:
		_branch_btn.tooltip_text = ""
		_branch_btn.modulate = Color.WHITE
	else:
		_branch_btn.tooltip_text = "Roster full."
		_branch_btn.modulate = Color(1, 1, 1, 0.45)


func _refresh_class_panel() -> void:
	for child in _class_panel_list.get_children():
		child.queue_free()

	var l := _lineage()
	var content := Data.content
	var cls_row := content.class_node(l.class_node)
	var cls_name := String(cls_row.get("name", l.class_node))

	# Current class summary line
	var stat_mods: Dictionary = cls_row.get("stat_mods", {})
	var mods_parts: Array[String] = []
	for stat: Variant in stat_mods:
		mods_parts.append("%s ×%.2f" % [String(stat).capitalize(), float(stat_mods[stat])])
	var home_niches: Array = cls_row.get("home_niches", [])
	var home_str := ""
	if not home_niches.is_empty():
		var niche_row := content.niche(String(home_niches[0]))
		var nm: Dictionary = cls_row.get("niche_mult", {})
		var mat_buff := float(nm.get("material", 1.0))
		home_str = (
			"  ·  Home: %s +%.0f%%"
			% [
				String(niche_row.get("name", home_niches[0])),
				(mat_buff - 1.0) * 100.0,
			]
		)
	var cur_lbl := Label.new()
	var mods_str := ("  ·  " + "  ".join(mods_parts)) if not mods_parts.is_empty() else ""
	cur_lbl.text = "Current: %s%s%s" % [cls_name, mods_str, home_str]
	cur_lbl.add_theme_color_override("font_color", GOOD)
	_class_panel_list.add_child(cur_lbl)

	var unlocks: Array = cls_row.get("unlocks_categories", [])
	if not unlocks.is_empty():
		var cat_lbl := Label.new()
		cat_lbl.text = "Unlocks: %s gear" % String(unlocks[0]).replace("_", " ").capitalize()
		cat_lbl.add_theme_color_override("font_color", DIM)
		cat_lbl.add_theme_font_size_override("font_size", 15)
		_class_panel_list.add_child(cat_lbl)

	# Find pickable children
	var children: Array = []
	for row: Dictionary in content.tables.get("class_tree", []):
		if String(row.get("parent", "")) == l.class_node:
			children.append(row)

	if children.is_empty():
		var leaf_lbl := Label.new()
		leaf_lbl.text = "Leaf class — branch a new lineage to try a different path."
		leaf_lbl.add_theme_color_override("font_color", DIM)
		leaf_lbl.add_theme_font_size_override("font_size", 15)
		leaf_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		leaf_lbl.custom_minimum_size = Vector2(1, 0)
		_class_panel_list.add_child(leaf_lbl)
		return

	for child_row: Dictionary in children:
		var child_id := String(child_row.get("id", ""))
		var child_name := String(child_row.get("name", child_id))

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_class_panel_list.add_child(card)

		var pad := MarginContainer.new()
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			pad.add_theme_constant_override(side, 10)
		card.add_child(pad)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		pad.add_child(vbox)

		# Class name + stat mods
		var name_row := HBoxContainer.new()
		vbox.add_child(name_row)
		var child_name_lbl := Label.new()
		child_name_lbl.text = child_name
		child_name_lbl.add_theme_font_size_override("font_size", 20)
		child_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(child_name_lbl)

		var child_mods: Dictionary = child_row.get("stat_mods", {})
		var cm_parts: Array[String] = []
		for stat: Variant in child_mods:
			cm_parts.append("%s ×%.2f" % [String(stat).capitalize(), float(child_mods[stat])])
		if not cm_parts.is_empty():
			var mods_lbl := Label.new()
			mods_lbl.text = "  ".join(cm_parts)
			mods_lbl.add_theme_color_override("font_color", DIM)
			mods_lbl.add_theme_font_size_override("font_size", 14)
			name_row.add_child(mods_lbl)

		# Home niche + category unlocked
		var child_home: Array = child_row.get("home_niches", [])
		var child_unlocks: Array = child_row.get("unlocks_categories", [])
		if not child_home.is_empty() or not child_unlocks.is_empty():
			var detail_parts: Array[String] = []
			if not child_home.is_empty():
				var niche_row := content.niche(String(child_home[0]))
				detail_parts.append("Home: %s" % String(niche_row.get("name", child_home[0])))
			if not child_unlocks.is_empty():
				detail_parts.append(
					"Unlocks: %s" % String(child_unlocks[0]).replace("_", " ").capitalize()
				)
			var detail_lbl := Label.new()
			detail_lbl.text = "  ·  ".join(detail_parts)
			detail_lbl.add_theme_color_override("font_color", DIM)
			detail_lbl.add_theme_font_size_override("font_size", 14)
			vbox.add_child(detail_lbl)

		# Requirements
		var reqs: Dictionary = child_row.get("requires", {})
		var reqs_met := true
		var req_parts: Array[String] = []
		for key: Variant in reqs.get("affix_keys", []):
			var role := String(key)
			var has_role := false
			for slot: String in l.doll:
				var inst: AdaptationInstance = l.doll[slot]
				for gd: Dictionary in inst.affixes:
					var ar := content.affix(String(gd.get("id", "")))
					if String(ar.get("orthogonal_role", "")) == role:
						has_role = true
						break
				if has_role:
					break
			if has_role:
				req_parts.append("✓ %s" % role.capitalize())
			else:
				req_parts.append("✗ %s (missing)" % role.capitalize())
				reqs_met = false
		for gid: Variant in reqs.get("genes", []):
			var gname := String(content.gene(String(gid)).get("name", String(gid)))
			if int(Store.state.genes_known.get(String(gid), 0)) > 0:
				req_parts.append("✓ %s" % gname)
			else:
				req_parts.append("✗ %s (missing)" % gname)
				reqs_met = false
		if not req_parts.is_empty():
			var req_lbl := Label.new()
			req_lbl.text = "Requires: " + "  ".join(req_parts)
			req_lbl.add_theme_font_size_override("font_size", 14)
			req_lbl.add_theme_color_override("font_color", GOOD if reqs_met else BAD)
			vbox.add_child(req_lbl)

		# Commit or confirm buttons
		if _pending_class_id == child_id:
			var warn_lbl := Label.new()
			warn_lbl.text = "⚠ Classes are sticky — cannot be undone for this lineage."
			warn_lbl.add_theme_color_override("font_color", BAD)
			warn_lbl.add_theme_font_size_override("font_size", 14)
			warn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			warn_lbl.custom_minimum_size = Vector2(1, 0)
			vbox.add_child(warn_lbl)
			var confirm_row := HBoxContainer.new()
			confirm_row.add_theme_constant_override("separation", 8)
			vbox.add_child(confirm_row)
			var confirm_btn := Button.new()
			confirm_btn.text = "Commit to %s" % child_name
			confirm_btn.disabled = not reqs_met
			confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cid := child_id
			confirm_btn.pressed.connect(func() -> void: _on_class_confirm_pressed(cid))
			confirm_row.add_child(confirm_btn)
			var cancel_btn := Button.new()
			cancel_btn.text = "Cancel"
			cancel_btn.pressed.connect(
				func() -> void:
					_pending_class_id = ""
					_refresh()
			)
			confirm_row.add_child(cancel_btn)
		else:
			var commit_btn := Button.new()
			commit_btn.text = "Commit to %s…" % child_name
			commit_btn.disabled = not reqs_met
			commit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cid := child_id
			commit_btn.pressed.connect(func() -> void: _on_class_commit_pressed(cid))
			vbox.add_child(commit_btn)


func _refresh_metabolize_button(btn: Button, def: Dictionary) -> void:
	var adaptation_id := String(def.get("id", ""))
	var def_name := String(def.get("name", adaptation_id))
	var l := _lineage()
	var content := Data.content

	# Category gate: grey out locked-category gear with class hint
	var cat := String(def.get("category", "generalist"))
	if not content.allowed_categories(l).has(cat):
		btn.text = "%s — requires %s" % [def_name, _class_for_category(cat, content)]
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.4)
		return
	btn.modulate = Color.WHITE

	var tier := Commands.next_tier(l, def)
	if tier == 0:
		btn.text = "%s — maxed" % def_name
		btn.disabled = true
		return
	var cost := Commands.metabolize_cost(def, tier)
	var mat_id := String(cost.keys()[0])
	var qty := int(cost[mat_id])
	var mat_name := String(content.material(mat_id).get("name", mat_id))
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
		row.size_flags_horizontal = Control.SIZE_FILL
		row.add_theme_constant_override("separation", 10)
		_splice_list.add_child(row)

		var current_copies := int(Store.state.genes_known.get(gene_id, 0))
		var lbl := Label.new()
		lbl.text = "%s  ·  from %s  (have ×%d)" % [gene_name, node_name, current_copies]
		lbl.add_theme_color_override("font_color", RarityColors.of(rarity))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(1, 0)
		row.add_child(lbl)

		var idx := i
		var claim_btn := Button.new()
		claim_btn.text = "Claim (+1 copy)"
		claim_btn.tooltip_text = (
			"Adds 1 copy of this gene to your codex.\n"
			+ "Gene copies unlock affixes — tap a doll slot to graft them."
		)
		claim_btn.pressed.connect(func() -> void: _on_claim_splice(idx))
		row.add_child(claim_btn)


# -- graft sheet --------------------------------------------------------------


func _open_graft_sheet(slot: String) -> void:
	_graft_slot = slot
	var sheet := _graft_sheet
	var sheet_h := 400.0
	sheet.size = Vector2(size.x, sheet_h)
	sheet.position = Vector2(0.0, size.y - sheet_h)
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

	var allowed_cats := content.allowed_categories(l)
	var any_shown := false
	for affix: Dictionary in content.tables.get("affixes", []):
		var affix_id := String(affix.get("id", ""))
		var gene_row := content.gene_for_affix(affix_id)
		if gene_row.is_empty():
			continue
		var gene_id := String(gene_row.get("id", ""))
		var copies := int(Store.state.genes_known.get(gene_id, 0))
		if copies == 0:
			continue

		any_shown = true
		var cat := String(affix.get("category", "generalist"))
		var cat_locked := not allowed_cats.has(cat)

		var current_tier := inst.graft_tier(affix_id)
		var target_tier := current_tier + 1

		var gc: Dictionary = affix.get("graft_cost", {})
		var mat := String(gc.get("material", ""))
		var cost_qty := int(
			roundf(float(gc.get("base", 0.0)) * pow(float(gc.get("growth", 1.0)), target_tier - 1))
		)
		var have_mat := int(Store.state.inventory_materials.get(mat, 0.0))
		var mat_name := String(content.material(mat).get("name", mat))

		var can_afford := have_mat >= cost_qty
		var has_copies := copies >= target_tier

		var row := HBoxContainer.new()
		list.add_child(row)
		var info_lbl := Label.new()
		var tier_str := "T%d→T%d" % [current_tier, target_tier] if current_tier > 0 else "→T1"
		if cat_locked:
			info_lbl.text = (
				"%s  %s  (requires %s)"
				% [String(affix.get("name", affix_id)), tier_str, _class_for_category(cat, content)]
			)
			info_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		else:
			info_lbl.text = (
				"%s  %s  (%d/%d copies · %d %s)"
				% [
					String(affix.get("name", affix_id)),
					tier_str,
					copies,
					target_tier,
					cost_qty,
					mat_name
				]
			)
			info_lbl.add_theme_color_override("font_color", DIM if not can_afford else Color.WHITE)
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_lbl)

		var aid := affix_id
		var graft_btn := Button.new()
		graft_btn.text = "Graft"
		graft_btn.disabled = cat_locked or not (can_afford and has_copies)
		graft_btn.modulate = Color(1, 1, 1, 0.4) if cat_locked else Color.WHITE
		graft_btn.pressed.connect(func() -> void: _on_graft_pressed(_graft_slot, aid))
		row.add_child(graft_btn)

	if not any_shown:
		var note := Label.new()
		note.text = "No genes in codex. Work the fight nodes."
		note.add_theme_color_override("font_color", DIM)
		list.add_child(note)

	sheet.visible = true


# -- helpers ------------------------------------------------------------------


func _class_for_category(category: String, content: Content) -> String:
	for row: Dictionary in content.tables.get("class_tree", []):
		if (row.get("unlocks_categories", []) as Array).has(category):
			return String(row.get("name", category))
	return category.replace("_", " ").capitalize()


# -- event handlers -----------------------------------------------------------


func _on_metabolize_pressed(adaptation_id: String) -> void:
	var result := Store.metabolize(_lineage().id, adaptation_id)
	if not result["ok"]:
		return
	var inst: AdaptationInstance = result["instance"]
	var def := Data.content.adaptation(inst.def_id)
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


func _on_loot(lineage_id: String, loot: Dictionary) -> void:
	if lineage_id != _lineage().id:
		return
	var refs: Dictionary = _cards.get(_lineage().assigned_node, {})
	if refs.is_empty():
		return
	var card: Control = refs["card"]
	if not card.visible:
		return
	var at := Vector2(48.0, card.global_position.y + 16.0)

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


func _on_branch_pressed() -> void:
	_active_lineage_idx = Store.state.lineages.size()
	_pending_class_id = ""
	var display_name := "Branch %d" % (_active_lineage_idx + 1)
	var result := Store.branch_lineage(display_name)
	if not result["ok"]:
		_active_lineage_idx = clampi(_active_lineage_idx - 1, 0, Store.state.lineages.size() - 1)


func _on_class_commit_pressed(class_id: String) -> void:
	_pending_class_id = class_id
	_refresh()


func _on_class_confirm_pressed(class_id: String) -> void:
	_pending_class_id = ""
	var result := Store.pick_class(_lineage().id, class_id)
	if not result["ok"]:
		push_warning("pick_class rejected: " + String(result.get("reason", "")))


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
