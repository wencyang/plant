extends RefCounted
## Real-time growth. A plant is a tree of nodes grown by tips (meristems).
## Tips bend toward light, lean on rock, branch, stall in darkness, wilt when
## they reach too far into open air, and spend energy as they grow.

const SEG := 9.0
const MAX_TIPS := 26
const SUPPORT_DIST := 18.0

var genome: Dictionary
var world
var wild := false
var rng := RandomNumberGenerator.new()

var pos := PackedVector2Array()
var parent := PackedInt32Array()
var born := PackedFloat32Array()
var desc := PackedInt32Array()
var kind := PackedByteArray()     # 0 shoot, 1 root
var alive := PackedByteArray()
var children: Array = []
var tips: Array = []              # {node, dir, seg, since, unsupported, kind, state}
var blooms: Array = []            # node indices with flowers
var fruits: Array = []            # node indices carrying fruit

var energy := 0.0
var energy_max := 0.0
var grown := 0.0
var time := 0.0
var events: Array = []

func setup(g: Dictionary, w, start_energy: float, seed_value: int, is_wild := false) -> void:
	genome = g
	world = w
	wild = is_wild
	rng.seed = seed_value
	energy = start_energy * float(g.get("vigor", 1.0))
	energy_max = energy
	var root := _add_node(w.seed_pos if not is_wild else Vector2.ZERO, -1, 0)
	_spawn_tip(root, Vector2.UP, 0)
	if int(g.roots) > 0:
		_spawn_tip(root, Vector2(-0.6, 1).normalized(), 1)
		_spawn_tip(root, Vector2(0.0, 1).normalized(), 1)
		_spawn_tip(root, Vector2(0.6, 1).normalized(), 1)

func place_at(p: Vector2) -> void:
	pos[0] = p
	for t in tips: pos[t.node] = p

func _add_node(p: Vector2, par: int, k: int) -> int:
	var i := pos.size()
	pos.append(p)
	parent.append(par)
	born.append(time)
	desc.append(0)
	kind.append(k)
	alive.append(1)
	children.append([])
	if par >= 0:
		children[par].append(i)
		var a := par
		while a >= 0:
			desc[a] += 1
			a = parent[a]
	return i

func _spawn_tip(from_node: int, dir: Vector2, k: int, unsupported := 0.0, rank := 0) -> void:
	var n := _add_node(pos[from_node], from_node, k)
	tips.append({"node": n, "dir": dir.normalized(), "seg": 0.0, "since": 0.0, "unsupported": unsupported, "kind": k, "state": "grow", "rank": rank, "len": 0.0})

const RANK_SPEED := [1.0, 0.55, 0.35]
const RANK_MAX_LEN := [100000.0, 150.0, 60.0]

## When a leader stops, the longest healthy side shoot takes over.
func _promote() -> void:
	for t in tips:
		if t.kind == 0 and t.rank == 0 and t.state != "stopped": return
	var best = null
	for t in tips:
		if t.kind == 0 and t.state == "grow" and (best == null or t.rank < best.rank or (t.rank == best.rank and t.len > best.len)):
			best = t
	if best != null:
		best.rank = 0

func _stop(tip: Dictionary, why: String, p: Vector2) -> void:
	tip.state = "stopped"
	tip.why = why
	if tip.kind == 0 and not wild:
		events.append({"t": "stop", "why": why, "pos": p, "leader": int(tip.get("rank", 0)) == 0})

func hit_this_frame(tip: Dictionary, _p: Vector2) -> bool:
	return float(tip.get("commit", 0.0)) > 0.3

## How far a node hangs in open air, measured back along the stem to support.
func _unsupported_at(node: int) -> float:
	if wild or world == null: return 0.0
	var dist := 0.0
	var n := node
	var guard := 0
	while n > 0 and guard < 120:
		if world.near_support(pos[n], SUPPORT_DIST, int(genome.tendrils) > 0): return dist
		dist += pos[n].distance_to(pos[parent[n]])
		n = parent[n]
		guard += 1
	return dist

func active_tips() -> int:
	var n := 0
	for t in tips:
		var node: int = int(t.get("node", -1))
		# A cut marks its descendants dead before the final tips-list cleanup.
		# Their newly freed capacity must be available to the replacement shoots.
		if node < 0 or node >= alive.size() or alive[node] == 0: continue
		if t.state == "grow" or t.state == "stalled": n += 1
	return n

