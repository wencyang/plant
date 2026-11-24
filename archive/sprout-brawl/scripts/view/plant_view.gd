extends Node2D
## A living, gene-drawn plant character: bold outlines, a face, idle sway,
## squash & stretch, attack lunges, hit flashes and a wilting faint.

const Species := preload("res://scripts/sim/species.gd")
const OUT := Color("1b2420")

var plant = null
var facing := 1.0          # 1 faces right (player), -1 faces left (enemy)
var show_badges := true
var badge_scale := 1.0
var display_atk := 0
var display_hp := 0
var display_poison := 0
var angry := false

# animation state
var t := 0.0
var phase := 0.0
var squash := 0.0          # spring value, positive = squashed
var squash_vel := 0.0
var lunge := 0.0           # forward offset in px
var flash := 0.0
var hurt := 0.0
var chomp := 0.0
var wilt := 0.0            # 0..1 fainting
var pop := 1.0             # spawn scale
var glow_pulse := 0.0
var badge_bump_atk := 0.0
var badge_bump_hp := 0.0
var blink_timer := 2.0
var blink := 0.0
var hover := 0.0
var lifted := false
var dimmed := false

func setup(p, face := 1.0) -> void:
	plant = p
	facing = face
	phase = randf() * TAU
	blink_timer = randf_range(1.0, 4.0)
	sync_stats()
	queue_redraw()

func sync_stats() -> void:
	if plant == null: return
	display_atk = plant.atk
	display_hp = plant.hp
	display_poison = plant.poison

func bounce(amount := 0.35) -> void:
	squash_vel -= amount * 14.0

func spawn_pop() -> void:
	pop = 0.0

func _process(delta: float) -> void:
	t += delta
	# spring for squash
	var force := -squash * 180.0 - squash_vel * 11.0
	squash_vel += force * delta
	squash += squash_vel * delta
	flash = max(0.0, flash - delta * 4.0)
	hurt = max(0.0, hurt - delta * 1.6)
	chomp = max(0.0, chomp - delta * 3.0)
	glow_pulse += delta
	badge_bump_atk = max(0.0, badge_bump_atk - delta * 3.0)
	badge_bump_hp = max(0.0, badge_bump_hp - delta * 3.0)
	pop = min(1.0, pop + delta * 3.5)
	hover = move_toward(hover, 1.0 if lifted else 0.0, delta * 6.0)
	blink_timer -= delta
	if blink_timer <= 0.0:
		blink = 1.0
		blink_timer = randf_range(1.8, 4.5)
	blink = max(0.0, blink - delta * 7.0)
	queue_redraw()

# ---------------------------------------------------------------- colours

func leaf_col() -> Color:
	return Color.from_hsv(float(plant.genes.leaf_hue), 0.62, 0.74)

func leaf_light() -> Color:
	return Color.from_hsv(float(plant.genes.leaf_hue) - 0.03, 0.48, 0.90)

func flower_col() -> Color:
	return Color.from_hsv(float(plant.genes.flower_hue), 0.62, 0.98)

func flower_dark() -> Color:
	return Color.from_hsv(float(plant.genes.flower_hue), 0.75, 0.70)

# ---------------------------------------------------------------- drawing helpers

func _poly(points: PackedVector2Array, fill: Color, width := 3.0) -> void:
	if points.size() < 3: return
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, OUT, width, true)

func _circle(c: Vector2, r: float, fill: Color, width := 3.0) -> void:
	draw_circle(c, r + width * 0.8, OUT)
	draw_circle(c, r, fill)

