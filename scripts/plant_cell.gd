extends Control
const Portrait = preload("res://scripts/plant_portrait.gd")
const Care = preload("res://scripts/plant_care.gd")
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
var _laying_out: bool = false
var _footer_height: float = 34.0

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
	title_label.add_theme_color_override("font_color", Color("284838"))
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(title_label)
	meta_label = Label.new()
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.clip_text = true
	meta_label.add_theme_font_size_override("font_size", 11)
	meta_label.add_theme_color_override("font_color", Color("617957"))
	add_child(meta_label)
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; pressed_at = 0; queue_redraw())
	resized.connect(_layout)
	title_label.minimum_size_changed.connect(_layout)
	meta_label.minimum_size_changed.connect(_layout)
	refresh()

func refresh() -> void:
	if not is_instance_valid(portrait): return
	portrait.plant = plant
	if plant.is_empty():
		title_label.text = "+" if zone == "display" else ""
		meta_label.text = "" if zone == "display" else "Plant here"
		tooltip_text = "A little space for something wonderful. Drag a plant here!"
	else:
		title_label.text = plant.get("name", "Unknown")
		var generation: int = int(plant.get("generation", 1))
		meta_label.add_theme_color_override("font_color",Color("617957"))
		var measure: Dictionary = Care.measurements(plant)
		meta_label.text = "%s · G%d" % [plant.get("type", "Leaf"), generation]
		if zone in ["bed","tray"] and not battle_locked:
			meta_label.text = "%.0f cm · %.0f g" % [float(measure.get("height_cm",0)),float(measure.get("weight_g",0))]
		if plant.get("withered",false):
			meta_label.text = "WITHERED · G%d" % generation
			meta_label.add_theme_color_override("font_color",Color("996540"))
		tooltip_text = "%s\n%s · %s · G%d\n%.1f cm tall · %.1f g\n%s\nTap to meet your plant · Hold for traits · Drag to plant" % [plant.get("name", ""), plant.get("type", ""), plant.get("rarity", "Common"), generation, float(measure.get("height_cm",0)),float(measure.get("weight_g",0)),_gene("pattern", "Solid")]
	_layout()
	queue_redraw()

func _gene(key: String, fallback: String) -> String:
	return str(plant.get("genes", {}).get(key, {}).get("dominant", fallback))