func is_growing() -> bool:
	var drinking := false
	for t in tips:
		if t.state == "drinking": drinking = true
	for t in tips:
		if t.state == "grow" and (t.kind == 1 or energy > 0.0 or drinking): return true
	return false

func step(dt: float) -> void:
	time += dt
	if not wild: _promote()
	var speed: float = float(genome.speed)
	var photo: float = float(genome.photo)
	var curl: float = float(genome.curl)
	var reach: float = float(genome.reach) * (2.3 if int(genome.get("buoyant", 0)) > 0 else 1.0)
	var waxy := int(genome.get("waxy", 0)) > 0
	var tendrils := int(genome.tendrils) > 0
	var thorns := int(genome.thorns) > 0
	var glow := int(genome.glow) > 0
	var branch_every: float = lerpf(210.0, 50.0, float(genome.branch)) * (0.55 if wild else 1.0)
	var lights: Array = [] if wild else world.lights()
	var count := tips.size()
	var drinking := 0
	for ti in count:
		var tip: Dictionary = tips[ti]
		if tip.state == "stopped": continue
		if tip.state == "drinking":
			drinking += 1
			if drinking <= 3: energy += 75.0 * dt
			continue
		var k: int = tip.kind
		if k == 0 and energy <= 0.0: continue
		var p: Vector2 = pos[tip.node]
		# darkness
		if k == 0 and not wild and not glow and world.in_dark(p) and not world.lure_near(p):
			tip.state = "stalled"
			continue
		if tip.state == "stalled": tip.state = "grow"
		if k == 1 and not wild and world.in_water(p):
			tip.state = "drinking"
			drinking += 1
			if drinking <= 3: energy += 75.0 * dt
			if rng.randf() < dt * 2.0: events.append({"t": "drink", "pos": p})
			continue
		# steering
		var desire := Vector2.DOWN
		if k == 0:
			var visited: Array = tip.get("visited", [])
			var lured := false
			for l in lights:
				if l.has("lure") and not visited.has(l.pos) and l.pos.distance_to(p) < 1000.0: lured = true
			desire = Vector2.UP * (0.05 if lured else 0.3)
			for l in lights:
				if l.has("lure") and visited.has(l.pos): continue
				var d: Vector2 = l.pos - p
				var dist := d.length()
				if l.has("lure") and dist < 60.0:
					visited = visited.duplicate()
					visited.append(l.pos)
					tip.visited = visited
					continue
				if dist > 1.0 and dist < l.r:
					var f: float = float(l.s) * (1.0 - dist / float(l.r)) * 2.0
					if l.has("near"): f *= clampf((dist - 40.0) / float(l.near), 0.0, 1.0)
					if l.has("close") and dist < float(l.close): f += 5.0 * (1.0 - dist / float(l.close))
					desire += d / dist * f
			desire = desire.normalized()
			var commit: float = tip.get("commit", 0.0)
			var in_draft: bool = (not wild) and world.updraft_at(p) != null
			if commit > 0.0:
				tip.commit = commit - dt
			elif not in_draft:
				tip.dir = tip.dir.lerp(desire, clampf(photo * 1.5 * dt, 0.0, 1.0)).normalized()
			tip.dir = tip.dir.rotated(curl * 0.8 * dt + rng.randf_range(-0.9, 0.9) * dt)
			if not wild:
				var ud = world.updraft_at(p)
				if ud != null:
					tip.dir = tip.dir.lerp(ud.dir, clampf(6.0 * dt, 0.0, 1.0)).normalized()
					tip.unsupported = 0.0
					tip.carried = true
				else:
					tip.carried = false
		else:
			var target := Vector2.DOWN
			if not wild and not world.waters.is_empty():
				var w: Vector2 = world.nearest_water(p)
				if w != Vector2.INF: target = (w - p).normalized() + Vector2.DOWN * 0.3
			tip.dir = tip.dir.lerp(target.normalized(), clampf(1.2 * dt, 0.0, 1.0)).normalized()
			tip.dir = tip.dir.rotated(rng.randf_range(-1.5, 1.5) * dt)
		var rank: int = int(tip.get("rank", 0))
		var step_len: float = speed * dt * (0.55 if k == 1 else RANK_SPEED[min(rank, 2)])
		var np: Vector2 = p + tip.dir * step_len
		if not wild:
			var hit: Dictionary = world.blocked(p, np, k)
			if hit.hit:
				if hit.kind == "crystal" and thorns and k == 0:
					world.crystals[hit.index].alive = false
					events.append({"t": "crystal", "i": hit.index, "pos": np})
				else:
					var resolved := false
					if hit.kind != "slick" or tendrils:
						# Smallest turn away from where we want to go, preferring the
						# side we were already going round (wall-following).
						var base: Vector2 = desire if k == 0 else tip.dir
						var side: float = float(tip.get("side", 1.0 if rng.randf() < 0.5 else -1.0))
						for step_i in range(1, 12):
							var off := 0.28 * step_i
							for sgn in [side, -side]:
								var c: Vector2 = base.rotated(off * sgn)
								var q: Vector2 = p + c * step_len
								if not world.blocked(p, q, k).hit:
									tip.dir = c
									tip.side = sgn
									np = q
									resolved = true
									tip.commit = 0.2
									tip.unsupported = 0.0
									break
							if resolved: break
					if not resolved:
						_stop(tip, "slick" if hit.kind == "slick" else "blocked", p)
						continue
			if k == 0 and not waxy and world.in_vent(np):
				_stop(tip, "burn", np)
				continue
			if not world.bounds.grow(-6).has_point(np):
				_stop(tip, "edge", p)
				continue
			if k == 0:
				if world.near_support(np, SUPPORT_DIST, tendrils):
					if tip.unsupported > reach * 0.35: events.append({"t": "lean", "pos": np})
					tip.unsupported = 0.0
				elif not tip.get("carried", false): tip.unsupported += step_len
				tip.reach_frac = clampf(1.0 - tip.unsupported / reach, 0.0, 1.0)
				if tip.unsupported > reach:
					_stop(tip, "droop", np)
					continue
		# a tip that hasn't made headway in a while gives up (saves energy)
		var anchor: Vector2 = tip.get("anchor", p)
		tip.anchor_t = float(tip.get("anchor_t", 0.0)) + dt
		if tip.anchor_t > 2.5:
			if p.distance_to(anchor) < speed * 0.5:
				_stop(tip, "stuck", p)
				continue
			tip.anchor = p
			tip.anchor_t = 0.0
		elif not tip.has("anchor"):
			tip.anchor = p
		tip.len = float(tip.get("len", 0.0)) + step_len
		if k == 0 and tip.len > RANK_MAX_LEN[min(rank, 2)]:
			tip.state = "stopped"
			tip.why = "done"
			continue
		# advance
		tip.seg += step_len
		if tip.seg >= SEG:
			tip.node = _add_node(np, tip.node, k)
			tip.seg = 0.0
		else:
			pos[tip.node] = np
		grown += step_len
		if k == 0: energy -= step_len
		else: energy -= step_len * 0.25
		# branching
		tip.since += step_len
		if k == 0 and rank < 2 and tip.since > branch_every * (1.0 + rank * 0.6) and rng.randf() < 0.6 and active_tips() < MAX_TIPS:
			tip.since = 0.0
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			_spawn_tip(tip.node, tip.dir.rotated(side * float(genome.spread)), 0, tip.unsupported, rank + 1)
			tips.back().visited = tip.get("visited", [])
			tips.back().side = side
			tip.dir = tip.dir.rotated(-side * float(genome.spread) * 0.35)
		elif k == 1 and tip.since > 140.0 and active_tips() < MAX_TIPS + 6 and rng.randf() < 0.5:
			tip.since = 0.0
			_spawn_tip(tip.node, tip.dir.rotated(rng.randf_range(-0.8, 0.8)), 1)
		if wild: continue
		# interactions
		if k == 0:
			for gi in world.goals.size():
				var g: Dictionary = world.goals[gi]
				if not g.reached and not world.sleeping(g) and np.distance_to(g.pos) < g.r:
					g.reached = true
					energy += float(g.bonus)
					energy_max = max(energy_max, energy)
					blooms.append(tip.node)
					events.append({"t": "goal", "i": gi, "pos": g.pos})
			for di in world.dews.size():
				var dw: Dictionary = world.dews[di]
				if not dw.taken and np.distance_to(dw.pos) < 30.0:
					dw.taken = true
					energy += float(dw.sap)
					energy_max = max(energy_max, energy)
					events.append({"t": "dew", "i": di, "pos": dw.pos})
			for si in world.switches.size():
				var sw: Dictionary = world.switches[si]
				if not sw.on and np.distance_to(sw.pos) < 46.0:
					sw.on = true
					var opened: Array = world.open_gates(sw.opens)
					events.append({"t": "switch", "i": si, "pos": sw.pos, "opened": opened})
			for wi in world.wilds.size():
				var w: Dictionary = world.wilds[wi]
				if w.pollinated: continue
				for wp in w.nodes:
					if np.distance_squared_to(wp) < 3000.0:
						w.pollinated = true
						fruits.append(tip.node)
						events.append({"t": "pollinate", "i": wi, "pos": np})
						break

