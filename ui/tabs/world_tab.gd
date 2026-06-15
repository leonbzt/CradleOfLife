class_name WorldTab
extends VBoxContainer

## The world tab (PHASE3_5 WP4): niche selector + key-gate guidance, the visible
## combat CLASH panel for the assigned node, the node cards, the splice-offer queue,
## and the splice catalogue. Reads UiState/Store; acts via Store + the ExpressSheet.

## Show-next-few (VISION §11/§16): reveal every unlocked rung + only this many of the
## next locked ones, so the ladder always shows a next step and never an overwhelm.
const SHOW_LOCKED_RUNGS: int = 2

var _ui: UiState
var _pop_layer: Control
var _express: ExpressSheet

var _niche_buttons: Dictionary = {}  # niche_id -> Button
var _niche_gate_panel: VBoxContainer
var _clash_panel: PanelContainer
var _clash_lines: VBoxContainer
var _cards: Dictionary = {}  # node_id -> {card, btn, name_lbl, matchup_lbl, danger_lbl}
var _splice_list: VBoxContainer
var _splice_catalogue: VBoxContainer
var _skill_panel: VBoxContainer
var _skill_rows: Dictionary = {}  # skill_id -> {level: Label, bar: ProgressBar}


func setup(ui: UiState, pop_layer: Control, express: ExpressSheet) -> void:
	_ui = ui
	_pop_layer = pop_layer
	_express = express
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)

	_build_niche_selector()
	_niche_gate_panel = VBoxContainer.new()
	_niche_gate_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_niche_gate_panel.add_theme_constant_override("separation", 4)
	add_child(_niche_gate_panel)

	add_child(UiUtil.section_label("CURRENT CLASH"))
	_build_clash_panel()
	add_child(UiUtil.section_label("YOUR SKILLS  ·  level the skill, not the node"))
	_build_skill_panel()
	add_child(UiUtil.section_label("THE WILD  ·  work the ladder; the next rungs show their key"))
	_build_node_cards()
	add_child(UiUtil.section_label("SPLICE OFFERS  ·  claim a copied gene"))
	_splice_list = VBoxContainer.new()
	_splice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_splice_list.add_theme_constant_override("separation", 6)
	add_child(_splice_list)
	add_child(UiUtil.section_label("SPLICE CATALOGUE  ·  signature genes — what to hunt"))
	_splice_catalogue = VBoxContainer.new()
	_splice_catalogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_splice_catalogue.add_theme_constant_override("separation", 6)
	add_child(_splice_catalogue)


func refresh() -> void:
	var l := _ui.active_lineage()
	var content := Data.content
	_refresh_niche_selector(l, content)
	_refresh_niche_gate(l, content)
	_refresh_clash(l, content)
	_refresh_skills(l)
	_refresh_node_cards(l, content)
	_refresh_splice_offers()
	_refresh_splice_catalogue(l, content)


## A forage tick on the shown lineage: pulse the clash panel (the fight heartbeat),
## and — if the worked node's card is on screen — float its loot.
func on_loot(loot: Dictionary) -> void:
	UiUtil.pulse(_clash_panel)
	var refs: Dictionary = _cards.get(_ui.active_lineage().assigned_node, {})
	if refs.is_empty():
		return
	var card: Control = refs["card"]
	if not card.is_visible_in_tree():
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
		var gene_row := Data.content.gene(String(gene.get("id", "")))
		var rarity := String(gene.get("rarity", "common"))
		LootPop.spawn(
			_pop_layer,
			at + Vector2(0.0, 30.0),
			"Gene: %s" % String(gene_row.get("name", "")),
			RarityColors.of(rarity),
			UiUtil.rarity_rank(rarity) >= UiUtil.rarity_rank("rare")
		)

	var offer := String(loot["splice_offer"])
	if offer != "":
		var gene_row := Data.content.gene(offer)
		var rarity := String(gene_row.get("rarity", "common"))
		LootPop.spawn(
			_pop_layer,
			at + Vector2(0.0, 60.0),
			"Splice offer: %s" % String(gene_row.get("name", offer)),
			RarityColors.of(rarity),
			UiUtil.rarity_rank(rarity) >= UiUtil.rarity_rank("rare")
		)


