extends Control
## A small, walkable breeding adventure. Physical routes are opened only by the
## inherited capabilities accepted by GardenState; this view never creates DNA.
signal action_requested(action: String,key: String)
signal returned_home()
const Portrait = preload("res://scripts/plant_portrait.gd")
const Locale = preload("res://scripts/localization.gd")
const SceneArt = preload("res://scripts/habitat_scene.gd")
const INK := Color("304a40")
const MUTED := Color("60765b")
const WARM := Color("a75e36")
const WORLD_SIZE := Vector2(1320,760)
const SPEED: float=185.0
const INTERACT_DISTANCE: float=86.0
const POSITIONS := {
	"river_fan":Vector2(150,265),"floatcap":Vector2(400,300),
	"gripvine":Vector2(135,570),"stone_root":Vector2(410,590),
	"crossing":Vector2(540,420),"moonbell":Vector2(910,280),
	"gate":Vector2(1040,420)
}
var state = null
var waiting: bool=false
var player_position:=Vector2(255,435)
var _map_rect:=Rect2()
var _camera:=Vector2.ZERO
var _world_scale: float=1.0
var _time: float=0.0
var _route_progress: float=0.0
var _route_seen: String=""
var _stage_seen: String=""
var _info: Dictionary={}
var _plants: Array=[]
var _portraits: Dictionary={}
var _captions: Dictionary={}
var _rows: Dictionary={}
var _header: PanelContainer
var _footer: PanelContainer
var _title: Label
var _objective: Label
var _target_label: Label
var _hint_label: Label
var _legend: Label
var _interact_button: Button
var _breed_button: Button
var _journal_button: Button
var _garden_button: Button
var _home_button: Button
var _dpad: GridContainer
var _map_clip: Control
var _world_layer: Control
var _backdrop: Texture2D
var _route_plant: Control
var _lantern_plant: Control
var _goal_tease: PanelContainer
var _goal_portrait: Control
var _waypoints: Array[Vector2]=[]
var _walk_action: String=""
var _walk_key: String=""
var _held_direction:=Vector2.ZERO
var _hint_override: String=""
var _tick: int=-1
var _font: Font

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	focus_mode=Control.FOCUS_ALL
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_backdrop=SceneArt.texture_for("Mosswood")
	var face:=SystemFont.new()
	face.font_names=PackedStringArray(["Avenir Next","Helvetica Neue","Arial","DejaVu Sans"])
	_font=face
	_map_clip=Control.new()
	_map_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_map_clip.clip_contents=true
	add_child(_map_clip)
	_world_layer=Control.new()
	_world_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_world_layer.size=WORLD_SIZE
	_map_clip.add_child(_world_layer)
	_build_ui()
	_build_goal_tease()
	resized.connect(_layout)
	refresh()
	_layout()
	grab_focus()

func _style(color: Color,border: Color=Color("a4b487"),padding: int=12) -> StyleBoxFlat:
	var result:=StyleBoxFlat.new()
	result.bg_color=color
	result.border_color=border
	result.set_border_width_all(2)
	result.set_content_margin_all(padding)
	return result

func _label(text: String,font_size: int=14,color: Color=INK) -> Label:
	var result:=Label.new()
	result.text=text
	result.add_theme_font_override("font",_font)
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	return result

func _button(text: String,action: String,key: String="") -> Button:
	var result:=Button.new()
	result.text=text
	result.clip_text=true
	result.focus_mode=Control.FOCUS_ALL
	result.set_meta("adventure_action",action)
	result.add_theme_font_override("font",_font)
	result.add_theme_font_size_override("font_size",14)
	for kind: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		result.add_theme_color_override(kind,INK)
	result.add_theme_stylebox_override("normal",_style(Color("e8efc0"),Color("9aae7c"),8))
	result.add_theme_stylebox_override("hover",_style(Color("fff0ba"),Color("c79f63"),8))
	result.add_theme_stylebox_override("pressed",_style(Color("f0ca99"),Color("bb8f53"),8))
	result.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),Color("c48249"),8))
	result.add_theme_stylebox_override("disabled",_style(Color("e3e7d0"),Color("b4bca3"),8))
	result.pressed.connect(func(): _request(action,key))
	return result

