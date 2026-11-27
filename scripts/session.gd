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
var tools_used := 0
const MAX_UNDO := 8
# These are simulation values, not objects. Restoring them in place preserves
# PlantView.sim, plant.world, and every wild plant's shared world reference.
const WORLD_FIELDS := ["bounds","rocks","crystals","goals","darks","waters","wilds","lures","vents","dews","switches","decoys","updrafts","time","seed_pos"]
const PLANT_FIELDS := ["pos","parent","born","desc","kind","alive","children","tips","blooms","fruits","energy","energy_max","grown","time","events"]
var _undo_history: Array[Dictionary]=[]
# One displaced entry is retained only until a drag commits or cancels. It is
# never nested inside history, so repeated moves cannot grow a hidden chain.
var _move_cancel_evicted: Dictionary={}
var _lure_move_open: bool=false

func start(level: Dictionary, genome: Dictionary, seed_value := 1) -> void:
	def = level
	_undo_history.clear()
	finish_lure_move()
	idle_time=0.0
	tools_used=0
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
	world.update(dt)
	plant.step(dt)
	if plant.is_growing(): idle_time = 0.0
	else: idle_time += dt

func add_lure(p: Vector2) -> bool:
	if world==null or lures_left<=0 or not p.is_finite() or not world.bounds.has_point(p) or world.in_dark(p): return false
	_checkpoint("Place lure","place_lure")
	lures_left-=1
	tools_used+=1
	world.lures.append(p)
	return true

func remove_lure(i: int) -> bool:
	if world==null or i<0 or i>=world.lures.size(): return false
	_checkpoint("Recall lure","recall_lure",i)
	world.lures.remove_at(i)
	lures_left+=1
	return true

## Call with coalesce=true only after the first successful motion of one drag.
## Distinct drags should begin with the default false, making one undo each.
func move_lure(i: int,p: Vector2,coalesce: bool=false) -> bool:
	if world==null or i<0 or i>=world.lures.size() or not p.is_finite() or not world.bounds.has_point(p) or world.in_dark(p): return false
	if world.lures[i].is_equal_approx(p): return false
	var continuing: bool=coalesce and _lure_move_open and not _undo_history.is_empty() and str(_undo_history.back().kind)=="move_lure" and int(_undo_history.back().lure_index)==i
	if not continuing: _checkpoint("Move lure","move_lure",i)
	world.lures[i]=p
	return true

func _hits_stem(a: Vector2,b: Vector2) -> bool:
	if plant==null or not a.is_finite() or not b.is_finite(): return false
	for i in range(1,plant.pos.size()):
		var parent: int=int(plant.parent[i])
		if int(plant.alive[i])==0 or int(plant.kind[i])!=0 or parent<0: continue
		if plant.pos[parent].distance_to(plant.pos[i])<0.5: continue
		if Geometry2D.segment_intersects_segment(a,b,plant.pos[parent],plant.pos[i])!=null: return true
	return false

func prune(a: Vector2,b: Vector2) -> Array:
	if prunes_left<=0 or not _hits_stem(a,b): return []
	_checkpoint("Prune stem","prune")
	var removed: Array=plant.prune(a,b)
	if not removed.is_empty():
		prunes_left-=1
		tools_used+=1
	return removed

## One successful hand-drawn swipe is one action and one checkpoint.
func prune_path(points: Array) -> Array:
	if prunes_left<=0 or points.size()<2: return []
	for point: Variant in points:
		if not point is Vector2 or not point.is_finite(): return []
	var hit: bool=false
	for i in range(points.size()-1):
		if _hits_stem(points[i],points[i+1]): hit=true; break
	if not hit: return []
	_checkpoint("Prune stem","prune")
	var removed: Array=[]
	for i in range(points.size()-1):
		# PlantSim emits a prune event even for a missed segment. Skip misses so
		# an empty swipe leaves the entire simulation unchanged.
		if _hits_stem(points[i],points[i+1]): removed.append_array(plant.prune(points[i],points[i+1]))
	if not removed.is_empty():
		prunes_left-=1
		tools_used+=1
	return removed

func _copy(value: Variant) -> Variant:
	if value is Array or value is Dictionary: return value.duplicate(true)
	if value is PackedVector2Array or value is PackedInt32Array or value is PackedFloat32Array or value is PackedByteArray: return value.duplicate()
	return value

func _checkpoint(action: String,kind: String,lure_index: int=-1) -> void:
	finish_lure_move()
	var world_state: Dictionary={}
	for field: String in WORLD_FIELDS: world_state[field]=_copy(world.get(field))
	var plant_state: Dictionary={}
	for field: String in PLANT_FIELDS: plant_state[field]=_copy(plant.get(field))
	_undo_history.append({"action":action,"kind":kind,"lure_index":lure_index,"world":world_state,"plant":plant_state,"rng_seed":plant.rng.seed,"rng_state":plant.rng.state,"lures_left":lures_left,"prunes_left":prunes_left,"tools_used":tools_used,"idle_time":idle_time})
	while _undo_history.size()>MAX_UNDO:
		var evicted: Dictionary=_undo_history.pop_front()
		if kind=="move_lure": _move_cancel_evicted=evicted
	_lure_move_open=kind=="move_lure"

func finish_lure_move() -> void:
	_lure_move_open=false
	_move_cancel_evicted={}

## Cancel an open drag without consuming an older checkpoint at capacity.
func cancel_lure_move() -> Dictionary:
	if not _lure_move_open or not can_undo() or str(_undo_history.back().kind)!="move_lure": return {"ok":false,"action":"","message":"There is no moving lure to cancel."}
	var evicted: Dictionary=_move_cancel_evicted
	var result: Dictionary=undo()
	if not evicted.is_empty(): _undo_history.push_front(evicted)
	result["cancelled"]=true
	return result

func can_undo() -> bool:
	return not _undo_history.is_empty()

func undo_label() -> String:
	return str(_undo_history.back().action) if can_undo() else ""

func undo() -> Dictionary:
	if not can_undo() or world==null or plant==null: return {"ok":false,"action":"","message":"There is no garden action to undo."}
	var before: float=float(world.time)
	var record: Dictionary=_undo_history.pop_back()
	finish_lure_move()
	for field: String in WORLD_FIELDS: world.set(field,_copy(record.world[field]))
	for field: String in PLANT_FIELDS: plant.set(field,_copy(record.plant[field]))
	plant.rng.seed=int(record.rng_seed)
	plant.rng.state=int(record.rng_state)
	plant.world=world
	for specimen in wild_sims: specimen.world=world
	lures_left=int(record.lures_left)
	prunes_left=int(record.prunes_left)
	tools_used=int(record.tools_used)
	idle_time=float(record.idle_time)
	return {"ok":true,"action":str(record.action),"kind":str(record.kind),"rewound_seconds":maxf(0.0,before-float(world.time)),"lures_left":lures_left,"prunes_left":prunes_left,"tools_used":tools_used}

func won() -> bool:
	return world.all_goals_reached()

func stuck() -> bool:
	return not won() and idle_time > 1.5


func dew_total() -> int:
	return world.dews.size()

func dew_taken() -> int:
	var n := 0
	for d in world.dews:
		if d.taken: n += 1
	return n

## [bloomed, all dew, within tool par]
func stars() -> Array:
	var par: int = int(def.get("par", 99))
	return [won(), dew_taken() == dew_total(), tools_used <= par]