# -- niche selector + key gate ------------------------------------------------


func _build_niche_selector() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	for niche: Dictionary in Data.content.tables.get("niches", []):
		var niche_id := String(niche.get("id", ""))
		var btn := Button.new()
		btn.text = String(niche.get("name", niche_id))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: _ui.set_active_niche(niche_id))
		row.add_child(btn)
		_niche_buttons[niche_id] = btn


func _refresh_niche_selector(l: Lineage, content: Content) -> void:
	for niche_id: String in _niche_buttons:
		var btn := _niche_buttons[niche_id] as Button
		var is_active := niche_id == _ui.active_niche
		var is_locked := not Commands.meets_niche_keys(l, content, niche_id)
		var niche := content.niche(niche_id)
		btn.text = String(niche.get("name", niche_id)) + ("  🔒" if is_locked else "")
		if is_active:
			btn.modulate = Color.WHITE
		elif is_locked:
			btn.modulate = Color(1, 1, 1, 0.55)
		else:
			btn.modulate = Color(1, 1, 1, 0.75)
		var keys: Array = niche.get("affix_keys", [])
		if is_locked and not keys.is_empty():
			btn.tooltip_text = "Requires: an expressed %s gene." % String(keys[0]).capitalize()
		else:
			btn.tooltip_text = ""


## Key guidance for the active niche when locked: the role, the generalist genes
## that satisfy it (easiest first), where each drops, and live status — own-but-
## unexpressed gets an Express shortcut (VISION §11: see the wall AND the key).
func _refresh_niche_gate(l: Lineage, content: Content) -> void:
	for child in _niche_gate_panel.get_children():
		child.queue_free()

	var niche := content.niche(_ui.active_niche)
	var keys: Array = niche.get("affix_keys", [])
	if keys.is_empty() or Commands.meets_niche_keys(l, content, _ui.active_niche):
		_niche_gate_panel.visible = false
		return
	_niche_gate_panel.visible = true

	var head := Label.new()
	head.text = "🔒 %s — locked" % String(niche.get("name", _ui.active_niche))
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", UiUtil.BAD)
	_niche_gate_panel.add_child(head)

	for key: Variant in keys:
		_build_key_block(l, content, String(key))


func _build_key_block(l: Lineage, content: Content, role: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_niche_gate_panel.add_child(card)
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 10)
	card.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	pad.add_child(box)

	var title := Label.new()
	title.text = "Express a %s gene onto any organ:" % role.capitalize()
	title.add_theme_color_override("font_color", UiUtil.GOOD)
	box.add_child(title)

	var options: Array = content.key_affixes_for_role(role)
	options.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (
				Validation.RARITIES.find(String((a["gene"] as Dictionary).get("rarity", "common")))
				< Validation.RARITIES.find(
					String((b["gene"] as Dictionary).get("rarity", "common"))
				)
			)
	)
	for opt: Dictionary in options:
		_build_key_option(l, content, opt["affix"], opt["gene"], box)


