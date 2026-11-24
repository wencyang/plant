extends Node2D
## Renders a session: sky, megaflora backdrop, rock, glass, crystal, water,
## darkness, sunwells, lures, wild plants and your plant.

const Palettes := preload("res://scripts/view/palettes.gd")
const PlantView := preload("res://scripts/view/plant_view.gd")
const Backdrop := preload("res://scripts/view/backdrop.gd")
const Fx := preload("res://scripts/view/fx.gd")

var session
var pal: Dictionary
var t := 0.0
var sky: ColorRect
var backdrop: Node2D
var rock_layer: Node2D
var deco: Node2D
var crystal_nodes: Array = []
var wild_views: Array = []
var plant_view: Node2D
var overlay: Node2D        # sunwells + lures, drawn above plants
var dark_rect: ColorRect
var fx: Node2D
var hover_lure := -1
var goal_bloom: Dictionary = {}
var pollinated_glow: Dictionary = {}

func build(s) -> void:
	session = s
	for c in get_children():
		remove_child(c)
		c.queue_free()
	crystal_nodes.clear()
	wild_views.clear()
	pal = Palettes.get_palette(str(s.def.get("palette", "dawn")))
	sky = ColorRect.new()
	sky.position = Vector2(-600, -400)
	sky.size = Vector2(2800, 1800)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/sky.gdshader")
	sm.set_shader_parameter("top_col", pal.top)
	sm.set_shader_parameter("bottom_col", pal.bottom)
	sm.set_shader_parameter("haze_col", pal.haze)
	sm.set_shader_parameter("stars", pal.stars)
	sky.material = sm
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	backdrop = Backdrop.new()
	add_child(backdrop)
	var shafts: Array = []
	for g in s.world.goals: shafts.append(g.pos)
	backdrop.setup(pal, hash(str(s.def.get("id", ""))), shafts)
	# water (behind rock so soil covers its edges)
	for w in s.world.waters:
		var wp := Polygon2D.new()
		wp.polygon = PackedVector2Array([w.position, Vector2(w.end.x, w.position.y), w.end, Vector2(w.position.x, w.end.y)])
		var wm := ShaderMaterial.new()
		wm.shader = preload("res://shaders/water.gdshader")
		wp.material = wm
		wp.z_index = 2
		add_child(wp)
	rock_layer = Node2D.new()
	add_child(rock_layer)
	for r in s.world.rocks:
		var poly := Polygon2D.new()
		poly.polygon = r.poly
		var m := ShaderMaterial.new()
		if r.slick:
			m.shader = preload("res://shaders/glass.gdshader")
			m.set_shader_parameter("tint", pal.haze.lerp(Color(0.6, 0.9, 1.0), 0.6))
		else:
			m.shader = preload("res://shaders/rock.gdshader")
			m.set_shader_parameter("col_a", pal.rock_a)
			m.set_shader_parameter("col_b", pal.rock_b)
			m.set_shader_parameter("speck", pal.speck)
			m.set_shader_parameter("soil", 1.0 if r.soil else 0.0)
			m.set_shader_parameter("top_y", r.aabb.position.y)
			m.set_shader_parameter("height", min(r.aabb.size.y, 400.0))
		poly.material = m
		rock_layer.add_child(poly)
	for w in s.world.waters:
		# the water pool shows through a window in the soil
		var window := Polygon2D.new()
		window.polygon = PackedVector2Array([w.position + Vector2(-4, -4), Vector2(w.end.x + 4, w.position.y - 4), w.end + Vector2(4, 4), Vector2(w.position.x - 4, w.end.y + 4)])
		var wm := ShaderMaterial.new()
		wm.shader = preload("res://shaders/water.gdshader")
		window.material = wm
		rock_layer.add_child(window)
	for c in s.world.crystals:
		var cp := Polygon2D.new()
		cp.polygon = c.poly
		var cm := ShaderMaterial.new()
		cm.shader = preload("res://shaders/crystal.gdshader")
		cp.material = cm
		rock_layer.add_child(cp)
		crystal_nodes.append(cp)
	deco = Node2D.new()
	deco.draw.connect(_draw_deco.bind(deco))
	add_child(deco)
	for i in s.wild_sims.size():
		var v := PlantView.new()
		add_child(v)
		v.setup(s.wild_sims[i], true)
		wild_views.append(v)
	plant_view = PlantView.new()
	add_child(plant_view)
	plant_view.setup(s.plant)
	# darkness
	dark_rect = ColorRect.new()
	dark_rect.position = Vector2(-600, -400)
	dark_rect.size = Vector2(2800, 1800)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dm := ShaderMaterial.new()
	dm.shader = preload("res://shaders/darkness.gdshader")
	dark_rect.material = dm
	dark_rect.visible = not s.world.darks.is_empty()
	add_child(dark_rect)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay.bind(overlay))
	add_child(overlay)
	fx = Fx.new()
	add_child(fx)

