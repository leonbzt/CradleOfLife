extends Node

## Autoload "Store". Holds the live GameState and persists it to user://save.json.
## All runtime mutations go through the named-command wrappers below (the pure
## logic lives in sim/commands.gd so it stays headless-testable); the UI never
## touches state directly — it observes the signals and re-reads.
##
## The save carries a schema_version so a save written by an old client still
## loads in a new one — the Tree never resets across years of patches
## (VISION.md §14). Migration is handled by GameState.migrate_and_load().

signal state_changed
signal loot_dropped(lineage_id: String, loot: Dictionary)
## Emitted with a closed-form Accrual batch (plus a "dt" key) when the player
## returns to enough offline time to be worth a Dev dispatch (Phase 3.5 WP1).
signal dispatch_ready(batch: Dictionary)

const SAVE_PATH: String = "user://save.json"

## Offline accrual: cap the elapsed gap so a forward/tampered clock or a long
## sleep mints at most this much (DECISIONS.md 2026-06-13); show a dispatch only
## for gaps past the floor — a quick reopen accrues silently.
const OFFLINE_CAP_SECONDS: float = 72.0 * 3600.0
const DISPATCH_MIN_SECONDS: float = 60.0

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


func forage_all(dt: float) -> void:
	for lin: Lineage in state.lineages:
		if lin.graduated:
			continue
		var loot := Commands.forage(state, Data.content, lin.id, dt, rng)
		if not loot.is_empty():
			loot_dropped.emit(lin.id, loot)
	save_state()
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


func claim_splice(index: int) -> Dictionary:
	var result := Commands.claim_splice(state, index)
	if result["ok"]:
		save_state()
		state_changed.emit()
	return result


func branch_lineage(display_name: String) -> Dictionary:
	var result := Commands.branch_lineage(state, Data.content, "", display_name)
	if result["ok"]:
		save_state()
		state_changed.emit()
	return result


func express(lineage_id: String, slot: String, affix_id: String) -> Dictionary:
	var result := Commands.express(state, Data.content, lineage_id, slot, affix_id)
	if result["ok"]:
		save_state()
		state_changed.emit()
	return result


## DEV (testing only): wipe the save and start a fresh Tree.
func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	new_game(int(Time.get_unix_time_from_system()))


## Compute and APPLY the offline accrual since `last_seen_unix`, returning the
## batch (with a "dt" key) for the Dev dispatch — or {} for a sub-floor gap, which
## still accrues silently so nothing is ever lost. The real-time counterpart of
## dev_fast_forward; both apply through Commands.apply_accrual_batch so an offline
## gap and a live grind can never drift (Phase 3.5 WP1). The UI calls this on
## launch; _notification calls it on resume from background.
func apply_offline_accrual() -> Dictionary:
	if state == null or rng == null or Data.content == null:
		return {}
	var now := int(Time.get_unix_time_from_system())
	var dt := Commands.offline_dt(state.last_seen_unix, now, OFFLINE_CAP_SECONDS)
	if dt <= 0.0:
		return {}
	var batch := Accrual.accrue(state, Data.content, dt, rng)
	Commands.apply_accrual_batch(state, batch)
	save_state()
	state_changed.emit()
	if dt < DISPATCH_MIN_SECONDS:
		return {}
	batch["dt"] = dt
	return batch


## DEV (testing only): jump `seconds` of offline accrual forward, apply it through
## the same path the real offline catch-up uses, and raise the dispatch so the
## dispatch UI can be exercised without waiting.
func dev_fast_forward(seconds: float) -> void:
	if state == null:
		return
	var batch := Accrual.accrue(state, Data.content, seconds, rng)
	Commands.apply_accrual_batch(state, batch)
	save_state()
	state_changed.emit()
	batch["dt"] = seconds
	dispatch_ready.emit(batch)


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
	return GameState.migrate_and_load(parsed as Dictionary)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_state()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		var batch := apply_offline_accrual()
		if not batch.is_empty():
			dispatch_ready.emit(batch)