func _build_key_option(
	l: Lineage, content: Content, affix: Dictionary, gene: Dictionary, box: VBoxContainer
) -> void:
	var affix_id := String(affix.get("id", ""))
	var gene_id := String(gene.get("id", ""))
	var rarity := String(gene.get("rarity", "common"))
	var slots: Array = affix.get("slots", [])
	var slot_names: Array[String] = []
	for s: Variant in slots:
		slot_names.append(String(s).replace("_", " ").capitalize())

	var line := Label.new()
	line.text = (
		"• %s — express on %s" % [String(affix.get("name", affix_id)), " / ".join(slot_names)]
	)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(1, 0)
	box.add_child(line)

	var copies := int(Store.state.genes_known.get(gene_id, 0))
	var status := HBoxContainer.new()
	status.size_flags_horizontal = Control.SIZE_FILL
	box.add_child(status)
	var status_lbl := Label.new()
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.custom_minimum_size = Vector2(1, 0)
	status_lbl.add_theme_font_size_override("font_size", 16)
	status.add_child(status_lbl)

	if copies > 0:
		status_lbl.text = (
			"   ✓ %s ×%d in codex — express it now" % [String(gene.get("name", gene_id)), copies]
		)
		status_lbl.add_theme_color_override("font_color", UiUtil.GOOD)
		var slot := UiUtil.first_expressible_slot(l, slots)
		var btn := Button.new()
		btn.text = "Express →"
		btn.pressed.connect(func() -> void: _express.open(slot))
		status.add_child(btn)
	else:
		var src := UiUtil.gene_source_text(content, gene_id)
		status_lbl.text = "   Find %s (%s): %s" % [String(gene.get("name", gene_id)), rarity, src]
		status_lbl.add_theme_color_override("font_color", UiUtil.DIM)


# -- clash panel --------------------------------------------------------------


func _build_clash_panel() -> void:
	_clash_panel = PanelContainer.new()
	_clash_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_clash_panel)
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 12)
	_clash_panel.add_child(pad)
	_clash_lines = VBoxContainer.new()
	_clash_lines.add_theme_constant_override("separation", 4)
	pad.add_child(_clash_lines)


func _refresh_clash(l: Lineage, content: Content) -> void:
	for c in _clash_lines.get_children():
		c.queue_free()

	var node_id := l.assigned_node
	if node_id == "":
		_clash_lines.add_child(
			_clash_line("No target assigned — tap a creature in The Wild.", UiUtil.DIM, 18)
		)
		return
	var node := content.node(node_id)
	var node_name := String(node.get("name", node_id))
	var eff_power := Resolve.effective_power(l, content)
	var yld := Resolve.yield_efficiency(l, node, content)

	if String(node.get("kind", "eat")) != "fight":
		_clash_lines.add_child(
			_clash_line("🌿  Grazing %s — undefended." % node_name, UiUtil.GOOD, 19)
		)
		_clash_lines.add_child(
			_clash_line("Throughput ×%.1f · a steady, safe harvest." % yld, UiUtil.DIM, 16)
		)
		return

	var totals := Resolve.affix_totals(l, content)
	var raw_def := float(node.get("defense", 0.0))
	var eff_def := Resolve.effective_defense(node, totals)
	var margin := eff_power - eff_def
	var verdict := "outgeared"
	var color := UiUtil.BAD
	if margin > 2.0:
		verdict = "free farm"
		color = UiUtil.GOOD
	elif margin > 0.0:
		verdict = "winning"
		color = UiUtil.GOOD
	elif is_zero_approx(margin):
		verdict = "even"
		color = UiUtil.DIM

	_clash_lines.add_child(_clash_line("⚔  Clashing with %s" % node_name, color, 19))

	# Power vs the CURRENT armour, with base armour + penetration in parentheses.
	var pen := float(totals.get("pen", 0.0))
	var power_line := "Power %.0f  vs  armour %.0f" % [eff_power, eff_def]
	if pen > 0.0:
		power_line += "  (base %.0f, penetration −%.0f)" % [raw_def, pen]
	_clash_lines.add_child(_clash_line(power_line, UiUtil.DIM, 17))
	_clash_lines.add_child(_clash_line("%s · yield ×%.1f" % [verdict, yld], color, 17))

	var danger := float(node.get("danger", 0.0))
	if danger > 0.0:
		var factor := Resolve.danger_factor(l, node, content)
		var pct := roundi((1.0 - factor) * 100.0)
		if pct > 0:
			_clash_lines.add_child(
				_clash_line(
					"Danger %d: retaliation taxes output −%d%%" % [int(danger), pct], UiUtil.BAD, 16
				)
			)
		else:
			_clash_lines.add_child(
				_clash_line("Danger %d: shrugged off — guard holds." % int(danger), UiUtil.GOOD, 16)
			)

	var spliceable := String(node.get("spliceable", ""))
	if spliceable != "":
		var gene_row := content.gene(spliceable)
		var gname := String(gene_row.get("name", spliceable))
		var rarity := String(gene_row.get("rarity", "common"))
		if Resolve.splice_rate_eff(l, node, content) > 0.0:
			_clash_lines.add_child(
				_clash_line(
					"Splice window OPEN — pins land: %s (%s)" % [gname, rarity],
					RarityColors.of(rarity),
					16
				)
			)
		else:
			_clash_lines.add_child(
				_clash_line(
					"Splice window closed — out-power it (or run stealth) to crack %s." % gname,
					UiUtil.DIM,
					16
				)
			)