func replace_plant(s) -> void:
	session = s
	plant_view.setup(s.plant)
	plant_view.flower_open.clear()
	plant_view.big_flowers.clear()
	plant_view.fruit_grow.clear()

func _process(delta: float) -> void:
	t += delta
	if session == null: return
	for i in crystal_nodes.size():
		var alive: bool = session.world.crystals[i].alive
		var cn: Polygon2D = crystal_nodes[i]
		if not alive and cn.visible:
			cn.modulate.a = move_toward(cn.modulate.a, 0.0, delta * 4.0)
			if cn.modulate.a <= 0.0: cn.visible = false
	if dark_rect.visible: _update_darkness()
	for gi in session.world.goals.size():
		if session.world.goals[gi].reached: goal_bloom[gi] = min(1.0, float(goal_bloom.get(gi, 0.0)) + delta * 0.8)
	for wi in session.world.wilds.size():
		if session.world.wilds[wi].pollinated: pollinated_glow[wi] = min(1.0, float(pollinated_glow.get(wi, 0.0)) + delta)
	overlay.queue_redraw()
	deco.queue_redraw()

func _update_darkness() -> void:
	var m: ShaderMaterial = dark_rect.material
	var darks: Array = []
	for d in session.world.darks: darks.append(Vector4(d.pos.x, d.pos.y, d.r, 0))
	while darks.size() < 4: darks.append(Vector4.ZERO)
	m.set_shader_parameter("darks", darks)
	m.set_shader_parameter("dark_count", session.world.darks.size())
	var lights: Array = []
	for l in session.world.lures: lights.append(Vector4(l.x, l.y, 250.0, 0))
	var pl = session.plant
	if int(pl.genome.glow) > 0:
		var step := maxi(1, pl.pos.size() / 24)
		for n in range(0, pl.pos.size(), step):
			if pl.alive[n] == 1 and pl.kind[n] == 0 and lights.size() < 30: lights.append(Vector4(pl.pos[n].x, pl.pos[n].y, 120.0, 0))
		for tip in pl.tips:
			if lights.size() < 32 and pl.alive[tip.node] == 1: lights.append(Vector4(pl.pos[tip.node].x, pl.pos[tip.node].y, 150.0, 0))
	for gi in session.world.goals.size():
		if session.world.goals[gi].reached and lights.size() < 32:
			var g = session.world.goals[gi]
			lights.append(Vector4(g.pos.x, g.pos.y, 260.0, 0))
	var count := lights.size()
	while lights.size() < 32: lights.append(Vector4.ZERO)
	m.set_shader_parameter("lights", lights)
	m.set_shader_parameter("light_count", count)

func _hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

# ------------------------------------------------------------ rock tops

