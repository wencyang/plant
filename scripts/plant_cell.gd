extends Control
const Portrait = preload("res://scripts/plant_portrait.gd")
signal chosen(id: String, zone: String, index: int)
signal inspected(id: String)
signal dropped(id: String, zone: String, index: int)
var plant: Dictionary = {}
var zone: String = "bed"
var index: int = 0
var selected: bool = false
var battle_locked: bool = false
var fighter: Dictionary = {}
var portrait: Control
var title_label: Label
var meta_label: Label
var hovered: bool = false
var pressed_at: float = 0.0
var held: bool = false
var clock: float = 0.0

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	portrait = Portrait.new()
	portrait.plant = plant
	add_child(portrait)
	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12 if zone != "tray" else 14)
	title_label.add_theme_color_override("font_color", Color("d4dac6"))
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(title_label)
	meta_label = Label.new()
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.clip_text = true
	meta_label.add_theme_font_size_override("font_size", 10)
	meta_label.add_theme_color_override("font_color", Color("84998c"))
	add_child(meta_label)
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; pressed_at = 0; queue_redraw())
	resized.connect(_layout)
	refresh()

func refresh() -> void:
	if not is_instance_valid(portrait): return
	portrait.plant = plant
	if plant.is_empty():
		title_label.text = "+" if zone == "display" else ""
		meta_label.text = "" if zone == "display" else "%02d" % (index + 1)
		tooltip_text = "Empty soil · drag a plant here, or select a packet and tap"
	else:
		title_label.text = plant.get("name", "Unknown")
		var generation: int = int(plant.get("generation", 1))
		meta_label.text = "%s · G%d" % [plant.get("type", "Leaf"), generation]
		if zone == "tray":
			meta_label.text = "%s · HP %d · FREE" % [plant.get("type","Leaf"),plant.get("stats",{}).get("vitality",100)] if plant.get("mature",true) else "%s · GROWING" % plant.get("type","Leaf")
		tooltip_text = "%s\n%s · %s · G%d\n%s\nTap to inspect · Hold for genes · Drag to plant" % [plant.get("name", ""), plant.get("type", ""), plant.get("rarity", "Common"), generation, _gene("pattern", "Solid")]
	_layout()
	queue_redraw()

func _gene(key: String, fallback: String) -> String:
	return str(plant.get("genes", {}).get(key, {}).get("dominant", fallback))

func _layout() -> void:
	if not is_instance_valid(portrait): return
	if battle_locked and zone in ["bed","enemy"]:
		portrait.position = Vector2(4,0)
		portrait.size = Vector2(minf(80,size.x*0.42),size.y-2)
		title_label.position = Vector2(portrait.size.x+6,9)
		title_label.size = Vector2(maxf(1,size.x-portrait.size.x-12),18)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		meta_label.position = Vector2(portrait.size.x+6,29)
		meta_label.size = Vector2(maxf(1,size.x-portrait.size.x-12),14)
		meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		return
	var footer: float = 31.0 if zone != "display" else 26.0
	portrait.position = Vector2(5, 1)
	portrait.size = Vector2(maxf(1, size.x - 10), maxf(1, size.y - footer - 2))
	title_label.position = Vector2(4, size.y - footer)
	title_label.size = Vector2(maxf(1, size.x - 8), 18)
	meta_label.position = Vector2(4, size.y - 15)
	meta_label.size = Vector2(maxf(1, size.x - 8), 14)

func _process(delta: float) -> void:
	clock += delta
	if pressed_at > 0 and clock - pressed_at > 0.55 and not held:
		held = true
		inspected.emit(str(plant.get("id", "")))
	if not fighter.is_empty() and is_instance_valid(portrait):
		portrait.alive = fighter.get("alive", true)
		portrait.energy = float(fighter.get("energy", 0))
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	var bg := Color("17251f") if zone == "display" else Color("14221e")
	if zone == "tray": bg = Color("1a2b25")
	if hovered: bg = bg.lightened(0.055)
	draw_style_box(_style(bg, Color("738575") if selected else Color("334b3c")), rect)
	_draw_living_soil()
	_draw_grown_frame(rect)
	if not plant.is_empty():
		var max_hp: float = float(plant.get("stats", {}).get("vitality", 100))
		var hp: float = float(fighter.get("hp", max_hp))
		var bar_y: float = size.y - 8 if battle_locked and zone in ["bed","enemy"] else size.y - (33 if zone != "display" else 28)
		if zone != "display":
			draw_line(Vector2(12, bar_y), Vector2(size.x - 12, bar_y), Color("263b30"), 2)
			draw_line(Vector2(12, bar_y), Vector2(12 + (size.x - 24) * clampf(hp / maxf(1, max_hp), 0, 1), bar_y), Color("839a6c"), 2)
			if not fighter.is_empty():
				draw_line(Vector2(12, bar_y + 3), Vector2(12 + (size.x - 24) * clampf(float(fighter.get("energy", 0)) / 100.0, 0, 1), bar_y + 3), Color("b59b69"), 1)
		if not plant.get("mature", true):
			draw_circle(Vector2(12, 12), 3, Color("d6b67b"))
		if plant.get("favorite", false):
			draw_circle(Vector2(size.x - 12, 12), 2.5, Color("ceb582"))
	if has_focus():
		draw_rect(rect.grow(-3), Color("9aaf94"), false, 1)

