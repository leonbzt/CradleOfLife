extends Node

## Autoload "Store". Holds the live GameState and persists it to user://save.json.
## The save carries a schema_version so a save written by an old client still
## loads in a new one — the Tree never resets across years of patches
## (VISION.md §14). The migration hook below is intentionally a near-passthrough:
## real migration steps land here when the first breaking schema change actually
## arrives, not before (YAGNI, CLAUDE.md §2.6).

const SAVE_PATH: String = "user://save.json"

var state: GameState


func _ready() -> void:
	state = load_state()


func new_game(master_seed: int) -> void:
	state = GameState.new()
	state.master_seed = master_seed
	save_state()


func save_state() -> void:
	if state == null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Store: cannot write " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(state.to_dict(), "  "))
	f.close()


func load_state() -> GameState:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Store: save file is corrupt; ignoring.")
		return null
	return _migrate_and_load(parsed)


func _migrate_and_load(d: Dictionary) -> GameState:
	var v: int = int(d.get("schema_version", 1))
	if v > GameState.SCHEMA_VERSION:
		push_warning(
			"Store: save is from a newer client (%d > %d)." % [v, GameState.SCHEMA_VERSION]
		)
	# Migration steps (v1 -> v2 -> ...) land here as the schema evolves.
	return GameState.from_dict(d)