func _build_ui() -> void:
	_header=PanelContainer.new()
	_header.set_meta("adventure_header",true)
	_header.add_theme_stylebox_override("panel",_style(Color("fff8df")))
	add_child(_header)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	_header.add_child(column)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	column.add_child(row)
	_title=_label("Moonbell Crossing",23)
	_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_title)
	_home_button=_button("Home","home")
	_home_button.custom_minimum_size=Vector2(58,36)
	row.add_child(_home_button)
	_objective=_label("A mysterious flower is glowing across the stream.",15,WARM)
	_objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_objective.set_meta("adventure_objective",true)
	column.add_child(_objective)
	_footer=PanelContainer.new()
	_footer.set_meta("adventure_footer",true)
	_footer.add_theme_stylebox_override("panel",_style(Color("fff8df")))
	add_child(_footer)
	var bottom:=VBoxContainer.new()
	bottom.add_theme_constant_override("separation",6)
	_footer.add_child(bottom)
	_target_label=_label("Four cuttings, two ways across.",16)
	_target_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_target_label.set_meta("adventure_target",true)
	bottom.add_child(_target_label)
	var action_row:=HBoxContainer.new()
	action_row.add_theme_constant_override("separation",8)
	bottom.add_child(action_row)
	_dpad=GridContainer.new()
	_dpad.columns=3
	_dpad.add_theme_constant_override("h_separation",2)
	_dpad.add_theme_constant_override("v_separation",2)
	action_row.add_child(_dpad)
	for direction: Vector2 in [Vector2.ZERO,Vector2.UP,Vector2.ZERO,Vector2.LEFT,Vector2.DOWN,Vector2.RIGHT]:
		if direction==Vector2.ZERO:
			var empty:=Control.new()
			empty.custom_minimum_size=Vector2(34,30)
			_dpad.add_child(empty)
		else:
			var letter: String="W" if direction==Vector2.UP else ("A" if direction==Vector2.LEFT else ("S" if direction==Vector2.DOWN else "D"))
			var key:=_button(letter,"move")
			key.focus_mode=Control.FOCUS_NONE
			key.custom_minimum_size=Vector2(34,30)
			key.add_theme_font_size_override("font_size",12)
			key.button_down.connect(func(): _waypoints.clear();_held_direction=direction)
			key.button_up.connect(func(): _held_direction=Vector2.ZERO;grab_focus())
			_dpad.add_child(key)
	var action_column:=VBoxContainer.new()
	action_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	action_column.add_theme_constant_override("separation",4)
	action_row.add_child(action_column)
	_interact_button=_button("Meet this plant [E]","interact")
	_interact_button.custom_minimum_size.y=36
	action_column.add_child(_interact_button)
	_hint_label=_label("Walk up to a plant, take a cutting, and try a cross.",12,MUTED)
	_hint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_hint_label.max_lines_visible=3
	action_column.add_child(_hint_label)
	var tools:=HBoxContainer.new()
	tools.add_theme_constant_override("separation",7)
	bottom.add_child(tools)
	_breed_button=_button("Breed here","cross")
	_breed_button.add_theme_stylebox_override("normal",_style(Color("f8d3a4"),Color("bf945d"),8))
	_journal_button=_button("Field notes","journal")
	_garden_button=_button("Garden","garden")
	for button: Button in [_breed_button,_journal_button,_garden_button]:
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y=36
		tools.add_child(button)
	_legend=_label("WASD / arrows · Tap to walk · E to meet · B to breed",11,MUTED)
	_legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_legend)

func _build_goal_tease() -> void:
	_goal_tease=PanelContainer.new()
	_goal_tease.mouse_filter=Control.MOUSE_FILTER_STOP
	_goal_tease.add_theme_stylebox_override("panel",_style(Color(1.0,0.97,0.85,0.94),Color("adac79"),6))
	_goal_tease.set_meta("adventure_tease",true)
	_map_clip.add_child(_goal_tease)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	_goal_tease.add_child(row)
	_goal_portrait=Portrait.new()
	_goal_portrait.custom_minimum_size=Vector2(43,60)
	row.add_child(_goal_portrait)
	var words:=VBoxContainer.new()
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",3)
	row.add_child(words)
	var clue:=_label("Beyond the stream",11,WARM)
	clue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	words.add_child(clue)
	var walk:=_button("Walk there →","walk_moonbell")
	walk.add_theme_font_size_override("font_size",11)
	walk.custom_minimum_size.y=27
	words.add_child(walk)

func _layout() -> void:
	if not is_instance_valid(_header): return
	var compact: bool=size.x<700
	var margin: float=8 if compact else 18
	var width: float=maxf(1,size.x-margin*2)
	_title.add_theme_font_size_override("font_size",18 if compact else 24)
	_objective.add_theme_font_size_override("font_size",13 if compact else 16)
	_header.position=Vector2(margin,margin)
	_header.size=Vector2(width,0)
	_header.size.y=_header.get_combined_minimum_size().y
	_footer.size=Vector2(width,0)
	_footer.size.y=_footer.get_combined_minimum_size().y
	_footer.position=Vector2(margin,size.y-margin-_footer.size.y)
	_map_rect=Rect2(Vector2(margin,_header.position.y+_header.size.y+8),Vector2(width,maxf(1,_footer.position.y-_header.position.y-_header.size.y-16)))
	_world_scale=0.84 if compact else minf(1.23,maxf(0.92,_map_rect.size.x/WORLD_SIZE.x))
	_map_clip.position=_map_rect.position
	_map_clip.size=_map_rect.size
	_goal_tease.position=Vector2(maxf(4,_map_rect.size.x-172),9)
	_goal_tease.size=Vector2(162,78)
	_update_camera()
	queue_redraw()

