extends RefCounted
## Seed vault, progress and settings.

const Levels := preload("res://scripts/levels.gd")
const Genome := preload("res://scripts/genome.gd")
const PATH := "user://bloomward.json"
const MAX_SEEDS := 40

var seeds: Array = []        # genomes
var completed: Dictionary = {}
var species_met: Dictionary = {}
var stars: Dictionary = {}   # level id -> [bool, bool, bool]
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
		for k in ["gen", "petals", "leaf_shape", "flower", "pattern", "stem", "thorns", "glow", "tendrils", "roots", "buoyant", "waxy"]:
			if g.has(k): g[k] = int(g[k])
	completed = d.get("completed", {})
	species_met = d.get("species_met", {})
	stars = d.get("stars", {})
	muted = bool(d.get("muted", false))

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"seeds": seeds, "completed": completed, "species_met": species_met, "stars": stars, "muted": muted}))

func add_seed(g: Dictionary) -> void:
	for s in seeds:
		if s.name == g.name and int(s.gen) == int(g.gen) and _same_traits(s, g): return
	seeds.push_front(g)
	if seeds.size() > MAX_SEEDS: seeds.resize(MAX_SEEDS)
	save()

func _same_traits(a: Dictionary, b: Dictionary) -> bool:
	# Two siblings with different colour, growth, petal count or ancestry are
	# distinct discoveries even when their gifts happen to match.
	for key: String in Genome.make({}):
		if Genome.RANGES.has(key):
			if absf(float(a.get(key,0))-float(b.get(key,0)))>0.00000001: return false
			continue
		if a.get(key)!=b.get(key): return false
	return true

func unlocked(index: int) -> bool:
	if index == 0: return true
	var prev: String = Levels.all()[index - 1].id
	return completed.has(prev)


func record_stars(id: String, got: Array) -> Array:
	var old: Array = stars.get(id, [false, false, false])
	var merged: Array = []
	for i in 3: merged.append(bool(old[i]) or bool(got[i]))
	stars[id] = merged
	save()
	return merged

func star_count(id: String) -> int:
	var n := 0
	for b in stars.get(id, []):
		if b: n += 1
	return n

func total_stars() -> int:
	var n := 0
	for id in stars: n += star_count(id)
	return n
