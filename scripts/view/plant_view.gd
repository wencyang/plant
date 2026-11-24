extends Node2D
## Renders a living PlantSim as a luminous alien plant. Every gene is visible:
## leaf shape, flower form & petal count, two colours, pattern, stem style,
## and trait organs (thorns, glow bulbs, tendrils, roots). Hybrids therefore
## visibly wear features from both parents.

const Genome := preload("res://scripts/genome.gd")

var sim = null
var t := 0.0
var bloom_all := false        # wild plants / previews: every resting tip flowers
var preview := false
var flower_open: Dictionary = {}   # node -> 0..1
var big_flowers: Dictionary = {}   # goal blooms
var fruit_grow: Dictionary = {}
var sway_amount := 1.0
var highlight := 0.0
var emissive := 1.0

var c_stem_base: Color
var c_stem_tip: Color
var c_leaf_a: Color
var c_leaf_b: Color
var c_petal: Color
var c_petal_dark: Color
var c_center: Color
var c_root: Color
var glow := false
var g: Dictionary

func setup(s, is_wild := false) -> void:
	sim = s
	bloom_all = is_wild
	g = s.genome
	var h: float = float(g.hue)
	var h2: float = float(g.hue2)
	glow = int(g.glow) > 0
	c_stem_base = Color.from_hsv(h, 0.55, 0.30)
	c_stem_tip = Color.from_hsv(wrapf(h + 0.03, 0, 1), 0.55, 0.88)
	c_leaf_a = Color.from_hsv(h, 0.7, 0.42)
	c_leaf_b = Color.from_hsv(wrapf(h + 0.06, 0, 1), 0.5, 0.98)
	c_petal = Color.from_hsv(h2, 0.62, 1.0)
	c_petal_dark = Color.from_hsv(wrapf(h2 - 0.03, 0, 1), 0.85, 0.55)
	c_center = Color.from_hsv(wrapf(h2 + 0.45, 0, 1), 0.45, 1.0)
	c_root = Color.from_hsv(0.09, 0.28, 0.78)
	emissive = 1.35 if glow else 1.0

func _hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

func _hash(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x % 10000) / 10000.0

func _process(delta: float) -> void:
	t += delta
	if sim == null: return
	# flowers open on resting shoot tips
	for tip in sim.tips:
		if tip.kind != 0: continue
		var n: int = tip.node
		if sim.alive[n] == 0: continue
		var resting: bool = tip.state == "stopped" or bloom_all
		if resting:
			flower_open[n] = min(1.0, float(flower_open.get(n, 0.0)) + delta * (0.6 if not bloom_all else 10.0))
	for n in sim.blooms:
		big_flowers[n] = min(1.0, float(big_flowers.get(n, 0.0)) + delta * 0.9)
	for n in sim.fruits:
		fruit_grow[n] = min(1.0, float(fruit_grow.get(n, 0.0)) + delta * 0.7)
	highlight = max(0.0, highlight - delta * 1.5)
	queue_redraw()

func P(n: int) -> Vector2:
	var p: Vector2 = sim.pos[n]
	if sway_amount <= 0.0: return p
	var base: Vector2 = sim.pos[0]
	var lift: float = clampf((base.y - p.y) / 500.0, 0.0, 1.0)
	return p + Vector2(sin(t * 1.1 + p.y * 0.012 + p.x * 0.004) * 4.0 * lift * sway_amount, 0)

func _age(n: int) -> float:
	return clampf((sim.time - sim.born[n]) / 1.4, 0.0, 1.0) if not bloom_all else 1.0

func _width(n: int) -> float:
	var w := 1.4 + 1.05 * sqrt(float(sim.desc[n]) + 1.0)
	if sim.kind[n] == 1: w *= 0.55
	return min(w, 15.0) * (0.35 + 0.65 * _age(n))

# =================================================================== draw

