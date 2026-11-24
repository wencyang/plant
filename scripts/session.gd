extends RefCounted
## One attempt at a level: the world, your plant and the wild plants.

const WorldSim := preload("res://scripts/world_sim.gd")
const PlantSim := preload("res://scripts/plant_sim.gd")
const Levels := preload("res://scripts/levels.gd")

var def: Dictionary
var world
var plant
var wild_sims: Array = []
var lures_left := 0
var prunes_left := 0
var idle_time := 0.0

func start(level: Dictionary, genome: Dictionary, seed_value := 1) -> void:
	def = level
	world = WorldSim.new()
	world.load_level(level)
	lures_left = int(level.get("lures", 0))
	prunes_left = int(level.get("prunes", 0))
	wild_sims.clear()
	for i in world.wilds.size():
		var w: Dictionary = world.wilds[i]
		var g: Dictionary = Levels.wild(str(w.genome))
		w.genome = g
		var ws = PlantSim.new()
		ws.setup(g, world, float(w.energy), 7000 + i * 31, true)
		ws.grow_wild(float(w.energy), w.pos)
		var pts := PackedVector2Array()
		for n in ws.pos.size():
			if ws.kind[n] == 0: pts.append(ws.pos[n])
		w.nodes = pts
		wild_sims.append(ws)
	plant = PlantSim.new()
	plant.setup(genome, world, float(level.energy), seed_value)

func step(dt: float) -> void:
	plant.step(dt)
	if plant.is_growing(): idle_time = 0.0
	else: idle_time += dt

func add_lure(p: Vector2) -> bool:
	if lures_left <= 0 or world.in_dark(p): return false
	lures_left -= 1
	world.lures.append(p)
	return true

func remove_lure(i: int) -> void:
	world.lures.remove_at(i)
	lures_left += 1

func prune(a: Vector2, b: Vector2) -> Array:
	if prunes_left <= 0: return []
	var removed: Array = plant.prune(a, b)
	if not removed.is_empty(): prunes_left -= 1
	return removed

## Cut along a hand-drawn swipe. Uses one prune if anything was cut.
func prune_path(points: Array) -> Array:
	if prunes_left <= 0 or points.size() < 2: return []
	var removed: Array = []
	for i in range(points.size() - 1):
		removed.append_array(plant.prune(points[i], points[i + 1]))
	if not removed.is_empty(): prunes_left -= 1
	return removed

func won() -> bool:
	return world.all_goals_reached()

func stuck() -> bool:
	return not won() and idle_time > 1.5