func _ellipse_pts(c: Vector2, rx: float, ry: float, rot := 0.0, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

func _leaf_pts(base: Vector2, angle: float, length: float, width: float, shape: int) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := 12
	for i in range(n + 1):
		var u := float(i) / n
		var w := 0.0
		match shape:
			0: w = pow(sin(PI * u), 0.75) * width
			1: w = sin(PI * pow(u, 0.7)) * width * (1.0 - u * 0.25)
			_: w = sin(PI * u) * width * (1.0 + 0.22 * sin(u * PI * 7.0))
		var along := Vector2(length * u, 0)
		left.append(base + (along + Vector2(0, -w)).rotated(angle))
		right.append(base + (along + Vector2(0, w)).rotated(angle))
	right.reverse()
	left.append_array(right)
	return left

func _bezier(a: Vector2, c: Vector2, b: Vector2, n := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var u := float(i) / n
		pts.append(a.lerp(c, u).lerp(c.lerp(b, u), u))
	return pts

func _stem(pts: PackedVector2Array, width: float, col: Color) -> void:
	draw_polyline(pts, OUT, width + 4.0, true)
	draw_polyline(pts, col, width, true)

# ---------------------------------------------------------------- main draw

func _draw() -> void:
	if plant == null: return
	var size: float = float(plant.genes.get("size", 1.0))
	var sway := sin(t * 1.7 + phase) * 0.05
	var sx := (1.0 - squash * 0.5) * pop
	var sy := (1.0 + squash) * pop
	if wilt > 0.0:
		sy *= 1.0 - wilt * 0.55
		sx *= 1.0 + wilt * 0.2
	var lift := -hover * 18.0
	var origin := Vector2(lunge * facing, lift)
	if hurt > 0.0:
		origin.x += sin(t * 70.0) * hurt * 5.0
	# shadow
	draw_set_transform(Vector2(0, 2), 0, Vector2.ONE)
	draw_colored_polygon(_ellipse_pts(Vector2(lunge * facing, 0), 34 * size * pop, 7 * pop), Color(0, 0, 0, 0.22 - hover * 0.08))
	# glow for mutants
	if plant.mutant or plant.pollen:
		var glow_col := Color.from_hsv(fmod(glow_pulse * 0.15, 1.0), 0.5, 1.0, 0.16 + 0.06 * sin(glow_pulse * 3.0))
		if plant.pollen and not plant.mutant: glow_col = Color(1.0, 0.92, 0.45, 0.16 + 0.06 * sin(glow_pulse * 3.0))
		for i in 3:
			draw_circle(origin + Vector2(0, -60 * size), (58 + i * 14) * size * pop, Color(glow_col, glow_col.a * (1.0 - i * 0.3)))
	draw_set_transform(origin, sway * (1.0 - wilt) + wilt * 0.9 * facing, Vector2(sx * size * facing, sy * size))
	_draw_body()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if flash > 0.0:
		draw_set_transform(origin, sway, Vector2(sx * size * facing, sy * size))
		draw_circle(Vector2(0, -55), 48, Color(1, 1, 1, flash * 0.55))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if show_badges and wilt < 0.3:
		_draw_badges()

func _draw_body() -> void:
	var species: String = plant.head()
	var extras: Array = plant.lineage.slice(1)
	var lc := leaf_col()
	var ll := leaf_light()
	var shape: int = int(plant.genes.leaf_shape)
	var head_pos := Vector2.ZERO
	# Extra leafy base when Sprigling blood runs in the family
	if extras.has("leaf"):
		_poly(_leaf_pts(Vector2(0, -6), PI + 0.35, 42, 13, shape), lc)
		_poly(_leaf_pts(Vector2(0, -6), -0.35, 42, 13, shape), lc)
	if extras.has("root") or species == "root":
		for i in 4:
			var a := 0.55 + i * 0.6
			draw_polyline(_bezier(Vector2(-12 + i * 8, -2), Vector2(-20 + i * 14, 8), Vector2(-26 + i * 18, 14)), Color(OUT, 0.7), 3.0, true)
	match species:
		"bloom":
			var top := Vector2(sin(t * 1.3 + phase) * 4, -82)
			_stem(_bezier(Vector2.ZERO, Vector2(10, -40), top), 6, lc.darkened(0.1))
			_poly(_leaf_pts(Vector2(2, -26), -0.5, 34, 11, shape), lc)
			_poly(_leaf_pts(Vector2(-2, -40), PI + 0.45, 30, 10, shape), ll)
			head_pos = top
			if extras.has("bloom") or plant.gen >= 3: _petal_ring(head_pos, 34, int(plant.genes.petals) + 3, flower_dark(), 9)
			_petal_ring(head_pos, 28, int(plant.genes.petals), flower_col(), 12)
			_circle(head_pos, 15, Color("ffd34d").lerp(flower_dark(), 0.25))
			_extras_on_head(head_pos, 15, extras)
			_face(head_pos + Vector2(2, 1), 15)
		"leaf":
			var top := Vector2(sin(t * 1.5 + phase) * 3, -50)
			_stem(_bezier(Vector2.ZERO, Vector2(-6, -25), top), 6, lc.darkened(0.1))
			_poly(_leaf_pts(Vector2(0, -18), -0.6, 26, 9, shape), lc)
			_poly(_leaf_pts(top + Vector2(-3, -14), -PI * 0.5 - 0.7, 30, 12, shape), ll)
			_poly(_leaf_pts(top + Vector2(3, -14), -PI * 0.5 + 0.7, 30, 12, shape), lc)
			_circle(top, 19, ll.lightened(0.1))
			head_pos = top
			_extras_on_head(head_pos, 19, extras)
			_face(head_pos + Vector2(3, 2), 19)
		"root":
			var body := Vector2(0, -30)
			for i in 3:
				_poly(_leaf_pts(body + Vector2(-6 + i * 6, -24), -PI * 0.5 + (i - 1) * 0.5 + sin(t * 2 + phase + i) * 0.08, 28, 8, shape), lc)
			var tuber := Color.from_hsv(0.07 + float(plant.genes.flower_hue) * 0.05, 0.55, 0.80)
			for i in 6:
				var a := -PI + 0.2 + i * (PI - 0.4) / 5.0
				var p := body + Vector2(cos(a) * 30, sin(a) * 27)
				var dir := Vector2(cos(a), sin(a))
				_poly(PackedVector2Array([p + dir.orthogonal() * 5, p + dir * 13, p - dir.orthogonal() * 5]), Color("f1e2c0"), 2.5)
			_poly(_ellipse_pts(body, 31, 28), tuber)
			draw_arc(body + Vector2(-8, 6), 18, 0.6, 2.2, 10, tuber.darkened(0.2), 2.5, true)
			head_pos = body
			_extras_on_head(head_pos, 28, extras)
			_face(body + Vector2(5, -2), 26)
		"spore":
			var top := Vector2(sin(t * 1.4 + phase) * 2, -44)
			var stalk := Color("f3ead4")
			_poly(PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(12, -40), Vector2(-12, -40)]), stalk)
			head_pos = Vector2(0, -22)
			var cap := PackedVector2Array()
			for i in range(17):
				var a := PI + PI * i / 16.0
				cap.append(top + Vector2(cos(a) * 40, sin(a) * 34 + 4))
			cap.append(top + Vector2(28, 10))
			cap.append(top + Vector2(-28, 10))
			_poly(cap, flower_col())
			for s in [Vector2(-18, -14), Vector2(4, -24), Vector2(20, -8), Vector2(-4, -4)]:
				draw_circle(top + s, 5.5, Color(1, 1, 1, 0.92))
			_extras_on_head(top + Vector2(0, -10), 30, extras)
			_face(head_pos + Vector2(2, 0), 13)
		"vine":
			var top := Vector2(sin(t * 1.2 + phase) * 6, -76)
			var pts := PackedVector2Array()
			for i in range(21):
				var u := i / 20.0
				pts.append(Vector2(sin(u * 9.0 + t * 1.5 + phase) * 10 * (1.0 - u * 0.5), -u * 76).lerp(top, u * u))
			_stem(pts, 6, lc.darkened(0.15))
			for i in 4:
				var p := pts[4 + i * 4]
				_poly(_leaf_pts(p, (-0.4 if i % 2 == 0 else PI + 0.4) + sin(t * 2.0 + i) * 0.1, 22, 8, shape), lc if i % 2 == 0 else ll)
			# whip tendril
			var whip := PackedVector2Array()
			for i in range(13):
				var u := i / 12.0
				whip.append(top + Vector2(u * 46, -sin(u * PI) * 18 + sin(u * 10.0 + t * 4.0) * 4 * u))
			_stem(whip, 3.5, lc)
			head_pos = top
			_circle(top, 17, ll)
			for i in 3:
				draw_circle(top + Vector2(-14 + i * 12, -15), 5, flower_col())
			_extras_on_head(head_pos, 17, extras)
			_face(top + Vector2(2, 1), 17)
		"toxin":
			var top := Vector2(sin(t * 1.4 + phase) * 3, -64)
			_stem(_bezier(Vector2.ZERO, Vector2(-14, -34), top), 6, lc.darkened(0.2))
			_poly(_leaf_pts(Vector2(-4, -22), PI + 0.4, 30, 10, shape), lc)
			_poly(_leaf_pts(Vector2(-6, -36), -0.3, 26, 9, shape), lc.darkened(0.1))
			var berry := Color.from_hsv(float(plant.genes.flower_hue), 0.6, 0.72)
			draw_line(top + Vector2(10, 10), top + Vector2(16, 28), OUT, 2.0)
			_circle(top + Vector2(16, 30), 7, berry.darkened(0.1))
			_circle(top, 22, berry)
			for i in 5:
				var a := -PI * 0.5 + (i - 2) * 0.45
				_poly(_leaf_pts(top + Vector2(0, -16), a, 14, 5, 1), lc.darkened(0.1), 2.0)
			draw_circle(top + Vector2(-8, -8), 5, Color(1, 1, 1, 0.35))
			# drip
			var drip_y := fmod(t * 20.0 + phase * 10.0, 30.0)
			draw_circle(top + Vector2(-6, 22 + drip_y), 3.0 * (1.0 - drip_y / 30.0), Color("9cff6a"))
			head_pos = top
			_extras_on_head(head_pos, 22, extras)
			_face(top + Vector2(3, 2), 22)
		"snap":
			var top := Vector2(sin(t * 1.3 + phase) * 3, -62)
			_stem(_bezier(Vector2.ZERO, Vector2(-10, -30), top + Vector2(-10, 4)), 7, lc.darkened(0.1))
			_poly(_leaf_pts(Vector2(0, -10), PI + 0.3, 34, 11, shape), lc)
			_poly(_leaf_pts(Vector2(0, -10), -0.3, 30, 10, shape), ll)
			var open := 0.55 + 0.12 * sin(t * 2.0 + phase) - chomp * 0.5
			_jaw(top, open, 1.0)
			head_pos = top + Vector2(0, -20)
			_extras_on_head(top, 26, extras)
			_face(top + Vector2(-4, -22 - open * 10), 12, true)
		"wisp":
			var top := Vector2(0, -70 + sin(t * 2.2 + phase) * 7)
			for i in 4:
				var pts := PackedVector2Array()
				for k in range(9):
					var u := k / 8.0
					pts.append(top + Vector2(-12 + i * 8 + sin(u * 6 + t * 3 + i) * 5, 16 + u * 36))
				draw_polyline(pts, Color(lc.lightened(0.3), 0.85), 2.5, true)
			var orb := Color.from_hsv(float(plant.genes.flower_hue), 0.25, 1.0)
			draw_circle(top, 34, Color(orb, 0.18))
			_circle(top, 22, orb)
			draw_circle(top + Vector2(-8, -8), 7, Color(1, 1, 1, 0.55))
			_poly(_leaf_pts(top + Vector2(0, -18), -PI * 0.5 - 0.7, 26, 8, 0), lc)
			_poly(_leaf_pts(top + Vector2(0, -18), -PI * 0.5 + 0.7, 26, 8, 0), ll)
			_circle(top + Vector2(-4, -22), 4, Color.WHITE, 2.0)
			_circle(top + Vector2(5, -21), 4, Color.WHITE, 2.0)
			head_pos = top
			_extras_on_head(head_pos, 22, extras)
			_face(top + Vector2(3, 3), 22)

