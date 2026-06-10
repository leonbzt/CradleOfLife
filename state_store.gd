extends Node

## Autoload "Store". Holds the live GameState and persists it to user://save.json.
## All runtime mutations go through the named-command wrappers below (the pure
## logic lives in sim/commands.gd so it stays headless-testable); the UI never
## touches state directly — it observes the signals and re-reads.
##
## The save carries a schema_version so a save written by an old client still
## loads in a new one — the Tree never resets across years of patches
## (VISION.md §14). The migration hook below is intentionally a near-passthrough:
## real migration steps land here when the first breaking schema change actually
## arrives, not before (YAGNI, CLAUDE.md §2.6).

## Something about the save changed; UI should refresh from `state`.
signal state_changed
## A foraging action landed loot (the rarity-coloured pop hangs off this).
signal loot_dropped(lineage_id: String, loot: Dictionary)

const SAVE_PATH: String = "user://save.json"

var state: GameState
var rng: Rng


func _ready() -> void:
	state = load_state()
	if state != null:
		rng = Rng.new(state.master_seed)
		rng.import_state(state.rng_streams)


func new_game(master_seed: int) -> void:
	state = GameState.new()
	state.master_seed = master_seed
	rng = Rng.new(master_seed)
	Commands.add_starter_lineage(state, Data.content)
	save_state()
	state_changed.emit()


func forage(lineage_id: String, dt: float) -> void:
	var loot := Commands.forage(state, Data.content, lineage_id, dt, rng)
	if loot.is_empty():
		return
	save_state()
	loot_dropped.emit(lineage_id, loot)
	state_changed.emit()


func metabolize(lineage_id: String, adaptation_id: String) -> Dictionary:
	var result := Commands.metabolize(state, Data.content, lineage_id, adaptation_id)
	if result["ok"]:
		save_state()
		state_changed.emit()
	return result


func assign_node(lineage_id: String, node_id: String) -> void:
	if Commands.assign_node(state, Data.content, lineage_id, node_id):
		save_state()
		state_changed.emit()


func save_state() -> void:
	if state == null:
		return
	state.last_seen_unix = int(Time.get_unix_time_from_system())
	if rng != null:
		state.rng_streams = rng.export_state()
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_state()


func _migrate_and_load(d: Dictionary) -> GameState:
	var v: int = int(d.get("schema_version", 1))
	if v > GameState.SCHEMA_VERSION:
		push_warning(
			"Store: save is from a newer client (%d > %d)." % [v, GameState.SCHEMA_VERSION]
		)
	# Migration steps (v1 -> v2 -> ...) land here as the schema evolves.
	return GameState.from_dict(d)
