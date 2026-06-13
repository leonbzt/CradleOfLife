class_name ExpressSheet
extends PanelContainer

## The bottom-sheet overlay for expressing banked genes onto an organ. Opened from
## the Body slot cards and from the World niche-key panel; owns its own content and
## the Express command + feedback, so neither tab has to. A leaf class — depends on
## UiState/Store/content, not on the tabs or the shell.

var _ui: UiState
var _pop_layer: Control
var _slot: String = ""
var _title_lbl: Label
var _list: VBoxContainer


func setup(ui: UiState, pop_layer: Control) -> void:
	_ui = ui
	_pop_layer = pop_layer
	visible = false
	z_index = 10

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 16)
	add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	_title_lbl = Label.new()
	_title_lbl.text = "EXPRESS"
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_lbl)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(func() -> void: visible = false)
	header.add_child(close_btn)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(list_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_list)


## Open (or refresh) the sheet for `slot`, listing every codex gene that fits this
## organ with its tier-up cost / cap / category status.
func open(slot: String) -> void:
	_slot = slot
	var screen := get_viewport().get_visible_rect().size
	var sheet_h := 400.0
	size = Vector2(screen.x, sheet_h)
	position = Vector2(0.0, screen.y - sheet_h)

	for child in _list.get_children():
		child.queue_free()

	var l := _ui.active_lineage()
	var content := Data.content
	var inst: AdaptationInstance = l.doll.get(slot)
	var cap := Commands.slot_express_cap(slot)
	var used := inst.affixes.size() if inst != null else 0
	_title_lbl.text = "EXPRESS — %s  (%d/%d)" % [UiUtil.slot_label(slot), used, cap]

	if inst == null:
		var note := Label.new()
		note.text = "No organ here yet — metabolize one into this slot first."
		note.add_theme_color_override("font_color", UiUtil.DIM)
		_list.add_child(note)
		visible = true
		return

	var organ_full := used >= cap
	var allowed_cats := content.allowed_categories(l)
	var any_shown := false
	for affix: Dictionary in content.tables.get("affixes", []):
		var affix_id := String(affix.get("id", ""))
		# Slot affinity: only genes that express on THIS organ appear here.
		if not Commands.affix_allows_slot(affix, slot):
			continue
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

		var current_tier := inst.express_tier(affix_id)
		var target_tier := current_tier + 1
		# A new affix needs a free expression slot; a tier-up never does.
		var cap_blocked := current_tier == 0 and organ_full

		var gc: Dictionary = affix.get("express_cost", {})
		var mat := String(gc.get("material", ""))
		var cost_qty := int(
			roundf(float(gc.get("base", 0.0)) * pow(float(gc.get("growth", 1.0)), target_tier - 1))
		)
		var have_mat := int(Store.state.inventory_materials.get(mat, 0.0))
		var mat_name := String(content.material(mat).get("name", mat))

		var can_afford := have_mat >= cost_qty
		var has_copies := copies >= target_tier

		var row := HBoxContainer.new()
		_list.add_child(row)
		var info_lbl := Label.new()
		var tier_str := "T%d→T%d" % [current_tier, target_tier] if current_tier > 0 else "→T1"
		if cat_locked:
			info_lbl.text = (
				"%s  %s  (requires %s)"
				% [
					String(affix.get("name", affix_id)),
					tier_str,
					UiUtil.class_for_category(cat, content)
				]
			)
			info_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		elif cap_blocked:
			info_lbl.text = (
				"%s  %s  (organ full — %d/%d)"
				% [String(affix.get("name", affix_id)), tier_str, used, cap]
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
			info_lbl.add_theme_color_override(
				"font_color", UiUtil.DIM if not can_afford else Color.WHITE
			)
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_lbl)

		var aid := affix_id
		var express_btn := Button.new()
		express_btn.text = "Express"
		express_btn.disabled = cat_locked or cap_blocked or not (can_afford and has_copies)
		express_btn.modulate = Color(1, 1, 1, 0.4) if (cat_locked or cap_blocked) else Color.WHITE
		express_btn.pressed.connect(func() -> void: _on_express_pressed(aid))
		row.add_child(express_btn)

	if not any_shown:
		var note := Label.new()
		note.text = "No genes in your codex fit this organ yet."
		note.add_theme_color_override("font_color", UiUtil.DIM)
		_list.add_child(note)

	visible = true


func _on_express_pressed(affix_id: String) -> void:
	var result := Store.express(_ui.active_lineage().id, _slot, affix_id)
	if not result["ok"]:
		return
	var inst: AdaptationInstance = result["instance"]
	var affix_row := Data.content.affix(affix_id)
	var at := get_viewport().get_visible_rect().size * Vector2(0.5, 0.75)
	LootPop.spawn(
		_pop_layer,
		at,
		"Expressed: %s" % String(affix_row.get("name", affix_id)),
		RarityColors.of(inst.rarity)
	)
	open(_slot)