func _petal_ring(c: Vector2, length: float, n: int, col: Color, width: float) -> void:
	for i in n:
		var a := TAU * i / n + t * 0.15
		_poly(_ellipse_pts(c + Vector2(cos(a), sin(a)) * length * 0.55, length * 0.5, width, a, 14), col, 2.5)

func _jaw(c: Vector2, open: float, s: float) -> void:
	var inner := Color("ff5d6e")
	var lobe := leaf_col().lerp(Color("c64a3a"), 0.35)
	for side in [-1, 1]:
		var ang: float = -open * side
		var pts := PackedVector2Array()
		for i in range(13):
			var a := PI * i / 12.0
			pts.append(c + Vector2(cos(a) * 30 - 2, -sin(a) * 18 * side).rotated(ang) * s)
		_poly(pts, lobe)
		var mouth := PackedVector2Array()
		for i in range(13):
			var a := PI * i / 12.0
			mouth.append(c + Vector2(cos(a) * 24 - 2, -sin(a) * 11 * side).rotated(ang) * s)
		draw_colored_polygon(mouth, inner)
		for k in 6:
			var a := PI * (k + 0.5) / 6.0
			var base := c + Vector2(cos(a) * 30 - 2, -sin(a) * 18 * side).rotated(ang) * s
			var tip := c + Vector2(cos(a) * 30 - 2, -sin(a) * 18 * side - 9 * side).rotated(ang) * s
			_poly(PackedVector2Array([base + Vector2(-3, 0), tip, base + Vector2(3, 0)]), Color("fffbe8"), 1.5)

