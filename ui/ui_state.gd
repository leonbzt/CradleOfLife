class_name UiState
extends RefCounted

## The small bundle of *view* state shared across tabs — which lineage and niche
## are shown, and any pending class commit. It is NOT game state (that lives in
## Store/GameState); it's purely what the UI is currently looking at.
##
## Tabs read it and mutate it through the setters; `changed` lets the shell fan a
## refresh out to every tab when the view (not the save) changes. A leaf class so
## tabs never need a reference back to the shell (no cyclic class deps).

signal changed
## Requests the shell switch to a named tab ("home"/"body"/"world"/"class").
signal navigate(tab_name: String)

var active_lineage_idx: int = 0
var active_niche: String = "shallow_benthos"
var pending_class_id: String = ""
## When a navigation targets a specific organ (e.g. the agenda's "tier up" jump),
## the destination tab pulses this slot once and clears it.
var focus_slot: String = ""


## The currently-shown lineage, index clamped to the live roster.
func active_lineage() -> Lineage:
	var lineages: Array = Store.state.lineages
	return lineages[clampi(active_lineage_idx, 0, lineages.size() - 1)]


func set_active_lineage_idx(idx: int) -> void:
	active_lineage_idx = idx
	pending_class_id = ""
	changed.emit()


func set_active_niche(niche_id: String) -> void:
	active_niche = niche_id
	changed.emit()


func set_pending_class_id(class_id: String) -> void:
	pending_class_id = class_id
	changed.emit()


## Ask the shell to show `tab_name`, optionally pulsing `slot` on arrival.
func request_navigate(tab_name: String, slot: String = "") -> void:
	focus_slot = slot
	navigate.emit(tab_name)


## Reset to defaults (after a save wipe). No emit — the caller's Store reset fires
## state_changed, which already triggers a full refresh.
func reset() -> void:
	active_lineage_idx = 0
	active_niche = "shallow_benthos"
	pending_class_id = ""
	focus_slot = ""