func refresh() -> void:
	if state!=null and state.has_method("adventure_info"):
		_info=state.adventure_info()
		_plants=state.adventure_plants()
	else:
		_info={"stage":"shore","route":"","cuttings":{}}
	var route: String=str(_info.get("route",""))
	if route!=_route_seen:
		_route_seen=route
		_route_progress=0.0 if not route.is_empty() else 1.0
		_waypoints.clear()
	_stage_seen=str(_info.get("stage","shore"))
	if is_instance_valid(_objective):
		_objective.text=str(_info.get("objective","A mysterious flower is glowing across the stream."))
	_sync_specimens()
	_update_hint()
	_layout()
	Locale.apply_tree(self)

func _sync_specimens() -> void:
	if not is_instance_valid(_world_layer): return
	for row: Dictionary in _plants:
		var key: String=str(row.get("key",""))
		if not POSITIONS.has(key): continue
		_rows[key]=row
		if key=="moonbell" and is_instance_valid(_goal_portrait): _goal_portrait.plant=row.get("plant",{})
		var art: Control=_portraits.get(key)
		if not is_instance_valid(art):
			art=Portrait.new()
			art.set_meta("adventure_specimen",key)
			_world_layer.add_child(art)
			_portraits[key]=art
			var caption:=_label(str(row.get("name",key)),15,INK)
			caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			caption.set_meta("adventure_patch_name",key)
			_world_layer.add_child(caption)
			_captions[key]=caption
		art.plant=row.get("plant",{})
		var p: Vector2=POSITIONS[key]
		art.position=p+Vector2(-48,-104)
		art.size=Vector2(96,111)
		var caption: Label=_captions[key]
		caption.text=str(row.get("name",key))
		caption.position=p+Vector2(-90,11)
		caption.size=Vector2(180,25)
	if state!=null:
		_route_plant=_placed_specimen(_route_plant,str(_info.get("route_plant_id","")),Vector2(650,421),Vector2(68,86),"route")
		_lantern_plant=_placed_specimen(_lantern_plant,str(_info.get("lantern_id","")),Vector2(1088,410),Vector2(90,116),"lantern")

func _placed_specimen(art: Control,id: String,foot: Vector2,extent: Vector2,role: String) -> Control:
	var specimen: Dictionary=state.get_plant(id).duplicate(true)
	if specimen.is_empty():
		if is_instance_valid(art): art.visible=false
		return art
	# The permanent landscape grows from its planted cutting. Its recorded DNA
	# stays visible even if the original later ages, is sold, or is mutated.
	var record: Dictionary=_info.get("route_record" if role=="route" else "lantern_record",{})
	var proof: Dictionary=record.get("evidence",{})
	for key: String in proof: specimen[key]=proof[key]
	specimen.mature=true
	specimen.withered=false
	specimen.life_age=0.0
	if not is_instance_valid(art):
		art=Portrait.new()
		art.set_meta("adventure_placed",role)
		_world_layer.add_child(art)
	art.visible=true
	art.plant=specimen
	art.position=foot+Vector2(-extent.x*0.5,-extent.y)
	art.size=extent
	return art

func hotspot_position(key: String) -> Vector2:
	return POSITIONS.get(key,Vector2(-1,-1))

func _stream_center(y: float) -> float:
	return 650.0+sin(y*0.008+0.2)*22.0+sin(y*0.019)*7.0

func is_walkable(point: Vector2) -> bool:
	if point.x<40 or point.y<80 or point.x>WORLD_SIZE.x-40 or point.y>WORLD_SIZE.y-40: return false
	var in_water: bool=absf(point.x-_stream_center(point.y))<74.0
	if in_water and (str(_info.get("route","")).is_empty() or absf(point.y-420)>43): return false
	if point.x>1076 and point.x<1110:
		if str(_info.get("stage","shore"))!="restored" or absf(point.y-420)>82: return false
	return true

func _update_camera() -> void:
	if not is_instance_valid(_world_layer) or _map_rect.size.x<1: return
	var extent: Vector2=_map_rect.size/_world_scale
	var forward: float=56.0 if size.x<700 else 0.0
	var desired: Vector2=player_position+Vector2(forward,-22)-extent*0.5
	_camera=Vector2(clampf(desired.x,0,maxf(0,WORLD_SIZE.x-extent.x)),clampf(desired.y,0,maxf(0,WORLD_SIZE.y-extent.y)))
	_world_layer.position=-_camera*_world_scale
	_world_layer.scale=Vector2.ONE*_world_scale
	if is_instance_valid(_goal_tease):
		var flower: Vector2=(POSITIONS.moonbell-_camera)*_world_scale
		var enough_space: bool=_map_rect.size.x>190 and _map_rect.size.y>150
		_goal_tease.visible=enough_space and size.x<700 and str(_info.get("stage","shore")) in ["shore","island"] and not Rect2(Vector2(12,100),_map_rect.size-Vector2(24,120)).has_point(flower)

func _request(action: String,key: String="") -> void:
	if action=="move": return
	if action=="walk_moonbell":
		walk_to(POSITIONS.moonbell+Vector2(-12,40),"moonbell","moonbell")
		return
	if action=="home": returned_home.emit(); return
	if waiting: return
	if action=="interact": interact(); return
	_held_direction=Vector2.ZERO
	_waypoints.clear()
	action_requested.emit(action,key)

