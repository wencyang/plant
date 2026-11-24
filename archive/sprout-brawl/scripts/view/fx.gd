extends Node2D
## Lightweight juice layer: particles, floating numbers, beams and banners.

const OUT := Color("1b2420")

var particles: Array = []
var texts: Array = []
var beams: Array = []
var rings: Array = []

func _process(delta: float) -> void:
	for p in particles:
		p.life -= delta
		p.vel.y += p.grav * delta
		p.vel *= 1.0 - p.drag * delta
		p.pos += p.vel * delta
		p.rot += p.spin * delta
	particles = particles.filter(func(p): return p.life > 0.0)
	for tx in texts:
		tx.life -= delta
		tx.pos.y -= tx.rise * delta
		tx.rise = max(10.0, tx.rise - 90.0 * delta)
	texts = texts.filter(func(tx): return tx.life > 0.0)
	for b in beams: b.life -= delta
	beams = beams.filter(func(b): return b.life > 0.0)
	for r in rings: r.life -= delta
	rings = rings.filter(func(r): return r.life > 0.0)
	queue_redraw()

func burst(pos: Vector2, color: Color, count := 14, speed := 260.0, shape := "dot", grav := 500.0, size := 6.0) -> void:
	for i in count:
		var a := randf() * TAU
		var s := randf_range(0.35, 1.0) * speed
		particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * s + Vector2(0, -speed * 0.35), "life": randf_range(0.5, 1.0), "max": 1.0,
			"color": color.lerp(Color.WHITE, randf() * 0.3), "grav": grav, "drag": 1.5, "size": size * randf_range(0.6, 1.3), "shape": shape, "rot": randf() * TAU, "spin": randf_range(-8, 8)})

func confetti(rect: Rect2, count := 80) -> void:
	var cols := [Color("ff6b8b"), Color("ffd34d"), Color("6be0a0"), Color("6bb8ff"), Color("c58bff"), Color("ff9f4a")]
	for i in count:
		particles.append({"pos": Vector2(randf_range(rect.position.x, rect.end.x), rect.position.y - randf() * 120), "vel": Vector2(randf_range(-60, 60), randf_range(50, 240)),
			"life": randf_range(1.8, 3.2), "max": 3.2, "color": cols[i % cols.size()], "grav": 120.0, "drag": 0.4, "size": randf_range(6, 11), "shape": "rect", "rot": randf() * TAU, "spin": randf_range(-10, 10)})

func number(pos: Vector2, text: String, color: Color, size := 30) -> void:
	texts.append({"pos": pos + Vector2(randf_range(-8, 8), 0), "text": text, "color": color, "life": 1.0, "rise": 120.0, "size": size})

func label(pos: Vector2, text: String, color: Color, size := 22) -> void:
	texts.append({"pos": pos, "text": text, "color": color, "life": 1.3, "rise": 50.0, "size": size})

func beam(a: Vector2, b: Vector2, color: Color, width := 8.0, life := 0.35, wavy := true) -> void:
	beams.append({"a": a, "b": b, "color": color, "width": width, "life": life, "max": life, "wavy": wavy})

func ring(pos: Vector2, color: Color, radius := 90.0, life := 0.5) -> void:
	rings.append({"pos": pos, "color": color, "radius": radius, "life": life, "max": life})

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for r in rings:
		var k: float = 1.0 - r.life / r.max
		draw_arc(r.pos, r.radius * (0.2 + k), 0, TAU, 40, Color(r.color, 1.0 - k), 8.0 * (1.0 - k) + 1.0, true)
	for b in beams:
		var k: float = b.life / b.max
		var pts := PackedVector2Array()
		var n := 18
		for i in range(n + 1):
			var u := float(i) / n
			var p: Vector2 = b.a.lerp(b.b, u)
			p.y -= sin(u * PI) * 60.0
			if b.wavy: p.y += sin(u * 20.0 + k * 20.0) * 6.0 * sin(u * PI)
			pts.append(p)
		draw_polyline(pts, OUT, b.width * k + 4, true)
		draw_polyline(pts, b.color, b.width * k, true)
	for p in particles:
		var a: float = clampf(p.life / 0.4, 0.0, 1.0)
		var c: Color = Color(p.color, a)
		match p.shape:
			"rect":
				draw_set_transform(p.pos, p.rot, Vector2.ONE)
				draw_rect(Rect2(-p.size * 0.5, -p.size * 0.3, p.size, p.size * 0.6), c)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"petal":
				draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.55))
				draw_circle(Vector2.ZERO, p.size, c)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"heart":
				draw_set_transform(p.pos, 0, Vector2.ONE * p.size / 10.0)
				var heart := PackedVector2Array()
				for i in 16:
					var t := TAU * i / 16.0
					heart.append(Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * 0.6)
				draw_colored_polygon(heart, c)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"star":
				var pts := PackedVector2Array()
				for i in 10:
					var t: float = TAU * i / 10.0 + p.rot
					pts.append(p.pos + Vector2(cos(t), sin(t)) * (p.size if i % 2 == 0 else p.size * 0.45))
				draw_colored_polygon(pts, c)
			_:
				draw_circle(p.pos, p.size, c)
	for tx in texts:
		var a: float = clampf(tx.life / 0.35, 0.0, 1.0)
		var s: int = tx.size
		var w := font.get_string_size(tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		var pos: Vector2 = tx.pos - Vector2(w * 0.5, 0)
		draw_string_outline(font, pos, tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 8, Color(OUT, a))
		draw_string(font, pos, tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color(tx.color, a))
