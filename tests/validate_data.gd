extends SceneTree

## Content gate 1, headless, for CI (IMPLEMENTATION.md §3, §6).
##   godot --headless --script res://tests/validate_data.gd
## Exits non-zero if any content row fails orthogonality or structural checks,
## so a bad affix or a dangling drop-table reference fails the build.


func _initialize() -> void:
	var content := Content.load_dir("res://data")
	var errors := Validation.validate(content)

	print("== content validation ==")
	print("  affixes:    %d" % (content.tables.get("affixes", []) as Array).size())
	print("  adaptations:%d" % (content.tables.get("adaptations", []) as Array).size())
	print("  genes:      %d" % (content.tables.get("genes", []) as Array).size())
	print("  materials:  %d" % (content.tables.get("materials", []) as Array).size())
	print("  nodes:      %d" % (content.tables.get("nodes", []) as Array).size())

	if errors.is_empty():
		print("  result: PASS")
		quit(0)
	else:
		print("  result: FAIL (%d)" % errors.size())
		for e in errors:
			print("   - " + e)
		quit(1)