func nearest_hotspot() -> Dictionary:
	var nearest: Dictionary={}
	var distance: float=INTERACT_DISTANCE
	for key: String in POSITIONS:
		var here: float=player_position.distance_to(POSITIONS[key])
		if here<distance:
			nearest={"key":key,"position":POSITIONS[key],"distance":here}
			distance=here
	return nearest

func interact() -> void:
	if waiting: return
	var target: Dictionary=nearest_hotspot()
	if target.is_empty():
		_hint_override="Walk closer to a plant, the riverbank, or the old gate."
		_update_hint()
		return
	var key: String=str(target.key)
	var action: String="inspect_parent"
	if key in ["crossing","gate","moonbell"]: action=key
	_request(action,"moonbell" if key=="moonbell" else (key if action=="inspect_parent" else ""))

func walk_to(point: Vector2,action: String="",key: String="") -> void:
	if waiting: return
	grab_focus()
	_held_direction=Vector2.ZERO
	_hint_override=""
	_waypoints.clear()
	_walk_action=action
	_walk_key=key
	var destination:=Vector2(clampf(point.x,45,WORLD_SIZE.x-45),clampf(point.y,85,WORLD_SIZE.y-45))
	if destination.x>1076 and str(_info.get("stage","shore"))!="restored":
		destination=POSITIONS.gate+Vector2(-5,15)
		_walk_action="gate"
		_walk_key=""
	var west: bool=player_position.x<_stream_center(player_position.y)
	var going_east: bool=destination.x>_stream_center(destination.y)
	if destination.x<1090 and player_position.x>1090:
		_waypoints.append(Vector2(1140,420))
		_waypoints.append(Vector2(1045,420))
	if west==going_east:
		if str(_info.get("route","")).is_empty():
			destination=POSITIONS.crossing+Vector2(0,35)
			_walk_action="crossing"
			_walk_key=""
		else:
			_waypoints.append(Vector2(535 if west else 790,420))
			_waypoints.append(Vector2(790 if west else 535,420))
	if destination.x>1090 and player_position.x<1090 and str(_info.get("stage","shore"))=="restored":
		_waypoints.append(Vector2(1045,420))
		_waypoints.append(Vector2(1140,420))
	if not is_walkable(destination):
		destination=Vector2(540 if west else 790,420)
	_waypoints.append(destination)