func _clash_line(text: String, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	return l


# -- skills readout -----------------------------------------------------------


func _build_skill_panel() -> void:
	_skill_panel = VBoxContainer.new()
	_skill_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_panel.add_theme_constant_override("separation", 8)
	add_child(_skill_panel)
	for s: Dictionary in Data.content.skills():
		var sid := String(s.get("id", ""))
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 1)
		_skill_panel.add_child(row)

		var head := HBoxContainer.new()
		row.add_child(head)
		var name_lbl := Label.new()
		name_lbl.text = String(s.get("name", sid))
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_lbl)
		var lvl_lbl := Label.new()
		lvl_lbl.add_theme_font_size_override("font_size", 16)
		lvl_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		head.add_child(lvl_lbl)

		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.custom_minimum_size = Vector2(0, 6)
		row.add_child(bar)

		_skill_rows[sid] = {"level": lvl_lbl, "bar": bar}


func _refresh_skills(l: Lineage) -> void:
	for sid: String in _skill_rows:
		var prog := Resolve.skill_progress(l, sid)
		var refs: Dictionary = _skill_rows[sid]
		var lvl_lbl := refs["level"] as Label
		var bar := refs["bar"] as ProgressBar
		if bool(prog.get("capped", false)):
			lvl_lbl.text = "Level %d · maxed" % int(prog["level"])
			bar.value = 1.0
		else:
			lvl_lbl.text = "Level %d" % int(prog["level"])
			bar.value = float(prog["frac"])


# -- node cards ---------------------------------------------------------------


func _build_node_cards() -> void:
	var empty_style := StyleBoxEmpty.new()
	for node: Dictionary in Data.content.tables.get("nodes", []):
		var node_id := String(node.get("id", ""))

		var card_frame := PanelContainer.new()
		card_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(card_frame)

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
		def_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		stats.add_child(def_lbl)
		var danger_lbl := Label.new()
		danger_lbl.add_theme_color_override("font_color", UiUtil.BAD)
		stats.add_child(danger_lbl)

		var matchup_lbl := Label.new()
		box.add_child(matchup_lbl)

		var flavor_lbl := Label.new()
		flavor_lbl.text = String(node.get("flavor", ""))
		flavor_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		flavor_lbl.add_theme_font_size_override("font_size", 16)
		flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor_lbl.custom_minimum_size = Vector2(1, 0)
		box.add_child(flavor_lbl)

		var click_btn := Button.new()
		click_btn.flat = true
		click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		for style in ["normal", "hover", "pressed", "disabled", "focus"]:
			click_btn.add_theme_stylebox_override(style, empty_style)
		click_btn.pressed.connect(
			func() -> void: Store.assign_node(_ui.active_lineage().id, node_id)
		)
		card_frame.add_child(click_btn)

		_cards[node_id] = {
			"card": card_frame,
			"btn": click_btn,
			"name_lbl": name_lbl,
			"matchup_lbl": matchup_lbl,
			"danger_lbl": danger_lbl,
		}


