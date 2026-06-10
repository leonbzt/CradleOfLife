extends Node

## Autoload "Data". Loads and validates all content JSON at boot, then holds it
## for the running game. Fails loudly on malformed or invalid content — a
## content regression should stop the build, never reach the player
## (IMPLEMENTATION.md §1, §3). The actual loading/validation lives in the
## Node-free sim classes so this autoload and the headless tests share one path.

const DATA_DIR: String = "res://data"

var content: Content


func _ready() -> void:
	content = Content.load_dir(DATA_DIR)
	var errors: Array[String] = Validation.validate(content)
	if not errors.is_empty():
		for e in errors:
			push_error("[content] " + e)
		push_error("[content] %d validation error(s); refusing to continue." % errors.size())
		get_tree().quit(1)