func _move(direction: Vector2,distance: float) -> bool:
	if direction.length_squared()<0.0001: return false
	var previous: Vector2=player_position
	var remaining: float=maxf(0,distance)
	while remaining>0.001:
		var step: float=minf(8.0,remaining)
		var next: Vector2=player_position+direction.normalized()*step
		var before: Vector2=player_position
		if is_walkable(next): player_position=next
		else:
			var slide_x:=Vector2(next.x,player_position.y)
			if is_walkable(slide_x): player_position=slide_x
			var slide_y:=Vector2(player_position.x,next.y)
			if is_walkable(slide_y): player_position=slide_y
		remaining-=step
		if player_position.is_equal_approx(before): break
	return not player_position.is_equal_approx(previous)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_time+=delta
	_route_progress=move_toward(_route_progress,1.0,delta*1.4)
	if not waiting:
		var direction: Vector2=_held_direction
		var owns_focus: bool=get_viewport().gui_get_focus_owner()==self or get_viewport().gui_get_focus_owner()==null
		if Input.is_physical_key_pressed(KEY_W) or (owns_focus and Input.is_physical_key_pressed(KEY_UP)): direction.y-=1
		if Input.is_physical_key_pressed(KEY_S) or (owns_focus and Input.is_physical_key_pressed(KEY_DOWN)): direction.y+=1
		if Input.is_physical_key_pressed(KEY_A) or (owns_focus and Input.is_physical_key_pressed(KEY_LEFT)): direction.x-=1
		if Input.is_physical_key_pressed(KEY_D) or (owns_focus and Input.is_physical_key_pressed(KEY_RIGHT)): direction.x+=1
		if direction!=Vector2.ZERO:
			_waypoints.clear()
			_move(direction,SPEED*minf(delta,0.06))
		elif not _waypoints.is_empty():
			var goal: Vector2=_waypoints[0]
			var distance: float=player_position.distance_to(goal)
			if distance<4:
				_waypoints.pop_front()
				if _waypoints.is_empty() and not _walk_action.is_empty():
					var action: String=_walk_action
					var key: String=_walk_key
					_walk_action=""
					_request(action,key)
			else: _move(goal-player_position,minf(distance,SPEED*minf(delta,0.06)))
	var tick: int=int(_time*24)
	if tick!=_tick:
		_tick=tick
		_update_hint()
		_layout()
		queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if waiting or not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_E,KEY_ENTER,KEY_SPACE: interact();get_viewport().set_input_as_handled()
		KEY_B: _request("cross","bench");get_viewport().set_input_as_handled()
		KEY_J: _request("journal");get_viewport().set_input_as_handled()
		KEY_G: _request("garden");get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if waiting: return
	var pressed: bool=(event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or not _map_rect.has_point(event.position): return
	var point: Vector2=(event.position-_map_rect.position)/_world_scale+_camera
	var found: String=""
	var best: float=66.0
	for key: String in POSITIONS:
		var distance: float=point.distance_to(POSITIONS[key]+Vector2(0,-28))
		if distance<best: best=distance;found=key
	if found.is_empty(): walk_to(point)
	else:
		var action: String=found if found in ["crossing","gate","moonbell"] else "inspect_parent"
		walk_to(POSITIONS[found]+Vector2(-12,40),action,"moonbell" if found=="moonbell" else (found if action=="inspect_parent" else ""))
	accept_event()

func _update_hint() -> void:
	if not is_instance_valid(_target_label): return
	var nearby: Dictionary=nearest_hotspot()
	var key: String=str(nearby.get("key",""))
	var title: String="Four cuttings, two ways across."
	var hint: String="Walk up to a plant, take a cutting, and try a cross."
	var action: String="Look around [E]"
	if key=="crossing":
		title="The riverbank"
		hint="A broad floating leaf or a strong climbing stem could make a way across."
		action="Try a plant here [E]" if str(_info.get("route","")).is_empty() else "Your living crossing [E]"
	elif key=="gate":
		title="The sleeping courtyard"
		hint="The old gate answers to a new generation of living light."
		action="Light the old gate [E]" if str(_info.get("stage","shore"))!="restored" else "Visit the restored garden [E]"
	elif _rows.has(key):
		var row: Dictionary=_rows[key]
		title=str(row.get("name",key))
		hint=str(row.get("tip",row.get("description",hint)))
		action="Meet this plant [E]"
	elif str(_info.get("stage","shore"))=="restored":
		title="Your plants made a new place."
		hint="The stream is crossed. The courtyard is alive. What will you grow next?"
	if nearby.is_empty() and bool(_info.get("cross_growing",false)):
		hint="Your cross fruit is growing. There are more cuttings to explore."
	_target_label.text=title
	_hint_label.text=_hint_override if not _hint_override.is_empty() else hint
	_interact_button.text=action
	_breed_button.text="Breed here"
	if bool(_info.get("cross_ready",false)):
		_breed_button.text="Fruit ready →"
	elif bool(_info.get("cross_growing",false)):
		var seconds: int=maxi(0,int(_info.get("cross_ready_at",0))-int(Time.get_unix_time_from_system()))
		_breed_button.text="Fruit · %ds" % seconds
	elif str(_info.get("stage","shore")) in ["shore","lantern"]:
		for id: String in _info.get("siblings",[]):
			var sibling: Dictionary=state.get_plant(id) if state!=null else {}
			if sibling.is_empty() or sibling.get("withered",false) or sibling.get("sold",false): continue
			if str(_info.get("stage","shore"))=="lantern" and int(sibling.get("generation",1))<3: continue
			_breed_button.text="Meet siblings →"
			break
	_interact_button.disabled=waiting
	_breed_button.disabled=waiting
	_journal_button.disabled=waiting
	_garden_button.disabled=waiting
	Locale.apply_tree(_footer)

func _poly(points: PackedVector2Array,color: Color,stroke: Color=INK,width: float=1.3) -> void:
	draw_colored_polygon(points,color)
	if stroke.a>0:
		var outline: PackedVector2Array=points.duplicate()
		outline.append(points[0])
		draw_polyline(outline,stroke,width,true)

func _ellipse(center: Vector2,radius: Vector2,color: Color,stroke: Color=Color.TRANSPARENT) -> void:
	var points:=PackedVector2Array()
	for i in range(32):
		var angle: float=TAU*float(i)/32.0
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
	_poly(points,color,stroke,1.2)

func _leaf(base: Vector2,tip: Vector2,width: float,color: Color) -> void:
	if width<0.4: return
	var axis: Vector2=tip-base
	var side: Vector2=axis.normalized().orthogonal()
	var points:=PackedVector2Array()
	for i in range(13):
		var t: float=float(i)/12.0
		points.append(base+axis*t+side*sin(t*PI)*width*(1.0+sin(t*PI*9)*0.045))
	for i in range(11,0,-1):
		var t: float=float(i)/12.0
		points.append(base+axis*t-side*sin(t*PI)*width*(1.0+sin(t*PI*9)*0.045))
	_poly(points,color)
	draw_line(base,tip,INK,0.95,true)
	for i in range(2,10,2):
		var t: float=float(i)/12.0
		for sign_value: float in [-1.0,1.0]:draw_line(base+axis*t,base+axis*(t+0.1)+side*sin(t*PI)*width*0.85*sign_value,Color("60785c"),0.7,true)

func _rock(p: Vector2,s: float=1.0) -> void:
	var points:=PackedVector2Array([p+Vector2(-24,4)*s,p+Vector2(-28,-12)*s,p+Vector2(-14,-29)*s,p+Vector2(9,-33)*s,p+Vector2(29,-14)*s,p+Vector2(24,7)*s,p+Vector2(-3,12)*s])
	_poly(points,Color("d3d2b9"))
	_poly(PackedVector2Array([p+Vector2(9,-33)*s,p+Vector2(29,-14)*s,p+Vector2(24,7)*s,p+Vector2(4,10)*s,p+Vector2(3,-9)*s]),Color("91aaa0"))
	draw_line(p+Vector2(-26,-12)*s,p+Vector2(3,-9)*s,INK,1.0,true)
	draw_line(p+Vector2(3,-9)*s,p+Vector2(-3,12)*s,INK,1.0,true)

func _draw() -> void:
	if _map_rect.size.x<1: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("e6e7ce"))
	draw_rect(_map_rect.grow(2),Color("829578"),false,1.6,true)
	draw_set_transform(_map_rect.position-_camera*_world_scale,0,Vector2.ONE*_world_scale)
	_draw_landscape()
	_draw_stream()
	_draw_courtyard()
	_draw_patches()
	_draw_player()
	if not _waypoints.is_empty():
		var goal: Vector2=_waypoints[-1]
		draw_arc(goal,10,0,TAU,24,Color("c28752"),1.2,true)
		draw_line(goal+Vector2(-4,0),goal+Vector2(4,0),Color("c28752"),1.2,true)
		draw_line(goal+Vector2(0,-4),goal+Vector2(0,4),Color("c28752"),1.2,true)
	draw_set_transform(Vector2.ZERO)
	# The map is a separate illustrated page; its moving world is clipped below
	# the HUD with paper masks, while specimen Controls use the same clip rect.
	draw_rect(Rect2(0,0,size.x,_map_rect.position.y),Color("e6e7ce"))
	draw_rect(Rect2(0,_map_rect.end.y,size.x,maxf(0,size.y-_map_rect.end.y)),Color("e6e7ce"))
	draw_rect(Rect2(0,_map_rect.position.y,_map_rect.position.x,_map_rect.size.y),Color("e6e7ce"))
	draw_rect(Rect2(_map_rect.end.x,_map_rect.position.y,maxf(0,size.x-_map_rect.end.x),_map_rect.size.y),Color("e6e7ce"))