func _draw() -> void:
	if sim == null: return
	var count: int = sim.pos.size()
	var stem_style: int = int(g.stem)
	# glow underlay
	if glow:
		for n in range(1, count):
			if sim.alive[n] == 0 or sim.kind[n] != 0: continue
			var par: int = sim.parent[n]
			draw_line(P(par), P(n), _hdr(Color(c_stem_tip, 0.05), 1.4), _width(n) * 1.6 + 5.0, true)
	# roots first
	for n in range(1, count):
		if sim.alive[n] == 0 or sim.kind[n] != 1: continue
		var par: int = sim.parent[n]
		var a := P(par)
		var b := P(n)
		draw_line(a, b, c_root.darkened(0.2), _width(n) + 1.5, true)
		draw_line(a, b, c_root, _width(n), true)
		if n % 4 == 0:
			var dir := (b - a).normalized()
			draw_line(b, b + dir.rotated(0.9) * 7.0, Color(c_root, 0.6), 1.0, true)
			draw_line(b, b + dir.rotated(-0.9) * 6.0, Color(c_root, 0.6), 1.0, true)
	# stems as tapered quads with gradient
	for n in range(1, count):
		if sim.alive[n] == 0 or sim.kind[n] != 0: continue
		var par: int = sim.parent[n]
		var a := P(par)
		var b := P(n)
		if a.distance_squared_to(b) < 0.25: continue
		var wa := _width(par) if sim.kind[par] == 0 else _width(n)
		var wb := _width(n)
		var dir := (b - a).normalized()
		var nrm := dir.orthogonal()
		var ca := c_stem_base.lerp(c_stem_tip, 1.0 / (1.0 + float(sim.desc[par]) * 0.06))
		var cb := c_stem_base.lerp(c_stem_tip, 1.0 / (1.0 + float(sim.desc[n]) * 0.06))
		var shade := 0.72
		draw_polygon(PackedVector2Array([a + nrm * wa * 0.5, b + nrm * wb * 0.5, b - nrm * wb * 0.5, a - nrm * wa * 0.5]),
			PackedColorArray([ca, cb, Color(cb.r * shade, cb.g * shade, cb.b * shade), Color(ca.r * shade, ca.g * shade, ca.b * shade)]))
		draw_circle(b, wb * 0.5, cb)
		# rim light on one side
		draw_line(a + nrm * wa * 0.32, b + nrm * wb * 0.32, Color(1, 1, 1, 0.13), max(1.0, wb * 0.18), true)
		match stem_style:
			1:
				if n % 4 == 0:
					draw_line(b + nrm * wb * 0.62, b - nrm * wb * 0.62, c_stem_base.darkened(0.3), 2.0, true)
					draw_line(b + nrm * wb * 0.55 - dir * 2.0, b - nrm * wb * 0.55 - dir * 2.0, Color(1, 1, 1, 0.25), 1.0, true)
			2:
				var tw := sin(float(n) * 0.9 + t * 0.6) * wb * 0.35
				draw_line(a + nrm * tw, b + nrm * sin(float(n + 1) * 0.9 + t * 0.6) * wb * 0.35, Color(c_leaf_b, 0.45), max(1.0, wb * 0.2), true)
		var pattern: int = int(g.pattern)
		if pattern == 2 and n % 5 == 0 and wb > 3.0:
			draw_circle(b, wb * 0.22, _hdr(c_petal, 1.2 * emissive))
		elif pattern == 3 and glow:
			draw_line(a, b, _hdr(Color(c_leaf_b, 0.5), 2.4), 1.0, true)
	# organs along stems
	var thorns := int(g.thorns) > 0
	var tendrils := int(g.tendrils) > 0
	for n in range(2, count):
		if sim.alive[n] == 0 or sim.kind[n] != 0: continue
		var par: int = sim.parent[n]
		var a := P(par)
		var b := P(n)
		var dir := (b - a).normalized()
		if dir == Vector2.ZERO: continue
		var age := _age(n)
		if thorns and n % 3 == 0 and age > 0.2:
			var side := 1.0 if n % 2 == 0 else -1.0
			var w := _width(n) * 0.5
			var base := a.lerp(b, 0.5) + dir.orthogonal() * side * w
			var tip := base + (dir.orthogonal() * side * 0.8 + dir * 0.6).normalized() * (7.0 + w) * age
			draw_colored_polygon(PackedVector2Array([base - dir * 3.0, tip, base + dir * 2.0]), Color.from_hsv(wrapf(float(g.hue) - 0.06, 0, 1), 0.6, 0.35))
			draw_circle(tip, 1.2, _hdr(Color(1.0, 0.55, 0.45), 1.6))
		if tendrils and n % 7 == 3:
			var side := 1.0 if (n / 7) % 2 == 0 else -1.0
			var pts := PackedVector2Array()
			var start := b
			var ang := dir.angle() + side * 1.2
			var r := 9.0 * age
			for i in 16:
				var u := i / 15.0
				ang += side * (0.35 + u * 0.5)
				start += Vector2(cos(ang), sin(ang)) * r * 0.32 * (1.0 - u * 0.6)
				pts.append(start)
			draw_polyline(pts, Color.from_hsv(wrapf(float(g.hue) + 0.08, 0, 1), 0.55, 0.85), 1.6, true)
		# leaves
		_maybe_leaf(n, a, b, dir, age)
		if glow and n % 9 == 5:
			var hang := b + Vector2(0, 9) * age
			draw_line(b, hang, Color(c_stem_tip, 0.6), 1.0, true)
			var pulse := 0.8 + 0.4 * sin(t * 2.0 + n)
			draw_circle(hang, 6.0 * age, Color(c_petal, 0.12))
			draw_circle(hang, 3.0 * age, _hdr(c_petal, 1.7 * pulse))
	# fruits from pollination
	for n in fruit_grow:
		if n >= count or sim.alive[n] == 0: continue
		_fruit(P(n), float(fruit_grow[n]))
	# flowers
	for n in flower_open:
		if n >= count or sim.alive[n] == 0: continue
		var par: int = sim.parent[n]
		var dir := (P(n) - P(par)).normalized() if par >= 0 else Vector2.UP
		_flower(P(n), dir, float(flower_open[n]), 1.0, n)
	for n in big_flowers:
		if n >= count or sim.alive[n] == 0: continue
		_flower(P(n), Vector2.UP, float(big_flowers[n]), 2.4, n)
	# growing tips: luminous meristems
	for tip in sim.tips:
		var n: int = tip.node
		if n >= count or sim.alive[n] == 0: continue
		var p := P(n)
		if tip.kind == 1:
			if tip.state == "drinking":
				draw_circle(p, 6.0, _hdr(Color(0.4, 0.8, 1.0, 0.35), 2.0))
				draw_circle(p, 2.5, _hdr(Color(0.6, 0.9, 1.0), 2.5))
			continue
		if tip.state == "grow" and (sim.energy > 0.0 or preview):
			var pulse := 0.75 + 0.25 * sin(t * 6.0 + n)
			draw_circle(p, 6.0, Color(c_stem_tip, 0.18))
			draw_circle(p, 2.8, _hdr(c_stem_tip.lightened(0.4), 1.8 * pulse * emissive))
		elif tip.state == "stalled":
			draw_circle(p, 3.0, Color(c_stem_tip, 0.35))

