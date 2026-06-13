class_name HomeTab
extends VBoxContainer

## The landing tab: the derived do-now agenda (PHASE3_5 WP2), the stash glance, and
## the DEV bar. Self-building, self-refreshing; reads UiState + Store, acts via
## Store / UiState navigation. No reference to the shell or other tabs.

var _ui: UiState
var _pop_layer: Control
var _agenda_list: VBoxContainer
var _mat_labels: Dictionary = {}  # material_id -> Label


func setup(ui: UiState, pop_layer: Control) -> void:
	_ui = ui
	_pop_layer = pop_layer
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)

	add_child(UiUtil.section_label("DO NOW  ·  what's worth a tap this check-in"))
	_agenda_list = VBoxContainer.new()
	_agenda_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agenda_list.add_theme_constant_override("separation", 6)
	add_child(_agenda_list)

	add_child(UiUtil.section_label("STASH"))
	add_child(_build_stash_row())

	_build_debug_bar()


func refresh() -> void:
	_refresh_agenda()
	_refresh_stash()


# -- agenda -------------------------------------------------------------------


func _refresh_agenda() -> void:
	for c in _agenda_list.get_children():
		c.queue_free()
	var l := _ui.active_lineage()
	var items := Agenda.for_lineage(Store.state, Data.content, l.id)
	if items.is_empty():
		var none := Label.new()
		none.text = "All caught up. Let it ride — or branch a new lineage."
		none.add_theme_color_override("font_color", UiUtil.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_agenda_list.add_child(none)
		return
	for item: Dictionary in items:
		var action: Dictionary = item.get("action", {})
		if action.is_empty():
			var lbl := Label.new()
			lbl.text = "·  " + String(item.get("text", ""))
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_color_override("font_color", UiUtil.DIM)
			_agenda_list.add_child(lbl)
		else:
			var btn := Button.new()
			btn.text = "▶  " + String(item.get("text", ""))
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(_on_agenda_action.bind(action))
			_agenda_list.add_child(btn)


## Claims act in place (a one-tap win); equipment tier-ups jump to the Body tab so
## the player chooses what the organ becomes there, rather than building blind.
func _on_agenda_action(action: Dictionary) -> void:
	match String(action.get("cmd", "")):
		"claim_splice":
			var result := Store.claim_splice(int(action.get("index", 0)))
			if not result["ok"]:
				return
			var gene_row := Data.content.gene(String(result.get("gene", "")))
			var rarity := String(gene_row.get("rarity", "common"))
			LootPop.spawn(
				_pop_layer,
				get_viewport().get_visible_rect().size * 0.5,
				"Spliced: %s" % String(gene_row.get("name", "")),
				RarityColors.of(rarity),
				UiUtil.rarity_rank(rarity) >= UiUtil.rarity_rank("rare")
			)
		"metabolize":
			var slot := String(
				Data.content.adaptation(String(action.get("adaptation_id", ""))).get("slot", "")
			)
			_ui.request_navigate("body", slot)


# -- stash --------------------------------------------------------------------


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


func _refresh_stash() -> void:
	for mat_id: String in _mat_labels:
		var mat := Data.content.material(mat_id)
		var qty := floori(float(Store.state.inventory_materials.get(mat_id, 0.0)))
		(_mat_labels[mat_id] as Label).text = "%s %d" % [String(mat.get("name", mat_id)), qty]


# -- DEV bar (testing only; remove before release) ----------------------------


func _build_debug_bar() -> void:
	add_child(UiUtil.section_label("DEV  ·  testing only"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var reset_btn := Button.new()
	reset_btn.text = "↺ Reset"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(
		func() -> void:
			_ui.reset()
			Store.reset_save()
	)
	row.add_child(reset_btn)

	var ff1_btn := Button.new()
	ff1_btn.text = "⏩ +1h"
	ff1_btn.tooltip_text = "Jump 1 hour of offline accrual forward."
	ff1_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ff1_btn.pressed.connect(func() -> void: Store.dev_fast_forward(3600.0))
	row.add_child(ff1_btn)

	var ff8_btn := Button.new()
	ff8_btn.text = "⏩ +8h"
	ff8_btn.tooltip_text = "Jump 8 hours of offline accrual forward."
	ff8_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ff8_btn.pressed.connect(func() -> void: Store.dev_fast_forward(8.0 * 3600.0))
	row.add_child(ff8_btn)
