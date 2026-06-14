extends Control

## Phase 3.5 UI shell. Portrait phone screen (720×1280, canvas_items stretch).
## Owns only the chrome: the persistent roster + header, the tab bar, the four tab
## scripts, and the cross-cutting overlays (loot pops, the express sheet, the Dev
## dispatch). Each tab (ui/tabs/*.gd) builds and refreshes itself from Store +
## UiState; the shell just fans state_changed out to them and routes navigation.
## A pure observer of Store — mutations only ever go through Store's named commands.

const ACTION_PERIOD: float = 2.5

# View state shared across tabs (which lineage/niche is shown, pending commit).
var _ui: UiState

# Persistent top widgets
var _roster_chips: Array[Button] = []
var _branch_btn: Button
var _header_name_label: Label
var _power_value: Label

# Tabs
var _tab_bar: HBoxContainer
var _tabs: Dictionary = {}  # name -> {scroll: ScrollContainer, btn: Button}
var _home_tab: HomeTab
var _body_tab: BodyTab
var _world_tab: WorldTab

# Overlays
var _pop_layer: Control
var _express_sheet: ExpressSheet
var _dispatch_sheet: Control


func _ready() -> void:
	if Store.state == null:
		Store.new_game(int(Time.get_unix_time_from_system()))
	_ui = UiState.new()
	_build_ui()

	Store.state_changed.connect(_refresh)
	Store.loot_dropped.connect(_on_loot)
	Store.dispatch_ready.connect(_show_dispatch)
	_ui.changed.connect(_refresh)
	_ui.navigate.connect(_select_tab)

	var timer := Timer.new()
	timer.wait_time = ACTION_PERIOD
	timer.autostart = true
	timer.timeout.connect(func() -> void: Store.forage_all(ACTION_PERIOD))
	add_child(timer)

	_refresh()

	# Offline catch-up dispatch on launch (Phase 3.5 WP1). A fresh game has no gap.
	var launch_batch := Store.apply_offline_accrual()
	if not launch_batch.is_empty():
		_show_dispatch(launch_batch)


# -- build (once) -------------------------------------------------------------


func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 18
	theme = ui_theme

	var bg := ColorRect.new()
	bg.color = UiUtil.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Persistent top: roster + header (visible on every tab).
	var top_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		top_margin.add_theme_constant_override(side, 20)
	top_margin.add_theme_constant_override("margin_top", 16)
	root.add_child(top_margin)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top_margin.add_child(top)
	_build_roster_bar(top)
	_build_header(top)

	_build_tab_bar(root)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	# Overlays first so the tabs can reference the pop layer + express sheet.
	_pop_layer = Control.new()
	_pop_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_express_sheet = ExpressSheet.new()
	_express_sheet.setup(_ui, _pop_layer)

	_home_tab = HomeTab.new()
	_home_tab.setup(_ui, _pop_layer)
	_body_tab = BodyTab.new()
	_body_tab.setup(_ui, _pop_layer, _express_sheet)
	_world_tab = WorldTab.new()
	_world_tab.setup(_ui, _pop_layer, _express_sheet)

	_add_tab(content, "home", "Home", _home_tab)
	_add_tab(content, "body", "Body", _body_tab)
	_add_tab(content, "world", "World", _world_tab)

	add_child(_pop_layer)
	add_child(_express_sheet)
	_dispatch_sheet = _build_dispatch_sheet()
	add_child(_dispatch_sheet)

	_select_tab("home")


func _build_tab_bar(root: VBoxContainer) -> void:
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 20)
	root.add_child(margin)
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)
	margin.add_child(_tab_bar)


## Wire a tab: a bar button + a scrollable wrapper holding the (already-built) tab
## node. Only one wrapper is visible at a time.
func _add_tab(
	parent: VBoxContainer, tab_name: String, label: String, tab_node: VBoxContainer
) -> void:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(func() -> void: _select_tab(tab_name))
	_tab_bar.add_child(btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 20)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	margin.add_child(tab_node)

	_tabs[tab_name] = {"scroll": scroll, "btn": btn}


func _select_tab(tab_name: String) -> void:
	for k: String in _tabs:
		var refs: Dictionary = _tabs[k]
		(refs["scroll"] as Control).visible = k == tab_name
		(refs["btn"] as Button).modulate = Color.WHITE if k == tab_name else Color(1, 1, 1, 0.5)
	_refresh()