func _draw_landscape() -> void:
	draw_rect(Rect2(Vector2.ZERO,WORLD_SIZE),Color("d6d9ad"))
	if _backdrop!=null:
		draw_texture_rect(_backdrop,Rect2(0,-60,WORLD_SIZE.x,WORLD_SIZE.y+100),false,Color(1,1,1,0.32))
	draw_rect(Rect2(Vector2.ZERO,WORLD_SIZE),Color(0.88,0.89,0.72,0.42))
	# Loose shaded terraces and paths carry the geography, with readable space
	# around all four useful parents and the potting place.
	_poly(PackedVector2Array([Vector2(45,400),Vector2(185,365),Vector2(310,393),Vector2(435,410),Vector2(560,392),Vector2(562,450),Vector2(425,462),Vector2(300,442),Vector2(190,420),Vector2(52,447)]),Color("ead8b0"),Color.TRANSPARENT)
	_poly(PackedVector2Array([Vector2(195,270),Vector2(230,300),Vector2(215,420),Vector2(205,550),Vector2(168,560),Vector2(175,420)]),Color("e3d5aa"),Color.TRANSPARENT)
	_poly(PackedVector2Array([Vector2(734,395),Vector2(878,384),Vector2(1059,396),Vector2(1059,451),Vector2(863,450),Vector2(731,454)]),Color("ead8b0"),Color.TRANSPARENT)
	for i in range(74):
		var p:=Vector2(62+posmod(i*127,1200),95+posmod(i*83,595))
		if absf(p.x-_stream_center(p.y))<95 or p.x>1070: continue
		var shade:=Color("a4b17e") if i%2==0 else Color("c2c594")
		draw_line(p,p+Vector2(3,-4),shade,0.8,true)
		if i%3==0: draw_line(p+Vector2(3,0),p+Vector2(5,-5),shade,0.8,true)
	for i in range(10):
		var y: float=100+i*64
		var center: float=_stream_center(y)
		_rock(Vector2(center-93,y),0.45+float(i%3)*0.16)
		_rock(Vector2(center+102,y+24),0.52+float(i%2)*0.18)
	for i in range(9):
		var p:=Vector2(37+posmod(i*173,1250),64+posmod(i*277,635))
		if p.distance_to(player_position)<110 or (p.x>470 and p.x<810): continue
		var clear: bool=true
		for site: Vector2 in POSITIONS.values():
			if p.distance_to(site)<118: clear=false;break
		if not clear: continue
		for j in range(4):
			_leaf(p,p+Vector2(-35+j*22,-60-28*sin(j*0.9+i)),11+float(j%2)*3,Color("90a980") if j%2 else Color("b6c491"))
	# A little potting bench makes breeding feel part of the place.
	_poly(PackedVector2Array([Vector2(295,472),Vector2(379,457),Vector2(412,478),Vector2(326,495)]),Color("bf9873"))
	draw_line(Vector2(326,495),Vector2(327,530),INK,4.0,true)
	draw_line(Vector2(396,482),Vector2(396,516),INK,4.0,true)
	_ellipse(Vector2(349,476),Vector2(13,7),Color("e0b07b"),INK)
	draw_line(Vector2(348,473),Vector2(349,456),INK,1.2,true)
	_leaf(Vector2(349,463),Vector2(336,451),6,Color("8daf78"))