func _refresh_node_cards(l: Lineage, content: Content) -> void:
	# Hide every card; the ladder below reveals the active niche's rungs.
	for node_id: String in _cards:
		(_cards[node_id]["card"] as Control).visible = false

	# The active niche's nodes, ordered by ladder_order (the sequential ladder).
	var ladder: Array = []
	for node_id: String in _cards:
		var node := content.node(node_id)
		if String(node.get("niche", "")) == _ui.active_niche:
			ladder.append(node)
	ladder.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("ladder_order", 0)) < float(b.get("ladder_order", 0))
	)

	var niche_locked := not Commands.meets_niche_keys(l, content, _ui.active_niche)
	var locked_shown := 0
	for node: Dictionary in ladder:
		var refs: Dictionary = _cards[String(node.get("id", ""))]
		var skill_locked := not Commands.meets_skill_requirement(l, node.get("requires", {}))
		# show-next-few: reveal every unlocked rung + only the next SHOW_LOCKED_RUNGS locked.
		if skill_locked:
			if locked_shown >= SHOW_LOCKED_RUNGS:
				continue
			locked_shown += 1
		(refs["card"] as Control).visible = true
		_render_node_card(l, content, node, refs, skill_locked, niche_locked)


## Render one ladder card: working/locked state, danger, and either the matchup
## verdict (unlocked) or the skill / niche requirement that gates it (locked).
func _render_node_card(
	l: Lineage,
	content: Content,
	node: Dictionary,
	refs: Dictionary,
	skill_locked: bool,
	niche_locked: bool
) -> void:
	var node_id := String(node.get("id", ""))
	var locked := skill_locked or niche_locked
	(refs["btn"] as Button).disabled = locked

	var active := l.assigned_node == node_id
	(refs["name_lbl"] as Label).text = (
		("🔒 " if locked else "")
		+ String(node.get("name", node_id))
		+ (" · working" if active else "")
	)
	(refs["card"] as Control).modulate = (
		Color(1, 1, 1, 0.4) if locked else (Color.WHITE if active else Color(1, 1, 1, 0.72))
	)

	var danger_lbl := refs["danger_lbl"] as Label
	var danger := float(node.get("danger", 0.0))
	danger_lbl.visible = danger > 0 and not locked
	if danger_lbl.visible:
		danger_lbl.text = "  DANGER %d" % int(danger)

	var matchup_lbl := refs["matchup_lbl"] as Label
	if skill_locked:
		matchup_lbl.text = "🔒 %s" % Commands.requirement_label(content, node.get("requires", {}))
		matchup_lbl.add_theme_color_override("font_color", UiUtil.BAD)
		return
	if niche_locked:
		var keys: Array = content.niche(_ui.active_niche).get("affix_keys", [])
		matchup_lbl.text = (
			"locked — express a %s gene (see the key panel)" % String(keys[0]).capitalize()
			if not keys.is_empty()
			else "locked"
		)
		matchup_lbl.add_theme_color_override("font_color", UiUtil.BAD)
		return

	var margin := Resolve.effective_power(l, content) - float(node.get("defense", 0.0))
	var verdict := "outgeared"
	var color := UiUtil.BAD
	if margin > 2.0:
		verdict = "free farm"
		color = UiUtil.GOOD
	elif margin > 0.0:
		verdict = "winning matchup"
		color = UiUtil.GOOD
	elif is_zero_approx(margin):
		verdict = "even matchup"
		color = UiUtil.DIM
	matchup_lbl.text = "%s · yield ×%.1f" % [verdict, Resolve.yield_efficiency(l, node, content)]
	matchup_lbl.add_theme_color_override("font_color", color)


# -- splice offers + catalogue ------------------------------------------------