func _draw_living_soil() -> void:
	# A moist, irregular planting hollow, drawn beneath the actual roots. Its
	# contour and strata remain quiet enough to read a plant's tissue markings.
	var footer: float = 26.0 if zone == "display" else 31.0
	var base_y: float = (size.y - footer - 3.0) * 0.88 + 3.0
	var center := Vector2(size.x * 0.5, base_y)
	var width: float = minf(size.x * 0.37, 105.0)
	var depth: float = minf(size.y * 0.135, 17.0)
	var phase: float = float(index) * 1.79 + (1.5 if zone == "display" else 0.0)
	for layer in range(3):
		var points := PackedVector2Array()
		var scale_factor: float = 1.1 - float(layer) * 0.18
		for j in range(49):
			var a: float = float(j) / 48.0 * TAU
			var edge: float = 1.0 + sin(a * 5 + phase) * 0.07 + sin(a * 11 + phase) * 0.035
			points.append(center + Vector2(cos(a) * width, sin(a) * depth) * scale_factor * edge)
		draw_colored_polygon(points, Color(0.09 - float(layer) * 0.008, 0.125 - float(layer) * 0.009, 0.096 - float(layer) * 0.009, 0.50))
		if layer != 1:
			draw_polyline(points, Color(0.29, 0.34, 0.23, 0.14 if layer == 0 else 0.09), 0.7, true)
	# Sediment and pale mineral flecks settle in the lower layers.
	for i in range(46):
		var x: float = fposmod(float(i * 43 + index * 19), maxf(1, size.x - 18)) + 9
		var y: float = base_y - depth * 0.55 + fposmod(float(i * 17 + index * 7), maxf(1, depth * 1.8))
		var tint := Color(0.51, 0.49, 0.33, 0.11) if i % 3 == 0 else Color(0.31, 0.39, 0.28, 0.12)
		draw_line(Vector2(x, y), Vector2(x + (1.7 if i % 4 else 3.3), y + 0.5), tint, 0.65)
	# Roots wind through the hollow, never as a rectangular grid or a selection glow.
	for i in range(5):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var start: Vector2 = center + Vector2(side * (4.0 + float(i) * 2), -0.5)
		var root_path := PackedVector2Array()
		for j in range(20):
			var t: float = float(j) / 19.0
			var reach: float = width * (0.45 + float(i % 3) * 0.16)
			root_path.append(start + Vector2(side * reach * t, sin(t * 5 + phase + float(i)) * depth * 0.20 + t * 3))
		draw_polyline(root_path, Color(0.34, 0.39, 0.27, 0.19 if not plant.is_empty() else 0.10), 0.75, true)
		for j in [7, 12, 16]:
			var point: Vector2 = root_path[j]
			draw_polyline(PackedVector2Array([point, point + Vector2(side * 2, 2), point + Vector2(side * 6, 3)]), Color(0.41, 0.43, 0.30, 0.13), 0.55, true)
	# A little decaying tissue at a bed's edge places it inside a growing world.
	for i in range(3):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var p: Vector2 = center + Vector2(side * width * (0.73 + float(i) * 0.08), depth * 0.55)
		var leaf := PackedVector2Array([p, p + Vector2(side * 8, -2), p + Vector2(side * 6, 3), p + Vector2(side * 2, 3)])
		draw_colored_polygon(leaf, Color(0.31, 0.33, 0.22, 0.14))

func _draw_grown_frame(rect: Rect2) -> void:
	if zone == "tray":
		return
	# Thin, fibrous chitin binds the soil dividers, with little seams at joins.
	for side in [0, 1]:
		var points := PackedVector2Array()
		for i in range(31):
			var t: float = float(i) / 30.0
			var x: float = rect.position.x + t * rect.size.x
			var y: float = rect.position.y + (2 if side == 0 else rect.size.y - 3)
			y += sin(t * 11 + float(index) * 2 + float(side)) * 0.75
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.28, 0.35, 0.25, 0.18), 0.65, true)
	for corner in range(4):
		var right: bool = corner % 2 == 1
		var lower: bool = corner >= 2
		var p := Vector2(size.x - 4 if right else 4, size.y - 4 if lower else 4)
		var side: float = -1.0 if right else 1.0
		var down: float = -1.0 if lower else 1.0
		draw_polyline(PackedVector2Array([p + Vector2(0, down * 11), p + Vector2(side * 1, down * 4), p + Vector2(side * 5, down), p + Vector2(side * 15, down * 2)]), Color(0.36, 0.42, 0.30, 0.22), 0.8, true)

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6 if zone == "tray" else 3)
	return s

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed_at = clock
			held = false
		else:
			pressed_at = 0
			if not held: chosen.emit(str(plant.get("id", "")), zone, index)
		accept_event()
	if event.is_action_pressed("ui_accept"):
		chosen.emit(str(plant.get("id", "")), zone, index)
		accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	pressed_at = 0
	if plant.is_empty() or battle_locked: return null
	var p := Portrait.new()
	p.plant = plant
	p.custom_minimum_size = Vector2(100, 110)
	p.size = Vector2(100, 110)
	set_drag_preview(p)
	return {"plant_id": str(plant.get("id", ""))}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not battle_locked and data is Dictionary and data.has("plant_id")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(str(data.plant_id), zone, index)