## Shared hit query: roots, detached growth and zero-length fresh tips are not
## swipe targets. Preview and the actual cut use the exact same geometry.
func _prune_hits(a: Vector2, b: Vector2) -> Array:
	var hits: Array = []
	for i in range(1, pos.size()):
		if alive[i] == 0 or kind[i] != 0 or parent[i] < 0: continue
		if pos[parent[i]].distance_to(pos[i]) < 0.5: continue
		if Geometry2D.segment_intersects_segment(a, b, pos[parent[i]], pos[i]) != null:
			hits.append(i)
	return hits

## Clone only plant data. The world is shared for read-only support queries;
## prune never updates it. Separate packed arrays, dictionaries and RNG keep a
## preview from affecting this plant, its event queue or future growth rolls.
func _prune_preview_copy():
	var copy = get_script().new()
	copy.genome = genome.duplicate(true)
	copy.world = world
	copy.wild = wild
	copy.rng.seed = rng.seed
	copy.rng.state = rng.state
	for key in ["pos", "parent", "born", "desc", "kind", "alive"]:
		copy.set(key, get(key).duplicate())
	for key in ["children", "tips", "blooms", "fruits", "events"]:
		copy.set(key, get(key).duplicate(true))
	copy.energy = energy
	copy.energy_max = energy_max
	copy.grown = grown
	copy.time = time
	return copy

