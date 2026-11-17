extends Control
## Actions are living growth: reaching fibers, settling spores and seeped pigment.
## Events refer to controls rather than fixed board coordinates, so an opponent's
## bed can slide into the home garden without detaching its effects.

var cell_lookup: Dictionary = {}
var _effects: Array[Dictionary] = []
var _serial: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func add_events(events: Array) -> void:
	for event in events:
		if not event is Dictionary:
			continue
		_serial += 1
		var effect: Dictionary = event.duplicate(true)
		effect["age"] = 0.0
		effect["seed"] = _serial * 137 + str(event.get("source", "")).hash() % 1000
		effect["duration"] = 1.9 if str(event.get("kind", "")) in ["spore", "toxin", "shade"] else 1.65
		effect["origin"] = _cell_point(str(event.get("source", "")), 0.42)
		effect["destination"] = _cell_point(str(event.get("target", "")), 0.42)
		_effects.append(effect)
	while _effects.size() > 60:
		_effects.pop_front()
	queue_redraw()

func clear_effects() -> void:
	_effects.clear()
	queue_redraw()

func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index]["age"] = float(_effects[index]["age"]) + delta
		if float(_effects[index]["age"]) >= float(_effects[index]["duration"]):
			_effects.remove_at(index)
	queue_redraw()

