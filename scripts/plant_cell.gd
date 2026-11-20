extends Control
const Portrait = preload("res://scripts/plant_portrait.gd")
const Care = preload("res://scripts/plant_care.gd")
const Locale = preload("res://scripts/localization.gd")
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
var _last_growth_second: int = -1
var _growth_progress: float = 0.0

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	set_meta("planting_cell_kind","grow_patch" if zone=="bed" else ("display_shelf" if zone=="display" else zone))
	if zone=="bed": set_meta("bed_index",index)
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
		title_label.text = "+ Add a plant" if zone=="display" else ("+ Plant a seed" if zone=="bed" else "+")
		meta_label.text = "Tap to choose" if zone in ["bed","display"] else ""
		tooltip_text = "Empty display shelf · tap to choose a mature plant" if zone=="display" else "Empty grow patch · tap to choose a seed or move a plant here"
		if battle_locked:
			title_label.text=""
			meta_label.text=""
	else:
		title_label.text = plant.get("name", "Unknown")
		var generation: int = int(plant.get("generation", 1))
		meta_label.add_theme_color_override("font_color",Color("617957"))
		var measure: Dictionary = Care.measurements(plant)
		meta_label.text = "%s · G%d" % [plant.get("type", "Leaf"), generation]
		if zone in ["bed","tray"] and not battle_locked:
			meta_label.text = "%.0f cm · %.0f g" % [float(measure.get("height_cm",0)),float(measure.get("weight_g",0))]
		if not plant.get("mature",true) and not battle_locked:
			_update_growth_label()
		elif meta_label.has_meta("plant_growth_label"): meta_label.remove_meta("plant_growth_label")
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
	var wrap_invitation: bool = plant.is_empty() and zone=="display" and size.x<88
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap_invitation else TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if wrap_invitation else TextServer.OVERRUN_TRIM_ELLIPSIS
	if wrap_invitation:
		title_size=9
		meta_size=8
	if plant.is_empty() and not wrap_invitation:
		# Even six narrow display shelves keep their invitation readable.
		var label_font: Font = title_label.get_theme_font("font")
		while title_size>8 and label_font.get_string_size(title_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x>maxf(1,size.x-8): title_size-=1
	if title_label.get_theme_font_size("font_size") != title_size: title_label.add_theme_font_size_override("font_size",title_size)
	if meta_label.get_theme_font_size("font_size") != meta_size: meta_label.add_theme_font_size_override("font_size",meta_size)
	var title_height: float = ceilf(title_label.get_theme_font("font").get_height(title_size))*(2 if wrap_invitation else 1)
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
		var text_y: float = floorf((size.y-title_height-meta_height-(11 if _is_growing() else 4))*0.5)
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
	_footer_height = title_height+meta_height+(11 if _is_growing() else 4)
	portrait.position = Vector2(3,1)
	portrait.size = Vector2(maxf(1,size.x-6),maxf(1,size.y-_footer_height-2))
	title_label.position = Vector2(4,size.y-_footer_height+(6 if _is_growing() else 0))
	title_label.size = Vector2(maxf(1,size.x-8),title_height)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.position = Vector2(4,size.y-2-meta_height)
	meta_label.size = Vector2(maxf(1,size.x-8),meta_height)
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_laying_out = false
	queue_redraw()

func _is_growing() -> bool:
	return not plant.is_empty() and not bool(plant.get("mature",true)) and not bool(plant.get("withered",false)) and not battle_locked

func _update_growth_label() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	_last_growth_second = now
	var remaining: int = maxi(0,int(plant.get("ready_at",now))-now)
	meta_label.text = "Growing · %ds" % remaining
	meta_label.set_meta("plant_growth_label",true)
	_growth_progress = float(Care.measurements(plant,now).get("growth_progress",0))
	Locale.apply_tree(meta_label)

func _process(delta: float) -> void:
	clock += delta
	if _is_growing() and _last_growth_second!=int(Time.get_unix_time_from_system()):
		_update_growth_label()
		queue_redraw()
	if not plant.is_empty() and pressed_at > 0 and clock - pressed_at > 0.55 and not held:
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
		if _is_growing():
			_draw_growth_meter()
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
	if plant.is_empty():
		_draw_empty_affordance()
		return
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

func _draw_empty_affordance() -> void:
	var middle := Vector2(roundf(size.x*0.5),roundf(portrait.position.y+portrait.size.y*0.52))
	var width: float = minf(56,maxf(18,portrait.size.x*0.62))
	var pit := Rect2(middle.x-width*0.5,middle.y+3,width,12)
	if zone=="display":
		pit = Rect2(middle.x-width*0.5,middle.y-12,width,25)
		draw_rect(pit,Color("d4e4b2"))
		draw_line(pit.position+Vector2(0,2),Vector2(pit.position.x,pit.end.y),Color("a6bb83"),2)
		draw_line(Vector2(pit.end.x,pit.position.y+2),pit.end,Color("a6bb83"),2)
		draw_rect(Rect2(pit.position.x-2,pit.end.y,width+4,3),Color("bcc79a"))
	else:
		draw_rect(pit,Color("d6cba2"))
		for segment in range(maxi(1,int(width/8))):
			var x: float = pit.position.x+segment*8
			draw_rect(Rect2(x,pit.position.y,4,1),Color("ad9b70"))
			draw_rect(Rect2(x,pit.end.y,4,1),Color("ad9b70"))
		draw_rect(Rect2(pit.position.x,pit.position.y+4,1,4),Color("ad9b70"))
		draw_rect(Rect2(pit.end.x,pit.position.y+4,1,4),Color("ad9b70"))
	if battle_locked: return
	var center_y: float = middle.y-1 if zone=="display" else middle.y-6
	var plus := Color("729451") if zone=="display" else Color("bd8e51")
	draw_rect(Rect2(middle.x-2,center_y-6,4,12),plus)
	draw_rect(Rect2(middle.x-6,center_y-2,12,4),plus)

func _draw_growth_meter() -> void:
	var x: float = 8
	var y: float = size.y-_footer_height+1
	var width: float = maxf(1,size.x-16)
	if zone=="bed" and size.x>=180 and size.y>=70:
		x = meta_label.position.x
		y = meta_label.position.y+meta_label.size.y+5
		width = meta_label.size.x
	draw_rect(Rect2(x,y,width,3),Color("d0d9a3"))
	draw_rect(Rect2(x,y,maxf(2,width*_growth_progress),3),Color("7aaf59"))
	# A compact hourglass marks a real growing plant; empty cells use a plus.
	draw_rect(Rect2(10,8,7,2),Color("c7944c"))
	draw_rect(Rect2(12,10,3,4),Color("e8bf75"))
	draw_rect(Rect2(10,14,7,2),Color("c7944c"))

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
