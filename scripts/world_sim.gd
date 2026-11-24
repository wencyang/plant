extends RefCounted
## The physical puzzle world: rock, crystal, darkness, water, sunwells, lures
## and wild plants. Pure data + geometry queries (no rendering).

var bounds := Rect2(0, 0, 1600, 1000)
var rocks: Array = []     # {poly, aabb, slick, soil}
var crystals: Array = []  # {poly, aabb, alive}
var goals: Array = []     # {pos, r, bonus, reached}
var darks: Array = []     # {pos, r}
var waters: Array = []    # Rect2
var wilds: Array = []     # {pos, genome, pollinated, nodes: PackedVector2Array}
var lures: Array = []     # Vector2
var seed_pos := Vector2(800, 860)

const LURE_LIGHT := 250.0

func load_level(def: Dictionary) -> void:
	rocks.clear()
	crystals.clear()
	goals.clear()
	darks.clear()
	waters.clear()
	wilds.clear()
	lures.clear()
	seed_pos = def.seed
	for r in def.get("rocks", []):
		var poly := PackedVector2Array(r.poly)
		rocks.append({"poly": poly, "aabb": _aabb(poly), "slick": r.get("slick", false), "soil": r.get("soil", false)})
	for c in def.get("crystals", []):
		var poly := PackedVector2Array(c)
		crystals.append({"poly": poly, "aabb": _aabb(poly), "alive": true})
	for g in def.get("goals", []):
		goals.append({"pos": g.pos, "r": g.get("r", 42.0), "bonus": g.get("bonus", 500.0), "reached": false})
	for d in def.get("darks", []):
		darks.append({"pos": d.pos, "r": d.r})
	for w in def.get("waters", []):
		waters.append(w)
	for w in def.get("wilds", []):
		wilds.append({"pos": w.pos, "genome": w.genome, "pollinated": false, "nodes": PackedVector2Array(), "energy": w.get("energy", 260.0)})

func _aabb(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly: r = r.expand(p)
	return r

## Segment a→b against solid geometry. kind 0 = shoot, 1 = root.
func blocked(a: Vector2, b: Vector2, kind := 0) -> Dictionary:
	var seg := Rect2(a, Vector2.ZERO).expand(b).grow(2)
	for i in crystals.size():
		var c: Dictionary = crystals[i]
		if c.alive and c.aabb.intersects(seg) and _hits(c.poly, a, b):
			return _result("crystal", i, c.poly, b)
	for i in rocks.size():
		var r: Dictionary = rocks[i]
		if kind == 1 and r.soil: continue
		if r.aabb.intersects(seg) and _hits(r.poly, a, b):
			return _result("slick" if r.slick else "rock", i, r.poly, b)
	return {"hit": false}

func _hits(poly: PackedVector2Array, a: Vector2, b: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(b, poly): return true
	var n := poly.size()
	for i in n:
		if Geometry2D.segment_intersects_segment(a, b, poly[i], poly[(i + 1) % n]) != null: return true
	return false

func _result(kind: String, index: int, poly: PackedVector2Array, p: Vector2) -> Dictionary:
	var best := INF
	var tangent := Vector2.RIGHT
	var n := poly.size()
	for i in n:
		var e0 := poly[i]
		var e1 := poly[(i + 1) % n]
		var q := Geometry2D.get_closest_point_to_segment(p, e0, e1)
		var d := q.distance_squared_to(p)
		if d < best:
			best = d
			tangent = (e1 - e0).normalized()
	return {"hit": true, "kind": kind, "index": index, "tangent": tangent}

## Is p close to something a stem can lean on?
func near_support(p: Vector2, dist: float, include_slick: bool) -> bool:
	var probe := Rect2(p, Vector2.ZERO).grow(dist)
	for r in rocks:
		if r.slick and not include_slick: continue
		if r.aabb.intersects(probe) and _poly_dist(r.poly, p) < dist: return true
	for c in crystals:
		if c.alive and c.aabb.intersects(probe) and _poly_dist(c.poly, p) < dist: return true
	return false

func _poly_dist(poly: PackedVector2Array, p: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(p, poly): return 0.0
	var best := INF
	var n := poly.size()
	for i in n:
		best = min(best, Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % n]).distance_to(p))
	return best

func in_dark(p: Vector2) -> bool:
	for d in darks:
		if p.distance_to(d.pos) < d.r: return true
	return false

func lure_near(p: Vector2, dist := LURE_LIGHT) -> bool:
	for l in lures:
		if p.distance_to(l) < dist: return true
	return false

func in_water(p: Vector2) -> bool:
	for w in waters:
		if w.has_point(p): return true
	return false

func nearest_water(p: Vector2) -> Vector2:
	var best := Vector2.INF
	for w in waters:
		var c: Vector2 = w.get_center()
		var q := Vector2(clampf(p.x, w.position.x, w.end.x), clampf(p.y, w.position.y, w.end.y))
		if best == Vector2.INF or q.distance_to(p) < best.distance_to(p): best = q
	return best

## Light sources that attract shoots: lures (strong), unreached sunwells.
func lights() -> Array:
	var out: Array = []
	for i in lures.size(): out.append({"pos": lures[i], "s": 3.0, "r": 1600.0, "near": 140.0, "lure": i})
	for g in goals:
		if not g.reached: out.append({"pos": g.pos, "s": 1.1, "r": 2400.0, "close": 380.0})
	return out

func all_goals_reached() -> bool:
	for g in goals:
		if not g.reached: return false
	return not goals.is_empty()
