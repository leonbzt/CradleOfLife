class_name LootPop
extends Label

## The rarity-coloured loot pop (IMPLEMENTATION.md §4 Phase 1): a drop floats up
## from where it happened and fades. The juice budget for the slice lives here —
## scale punch in, drift up, fade out.


static func spawn(layer: Control, at: Vector2, pop_text: String, color: Color) -> void:
	var pop := LootPop.new()
	pop.text = pop_text
	pop.add_theme_color_override("font_color", color)
	pop.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	pop.add_theme_font_size_override("font_size", 26)
	pop.add_theme_constant_override("outline_size", 8)
	pop.z_index = 100
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(pop)
	pop.global_position = at + Vector2(randf_range(-16.0, 16.0), randf_range(-8.0, 4.0))
	pop.scale = Vector2(1.4, 1.4)

	var t := pop.create_tween()
	t.set_parallel(true)
	(
		t
		. tween_property(pop, "position:y", pop.position.y - 90.0, 0.9)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	t.tween_property(pop, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	(
		t
		. tween_property(pop, "modulate:a", 0.0, 0.4)
		. set_delay(0.5)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	t.chain().tween_callback(pop.queue_free)
