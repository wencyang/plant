extends RefCounted
## Seed vault, progress and settings.

const Levels := preload("res://scripts/levels.gd")
const PATH := "user://bloomward.json"
const MAX_SEEDS := 40

var seeds: Array = []        # genomes
var completed: Dictionary = {}
var species_met: Dictionary = {}
var muted := false
var path := PATH

func _init(p := PATH) -> void:
	path = p
	load_data()
	if seeds.is_empty(): seeds.append(Levels.starter())

func load_data() -> void:
	if not FileAccess.file_exists(path): return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return
	seeds = d.get("seeds", [])
	for g in seeds:
		for k in ["gen", "petals", "leaf_shape", "flower", "pattern", "stem", "thorns", "glow", "tendrils", "roots"]:
			if g.has(k): g[k] = int(g[k])
	completed = d.get("completed", {})
	species_met = d.get("species_met", {})
	muted = bool(d.get("muted", false))

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"seeds": seeds, "completed": completed, "species_met": species_met, "muted": muted}))

func add_seed(g: Dictionary) -> void:
	for s in seeds:
		if s.name == g.name and int(s.gen) == int(g.gen) and _same_traits(s, g): return
	seeds.push_front(g)
	if seeds.size() > MAX_SEEDS: seeds.resize(MAX_SEEDS)
	save()

func _same_traits(a: Dictionary, b: Dictionary) -> bool:
	for t in ["thorns", "glow", "tendrils", "roots", "leaf_shape", "flower"]:
		if int(a[t]) != int(b[t]): return false
	return true

func unlocked(index: int) -> bool:
	if index == 0: return true
	var prev: String = Levels.all()[index - 1].id
	return completed.has(prev)
