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
	title_label.add_theme_font_size_override("font_size", 13 if zone != "tray" else 14)
	title_label.add_theme_color_override("font_color", Color("d4dac6"))
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(title_label)
	meta_label = Label.new()
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.clip_text = true
	meta_label.add_theme_font_size_override("font_size", 11)
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
	# A stepped peat hollow: coherent clusters instead of antialiased contours.
	var footer: float = 26.0 if zone == "display" else 31.0
	var base_y: int = roundi((size.y-footer-3)*0.88+3)
	var center_x: int = roundi(size.x*0.5)
	var half: int = mini(roundi(size.x*0.35),94)
	for layer in range(4):
		var span: int = half-4*layer
		var y: int = base_y-4+layer*4
		var earth: Color = Color("1a302b") if layer%2==0 else Color("20372c")
		draw_rect(Rect2(center_x-span,y,maxi(4,span*2),4),earth)
		if layer in [0,3]: draw_rect(Rect2(center_x-span+4,y,maxi(4,span*2-8),1),Color("3b4e34"))
	for i in range(30):
		var x: int = center_x-half+posmod(i*23+index*7,maxi(1,half*2))
		var y: int = base_y-2+posmod(i*7+index*3,13)
		var tint := Color("40533a") if i%5==0 else Color("2d4332")
		draw_rect(Rect2(x,y,2 if i%3 else 4,1),tint)
	# Short square turns are thin root hairs, not straight projectile-like lines.
	if not plant.is_empty():
		for i in range(4):
			var side: int = -1 if i%2==0 else 1
			var length: int = mini(half-4,12+i*7)
			var x: int = center_x+side*4
			var y: int = base_y+3+int(i/2)*3
			var root_color := Color("4b6243")
			draw_rect(Rect2(mini(x,x+side*length),y,length,1),root_color)
			draw_rect(Rect2(x+side*length,y,1,3),root_color)
			draw_rect(Rect2(mini(x+side*length,x+side*(length+4)),y+3,4,1),Color("354b34"))

func _draw_grown_frame(rect: Rect2) -> void:
	# Stepped, square joins give every packet and soil tile the same sprite scale.
	var frame_color := Color("48634a")
	var shade_color := Color("142d2a")
	for corner in range(4):
		var right: bool = corner%2==1
		var lower: bool = corner>=2
		var x: int = roundi(rect.end.x-4 if right else rect.position.x+3)
		var y: int = roundi(rect.end.y-4 if lower else rect.position.y+3)
		var horizontal: int = -1 if right else 1
		var vertical: int = -1 if lower else 1
		draw_rect(Rect2(mini(x,x+horizontal*9),y,10,1),frame_color)
		draw_rect(Rect2(x,mini(y,y+vertical*5),1,6),frame_color)
		draw_rect(Rect2(x+horizontal,y+vertical,2,2),shade_color)

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
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