func _extras_on_head(c: Vector2, r: float, extras: Array) -> void:
	for e in extras:
		match e:
			"bloom":
				for i in 5:
					var a := -PI * 0.5 + (i - 2) * 0.5
					_circle(c + Vector2(cos(a), sin(a)) * (r + 4), 6, flower_col(), 2.0)
			"root":
				for i in 4:
					var a := -PI * 0.5 + (i - 1.5) * 0.6
					var p := c + Vector2(cos(a), sin(a)) * r
					var dir := Vector2(cos(a), sin(a))
					_poly(PackedVector2Array([p + dir.orthogonal() * 4, p + dir * 11, p - dir.orthogonal() * 4]), Color("f1e2c0"), 2.0)
			"spore":
				for s in [Vector2(-0.5, -0.4), Vector2(0.45, -0.55), Vector2(-0.2, 0.5)]:
					draw_circle(c + s * r, r * 0.16, Color(1, 1, 1, 0.85))
				for i in 3:
					var y := fmod(t * 14.0 + i * 13.0, 40.0)
					draw_circle(c + Vector2(-r + i * r, -r - y), 2.5, Color(flower_col(), 1.0 - y / 40.0))
			"vine":
				for side in [-1, 1]:
					var pts := PackedVector2Array()
					for i in range(10):
						var a := i * 0.75 + t
						pts.append(c + Vector2(side * (r + i * 2.2), -4) + Vector2(cos(a), sin(a)) * (9 - i * 0.8))
					draw_polyline(pts, leaf_col().darkened(0.2), 2.5, true)
			"toxin":
				_circle(c + Vector2(-r * 0.6, r * 0.9), 5, Color.from_hsv(float(plant.genes.flower_hue), 0.6, 0.55), 2.0)
				_circle(c + Vector2(r * 0.1, r * 1.05), 4, Color.from_hsv(float(plant.genes.flower_hue), 0.6, 0.6), 2.0)
			"wisp":
				for i in 4:
					var a := t * 1.5 + i * TAU / 4.0
					draw_circle(c + Vector2(cos(a) * (r + 14), sin(a) * (r + 8) * 0.5), 3.0, Color(0.75, 1.0, 1.0, 0.85))
			"snap":
				for k in 4:
					var x := -r * 0.35 + k * r * 0.25
					_poly(PackedVector2Array([c + Vector2(x, r * 0.35), c + Vector2(x + r * 0.11, r * 0.62), c + Vector2(x + r * 0.22, r * 0.35)]), Color("fffbe8"), 1.5)