func _draw_stream() -> void:
	var left:=PackedVector2Array()
	var right:=PackedVector2Array()
	for i in range(29):
		var y: float=float(i)*WORLD_SIZE.y/28.0
		var center: float=_stream_center(y)
		left.append(Vector2(center-74,y))
		right.append(Vector2(center+74,y))
	var water: PackedVector2Array=left.duplicate()
	for i in range(right.size()-1,-1,-1): water.append(right[i])
	_poly(water,Color("77bcb1"),Color.TRANSPARENT)
	draw_polyline(left,Color("587c6b"),2.1,true)
	draw_polyline(right,Color("587c6b"),2.1,true)
	for i in range(31):
		var y: float=fposmod(i*29.0+_time*9,WORLD_SIZE.y)
		var x: float=_stream_center(y)-52+posmod(i*47,104)
		var length: float=8+float(i%4)*4
		draw_line(Vector2(x,y),Vector2(x+length,y-2),Color("c8e3c9"),0.9,true)
	var route: String=str(_info.get("route",""))
	if route=="vine":
		var extent: float=230*_route_progress
		for side: float in [-1.0,1.0]:
			var points:=PackedVector2Array()
			for i in range(21):
				var t: float=float(i)/20.0
				points.append(Vector2(535+extent*t,420+side*22+sin(t*PI)*side*8))
			draw_polyline(points,INK,12,true)
			draw_polyline(points,Color("8aa975"),8,true)
			for i in range(1,9):
				var x: float=535+extent*float(i)/9.0
				_leaf(Vector2(x,420+side*21),Vector2(x+12,420+side*43),8,Color("b1c58a"))
		for i in range(13):
			var x: float=541+extent*float(i)/13.0
			draw_line(Vector2(x,396),Vector2(x+4,444),Color("647e50"),4.5,true)
	elif route=="raft":
		var center:=Vector2(650,420+sin(_time*1.4)*1.8)
		for i in range(4):
			var offset: float=-76+i*50
			_leaf(center+Vector2(offset-28,17),center+Vector2(offset+38,-13),30*_route_progress,Color("a8c88c") if i%2 else Color("8fb78d"))
		for i in range(3):_ellipse(center+Vector2(-61+i*61,30),Vector2(14,9),Color("d7c7a0"),INK)
		var q:=center+Vector2(-109,28)
		draw_line(q,q+Vector2(220,-10),Color("6f8a56"),2.5,true)
	else:
		# The empty gap is visible and the bright island flower teases its goal.
		for i in range(3):
			var p:=Vector2(534+i*12,424+(i%2)*7)
			draw_line(p,p+Vector2(2,-14),Color("8e9e6a"),1.3,true)
		var point:=Vector2(727,410)
		draw_line(point,point+Vector2(25,-7),Color("cfbe8b"),2.0,true)

func _draw_courtyard() -> void:
	var restored: bool=str(_info.get("stage","shore"))=="restored"
	_poly(PackedVector2Array([Vector2(1110,189),Vector2(1283,164),Vector2(1290,618),Vector2(1110,647)]),Color("e2d9bc"))
	for row in range(12):
		var y: float=208+row*34
		draw_line(Vector2(1112,y),Vector2(1285,y-27),Color("b8bca4"),0.8,true)
		for col in range(4):
			var x: float=1120+col*43+(row%2)*16
			draw_line(Vector2(x,y-5),Vector2(x,y+28),Color("b8bca4"),0.7,true)
	for section in range(9):
		var y: float=100+section*73
		if restored and y+78>338 and y<502: continue
		_poly(PackedVector2Array([Vector2(1076,y),Vector2(1093,y-12),Vector2(1110,y-2),Vector2(1110,y+66),Vector2(1092,y+78),Vector2(1076,y+68)]),Color("c1c6aa"))
		for seam in range(3):
			draw_line(Vector2(1077,y+16+seam*18),Vector2(1092,y+25+seam*18),Color("7d8c77"),0.9,true)
			draw_line(Vector2(1092,y+25+seam*18),Vector2(1109,y+14+seam*18),Color("7d8c77"),0.9,true)
	if not restored:
		for i in range(6):
			var base:=Vector2(1085+(i%2)*12,493)
			var end:=Vector2(1082+(i%3)*6,337)
			draw_line(base,end,INK,5.4,true)
			draw_line(base,end,Color("7a9272"),3.0,true)
			_leaf(Vector2(1087,460-i*21),Vector2(1063 if i%2 else 1113,440-i*19),9,Color("94a47e"))
		_ellipse(Vector2(1094,420),Vector2(12,14),Color("dfc991"),INK)
		for i in range(5):
			var a: float=TAU*i/5.0
			draw_line(Vector2(1094,420)+Vector2(cos(a),sin(a))*4,Vector2(1094,420)+Vector2(cos(a),sin(a))*9,Color("9c936d"),1.1,true)
	else:
		for i in range(14):
			var p:=Vector2(1136+posmod(i*43,130),245+posmod(i*79,310))
			_leaf(p,p+Vector2(-12,-34-i%3*7),9,Color("8ba678"))
			for petal in range(5):
				var a: float=TAU*petal/5.0
				_ellipse(p+Vector2(0,-31)+Vector2(cos(a),sin(a))*7,Vector2(5,7),Color("e8b58b"),Color("8b7760"))
			_ellipse(p+Vector2(0,-31),Vector2(3,3),Color("dfc579"))
		for i in range(7):
			var p:=Vector2(1145+posmod(i*71,126),270+posmod(i*53,270))+Vector2(sin(_time*0.8+i)*12,cos(_time+i)*7)
			_ellipse(p+Vector2(-4,0),Vector2(4.5,2.5),Color("e4b17e"),INK)
			_ellipse(p+Vector2(4,0),Vector2(4.5,2.5),Color("e4b17e"),INK)
			draw_line(p+Vector2(0,-2),p+Vector2(0,3),INK,1.2,true)
	# A dry fountain at the heart will fill when the new lantern plant awakens it.
	_ellipse(Vector2(1210,437),Vector2(42,22),Color("b9c3aa"),INK)
	_ellipse(Vector2(1210,431),Vector2(34,16),Color("86b7aa") if restored else Color("d7ceb2"),INK)
	if restored:
		draw_line(Vector2(1210,430),Vector2(1210,384+sin(_time*2)*3),Color("c5dfc5"),3.5,true)
		for i in range(6):
			var p:=Vector2(1210+sin(i*1.7+_time)*13,392+posmod(i*11+int(_time*30),37))
			_ellipse(p,Vector2(1.8,3.2),Color("bfe1cb"))