func _draw_deco(deco: Node2D) -> void:
	for r in session.world.rocks:
		var poly: PackedVector2Array = r.poly
		var area := 0.0
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			area += a.x * b.y - b.x * a.y
		var sgn := 1.0 if area > 0 else -1.0
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var e := b - a
			if e.length() < 1.0: continue
			var nrm := Vector2(e.y, -e.x).normalized() * sgn
			if r.slick:
				deco.draw_line(a, b, _hdr(Color(0.8, 0.95, 1.0, 0.7), 1.6), 1.5, true)
				continue
			if nrm.y < -0.55:
				# glowing moss and little fungi along top edges
				deco.draw_line(a, b, Color(pal.moss, 0.55), 4.0, true)
				deco.draw_line(a + Vector2(0, -1), b + Vector2(0, -1), _hdr(Color(pal.moss, 0.6), 1.5), 1.2, true)
				var steps := int(e.length() / 14.0)
				for k in steps:
					var u: float = (k + 0.5) / max(1, steps)
					var p := a.lerp(b, u)
					var hsh := fmod(sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453, 1.0)
					hsh = abs(hsh)
					if hsh < 0.18:
						var h := 6.0 + hsh * 40.0
						var sw := sin(t * 1.6 + p.x * 0.05) * 1.5
						deco.draw_line(p, p + Vector2(sw, -h), Color(pal.moss.darkened(0.3), 0.9), 1.2, true)
						deco.draw_circle(p + Vector2(sw, -h), 2.2, _hdr(pal.moss, 1.7 + 0.4 * sin(t * 2.0 + p.x)))
					elif hsh < 0.32:
						deco.draw_circle(p + Vector2(0, -2), 2.0 + hsh * 6.0, Color(pal.moss, 0.25))
			else:
				deco.draw_line(a, b, Color(0, 0, 0, 0.35), 2.0, true)
	for c in session.world.crystals:
		if not c.alive: continue
		var pts: PackedVector2Array = c.poly.duplicate()
		pts.append(c.poly[0])
		deco.draw_polyline(pts, _hdr(Color(0.6, 1.0, 1.0, 0.9), 2.0), 1.5, true)

# ------------------------------------------------------------ sunwells & lures

func _draw_overlay(overlay: Node2D) -> void:
	var font := ThemeDB.fallback_font
	for gi in session.world.goals.size():
		var g = session.world.goals[gi]
		var p: Vector2 = g.pos
		var bloom: float = goal_bloom.get(gi, 0.0)
		var pulse := 0.85 + 0.15 * sin(t * 2.2 + gi)
		var sun: Color = pal.sun
		# corona rays
		for i in 12:
			var a := TAU * i / 12.0 + t * 0.08
			var l := (60.0 + 18.0 * sin(t * 1.3 + i)) * (1.0 + bloom * 0.8)
			overlay.draw_line(p + Vector2(cos(a), sin(a)) * 18.0, p + Vector2(cos(a), sin(a)) * l, Color(sun, 0.07), 6.0, true)
		for i in 5:
			overlay.draw_circle(p, 22.0 + i * 16.0 + bloom * 30.0, Color(sun, 0.05 * pulse))
		if bloom <= 0.0:
			overlay.draw_circle(p, 16.0 * pulse, _hdr(sun, 1.8))
			overlay.draw_arc(p, g.r, 0, TAU, 40, Color(sun, 0.25), 1.5, true)
			for i in 3:
				var a := t * (0.8 + i * 0.3) + i * 2.0
				overlay.draw_circle(p + Vector2(cos(a), sin(a)) * (26.0 + i * 6.0), 2.0, _hdr(sun, 2.0))
		else:
			overlay.draw_circle(p, 18.0 + bloom * 6.0, _hdr(sun, 2.4 * pulse))
	for i in session.world.lures.size():
		var l: Vector2 = session.world.lures[i]
		var cyan := Color(0.55, 1.0, 0.95)
		var hov: bool = i == hover_lure
		overlay.draw_arc(l, 250.0, 0, TAU, 64, Color(cyan, 0.06 if not hov else 0.16), 1.0, true)
		for k in 4:
			overlay.draw_circle(l, 10.0 + k * 9.0, Color(cyan, 0.05))
		overlay.draw_circle(l, 7.0 + sin(t * 4.0) * 1.0, _hdr(cyan, 2.4))
		for k in 5:
			var a := t * (1.5 + k * 0.2) + k * 1.3
			overlay.draw_circle(l + Vector2(cos(a), sin(a) * 0.7) * (16.0 + k * 3.0), 1.6, _hdr(cyan, 2.0))
	for wi in session.world.wilds.size():
		var w = session.world.wilds[wi]
		var gl: float = pollinated_glow.get(wi, 0.0)
		if gl > 0.0:
			for k in 6:
				var a := t * 0.9 + k * TAU / 6.0
				overlay.draw_circle(w.pos + Vector2(cos(a) * 30.0, -60.0 + sin(a) * 40.0), 1.8, _hdr(Color(1.0, 0.95, 0.6, gl), 2.2))