func _face(c: Vector2, r: float, small := false) -> void:
	var eye_r: float = r * (0.3 if not small else 0.55)
	eye_r = clampf(eye_r, 4.0, 7.5)
	var gap: float = r * 0.42 if not small else 0.0
	var eye_style: int = int(plant.genes.get("eyes", 0))
	var squint: float = clampf(max(blink, hurt * 0.8), 0.0, 1.0)
	var eyes: Array = [c + Vector2(gap * 0.5 + 2, -r * 0.12)] if small else [c + Vector2(-gap * 0.55, -r * 0.15), c + Vector2(gap * 0.75, -r * 0.15)]
	for e in eyes:
		var ry: float = eye_r * (1.0 - squint * 0.85)
		draw_colored_polygon(_ellipse_pts(e, eye_r + 2, ry + 2, 0, 16), OUT)
		draw_colored_polygon(_ellipse_pts(e, eye_r, ry, 0, 16), Color.WHITE)
		if squint < 0.7:
			var pupil: Vector2 = e + Vector2(eye_r * 0.3, eye_r * 0.1)
			var pr: float = eye_r * (0.62 if eye_style == 2 else 0.5)
			draw_circle(pupil, pr, OUT if not plant.mutant else Color("3a1f6e"))
			draw_circle(pupil + Vector2(-pr * 0.35, -pr * 0.4), pr * 0.35, Color.WHITE)
		if eye_style == 1 and squint < 0.5:
			draw_colored_polygon(_ellipse_pts(e + Vector2(0, -eye_r * 0.55), eye_r + 1, eye_r * 0.5, 0, 12), leaf_light() if plant.head() != "bloom" else Color("ffd34d"))
			draw_line(e + Vector2(-eye_r, -eye_r * 0.15), e + Vector2(eye_r, -eye_r * 0.15), OUT, 2.0)
		if angry:
			draw_line(e + Vector2(-eye_r, -eye_r * 1.5), e + Vector2(eye_r, -eye_r * 0.9), OUT, 3.0)
	if small: return
	var m := c + Vector2(gap * 0.15, r * 0.35)
	if hurt > 0.3:
		draw_circle(m, r * 0.14 + 1.5, OUT)
		draw_circle(m, r * 0.14, Color("8c2f3a"))
	elif angry:
		draw_line(m + Vector2(-r * 0.2, 0), m + Vector2(r * 0.2, -1), OUT, 2.5)
	else:
		draw_arc(m + Vector2(0, -r * 0.08), r * 0.2, 0.3, PI - 0.3, 8, OUT, 2.5, true)
	# cheeks
	draw_circle(c + Vector2(-gap * 0.95, r * 0.22), r * 0.13, Color(1.0, 0.45, 0.5, 0.35))
	draw_circle(c + Vector2(gap * 1.2, r * 0.22), r * 0.13, Color(1.0, 0.45, 0.5, 0.35))