func _draw_patches() -> void:
	for key: String in POSITIONS:
		if key in ["crossing","gate"]: continue
		var p: Vector2=POSITIONS[key]
		_ellipse(p+Vector2(0,5),Vector2(39,13),Color("bec999"),Color("87996c"))
		if key=="moonbell":
			for i in range(5):
				var angle: float=_time*0.45+float(i)*TAU/5.0
				var q:=p+Vector2(cos(angle)*45,sin(angle)*14-44)
				_ellipse(q,Vector2(2.4,2.4),Color("fff2b8"))
		if _rows.get(key,{}).get("claimed",false):
			_poly(PackedVector2Array([p+Vector2(28,-12),p+Vector2(34,-8),p+Vector2(44,-21),p+Vector2(47,-17),p+Vector2(35,-3),p+Vector2(26,-8)]),Color("b1c389"),INK,0.8)
	var nearby: Dictionary=nearest_hotspot()
	if not nearby.is_empty():
		var p: Vector2=nearby.position
		var y: float=-119 if str(nearby.key) in _rows else -26
		draw_arc(p+Vector2(0,5),46,0,TAU,40,Color("c78e54"),1.8,true)
		_poly(PackedVector2Array([p+Vector2(-6,y),p+Vector2(6,y),p+Vector2(0,y+8)]),Color("d8b975"))

func _draw_player() -> void:
	var p: Vector2=player_position
	var bob: float=sin(_time*9)*1.0 if not waiting and (not _waypoints.is_empty() or _held_direction!=Vector2.ZERO) else 0.0
	_ellipse(p+Vector2(4,3),Vector2(14,4.5),Color(0.26,0.36,0.25,0.24))
	draw_line(p+Vector2(-5,-12),p+Vector2(-6,0),Color("465d4a"),6.0,true)
	draw_line(p+Vector2(5,-12),p+Vector2(7,0),Color("465d4a"),6.0,true)
	_poly(PackedVector2Array([p+Vector2(-10,-34+bob),p+Vector2(9,-34+bob),p+Vector2(13,-12),p+Vector2(-12,-12)]),Color("9db17c"))
	draw_line(p+Vector2(-9,-29+bob),p+Vector2(-13,-15),Color("cfb58c"),5,true)
	draw_line(p+Vector2(10,-29+bob),p+Vector2(14,-13),Color("cfb58c"),5,true)
	_ellipse(p+Vector2(1,-43+bob),Vector2(9,11),Color("d7bc90"),INK)
	_ellipse(p+Vector2(1,-51+bob),Vector2(17,5),Color("d4c393"),INK)
	_poly(PackedVector2Array([p+Vector2(-8,-52+bob),p+Vector2(-5,-64+bob),p+Vector2(8,-63+bob),p+Vector2(11,-51+bob)]),Color("c6b783"))
	draw_line(p+Vector2(-8,-52+bob),p+Vector2(11,-51+bob),Color("6f7e5d"),2.0,true)
	_ellipse(p+Vector2(13,-18),Vector2(7,10),Color("b49368"),INK)
	draw_line(p+Vector2(10,-32),p+Vector2(-6,-13),Color("8b7958"),1.6,true)
	draw_circle(p+Vector2(-2,-43+bob),1,INK,true,-1,true)
	draw_circle(p+Vector2(4,-43+bob),1,INK,true,-1,true)