func _layout() -> void:
	if not is_instance_valid(portrait) or not is_instance_valid(meta_label) or _laying_out: return
	_laying_out = true
	var compact: bool = size.x < 96 or size.y < 85 or zone == "display"
	var title_size: int = 11 if compact else (14 if zone == "tray" else 13)
	var meta_size: int = 9 if compact else 11
	if title_label.get_theme_font_size("font_size") != title_size: title_label.add_theme_font_size_override("font_size",title_size)
	if meta_label.get_theme_font_size("font_size") != meta_size: meta_label.add_theme_font_size_override("font_size",meta_size)
	var title_height: float = ceilf(title_label.get_theme_font("font").get_height(title_size))
	var meta_height: float = ceilf(meta_label.get_theme_font("font").get_height(meta_size))
	if battle_locked and zone in ["bed","enemy"]:
		portrait.position = Vector2(3,1)
		portrait.size = Vector2(minf(96,size.x*0.44),maxf(1,size.y-3))
		title_label.position = Vector2(portrait.size.x+6,6)
		title_label.size = Vector2(maxf(1,size.x-portrait.size.x-12),title_height)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		meta_label.position = Vector2(portrait.size.x+6,8+title_height)
		meta_label.size = Vector2(maxf(1,size.x-portrait.size.x-12),meta_height)
		meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_laying_out = false
		return
	if not battle_locked and zone == "bed" and not plant.is_empty() and size.x >= 180 and size.y >= 70:
		# Wide garden beds have enough room to place the label beside the plant.
		# Give the specimen the full card height instead of shrinking its crown
		# to make room for two rows of text underneath.
		_footer_height = 0
		portrait.position = Vector2(5,3)
		portrait.size = Vector2(minf(size.x*0.42,size.y*1.05),maxf(1,size.y-6))
		var text_x: float = portrait.position.x+portrait.size.x+6
		var text_width: float = maxf(1,size.x-text_x-8)
		var text_y: float = floorf((size.y-title_height-meta_height-4)*0.5)
		title_label.position = Vector2(text_x,text_y)
		title_label.size = Vector2(text_width,title_height)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meta_label.position = Vector2(text_x,text_y+title_height+4)
		meta_label.size = Vector2(text_width,meta_height)
		meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_laying_out = false
		queue_redraw()
		return
	# Keep the footer to the actual font ascent/descent, including CJK fonts.
	# One clear gap above the name leaves the remaining height for the specimen.
	_footer_height = title_height+meta_height+4
	portrait.position = Vector2(3,1)
	portrait.size = Vector2(maxf(1,size.x-6),maxf(1,size.y-_footer_height-2))
	title_label.position = Vector2(4,size.y-_footer_height)
	title_label.size = Vector2(maxf(1,size.x-8),title_height)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.position = Vector2(4,size.y-2-meta_height)
	meta_label.size = Vector2(maxf(1,size.x-8),meta_height)
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_laying_out = false
	queue_redraw()

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
	var bg := Color("e4f0c7") if zone == "display" else Color("edf4ce")
	if zone == "tray": bg = Color("fff3cf")
	if zone == "enemy": bg = Color("f4e8d4")
	if plant.is_empty(): bg = Color("e0e8b9")
	if hovered: bg = bg.lightened(0.13)
	if selected: bg = Color("fff0ad")
	draw_style_box(_style(bg, Color("e49b51") if selected else Color("a2bc77")), rect)
	_draw_living_soil()
	_draw_grown_frame(rect)
	if not plant.is_empty():
		# Garden specimens have no missing health to communicate. Combat meters
		# stay beside the artwork instead of running through its root silhouette.
		if battle_locked and not fighter.is_empty() and zone in ["bed","enemy"]:
			var max_hp: float = float(fighter.get("max_hp",plant.get("stats",{}).get("vitality",100)))
			var hp: float = float(fighter.get("hp",max_hp))
			var bar_y: float = size.y-9
			var bar_start: float = portrait.position.x+portrait.size.x+7
			var bar_width: float = maxf(1,size.x-10-bar_start)
			draw_line(Vector2(bar_start,bar_y),Vector2(bar_start+bar_width,bar_y),Color("c7d7a2"),2)
			draw_line(Vector2(bar_start,bar_y),Vector2(bar_start+bar_width*clampf(hp/maxf(1,max_hp),0,1),bar_y),Color("66a757"),2)
			draw_line(Vector2(bar_start,bar_y+3),Vector2(bar_start+bar_width*clampf(float(fighter.get("energy",0))/100.0,0,1),bar_y+3),Color("e0aa4b"),1)
		if not plant.get("mature", true):
			draw_circle(Vector2(12, 12), 3, Color("f0b75c"))
		if plant.get("favorite", false):
			# A little pixel heart celebrates favourites without covering their leaves.
			draw_rect(Rect2(size.x-17,9,4,4),Color("e4866a"))
			draw_rect(Rect2(size.x-11,9,4,4),Color("e4866a"))
			draw_rect(Rect2(size.x-15,12,6,4),Color("e4866a"))
			draw_rect(Rect2(size.x-13,16,2,2),Color("e4866a"))
	if has_focus():
		draw_rect(rect.grow(-3), Color("dc994e"), false, 1)

func _draw_living_soil() -> void:
	if not is_instance_valid(portrait): return
	# A single quiet planting plane anchors the sprite. Its width follows the
	# artwork, so a wide bed cell never becomes a second striped illustration.
	var combat: bool = battle_locked and zone in ["bed","enemy"]
	var center_x: int = roundi(portrait.position.x+portrait.size.x*0.5)
	var base_y: int = roundi(portrait.position.y+portrait.size.y-3)
	var half: int = maxi(4,roundi(minf(portrait.size.x*0.26,portrait.size.y*0.32)))
	if plant.is_empty(): half = maxi(7,mini(half,33))
	if combat: half = mini(half,22)
	var earth := Color("c4bc87") if not plant.is_empty() else Color("c0b481")
	draw_rect(Rect2(center_x-half+3,base_y-2,maxi(2,half*2-6),2),earth)
	draw_rect(Rect2(center_x-half,base_y,maxi(2,half*2),2),earth.darkened(0.08))
	draw_rect(Rect2(center_x-half+4,base_y+2,maxi(2,half*2-8),1),earth.darkened(0.15))
	if plant.is_empty():
		# A tiny hopeful sprout is an invitation to plant, rather than an empty slot.
		var stem_y: float = maxf(14,base_y-12)
		draw_rect(Rect2(center_x-1,stem_y,2,10),Color("86ac62"))
		draw_rect(Rect2(center_x-7,stem_y-2,6,4),Color("8cb96a"))
		draw_rect(Rect2(center_x+1,stem_y-5,6,4),Color("a0c976"))
		for i in range(5):
			var x: int = center_x-half+4+posmod(i*13+index*3,maxi(1,half*2-8))
			draw_rect(Rect2(x,base_y,2,1),Color("e0d09b"))

func _draw_grown_frame(rect: Rect2) -> void:
	# Stepped, square joins give every packet and soil tile the same sprite scale.
	var frame_color := Color("c0d596")
	var shade_color := Color("f8f9de")
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
	if plant.is_empty() or battle_locked or plant.get("withered",false): return null
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