# ---------------------------------------------------------------- stat badges

func _draw_badges() -> void:
	var font := ThemeDB.fallback_font
	var y := 22.0
	var s := badge_scale
	var atk_c := Vector2(-20 * s, y * s)
	var hp_c := Vector2(20 * s, y * s)
	var ra := 15.0 * s * (1.0 + badge_bump_atk * 0.5)
	var rh := 15.0 * s * (1.0 + badge_bump_hp * 0.5)
	# attack: orange burst
	var burst := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		burst.append(atk_c + Vector2(cos(a), sin(a)) * (ra if i % 2 == 0 else ra * 0.78))
	_poly(burst, Color("ff8a3d"), 2.5)
	# health: heart
	var heart := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var hx := 16.0 * pow(sin(a), 3)
		var hy := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
		heart.append(hp_c + Vector2(hx, hy + 1.5) * rh / 17.0)
	_poly(heart, Color("4fcf6b") if display_hp > 0 else Color("6b6b6b"), 2.5)
	var fs := int(17 * s)
	_num(font, str(display_atk), atk_c, fs)
	_num(font, str(max(display_hp, 0)), hp_c, fs)
	if display_poison > 0:
		var pc := Vector2(0, (y + 26) * s)
		_circle(pc, 10 * s, Color("a35cff"), 2.0)
		_num(font, str(display_poison), pc, int(13 * s))
	# ability pips
	if plant.abilities.size() > 0:
		var keys: Array = plant.abilities.keys()
		var x0 := -float(keys.size() - 1) * 7.0 * s
		for i in keys.size():
			var col: Color = Species.ABILITIES[keys[i]].color
			_circle(Vector2(x0 + i * 14 * s, (y - 26) * s + 4), 4.5 * s, col, 1.5)

func _num(font: Font, text: String, c: Vector2, fs: int) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := c + Vector2(-w * 0.5, fs * 0.36)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, OUT)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func head_offset() -> Vector2:
	var size: float = float(plant.genes.get("size", 1.0)) if plant != null else 1.0
	return Vector2(0, -60 * size * scale.y)

func hit_test(local: Vector2) -> bool:
	var size: float = float(plant.genes.get("size", 1.0)) if plant != null else 1.0
	return Rect2(Vector2(-44, -120 * size), Vector2(88, 150 * size)).has_point(local)
