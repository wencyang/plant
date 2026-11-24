extends Node2D
## Luminous particles, falling pruned stems, pollen streams, swipe trail.

var particles: Array = []
var debris: Array = []
var streams: Array = []
var rings: Array = []
var trail: Array = []       # Vector2 points of an active swipe
var trail_fade: Array = []  # [points, life]

func _process(delta: float) -> void:
	for p in particles:
		p.life -= delta
		p.vel.y += p.grav * delta
		p.vel *= 1.0 - p.drag * delta
		p.pos += p.vel * delta
	particles = particles.filter(func(p): return p.life > 0.0)
	for d in debris:
		d.life -= delta
		d.vel.y += 420.0 * delta
		d.off += d.vel * delta
		d.rot += d.spin * delta
	debris = debris.filter(func(d): return d.life > 0.0)
	for s in streams:
		s.t += delta
	streams = streams.filter(func(s): return s.t < s.dur)
	for r in rings: r.life -= delta
	rings = rings.filter(func(r): return r.life > 0.0)
	for tf in trail_fade: tf[1] -= delta
	trail_fade = trail_fade.filter(func(tf): return tf[1] > 0.0)
	queue_redraw()

func burst(pos: Vector2, color: Color, count := 20, speed := 160.0, grav := 0.0, size := 2.5, life := 1.2) -> void:
	for i in count:
		var a := randf() * TAU
		particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * speed * randf_range(0.3, 1.0), "life": life * randf_range(0.6, 1.0), "max": life,
			"color": color, "grav": grav, "drag": 1.6, "size": size * randf_range(0.6, 1.4)})

func ring(pos: Vector2, color: Color, radius := 120.0, life := 0.8) -> void:
	rings.append({"pos": pos, "color": color, "radius": radius, "life": life, "max": life})

func add_debris(segments: Array, color: Color) -> void:
	# group cut segments into one falling piece per prune
	if segments.is_empty(): return
	var pivot: Vector2 = segments[0][0]
	debris.append({"segs": segments, "pivot": pivot, "off": Vector2.ZERO, "vel": Vector2(randf_range(-40, 40), -60), "rot": 0.0, "spin": randf_range(-1.2, 1.2), "life": 1.6, "color": color})

func pollen_stream(from: Vector2, to: Vector2, color: Color) -> void:
	streams.append({"a": from, "b": to, "t": 0.0, "dur": 1.6, "color": color})

func _hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

func _draw() -> void:
	for r in rings:
		var k: float = 1.0 - r.life / r.max
		draw_arc(r.pos, r.radius * (0.15 + k), 0, TAU, 48, _hdr(Color(r.color, 1.0 - k), 1.8), 3.0 * (1.0 - k) + 0.5, true)
	for d in debris:
		var a: float = clampf(d.life / 0.6, 0.0, 1.0)
		for sgm in d.segs:
			var p0: Vector2 = (sgm[0] - d.pivot).rotated(d.rot) + d.pivot + d.off
			var p1: Vector2 = (sgm[1] - d.pivot).rotated(d.rot) + d.pivot + d.off
			draw_line(p0, p1, Color(d.color, a), 3.0, true)
	for s in streams:
		var k: float = s.t / s.dur
		for i in 14:
			var u: float = fmod(k * 1.6 + i / 14.0, 1.0)
			if u > k * 1.6: continue
			var p: Vector2 = s.a.lerp(s.b, u) + Vector2(sin(u * 9.0 + i) * 14.0, -sin(u * PI) * 50.0)
			draw_circle(p, 2.4, _hdr(s.color, 2.2))
			draw_circle(p, 6.0, Color(s.color, 0.12))
	for p in particles:
		var a: float = clampf(p.life / (p.max * 0.5), 0.0, 1.0)
		draw_circle(p.pos, p.size * 2.5, Color(p.color, 0.08 * a))
		draw_circle(p.pos, p.size, _hdr(Color(p.color, a), 1.9))
	for tf in trail_fade:
		_trail(tf[0], tf[1] / 0.35)
	if trail.size() > 1: _trail(trail, 1.0)

func _trail(pts: Array, a: float) -> void:
	var packed := PackedVector2Array(pts)
	draw_polyline(packed, Color(1.0, 0.95, 0.85, 0.15 * a), 10.0, true)
	draw_polyline(packed, _hdr(Color(1.0, 0.95, 0.85, 0.9 * a), 2.0), 2.0, true)
