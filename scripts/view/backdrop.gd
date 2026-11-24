extends Node2D
## Far landscape: alien megaflora silhouettes in layered haze, light shafts
## falling on sunwells, and drifting luminous spores.

var pal: Dictionary
var shapes_far: Array = []
var shapes_mid: Array = []
var spores: Array = []
var shafts: Array = []   # Vector2 positions of light sources
var t := 0.0
var rng := RandomNumberGenerator.new()

func setup(palette: Dictionary, seed_value: int, shaft_points: Array) -> void:
	pal = palette
	rng.seed = seed_value
	shafts = shaft_points
	shapes_far = _make_layer(14, 0.55, 520.0)
	shapes_mid = _make_layer(10, 0.85, 700.0)
	spores.clear()
	for i in 70:
		spores.append({"p": Vector2(rng.randf_range(-100, 1700), rng.randf_range(0, 1000)), "v": Vector2(rng.randf_range(-6, 6), rng.randf_range(-14, -4)), "r": rng.randf_range(0.8, 2.2), "ph": rng.randf() * TAU})

func _make_layer(n: int, scale_k: float, base_y: float) -> Array:
	var out: Array = []
	for i in n:
		var kind := rng.randi_range(0, 3)
		var x := rng.randf_range(-150, 1750)
		var h := rng.randf_range(180, 460) * scale_k
		out.append({"kind": kind, "x": x, "y": base_y + rng.randf_range(0, 160), "h": h, "w": rng.randf_range(16, 40) * scale_k, "cap": rng.randf_range(50, 130) * scale_k, "lean": rng.randf_range(-0.25, 0.25), "ph": rng.randf() * TAU})
	return out

func _process(delta: float) -> void:
	t += delta
	for s in spores:
		s.p += s.v * delta + Vector2(sin(t * 0.7 + s.ph) * 6.0, 0) * delta
		if s.p.y < -20: s.p.y = 1020
		if s.p.x < -120: s.p.x = 1720
		if s.p.x > 1720: s.p.x = -120
	queue_redraw()

func _draw() -> void:
	if pal.is_empty(): return
	_layer(shapes_far, pal.far, 0.55)
	# fog band
	_fog(560.0, 260.0, Color(pal.haze, 0.10))
	_layer(shapes_mid, pal.mid, 0.9)
	_fog(820.0, 240.0, Color(pal.haze, 0.07))
	for sp in shafts:
		var top := Vector2(sp.x + 160, -60)
		var w0 := 60.0
		var w1 := 220.0
		for i in 3:
			var k := 1.0 + i * 0.6
			draw_colored_polygon(PackedVector2Array([top + Vector2(-w0 * k, 0), top + Vector2(w0 * k, 0), sp + Vector2(w1 * 0.5 * k, 40), sp + Vector2(-w1 * 0.5 * k, 40)]),
				Color(pal.sun, 0.035 - i * 0.008))
	for s in spores:
		var a := 0.5 + 0.5 * sin(t * 1.5 + s.ph)
		draw_circle(s.p, s.r * 2.6, Color(pal.moss, 0.05 * a))
		draw_circle(s.p, s.r * 0.7, Color(pal.moss.r * 1.6, pal.moss.g * 1.6, pal.moss.b * 1.6, 0.7 * a))

func _fog(y: float, h: float, c: Color) -> void:
	var clear := Color(c, 0.0)
	draw_polygon(PackedVector2Array([Vector2(-400, y - h), Vector2(2000, y - h), Vector2(2000, y), Vector2(-400, y)]), PackedColorArray([clear, clear, c, c]))
	draw_polygon(PackedVector2Array([Vector2(-400, y), Vector2(2000, y), Vector2(2000, y + h), Vector2(-400, y + h)]), PackedColorArray([c, c, clear, clear]))

func _layer(shapes: Array, col: Color, sway: float) -> void:
	for s in shapes:
		var base: Vector2 = Vector2(s.x, s.y + 400)
		var lean: float = s.lean + sin(t * 0.25 + s.ph) * 0.02 * sway
		var top: Vector2 = base + Vector2(sin(lean) * s.h, -s.h)
		match int(s.kind):
			0: # mushroom stalk with cap
				_stalk(base, top, s.w, col)
				var cap := PackedVector2Array()
				for i in 17:
					var a := PI + PI * i / 16.0
					cap.append(top + Vector2(cos(a) * s.cap, sin(a) * s.cap * 0.45 + 6))
				draw_colored_polygon(cap, col)
				for i in 5:
					var gx: Vector2 = top + Vector2(-s.cap * 0.7 + i * s.cap * 0.35, 8 + (i % 2) * 6)
					draw_circle(gx, 2.0, Color(pal.moss, 0.35))
			1: # frond tree
				_stalk(base, top, s.w * 0.6, col)
				for i in 7:
					var a := -PI * 0.5 + (i - 3) * 0.42 + sin(t * 0.4 + s.ph + i) * 0.03
					var tip: Vector2 = top + Vector2(cos(a), sin(a)) * s.cap * 1.2
					var mid: Vector2 = top.lerp(tip, 0.5) + Vector2(cos(a + 1.57), sin(a + 1.57)) * s.cap * 0.12
					draw_colored_polygon(PackedVector2Array([top, mid, tip, top.lerp(tip, 0.5) - Vector2(cos(a + 1.57), sin(a + 1.57)) * s.cap * 0.12]), col)
			2: # floating spore sphere
				var c: Vector2 = top + Vector2(0, -s.cap * 0.5 + sin(t * 0.5 + s.ph) * 8.0)
				draw_circle(c, s.cap * 0.55, col)
				draw_circle(c + Vector2(-s.cap * 0.15, -s.cap * 0.15), s.cap * 0.18, Color(pal.haze, 0.12))
				for i in 4:
					draw_line(c + Vector2((i - 1.5) * s.cap * 0.2, s.cap * 0.45), c + Vector2((i - 1.5) * s.cap * 0.25, s.cap * 1.4), Color(col, 0.7), 2.0, true)
			3: # arch
				var pts := PackedVector2Array()
				var r: float = s.h * 0.55
				for i in 25:
					var a := PI + PI * i / 24.0
					pts.append(base + Vector2(r + cos(a) * r, sin(a) * r * 1.2))
				draw_polyline(pts, col, s.w * 1.1, true)

func _stalk(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var nrm := (b - a).normalized().orthogonal()
	draw_colored_polygon(PackedVector2Array([a + nrm * w, b + nrm * w * 0.45, b - nrm * w * 0.45, a - nrm * w]), col)