## Pure, exact for the currently paused tree. A curved path is evaluated in
## order exactly like Session.prune_path: a later piece may cut an earlier
## anchor and remove the fresh zero-length tips that it had just created.
## removed_node_ids/removed_segments describe ORIGINAL live growth. Temporary
## tips created and removed inside this preview are reported separately in
## all_removed_node_ids/all_removed_segments for diagnostic comparisons.
func preview_prune_path(points: Array) -> Dictionary:
	var out := {"valid": true, "has_hits": false, "cuts": [], "cut_positions": PackedVector2Array(),
		"crossed_node_ids": [], "removed_node_ids": [], "removed_segments": [], "visible_segment_count": 0,
		"all_removed_node_ids": [], "all_removed_segments": [], "sap_refund": 0.0,
		"new_shoots": 0, "new_shoot_positions": [], "new_shoot_directions": [], "exact_when_paused": true}
	if points.size() < 2: return out
	for point in points:
		if not point is Vector2 or not point.is_finite():
			out.valid = false
			return out
	var copy = _prune_preview_copy()
	var original_count: int = pos.size()
	var original_seen := {}
	var all_seen := {}
	var crossed_seen := {}
	for path_segment in range(points.size() - 1):
		var a: Vector2 = points[path_segment]
		var b: Vector2 = points[path_segment + 1]
		# The real cut records which roots were cut and which shoots it actually
		# spawned after freeing capacity. Preview has no second capacity model.
		var removed: Array = copy.prune(a, b)
		if removed.is_empty(): continue
		var actual_cut: Dictionary = copy.events.back()
		for node_id in actual_cut.get("crossed_node_ids", []):
			if int(node_id) < original_count and not crossed_seen.has(node_id):
				crossed_seen[node_id] = true
				out.crossed_node_ids.append(node_id)
		for segment in removed:
			var node_id: int = int(segment[2])
			if not all_seen.has(node_id):
				all_seen[node_id] = true
				out.all_removed_node_ids.append(node_id)
				out.all_removed_segments.append(segment.duplicate())
			if node_id >= original_count or int(alive[node_id]) == 0 or original_seen.has(node_id): continue
			original_seen[node_id] = true
			out.removed_node_ids.append(node_id)
			out.removed_segments.append(segment.duplicate())
			if segment[0].distance_to(segment[1]) >= 0.5: out.visible_segment_count += 1
		for record: Dictionary in actual_cut.get("cuts", []):
			var cut: Dictionary = record.duplicate(true)
			cut.path_segment = path_segment
			# A later curve piece may still remove this new pair. Final survivors
			# are filled below using the actual copied tree's live-node flags.
			cut.directions = []
			cut.new_shoots = 0
			out.cuts.append(cut)
			out.cut_positions.append(cut.position)
	out.sap_refund = maxf(0.0, float(copy.energy) - energy)
	for cut: Dictionary in out.cuts:
		cut.survives = int(copy.alive[int(cut.parent_id)]) == 1
		for index in range(cut.spawned_node_ids.size()):
			var node_id: int = int(cut.spawned_node_ids[index])
			if node_id >= copy.alive.size() or int(copy.alive[node_id]) == 0: continue
			var direction: Vector2 = cut.planned_directions[index]
			cut.directions.append(direction)
			cut.new_shoots += 1
			out.new_shoots += 1
			out.new_shoot_positions.append(copy.pos[node_id])
			out.new_shoot_directions.append(direction)
	out.has_hits = not out.removed_node_ids.is_empty()
	return out