func _build_roster_bar(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	for i in range(2):
		var chip := Button.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		chip.pressed.connect(func() -> void: _ui.set_active_lineage_idx(idx))
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
	_header_name_label.add_theme_font_size_override("font_size", 28)
	who.add_child(_header_name_label)
	var age_label := Label.new()
	age_label.text = "Age I: The Sea  ·  Cambrian meta"
	age_label.add_theme_color_override("font_color", UiUtil.DIM)
	age_label.add_theme_font_size_override("font_size", 16)
	who.add_child(age_label)

	var power := VBoxContainer.new()
	row.add_child(power)
	var caption := Label.new()
	caption.text = "POWER"
	caption.add_theme_color_override("font_color", UiUtil.DIM)
	caption.add_theme_font_size_override("font_size", 16)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power.add_child(caption)
	_power_value = Label.new()
	_power_value.add_theme_font_size_override("font_size", 34)
	_power_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power.add_child(_power_value)


# -- refresh (every state / view change) --------------------------------------


func _refresh() -> void:
	var l := _ui.active_lineage()
	var content := Data.content
	_refresh_header(l, content)
	_refresh_roster_bar()
	_home_tab.refresh()
	_body_tab.refresh()
	_world_tab.refresh()


func _refresh_header(l: Lineage, content: Content) -> void:
	_header_name_label.text = l.display_name
	# Power readout — show soft-cap cue when raw power exceeds the knee.
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
				var role := Resolve.derived_role(lin, Data.content)
				chip.text = "%s · %s" % [lin.display_name, role]
				chip.disabled = false
				chip.modulate = (
					Color.WHITE if i == _ui.active_lineage_idx else Color(1, 1, 1, 0.65)
				)
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


# -- event handlers -----------------------------------------------------------


func _on_branch_pressed() -> void:
	_ui.active_lineage_idx = Store.state.lineages.size()
	var display_name := "Branch %d" % (_ui.active_lineage_idx + 1)
	var result := Store.branch_lineage(display_name)
	if not result["ok"]:
		_ui.active_lineage_idx = clampi(
			_ui.active_lineage_idx - 1, 0, Store.state.lineages.size() - 1
		)


## A forage tick: hand the loot to the World tab (the clash heartbeat + node pops),
## but only for the lineage currently shown.
func _on_loot(lineage_id: String, loot: Dictionary) -> void:
	if lineage_id != _ui.active_lineage().id:
		return
	_world_tab.on_loot(loot)


# -- the while-you-were-away dispatch (WP1) -----------------------------------


func _build_dispatch_sheet() -> Control:
	var root := Control.new()
	root.visible = false
	root.z_index = 20
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	center.add_child(panel)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 18)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pad.add_child(vbox)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	var headline := Label.new()
	headline.add_theme_font_size_override("font_size", 18)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(headline)

	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 4)
	vbox.add_child(summary)

	var cont := Button.new()
	cont.text = "Continue"
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.pressed.connect(func() -> void: root.visible = false)
	vbox.add_child(cont)

	root.set_meta("title", title)
	root.set_meta("headline", headline)
	root.set_meta("summary", summary)
	return root


## Present an applied Accrual batch as a Dev dispatch (VISION.md §16): good-news
## framing, the rare moment up top, the rest a tidy tally — never a scroll of every
## event, never a "you lost progress" line.
func _show_dispatch(batch: Dictionary) -> void:
	var content := Data.content
	var title := _dispatch_sheet.get_meta("title") as Label
	var headline := _dispatch_sheet.get_meta("headline") as Label
	var summary := _dispatch_sheet.get_meta("summary") as VBoxContainer
	for c in summary.get_children():
		c.queue_free()

	title.text = (
		"DISPATCH — %s offline.  The server kept running."
		% _format_elapsed(float(batch.get("dt", 0.0)))
	)

	var gene_by_rarity: Dictionary = {}
	var splice_count := 0
	var best_rarity := ""
	var best_gene := ""
	for ev: Dictionary in batch.get("events", []) as Array:
		match String(ev.get("kind", "")):
			"gene":
				var r := String(ev.get("rarity", "common"))
				gene_by_rarity[r] = int(gene_by_rarity.get(r, 0)) + 1
				if UiUtil.rarity_rank(r) > UiUtil.rarity_rank(best_rarity):
					best_rarity = r
					best_gene = String(ev.get("gene", ""))
			"splice":
				splice_count += 1

	if best_gene != "" and UiUtil.rarity_rank(best_rarity) >= UiUtil.rarity_rank("rare"):
		var gname := String(content.gene(best_gene).get("name", best_gene))
		headline.text = "The grind paid out: %s (%s)." % [gname, best_rarity]
		headline.add_theme_color_override("font_color", RarityColors.of(best_rarity))
	elif splice_count > 0:
		headline.text = "A splice is waiting to be claimed."
		headline.add_theme_color_override("font_color", RarityColors.of("epic"))
	else:
		headline.text = "Steady progress while you were away."
		headline.add_theme_color_override("font_color", UiUtil.GOOD)

	var mats: Dictionary = batch.get("materials", {})
	var mat_line := ""
	for mat_id: String in mats:
		var q := roundi(float(mats[mat_id]))
		if q <= 0:
			continue
		var mname := String(content.material(mat_id).get("name", mat_id))
		mat_line += ("" if mat_line == "" else "   ") + "+%d %s" % [q, mname]
	if mat_line != "":
		summary.add_child(_dispatch_line("Harvest:  " + mat_line, UiUtil.DIM))

	var parts: Array[String] = []
	for r: String in ["legendary", "epic", "rare", "uncommon", "common"]:
		if gene_by_rarity.has(r):
			parts.append("%d %s" % [int(gene_by_rarity[r]), r])
	if not parts.is_empty():
		summary.add_child(_dispatch_line("Genes:  " + " · ".join(parts), UiUtil.DIM))
	if splice_count > 0:
		summary.add_child(
			_dispatch_line("Splice offers waiting:  %d" % splice_count, RarityColors.of("epic"))
		)
	if mat_line == "" and parts.is_empty() and splice_count == 0:
		summary.add_child(_dispatch_line("Nothing notable — the server was quiet.", UiUtil.DIM))

	_dispatch_sheet.visible = true
	UiUtil.pulse(headline)


func _dispatch_line(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	return l


func _format_elapsed(seconds: float) -> String:
	var s := int(seconds)
	var d := s / 86400
	var h := (s % 86400) / 3600
	var m := (s % 3600) / 60
	if d > 0:
		return "%dd %dh" % [d, h]
	if h > 0:
		return "%dh %dm" % [h, m]
	return "%dm" % maxi(m, 1)