func _refresh_splice_offers() -> void:
	for child in _splice_list.get_children():
		child.queue_free()

	var offers: Array = Store.state.splice_offers
	if offers.is_empty():
		var none := Label.new()
		none.text = "Splice queue empty."
		none.add_theme_color_override("font_color", UiUtil.DIM)
		none.add_theme_font_size_override("font_size", 16)
		_splice_list.add_child(none)
		return

	for i in range(offers.size()):
		var offer: Dictionary = offers[i]
		var gene_id := String(offer.get("gene", ""))
		var gene_row := Data.content.gene(gene_id)
		var gene_name := String(gene_row.get("name", gene_id))
		var rarity := String(gene_row.get("rarity", "common"))
		var node_name := String(Data.content.node(String(offer.get("node", ""))).get("name", ""))

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
			+ "Gene copies unlock traits — express them in the Body tab."
		)
		claim_btn.pressed.connect(func() -> void: _on_claim_splice(idx))
		row.add_child(claim_btn)


func _on_claim_splice(index: int) -> void:
	var result := Store.claim_splice(index)
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


## Every spliceable creature as a collection target — signature gene, copies
## banked, the express tier those copies unlock, and a reach hint. Makes "what
## should I fight" a legible build decision.
func _refresh_splice_catalogue(l: Lineage, content: Content) -> void:
	for c in _splice_catalogue.get_children():
		c.queue_free()

	var eff_power := Resolve.effective_power(l, content)
	var targets: Array = []
	var known := 0
	for node: Dictionary in content.tables.get("nodes", []):
		if String(node.get("spliceable", "")) == "":
			continue
		targets.append(node)
		if int(Store.state.genes_known.get(String(node.get("spliceable", "")), 0)) > 0:
			known += 1

	var head := Label.new()
	head.text = "%d / %d signature genes obtained" % [known, targets.size()]
	head.add_theme_color_override("font_color", UiUtil.DIM)
	head.add_theme_font_size_override("font_size", 16)
	_splice_catalogue.add_child(head)

	for node: Dictionary in targets:
		var gene_id := String(node.get("spliceable", ""))
		var gene_row := content.gene(gene_id)
		var gname := String(gene_row.get("name", gene_id))
		var rarity := String(gene_row.get("rarity", "common"))
		var copies := int(Store.state.genes_known.get(gene_id, 0))
		var defense := float(node.get("defense", 0.0))

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_splice_catalogue.add_child(card)
		var pad := MarginContainer.new()
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			pad.add_theme_constant_override(side, 10)
		card.add_child(pad)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		pad.add_child(box)

		var top := HBoxContainer.new()
		box.add_child(top)
		var name_lbl := Label.new()
		name_lbl.text = String(node.get("name", ""))
		name_lbl.add_theme_font_size_override("font_size", 19)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override(
			"font_color", RarityColors.of(rarity) if copies > 0 else UiUtil.DIM
		)
		top.add_child(name_lbl)
		var copies_lbl := Label.new()
		if copies > 0:
			copies_lbl.text = "×%d · express ≤T%d" % [copies, copies]
			copies_lbl.add_theme_color_override("font_color", UiUtil.GOOD)
		else:
			copies_lbl.text = "not yet spliced"
			copies_lbl.add_theme_color_override("font_color", UiUtil.DIM)
		copies_lbl.add_theme_font_size_override("font_size", 16)
		top.add_child(copies_lbl)

		var reach := (
			"in reach" if eff_power > defense else "need +%d power" % ceili(defense - eff_power)
		)
		var detail := Label.new()
		detail.text = (
			"Signature: %s (%s)  ·  %s · DEF %d · %s"
			% [
				gname,
				rarity,
				String(content.niche(String(node.get("niche", ""))).get("name", "")),
				int(defense),
				reach
			]
		)
		detail.add_theme_color_override("font_color", UiUtil.DIM)
		detail.add_theme_font_size_override("font_size", 16)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(1, 0)
		box.add_child(detail)