func _cell_point(id: String, height_ratio: float, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var cell: Variant = cell_lookup.get(id)
	if not is_instance_valid(cell) or not cell is Control:
		return fallback
	var global_point: Vector2 = cell.get_global_transform() * Vector2(cell.size.x * 0.5, cell.size.y * height_ratio)
	return get_global_transform().affine_inverse() * global_point

func _draw() -> void:
	for effect: Dictionary in _effects:
		var t: float = clampf(float(effect.age) / float(effect.duration), 0.0, 1.0)
		var opacity: float = minf(1.0, t * 8.0) * pow(1.0 - t, 0.65)
		var origin: Vector2 = _cell_point(str(effect.get("source", "")), 0.42, effect.origin)
		var target: Vector2 = _cell_point(str(effect.get("target", "")), 0.42, effect.destination)
		var soil: Vector2 = _cell_point(str(effect.get("target", "")), 0.79, target + Vector2(0, 24))
		var seed_value: float = float(effect.seed)
		match str(effect.get("kind", "root")):
			"entangle":
				_fiber(origin + Vector2(0, 22), soil, t, opacity, Color("86916a"), seed_value, 2.0)
				_entanglement(target, soil, t, opacity, seed_value)
			"parasite":
				_fiber(origin, target, t, opacity, Color("b0bca0"), seed_value, 1.4)
				_fiber(origin + Vector2(3, 0), target + Vector2(3, 0), t, opacity * 0.45, Color("c2c6a9"), seed_value + 2, 0.7)
				_sacs(target, t, opacity, Color("b8c6ae"), seed_value)
			"spore":
				_spores(origin, target, t, opacity, seed_value)
			"toxin":
				_seep(soil, t, opacity, seed_value)
			"bloom":
				_bloom(origin, t, opacity, seed_value)
				_spores(origin, target, t, opacity * 0.35, seed_value)
			"shade":
				_shade(target, t, opacity, seed_value)
			"wither":
				_wither(target, soil, t, opacity, seed_value)
			"devour":
				_devour(target, t, opacity)
			_:
				var healing: bool = float(effect.get("amount", 0)) < 0
				if origin.distance_to(target) > 12:
					_fiber(origin + Vector2(0, 22), soil, t, opacity * 0.8, Color("889974") if healing else Color("697f5d"), seed_value, 1.4)
				_root_network(soil, t, opacity, seed_value, healing)

func _fiber(origin: Vector2, target: Vector2, t: float, alpha: float, color: Color, phase: float, width: float) -> void:
	var distance: float = origin.distance_to(target)
	if distance < 1:
		return
	var normal: Vector2 = Vector2(-(target - origin).y, (target - origin).x).normalized()
	var growth: float = minf(1.0, t * 3.8)
	var points := PackedVector2Array()
	for i in range(43):
		var s: float = float(i) / 42.0 * growth
		var arch: float = sin(s * PI) * minf(42.0, distance * 0.14)
		var curl: float = sin(s * 17.0 + phase) * 4.0 * sin(s * PI)
		points.append(origin.lerp(target, s) + normal * (arch + curl))
	draw_polyline(points, Color(0.08, 0.16, 0.12, alpha * 0.8), width + 1.6, true)
	color.a = alpha * 0.8
	draw_polyline(points, color, width, true)
	# Searching root hairs branch from older tissue; the tip itself never flies.
	for i in range(5, points.size() - 3, 6):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var start: Vector2 = points[i]
		var end: Vector2 = start + normal * side * (5.0 + sin(phase + float(i)) * 3) + (target - origin).normalized() * 3
		draw_polyline(PackedVector2Array([start, start.lerp(end, 0.5) + normal * 2, end]), Color(color, alpha * 0.65), 0.7, true)

func _entanglement(target: Vector2, soil: Vector2, t: float, alpha: float, phase: float) -> void:
	var growth: float = minf(1.0, t * 3.0)
	for i in range(3):
		var points := PackedVector2Array()
		for j in range(30):
			var s: float = float(j) / 29.0 * growth
			var p: Vector2 = soil.lerp(target + Vector2(0, -7), s)
			p.x += sin(s * TAU * 1.4 + phase + float(i) * 2) * (12 - s * 5)
			points.append(p)
		draw_polyline(points, Color(0.42, 0.48, 0.28, alpha * 0.80), 1.0, true)

func _spores(origin: Vector2, target: Vector2, t: float, alpha: float, phase: float) -> void:
	for i in range(23):
		var offset: float = float(i) * 2.399 + phase
		var travel: float = clampf(t * 1.2 - float(i % 5) * 0.05, 0.0, 1.0)
		var point: Vector2 = origin.lerp(target, travel)
		var spread: float = 9.0 + sin(t * PI) * 20.0
		point += Vector2(cos(offset + t), sin(offset * 1.2)) * spread
		point += Vector2(sin(t * 2 + offset) * 4, t * 13 - 9)
		var r: float = 0.6 + float(i % 3) * 0.55
		draw_circle(point, r * 3.1, Color(0.60, 0.69, 0.56, alpha * 0.025))
		draw_circle(point, r, Color(0.73, 0.78, 0.66, alpha * (0.35 + float(i % 3) * 0.10)))

func _seep(center: Vector2, t: float, alpha: float, phase: float) -> void:
	for layer in range(3):
		var points := PackedVector2Array()
		var spread: float = (10 + float(layer) * 7) * (0.5 + t * 0.8)
		for i in range(37):
			var a: float = float(i) / 36 * TAU
			var rough: float = 1.0 + sin(a * 7 + phase) * 0.13 + sin(a * 11 + phase) * 0.07
			points.append(center + Vector2(cos(a), sin(a) * 0.36) * spread * rough)
		draw_colored_polygon(points, Color(0.26 + float(layer) * 0.03, 0.29, 0.14, alpha * 0.13))
	for i in range(10):
		var a: float = float(i) * 2.4 + phase
		var p: Vector2 = center + Vector2(cos(a) * 18, sin(a) * 6 - t * 12)
		draw_circle(p, 0.7, Color(0.57, 0.55, 0.27, alpha * 0.5))

func _sacs(center: Vector2, t: float, alpha: float, color: Color, phase: float) -> void:
	for i in range(5):
		var a: float = float(i) / 5 * TAU + phase
		var p: Vector2 = center + Vector2(cos(a), sin(a)) * (7 + t * 3)
		color.a = alpha * 0.4
		draw_circle(p, 1.4, color)

func _root_network(center: Vector2, t: float, alpha: float, phase: float, healing: bool) -> void:
	var color := Color("9eac80") if healing else Color("7e8a62")
	for i in range(7):
		var a: float = float(i) / 7 * TAU + phase
		var tip: Vector2 = center + Vector2(cos(a) * 25, sin(a) * 10)
		_fiber(center, tip, t, alpha * 0.6, color, a, 0.8)
	if healing:
		_sacs(center - Vector2(0, t * 22), t, alpha * 0.55, color, phase)

func _bloom(center: Vector2, t: float, alpha: float, phase: float) -> void:
	var opening: float = sin(minf(t * 1.5, 1.0) * PI * 0.6)
	for i in range(7):
		var angle: float = float(i) / 7 * TAU + phase * 0.01
		var direction := Vector2(cos(angle), sin(angle) * 0.8)
		var normal := Vector2(-direction.y, direction.x).normalized()
		var points := PackedVector2Array()
		for j in range(25):
			var s: float = float(j) / 24.0
			points.append(center + direction * s * 35 * opening + normal * sin(s * PI) * 6 * opening)
		for j in range(24, -1, -1):
			var s: float = float(j) / 24.0
			points.append(center + direction * s * 35 * opening - normal * sin(s * PI) * 6 * opening)
		draw_colored_polygon(points, Color(0.69, 0.58, 0.39, alpha * 0.14))
		draw_polyline(PackedVector2Array([center, center + direction * 30 * opening]), Color(0.77, 0.66, 0.45, alpha * 0.32), 0.7, true)
	for i in range(4, 0, -1):
		draw_circle(center, 3.5 + float(i) * 3.0 * opening, Color(0.85, 0.70, 0.43, alpha * 0.025))
	draw_circle(center, 3.0 + opening, Color(0.85, 0.74, 0.50, alpha * 0.45))

func _shade(center: Vector2, t: float, alpha: float, phase: float) -> void:
	for i in range(6):
		var a: float = float(i) * 2.4 + phase
		var c: Vector2 = center + Vector2(cos(a) * 12, sin(a) * 7 + t * 6)
		var points := PackedVector2Array()
		for j in range(25):
			var s: float = float(j) / 24 * TAU
			points.append(c + Vector2(cos(s) * 23, sin(s) * 10))
		draw_colored_polygon(points, Color(0.03, 0.09, 0.07, alpha * 0.10))

func _wither(target: Vector2, soil: Vector2, t: float, alpha: float, phase: float) -> void:
	for i in range(8):
		var a: float = float(i) * 2.4 + phase
		var p: Vector2 = target.lerp(soil, t * 0.8) + Vector2(cos(a) * (8 + t * 6), sin(a) * 11)
		var points := PackedVector2Array([p, p + Vector2(2, 3), p + Vector2(4, 2), p + Vector2(2, 5)])
		draw_colored_polygon(points, Color(0.46, 0.44, 0.32, alpha * 0.30))

func _devour(center: Vector2, t: float, alpha: float) -> void:
	var closing: float = 1 - minf(t * 2, 1.0)
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array([center + Vector2(side * closing * 20, -15), center + Vector2(side * (8 + closing * 18), 2), center + Vector2(0, 15), center])
		draw_colored_polygon(points, Color(0.43, 0.38, 0.29, alpha * 0.3))
