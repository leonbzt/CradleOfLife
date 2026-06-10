class_name Rng
extends RefCounted

## Deterministic, named RNG streams over a single master seed.
##
## The chase, splicing, and offline accrual must be reproducible: the events an
## offline batch computes have to match what a scheduled notification predicted
## (VISION.md §16). A single global RNG cannot give that — interleaving draws
## from different systems makes any one stream unreplayable. So every concern
## draws from its OWN named stream, each derived deterministically from one
## stored master seed. Tests pass a fixed seed and get identical runs.

var _master_seed: int
var _streams: Dictionary = {}  # stream_name: String -> RandomNumberGenerator


func _init(master_seed: int = 0) -> void:
	_master_seed = master_seed


## The named stream, created deterministically on first use.
func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var r := RandomNumberGenerator.new()
		r.seed = _derive_seed(stream_name)
		_streams[stream_name] = r
	return _streams[stream_name]


func _derive_seed(stream_name: String) -> int:
	return hash(str(_master_seed) + ":" + stream_name)


## True with probability p, drawn from the named stream.
func chance(stream_name: String, p: float) -> bool:
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	return stream(stream_name).randf() < p


func randf(stream_name: String) -> float:
	return stream(stream_name).randf()


func randi_range(stream_name: String, from: int, to: int) -> int:
	return stream(stream_name).randi_range(from, to)


## Snapshot of every stream's position, for the save file. Without this, each
## app launch would re-derive streams from the master seed and replay the same
## upcoming roll sequence. States are stored as Strings: they are 64-bit ints,
## and JSON round-trips numbers as floats, which would corrupt them.
func export_state() -> Dictionary:
	var out: Dictionary = {}
	for stream_name: String in _streams:
		out[stream_name] = str((_streams[stream_name] as RandomNumberGenerator).state)
	return out


## Restores stream positions captured by export_state(). Streams not present
## stay lazily derived from the master seed as usual.
func import_state(saved: Dictionary) -> void:
	for stream_name: String in saved:
		stream(stream_name).state = String(saved[stream_name]).to_int()


## Inter-arrival time for a Poisson process of rate `rate` (events per unit
## time), sampled by inverse-CDF: -ln(U)/rate. This is how closed-form accrual
## (sim/accrual.gd) walks discrete rare events without frame-ticking elapsed
## offline time — and how we can predict WHEN the next event lands.
func exp_interval(stream_name: String, rate: float) -> float:
	if rate <= 0.0:
		return INF
	var u: float = maxf(stream(stream_name).randf(), 1e-12)
	return -log(u) / rate
