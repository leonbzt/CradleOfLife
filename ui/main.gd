extends Control

## The Phase 1 vertical slice, one portrait screen (IMPLEMENTATION.md §4):
## the wild (nodes with visible DEF vs your PWR), the equipment doll (three
## slots), Metabolize, and the stash. Pure observer of Store — every label is
## re-read from GameState on state_changed; nothing here mutates state except
## through Store's named commands.
##
## All layout is built in code from content data: no hand-authored widgets to
## drift when data rows change. Placeholder look — the retro-pixel theme is an
## art pass, not a structure change.

## Seconds between foraging actions while the app is open. Live play earns at
## the same per-second rate accrual will use — idle earns, attention spends
## (VISION.md §12); being present is never a multiplier.
const ACTION_PERIOD: float = 2.5

## The Phase 1 doll subset (the slice ships three of the six slots).
const PHASE1_SLOTS: Array[String] = ["mouthparts", "integument", "locomotion"]

const BG_COLOR := Color("0b1d2a")
const DIM := Color("8b9aa7")
const GOOD := Color("5fd97a")
const BAD := Color("ff7b72")

var _power_value: Label
var _cards: Dictionary = {}  # node_id -> {card, name, def, matchup}
var _doll_values: Dictionary = {}  # slot -> Label
var _build_buttons: Dictionary = {}  # adaptation_id -> Button
var _mat_labels: Dictionary = {}  # material_id -> Label
var _pop_layer: Control


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
	col.add_child(_section_label("THE WILD"))
	for node: Dictionary in Data.content.tables.get("nodes", []):
		var card := _node_card(node)
		col.add_child(card)
	col.add_child(_section_label("THE BUILD"))
	for slot in PHASE1_SLOTS:
		col.add_child(_doll_row(slot))
	col.add_child(_section_label("METABOLIZE"))
	for def: Dictionary in Data.content.tables.get("adaptations", []):
		if PHASE1_SLOTS.has(String(def.get("slot", ""))):
			col.add_child(_build_button(def))
	col.add_child(_section_label("STASH"))
	col.add_child(_stash_row())

	_pop_layer = Control.new()
	_pop_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pop_layer)


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
	var niche := Label.new()
	niche.text = "The Shallow Benthos — Sea Age"
	var niches: Array = Data.content.tables.get("niches", [])
	if not niches.is_empty():
		niche.text = String((niches[0] as Dictionary).get("name", niche.text))
	niche.add_theme_color_override("font_color", DIM)
	niche.add_theme_font_size_override("font_size", 15)
	who.add_child(niche)

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


func _section_label(caption: String) -> Label:
	var l := Label.new()
	l.text = caption
	l.add_theme_color_override("font_color", DIM)
	l.add_theme_font_size_override("font_size", 16)
	return l


func _node_card(node: Dictionary) -> Button:
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
	var name_label := Label.new()
	name_label.text = String(node.get("name", node_id))
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var def_label := Label.new()
	def_label.text = "DEF %d" % int(node.get("defense", 0))
	def_label.add_theme_color_override("font_color", DIM)
	top.add_child(def_label)

	var matchup := Label.new()
	box.add_child(matchup)

	var flavor := Label.new()
	flavor.text = String(node.get("flavor", ""))
	flavor.add_theme_color_override("font_color", DIM)
	flavor.add_theme_font_size_override("font_size", 14)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(flavor)

	_cards[node_id] = {"card": card, "name": name_label, "matchup": matchup}
	return card


func _doll_row(slot: String) -> Control:
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = slot.capitalize()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	_doll_values[slot] = value
	return row


func _build_button(def: Dictionary) -> Button:
	var adaptation_id := String(def.get("id", ""))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 56)
	btn.pressed.connect(func() -> void: _on_metabolize_pressed(adaptation_id))
	_build_buttons[adaptation_id] = btn
	return btn


func _stash_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	for mat: Dictionary in Data.content.tables.get("materials", []):
		var mat_id := String(mat.get("id", ""))
		var l := Label.new()
		l.add_theme_color_override("font_color", RarityColors.of(String(mat.get("rarity", ""))))
		row.add_child(l)
		_mat_labels[mat_id] = l
	return row


# -- refresh (every state change) ---------------------------------------------


func _refresh() -> void:
	var l := _lineage()
	_power_value.text = "%.0f" % Resolve.effective_power(l)

	for node_id: String in _cards:
		var node := Data.content.node(node_id)
		var refs: Dictionary = _cards[node_id]
		var active := l.assigned_node == node_id
		(refs["name"] as Label).text = (
			String(node.get("name", node_id)) + (" · working" if active else "")
		)
		(refs["card"] as Button).modulate = Color.WHITE if active else Color(1, 1, 1, 0.72)
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
		var matchup := refs["matchup"] as Label
		matchup.text = "%s · yield ×%.1f" % [verdict, Resolve.yield_efficiency(l, node)]
		matchup.add_theme_color_override("font_color", color)

	for slot: String in _doll_values:
		var value := _doll_values[slot] as Label
		var inst: AdaptationInstance = l.doll.get(slot)
		if inst == null:
			value.text = "empty"
			value.add_theme_color_override("font_color", DIM)
		else:
			var def := Data.content.adaptation(inst.def_id)
			value.text = "%s · T%d" % [String(def.get("name", inst.def_id)), inst.tier]
			value.add_theme_color_override("font_color", RarityColors.of(inst.rarity))

	for adaptation_id: String in _build_buttons:
		_refresh_build_button(adaptation_id)

	for mat_id: String in _mat_labels:
		var mat := Data.content.material(mat_id)
		var qty := floori(float(Store.state.inventory_materials.get(mat_id, 0.0)))
		(_mat_labels[mat_id] as Label).text = "%s %d" % [String(mat.get("name", mat_id)), qty]


func _refresh_build_button(adaptation_id: String) -> void:
	var btn := _build_buttons[adaptation_id] as Button
	var def := Data.content.adaptation(adaptation_id)
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


# -- juice ---------------------------------------------------------------------


func _on_metabolize_pressed(adaptation_id: String) -> void:
	var result := Store.metabolize(_lineage().id, adaptation_id)
	if not result["ok"]:
		return
	var inst: AdaptationInstance = result["instance"]
	var def := Data.content.adaptation(inst.def_id)
	var btn := _build_buttons[adaptation_id] as Button
	var at := btn.global_position + Vector2(btn.size.x * 0.5, 0.0)
	LootPop.spawn(
		_pop_layer,
		at,
		"%s T%d" % [String(def.get("name", inst.def_id)), inst.tier],
		RarityColors.of(inst.rarity)
	)
	_pulse(_power_value)


func _on_loot(_lineage_id: String, loot: Dictionary) -> void:
	var refs: Dictionary = _cards.get(_lineage().assigned_node, {})
	if refs.is_empty():
		return
	var card := refs["card"] as Button
	var at := card.global_position + Vector2(card.size.x * 0.66, 16.0)
	var mats: Dictionary = loot["materials"]
	for mat_id: String in mats:
		var qty := float(mats[mat_id])
		var mat := Data.content.material(mat_id)
		var amount := "+%d" % roundi(qty) if qty >= 0.95 else "+%.1f" % qty
		LootPop.spawn(
			_pop_layer,
			at,
			"%s %s" % [amount, String(mat.get("name", mat_id))],
			RarityColors.of(String(mat.get("rarity", "common")))
		)


func _pulse(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(1.3, 1.3)
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
