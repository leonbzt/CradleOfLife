class_name ClassTab
extends VBoxContainer

## The specialization tab: the current class, what each child class costs/unlocks,
## live requirement checks, and the sticky two-step commit. Reads UiState/Store;
## the pending-commit choice lives in UiState so a refresh preserves it.

var _ui: UiState
var _class_panel_list: VBoxContainer


func setup(ui: UiState) -> void:
	_ui = ui
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	add_child(UiUtil.section_label("CLASS"))
	_class_panel_list = VBoxContainer.new()
	_class_panel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_panel_list.add_theme_constant_override("separation", 8)
	add_child(_class_panel_list)


func refresh() -> void:
	for child in _class_panel_list.get_children():
		child.queue_free()

	var l := _ui.active_lineage()
	var content := Data.content
	var cls_row := content.class_node(l.class_node)
	var cls_name := String(cls_row.get("name", l.class_node))

	# Current class summary line.
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
			% [String(niche_row.get("name", home_niches[0])), (mat_buff - 1.0) * 100.0]
		)
	var cur_lbl := Label.new()
	var mods_str := ("  ·  " + "  ".join(mods_parts)) if not mods_parts.is_empty() else ""
	cur_lbl.text = "Current: %s%s%s" % [cls_name, mods_str, home_str]
	cur_lbl.add_theme_color_override("font_color", UiUtil.GOOD)
	cur_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cur_lbl.custom_minimum_size = Vector2(1, 0)
	_class_panel_list.add_child(cur_lbl)

	var unlocks: Array = cls_row.get("unlocks_categories", [])
	if not unlocks.is_empty():
		var cat_lbl := Label.new()
		cat_lbl.text = "Unlocks: %s gear" % String(unlocks[0]).replace("_", " ").capitalize()
		cat_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		cat_lbl.add_theme_font_size_override("font_size", 16)
		_class_panel_list.add_child(cat_lbl)

	var children: Array = []
	for row: Dictionary in content.tables.get("class_tree", []):
		if String(row.get("parent", "")) == l.class_node:
			children.append(row)

	if children.is_empty():
		var leaf_lbl := Label.new()
		leaf_lbl.text = "Leaf class — branch a new lineage to try a different path."
		leaf_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		leaf_lbl.add_theme_font_size_override("font_size", 16)
		leaf_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		leaf_lbl.custom_minimum_size = Vector2(1, 0)
		_class_panel_list.add_child(leaf_lbl)
		return

	for child_row: Dictionary in children:
		_build_child_class_card(l, content, child_row)


func _build_child_class_card(l: Lineage, content: Content, child_row: Dictionary) -> void:
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
		mods_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		mods_lbl.add_theme_font_size_override("font_size", 16)
		name_row.add_child(mods_lbl)

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
		detail_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		detail_lbl.add_theme_font_size_override("font_size", 16)
		vbox.add_child(detail_lbl)

	# Requirements (affix-key roles + genes).
	var reqs: Dictionary = child_row.get("requires", {})
	var reqs_met := true
	var req_parts: Array[String] = []
	for key: Variant in reqs.get("affix_keys", []):
		var role := String(key)
		var has_role := false
		for slot: String in l.doll:
			var inst: AdaptationInstance = l.doll[slot]
			for gd: Dictionary in inst.affixes:
				if (
					String(content.affix(String(gd.get("id", ""))).get("orthogonal_role", ""))
					== role
				):
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
		req_lbl.add_theme_font_size_override("font_size", 16)
		req_lbl.add_theme_color_override("font_color", UiUtil.GOOD if reqs_met else UiUtil.BAD)
		req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		req_lbl.custom_minimum_size = Vector2(1, 0)
		vbox.add_child(req_lbl)

	# Sticky two-step commit (the choice is held in UiState across refreshes).
	if _ui.pending_class_id == child_id:
		var warn_lbl := Label.new()
		warn_lbl.text = "⚠ Classes are sticky — cannot be undone for this lineage."
		warn_lbl.add_theme_color_override("font_color", UiUtil.BAD)
		warn_lbl.add_theme_font_size_override("font_size", 16)
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
		confirm_btn.pressed.connect(func() -> void: _on_confirm(child_id))
		confirm_row.add_child(confirm_btn)
		var cancel_btn := Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.pressed.connect(func() -> void: _ui.set_pending_class_id(""))
		confirm_row.add_child(cancel_btn)
	else:
		var commit_btn := Button.new()
		commit_btn.text = "Commit to %s…" % child_name
		commit_btn.disabled = not reqs_met
		commit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		commit_btn.pressed.connect(func() -> void: _ui.set_pending_class_id(child_id))
		vbox.add_child(commit_btn)


func _on_confirm(class_id: String) -> void:
	var result := Store.pick_class(_ui.active_lineage().id, class_id)
	_ui.set_pending_class_id("")
	if not result["ok"]:
		push_warning("pick_class rejected: " + String(result.get("reason", "")))