func _maybe_leaf(n: int, a: Vector2, b: Vector2, dir: Vector2, age: float) -> void:
	var shape: int = int(g.leaf_shape)
	var every := 3
	if shape == 2: every = 4
	elif shape == 3: every = 2
	if n % every != 0: return
	var hsh := _hash(n)
	var side := 1.0 if (n / every) % 2 == 0 else -1.0
	var sway := sin(t * 1.4 + n * 0.7) * 0.1
	var ang := dir.angle() + side * (0.85 + hsh * 0.35) + sway
	var size: float = 31.0 * float(g.leaf_size) * (0.75 + hsh * 0.5) * age
	if size < 1.5: return
	var base := b
	match shape:
		0: _leaf_blade(base, ang, size, side)
		1: _leaf_fan(base, ang, size * 0.85)
		2: _leaf_frond(base, ang, size * 1.25, age, side)
		3: _leaf_needles(base, ang, size * 0.9)

func _leaf_blade(base: Vector2, ang: float, size: float, _side: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 10
	var w := size * 0.28
	var left: Array = []
	var right: Array = []
	for i in range(n + 1):
		var u := float(i) / n
		var hw := w * sin(PI * pow(u, 0.75)) * (1.0 - 0.25 * u)
		var along := Vector2(size * u, 0)
		left.append([base + (along + Vector2(0, -hw)).rotated(ang), u])
		right.append([base + (along + Vector2(0, hw)).rotated(ang), u])
	right.reverse()
	for e in left + right:
		pts.append(e[0])
		cols.append(c_leaf_a.lerp(c_leaf_b, e[1]))
	draw_polygon(pts, cols)
	var tip := base + Vector2(size, 0).rotated(ang)
	draw_line(base, tip, Color(c_leaf_a.darkened(0.3), 0.7), 1.0, true)
	_leaf_pattern(base, ang, size, w)
	draw_polyline(pts, Color(c_leaf_b.lightened(0.3), 0.35), 1.0, true)

func _leaf_pattern(base: Vector2, ang: float, size: float, w: float) -> void:
	match int(g.pattern):
		1:
			for k in 3:
				var u := 0.3 + k * 0.2
				var c := base + Vector2(size * u, 0).rotated(ang)
				var off := Vector2(0, w * 0.75).rotated(ang)
				draw_line(c - off, c + off, Color(c_petal_dark, 0.55), 2.0, true)
		2:
			for k in 3:
				var u := 0.3 + k * 0.2
				draw_circle(base + Vector2(size * u, (k - 1) * w * 0.3).rotated(ang), w * 0.16, Color(c_petal, 0.85))
		3:
			for k in 4:
				var u := 0.2 + k * 0.18
				var c := base + Vector2(size * u, 0).rotated(ang)
				var col := _hdr(Color(c_leaf_b, 0.8), 1.8 * emissive)
				draw_line(c, c + Vector2(size * 0.14, -w * 0.6).rotated(ang), col, 1.0, true)
				draw_line(c, c + Vector2(size * 0.14, w * 0.6).rotated(ang), col, 1.0, true)

func _leaf_fan(base: Vector2, ang: float, size: float) -> void:
	var pts := PackedVector2Array([base])
	var cols := PackedColorArray([c_leaf_a])
	var spread := 1.25
	for i in range(13):
		var u := float(i) / 12.0
		var a := ang - spread * 0.5 + spread * u
		var notch := 1.0 - 0.22 * exp(-pow((u - 0.5) * 7.0, 2.0))
		var r := size * notch * (1.0 + 0.06 * sin(u * 25.0))
		pts.append(base + Vector2(cos(a), sin(a)) * r)
		cols.append(c_leaf_b)
	draw_polygon(pts, cols)
	for k in 5:
		var a := ang - spread * 0.4 + spread * 0.2 * k
		var col := Color(c_leaf_a.darkened(0.2), 0.6)
		if int(g.pattern) == 3: col = _hdr(Color(c_leaf_b, 0.8), 1.8 * emissive)
		draw_line(base, base + Vector2(cos(a), sin(a)) * size * 0.85, col, 1.0, true)
	if int(g.pattern) == 1:
		draw_arc(base, size * 0.55, ang - spread * 0.45, ang + spread * 0.45, 12, Color(c_petal_dark, 0.6), 2.5, true)
	elif int(g.pattern) == 2:
		for k in 3: draw_circle(base + Vector2(cos(ang + (k - 1) * 0.35), sin(ang + (k - 1) * 0.35)) * size * 0.62, size * 0.07, Color(c_petal, 0.9))
	draw_polyline(pts.slice(1), Color(c_leaf_b.lightened(0.3), 0.4), 1.0, true)

func _leaf_frond(base: Vector2, ang: float, size: float, age: float, side: float) -> void:
	# rachis that unrolls like a fiddlehead while young
	var pts := PackedVector2Array()
	var a := ang
	var p := base
	var n := 12
	for i in range(n + 1):
		pts.append(p)
		var u := float(i) / n
		a += side * (1.0 - age) * u * 0.9 - side * 0.03
		p += Vector2(cos(a), sin(a)) * size / n
	draw_polyline(pts, c_leaf_a, 1.6, true)
	for i in range(1, n):
		var u := float(i) / n
		var q := pts[i]
		var d := (pts[i + 1] - pts[i - 1]).normalized()
		var l := size * 0.32 * (1.0 - u * 0.75) * age
		if l < 1.2: continue
		for sgn in [-1.0, 1.0]:
			var la: float = d.angle() + sgn * 1.05
			var tip := q + Vector2(cos(la), sin(la)) * l
			var mid := q.lerp(tip, 0.5) + d * l * 0.18
			var col := c_leaf_a.lerp(c_leaf_b, u)
			draw_colored_polygon(PackedVector2Array([q, mid + d.orthogonal() * l * 0.12 * sgn, tip, mid - d.orthogonal() * l * 0.12 * sgn]), col)
			if int(g.pattern) == 2 and i % 3 == 0: draw_circle(mid, 1.4, Color(c_petal, 0.9))
			if int(g.pattern) == 3: draw_line(q, tip, _hdr(Color(c_leaf_b, 0.7), 1.6 * emissive), 1.0, true)
		if int(g.pattern) == 1 and i % 3 == 0: draw_circle(q, 1.8, c_petal_dark)

func _leaf_needles(base: Vector2, ang: float, size: float) -> void:
	for k in 5:
		var a := ang + (k - 2) * 0.22
		var tip: Vector2 = base + Vector2(cos(a), sin(a)) * size * (0.75 + 0.25 * (1.0 - abs(k - 2) / 2.0))
		draw_polygon(PackedVector2Array([base + Vector2(cos(a + 1.57), sin(a + 1.57)) * 1.6, tip, base - Vector2(cos(a + 1.57), sin(a + 1.57)) * 1.6]),
			PackedColorArray([c_leaf_a, c_leaf_b, c_leaf_a]))
		if int(g.pattern) == 1: draw_circle(base.lerp(tip, 0.6), 1.5, c_petal_dark)
		elif int(g.pattern) >= 2: draw_circle(tip, 1.4, _hdr(c_petal, 1.4 * emissive))

func _flower(c: Vector2, dir: Vector2, open: float, scale_k: float, seed_n: int) -> void:
	var o := ease(open, -2.2)
	if o <= 0.01: return
	var s := 17.0 * scale_k * o
	if s < 2.5: return
	var petals: int = int(g.petals)
	var form: int = int(g.flower)
	var spin := t * 0.15 * (1.0 if seed_n % 2 == 0 else -1.0)
	# soft halo
	for i in 4:
		draw_circle(c, s * (0.9 + i * 0.45), Color(c_petal, 0.035))
	match form:
		0: # bell, hanging
			var stalk := c + Vector2(0, s * 0.9)
			draw_line(c, stalk, c_stem_tip, 1.5, true)
			var top := stalk
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			pts.append(top + Vector2(-s * 0.35, 0))
			cols.append(c_petal_dark)
			for i in range(petals * 2 + 1):
				var u := float(i) / (petals * 2)
				var x := lerpf(-s * 0.75, s * 0.75, u)
				var lobe := (s * 0.18) if i % 2 == 0 else 0.0
				pts.append(top + Vector2(x, s * 1.25 + lobe))
				cols.append(c_petal)
			pts.append(top + Vector2(s * 0.35, 0))
			cols.append(c_petal_dark)
			draw_polygon(pts, cols)
			draw_circle(top + Vector2(0, s * 1.2), s * 0.28, _hdr(c_center, 1.5 * emissive))
			_petal_pattern_bell(top, s)
		1: # star
			for i in petals:
				var a := TAU * i / petals + spin
				var tip := c + Vector2(cos(a), sin(a)) * s
				var w := Vector2(cos(a + 1.57), sin(a + 1.57)) * s * 0.22
				var mid := c + Vector2(cos(a), sin(a)) * s * 0.45
				draw_polygon(PackedVector2Array([c, mid + w, tip, mid - w]), PackedColorArray([c_petal_dark, c_petal, c_petal.lightened(0.2), c_petal]))
				_petal_pattern(c, a, s)
			draw_circle(c, s * 0.26, _hdr(c_center, 1.5 * emissive))
			for i in 6:
				var a := TAU * i / 6.0 - spin
				draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.38, 1.3 * scale_k, _hdr(c_center, 1.6))
		2: # lantern
			draw_circle(c, s * 0.95, Color(c_petal, 0.35))
			for i in petals:
				var x := lerpf(-0.8, 0.8, (i + 0.5) / petals)
				draw_arc(c + Vector2(x * s * 0.2, 0), s * 0.9, -PI * 0.5 - 1.2 + x, -PI * 0.5 + 1.2 + x, 10, Color(c_petal.lightened(0.3), 0.7), 1.2, true)
			var pulse := 0.85 + 0.15 * sin(t * 2.5 + seed_n)
			draw_circle(c, s * 0.42, _hdr(c_center, 1.5 * pulse * emissive))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.75), c + Vector2(0, -s * 1.15), c + Vector2(s * 0.45, -s * 0.75)]), c_leaf_a)
			_petal_pattern(c, -PI * 0.5, s * 0.8)
		3: # frill
			for layer in 2:
				var r := s * (1.0 - layer * 0.38)
				var pts := PackedVector2Array()
				var waves := petals * 2
				for i in 48:
					var a := TAU * i / 48.0 + spin * (1 - layer * 2)
					var rr := r * (0.82 + 0.18 * sin(a * waves))
					pts.append(c + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, c_petal_dark if layer == 0 else c_petal)
			if int(g.pattern) == 1:
				draw_arc(c, s * 0.7, 0, TAU, 32, Color(c_center, 0.6), 1.5, true)
			elif int(g.pattern) == 2:
				for i in petals: draw_circle(c + Vector2(cos(TAU * i / petals + spin), sin(TAU * i / petals + spin)) * s * 0.75, s * 0.07, Color(c_center, 0.9))
			draw_circle(c, s * 0.24, _hdr(c_center, 1.5 * emissive))