## Cut every stem segment crossing a→b. Returns removed segments for debris.
func prune(a: Vector2, b: Vector2) -> Array:
	var removed: Array = []
	var hits: Array = _prune_hits(a, b)
	if hits.is_empty(): return removed
	var dead := {}
	var cut_records: Array = []
	for h in hits:
		if dead.has(h): continue
		var stack := [h]
		var refund := 0.0
		while not stack.is_empty():
			var n: int = stack.pop_back()
			if dead.has(n): continue
			dead[n] = true
			alive[n] = 0
			removed.append([pos[parent[n]], pos[n], n])
			refund += pos[parent[n]].distance_to(pos[n])
			for c in children[n]: stack.append(c)
		var a_node := parent[h]
		var lost := desc[h] + 1
		var up := a_node
		while up >= 0:
			desc[up] -= lost
			up = parent[up]
		children[a_node].erase(h)
		energy += refund * 0.6
		# pruning wakes two fresh shoots at the cut
		var base_dir := (pos[h] - pos[a_node]).normalized()
		if base_dir == Vector2.ZERO: base_dir = Vector2.UP
		var spread: float = max(0.45, float(genome.spread))
		var spawned: Array = []
		var directions: Array = []
		for side in [-1.0, 1.0]:
			if active_tips() < MAX_TIPS:
				_spawn_tip(a_node, base_dir.rotated(side * spread), 0, _unsupported_at(a_node))
				tips.back().side = side
				spawned.append(int(tips.back().node))
				directions.append(tips.back().dir)
		var crossing: Variant = Geometry2D.segment_intersects_segment(a, b, pos[a_node], pos[h])
		cut_records.append({"node_id": int(h), "parent_id": int(a_node),
			"position": crossing if crossing is Vector2 else (pos[a_node] + pos[h]) * 0.5,
			"anchor": pos[a_node], "base_direction": base_dir, "directions": directions.duplicate(),
			"planned_directions": directions, "spawned_node_ids": spawned, "spawned_shoots": spawned.size(),
			"new_shoots": spawned.size(), "survives": true})
	tips = tips.filter(func(t): return alive[t.node] == 1)
	blooms = blooms.filter(func(n): return alive[n] == 1)
	fruits = fruits.filter(func(n): return alive[n] == 1)
	events.append({"t": "prune", "count": removed.size(), "crossed_node_ids": hits, "cuts": cut_records})
	return removed

## Grow a wild plant in place (no interactions), for decoration + pollination.
func grow_wild(total: float, origin: Vector2) -> void:
	place_at(origin)
	var guard := 0
	while energy > 0.0 and guard < 4000 and is_growing():
		step(1.0 / 30.0)
		guard += 1