func _petal_pattern(c: Vector2, a: float, s: float) -> void:
	match int(g.pattern):
		1:
			var p := c + Vector2(cos(a), sin(a)) * s * 0.6
			var w := Vector2(cos(a + 1.57), sin(a + 1.57)) * s * 0.12
			draw_line(p - w, p + w, Color(c_center, 0.7), 1.5, true)
		2:
			draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.62, s * 0.07, Color(c_center, 0.95))
		3:
			draw_line(c, c + Vector2(cos(a), sin(a)) * s * 0.85, _hdr(Color(c_center, 0.8), 1.8 * emissive), 1.0, true)

func _petal_pattern_bell(top: Vector2, s: float) -> void:
	match int(g.pattern):
		1: draw_line(top + Vector2(-s * 0.6, s * 0.75), top + Vector2(s * 0.6, s * 0.75), Color(c_center, 0.6), 2.0, true)
		2:
			for k in 3: draw_circle(top + Vector2((k - 1) * s * 0.35, s * 0.7), s * 0.07, Color(c_center, 0.9))
		3:
			for k in 3: draw_line(top + Vector2((k - 1) * s * 0.2, s * 0.15), top + Vector2((k - 1) * s * 0.45, s * 1.2), _hdr(Color(c_center, 0.7), 1.8), 1.0, true)

func _fruit(c: Vector2, grow: float) -> void:
	var r := 9.0 * ease(grow, -2.0)
	var col := Color.from_hsv(float(g.hue2), 0.7, 0.85)
	var hang := c + Vector2(0, 8 * grow)
	draw_line(c, hang, c_stem_tip, 1.5, true)
	draw_circle(hang, r * 1.8, _hdr(Color(col, 0.15), 1.8))
	draw_circle(hang, r, col)
	draw_circle(hang + Vector2(-r * 0.3, -r * 0.3), r * 0.35, _hdr(Color(1, 1, 1, 0.6), 1.4))
	for i in 3:
		var a := t * 1.2 + i * TAU / 3.0
		draw_circle(hang + Vector2(cos(a), sin(a)) * r * 1.5, 1.4, _hdr(Color(1.0, 0.95, 0.6), 2.4))
