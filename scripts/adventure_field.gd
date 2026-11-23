extends Control
## A small, walkable breeding adventure. Physical routes are opened only by the
## inherited capabilities accepted by GardenState; this view never creates DNA.
signal action_requested(action: String,key: String)
signal returned_home()
signal terrain_step(kind: String)
const Portrait = preload("res://scripts/plant_portrait.gd")
const Locale = preload("res://scripts/localization.gd")
const SceneArt = preload("res://scripts/habitat_scene.gd")
const INK := Color("304a40")
const MUTED := Color("60765b")
const WARM := Color("a75e36")
const WORLD_SIZE := Vector2(1920,1280)
const NAV_CELL: int=20
const DISCOVERY_IDS: Array[String]=["rain_nursery","seed_catch","cistern","moth_garden","wind_terrace"]
const PLACE_NAMES: Dictionary={"rain_nursery":"Rain Nursery","seed_catch":"Seed Catch Hollow","cistern":"Old Cistern","moth_garden":"Moth Garden","wind_terrace":"Wind Terrace"}
const BOULDERS: Array[Vector3]=[Vector3(90,155,48),Vector3(470,100,52),Vector3(410,720,62),Vector3(110,1070,58),Vector3(475,1140,60),Vector3(810,160,56),Vector3(800,850,50),Vector3(1210,1080,62),Vector3(1630,500,90),Vector3(1750,1050,70)]
const SPEED: float=185.0
const INTERACT_DISTANCE: float=86.0
const POSITIONS := {
	"river_fan":Vector2(150,265),"floatcap":Vector2(400,300),
	"gripvine":Vector2(135,570),"stone_root":Vector2(410,590),
	"crossing":Vector2(540,420),"moonbell":Vector2(910,280),
	"gate":Vector2(1040,420),"rain_nursery":Vector2(335,155),
	"seed_catch":Vector2(265,900),"cistern":Vector2(970,1010),
	"moth_garden":Vector2(935,675),"wind_terrace":Vector2(1580,870)
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
var _guided_step: Dictionary={}
var _next_button: Button
var _routes_button: Button
var _party_button: Button
var _guide_button: Button
var _bag_button: Button
var _menu_buttons: Array[Button]=[]
var _companion: Control
var _companion_label: Label
var _companion_id: String=""
var _companion_position:=Vector2(220,455)
var _last_move_direction:=Vector2.RIGHT
var _sites: Dictionary={}
var _site_portraits: Dictionary={}
var _site_captions: Dictionary={}
var _pathfinder:=AStarGrid2D.new()
var _navigation_signature: String=""
var _rendered_language: String=""
var _place_seen: String=""
var _day_label: Label
var _stride_distance: float=0.0
var _celebration_site: String=""
var _celebration_until: float=0.0

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
	if state!=null:
		var saved: Array=state.adventure.get("position",[255.0,435.0])
		var point:=Vector2(float(saved[0]),float(saved[1]))
		if is_walkable(point): player_position=point
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
	_header.add_theme_stylebox_override("panel",_style(Color("fff8df"),Color("a4b487"),10))
	add_child(_header)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	_header.add_child(column)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",7)
	column.add_child(row)
	_title=_label("Moonbell Crossing",23)
	_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_title)
	_day_label=_label("Day 1",12,MUTED)
	row.add_child(_day_label)
	_routes_button=_button("Routes","wilds")
	_routes_button.custom_minimum_size=Vector2(68,32)
	row.add_child(_routes_button)
	var goal_row:=HBoxContainer.new()
	goal_row.add_theme_constant_override("separation",7)
	column.add_child(goal_row)
	_objective=_label("Reach the glowing flower.",14,WARM)
	_objective.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_objective.set_meta("adventure_objective",true)
	goal_row.add_child(_objective)
	_journal_button=_button("Journal","journal")
	_journal_button.custom_minimum_size=Vector2(68,30)
	_journal_button.add_theme_font_size_override("font_size",12)
	goal_row.add_child(_journal_button)
	_footer=PanelContainer.new()
	_footer.set_meta("adventure_footer",true)
	_footer.add_theme_stylebox_override("panel",_style(Color("fff8df"),Color("a4b487"),10))
	add_child(_footer)
	var bottom:=VBoxContainer.new()
	bottom.add_theme_constant_override("separation",5)
	_footer.add_child(bottom)
	_target_label=_label("Riverside path",15)
	_target_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_target_label.set_meta("adventure_target",true)
	bottom.add_child(_target_label)
	var actions:=HBoxContainer.new()
	actions.add_theme_constant_override("separation",7)
	bottom.add_child(actions)
	_interact_button=_button("Meet nearby [E]","interact")
	_interact_button.add_theme_stylebox_override("normal",_style(Color("f8d3a4"),Color("bf945d"),8))
	_interact_button.custom_minimum_size.y=36
	_interact_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_child(_interact_button)
	_breed_button=_button("Cross [B]","cross","bench")
	_breed_button.custom_minimum_size=Vector2(94,36)
	actions.add_child(_breed_button)
	_next_button=_button("Hint: Meet River Fan →","next")
	_next_button.add_theme_font_size_override("font_size",12)
	_next_button.add_theme_stylebox_override("normal",_style(Color("f7f3dc"),Color("d0c9a8"),5))
	_next_button.custom_minimum_size.y=27
	bottom.add_child(_next_button)
	var menu:=HBoxContainer.new()
	menu.add_theme_constant_override("separation",5)
	bottom.add_child(menu)
	_party_button=_button("Party","party")
	_guide_button=_button("Guide","dex")
	_bag_button=_button("Bag","bag")
	_garden_button=_button("Garden","garden")
	_home_button=_garden_button
	_menu_buttons=[_party_button,_guide_button,_bag_button,_garden_button]
	for button: Button in _menu_buttons:
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y=35
		menu.add_child(button)
	_hint_label=_label("Tap the map to walk. Tap a plant to meet it.",12,MUTED)
	_hint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_hint_label.max_lines_visible=1
	bottom.add_child(_hint_label)
	_legend=_label("WASD walk · E interact · B cross · P party · I bag",11,MUTED)
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
	_sync_language()
	var compact: bool=size.x<700
	var margin: float=8 if compact else 18
	var width: float=maxf(1,size.x-margin*2)
	_title.add_theme_font_size_override("font_size",17 if compact else 23)
	_legend.visible=not compact
	_hint_label.visible=not compact
	for button: Button in _menu_buttons: button.add_theme_font_size_override("font_size",12 if compact else 14)
	_routes_button.custom_minimum_size=Vector2(64 if compact else 72,32)
	_journal_button.custom_minimum_size=Vector2(64 if compact else 72,30)
	_objective.add_theme_font_size_override("font_size",12 if compact else 14)
	_header.position=Vector2(margin,margin)
	_header.size=Vector2(width,0)
	_header.size.y=_header.get_combined_minimum_size().y
	_footer.size=Vector2(width,0)
	_footer.size.y=_footer.get_combined_minimum_size().y
	_footer.position=Vector2(margin,size.y-margin-_footer.size.y)
	_map_rect=Rect2(Vector2(margin,_header.position.y+_header.size.y+8),Vector2(width,maxf(1,_footer.position.y-_header.position.y-_header.size.y-16)))
	_world_scale=0.82 if compact else 1.03
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
		_set_text(_objective,"A pale flower glows beyond the stream." if str(_info.get("route","")).is_empty() else "What else could your plants change here?")
	if is_instance_valid(_day_label):
		_set_text(_day_label,"Day %d" % int(state.garden_day if state!=null else 1))
	_sync_specimens()
	_sync_discoveries()
	_rebuild_navigation()
	_sync_companion()
	_guided_step=_next_step()
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
		_set_text(caption,str(row.get("name",key)))
		caption.position=p+Vector2(-90,11)
		caption.size=Vector2(180,25)
	if state!=null:
		_route_plant=_placed_specimen(_route_plant,str(_info.get("route_plant_id","")),Vector2(650,421),Vector2(68,86),"route")
		_lantern_plant=_placed_specimen(_lantern_plant,str(_info.get("lantern_id","")),Vector2(1088,410),Vector2(90,116),"lantern")

func _set_text(control: Control,source: String) -> void:
	var rendered: String=Locale.text(source)
	control.set_meta("_locale_source_text",source)
	control.set_meta("_locale_rendered_text",rendered)
	control.set("text",rendered)
	Locale.apply_tree(control)

func _sync_language() -> void:
	var language: String=Locale.get_language()
	if language==_rendered_language: return
	_rendered_language=language
	Locale.apply_tree(self)

func _sync_discoveries() -> void:
	_sites.clear()
	if state!=null and state.has_method("adventure_sites"):
		for row: Dictionary in state.adventure_sites(): _sites[str(row.id)]=row
	for key: String in DISCOVERY_IDS:
		var row: Dictionary=_sites.get(key,{})
		var caption: Label=_site_captions.get(key)
		if not is_instance_valid(caption):
			caption=_label("",15,INK)
			caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
			caption.set_meta("adventure_place",key)
			_world_layer.add_child(caption)
			_site_captions[key]=caption
		_set_text(caption,str(row.get("name",PLACE_NAMES.get(key,key))))
		caption.position=POSITIONS[key]+Vector2(-120,58)
		caption.size=Vector2(240,24)
		var record: Dictionary=row.get("enhancement_record",{}) if bool(row.get("enhanced",false)) else row.get("placement",{})
		if record.is_empty(): record=row.get("placement",{})
		var portrait: Control=_site_portraits.get(key)
		if record.is_empty():
			if is_instance_valid(portrait): portrait.visible=false
			continue
		var specimen: Dictionary=state.get_plant(str(record.get("plant_id",""))).duplicate(true)
		for gene_key: String in record.get("evidence",{}): specimen[gene_key]=record.evidence[gene_key]
		if specimen.is_empty(): continue
		specimen.mature=true
		specimen.withered=false
		specimen.life_age=0.0
		if not is_instance_valid(portrait):
			portrait=Portrait.new()
			portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
			portrait.set_meta("adventure_placed",key)
			_world_layer.add_child(portrait)
			_site_portraits[key]=portrait
		portrait.set_meta("plant_id",str(record.get("plant_id","")))
		portrait.plant=specimen
		portrait.visible=true
		portrait.position=POSITIONS[key]+Vector2(-48,-96)
		portrait.size=Vector2(96,116)

func discovery_position(site_id: String) -> Vector2:
	return POSITIONS.get(site_id,Vector2(-1,-1))

func _site_solved(key: String) -> bool:
	return bool(_sites.get(key,{}).get("solved",false)) or not _sites.get(key,{}).get("placement",{}).is_empty()

func _site_approach(key: String) -> String:
	var row: Dictionary=_sites.get(key,{})
	var record: Dictionary=row.get("enhancement_record",{}) if bool(row.get("enhanced",false)) else row.get("placement",{})
	return str(record.get("approach",""))

func _site_combined(key: String) -> bool:
	return bool(_sites.get(key,{}).get("enhanced",false)) or bool(_sites.get(key,{}).get("placement",{}).get("combined",false))

func _place_name() -> String:
	if player_position.x>1420: return "Wind Terrace"
	if player_position.y>800: return "Seed Catch Hollow" if player_position.x<650 else "Old Cistern"
	if player_position.x>1080 and player_position.y<650: return "Moonbell Courtyard"
	if player_position.x>740: return "Moonbell Orchard" if player_position.y<510 else "Moth Garden"
	if player_position.y<230: return "Rain Nursery"
	return "Moonbell Crossing"

func _sync_companion() -> void:
	var lead: Dictionary={}
	if state!=null and state.has_method("travel_party"):
		for specimen: Dictionary in state.travel_party():
			var id: String=str(specimen.get("id",""))
			if not id.is_empty() and state.owns_plant(id) and not bool(specimen.get("withered",false)):
				lead=specimen
				break
	_companion_id=str(lead.get("id",""))
	if lead.is_empty():
		if is_instance_valid(_companion): _companion.visible=false
		if is_instance_valid(_companion_label): _companion_label.visible=false
		return
	if not is_instance_valid(_companion):
		_companion=Portrait.new()
		_companion.set_meta("adventure_companion",true)
		_companion.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_companion.size=Vector2(62,78)
		_world_layer.add_child(_companion)
		_companion_label=_label("",11,INK)
		_companion_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		_companion_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_companion_label.size=Vector2(140,18)
		_world_layer.add_child(_companion_label)
	_companion.set_meta("plant_id",_companion_id)
	_companion.plant=lead
	_companion.visible=true
	_set_text(_companion_label,str(lead.get("name","")))
	_companion_label.visible=true
	_update_companion(0.0)

func _update_companion(delta: float) -> void:
	if not is_instance_valid(_companion) or not _companion.visible: return
	var wanted: Vector2=player_position-_last_move_direction*42+Vector2(0,16)
	_companion_position=_companion_position.lerp(wanted,clampf(delta*7,0,1))
	_companion.position=_companion_position-Vector2(31,67)
	_companion_label.position=_companion_position+Vector2(-70,9)

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
	if in_water:
		var main_crossing: bool=not str(_info.get("route","")).is_empty() and absf(point.y-420)<43
		var lower_crossing: bool=_site_solved("cistern") and absf(point.y-980)<40
		if not main_crossing and not lower_crossing: return false
	# The old courtyard is an enclosed place. The rest of the valley loops
	# around its walls, so it never blocks the whole eastern half of the map.
	var courtyard: Rect2=Rect2(1076,170,320,485)
	if courtyard.has_point(point):
		if str(_info.get("stage","shore"))!="restored": return false
		if point.x<1110 and absf(point.y-420)>75: return false
		if point.x>1368 or point.y<195 or point.y>628: return false
	for stone: Vector3 in BOULDERS:
		var relative: Vector2=(point-Vector2(stone.x,stone.y))/Vector2(stone.z,stone.z*0.52)
		if relative.length_squared()<0.72: return false
	# A clearly drawn ridge separates the high terrace from the orchard; paths
	# around both ends make it a loop, rather than a long corridor.
	if Rect2(1420,170,90,440).has_point(point): return false
	return true

func _navigation_cell(point: Vector2) -> Vector2i:
	return Vector2i(clampi(roundi(point.x/NAV_CELL),0,int(WORLD_SIZE.x/NAV_CELL)-1),clampi(roundi(point.y/NAV_CELL),0,int(WORLD_SIZE.y/NAV_CELL)-1))

func _rebuild_navigation() -> void:
	var signature: String=str(_info.get("route",""))+"/"+str(_info.get("stage",""))+"/"+str(_site_solved("cistern"))
	if signature==_navigation_signature: return
	_navigation_signature=signature
	_pathfinder.region=Rect2i(0,0,int(WORLD_SIZE.x/NAV_CELL),int(WORLD_SIZE.y/NAV_CELL))
	_pathfinder.cell_size=Vector2.ONE*NAV_CELL
	_pathfinder.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	_pathfinder.update()
	for y in range(_pathfinder.region.size.y):
		for x in range(_pathfinder.region.size.x):
			var point:=Vector2(x*NAV_CELL,y*NAV_CELL)
			var safe: bool=is_walkable(point)
			for offset: Vector2 in [Vector2(10,0),Vector2(-10,0),Vector2(0,10),Vector2(0,-10)]:
				safe=safe and is_walkable(point+offset)
			_pathfinder.set_point_solid(Vector2i(x,y),not safe)

func _segment_walkable(a: Vector2,b: Vector2) -> bool:
	var steps: int=maxi(1,ceili(a.distance_to(b)/4))
	for i in range(steps+1):
		if not is_walkable(a.lerp(b,float(i)/steps)): return false
	return true

func _nearest_navigation_cell(point: Vector2) -> Vector2i:
	var origin: Vector2i=_navigation_cell(point)
	if not _pathfinder.is_point_solid(origin) and _segment_walkable(point,Vector2(origin)*NAV_CELL): return origin
	for radius in range(1,7):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var test: Vector2i=origin+Vector2i(x,y)
				if _pathfinder.is_in_boundsv(test) and not _pathfinder.is_point_solid(test) and _segment_walkable(point,Vector2(test)*NAV_CELL): return test
	return origin

func _update_camera() -> void:
	if not is_instance_valid(_world_layer) or _map_rect.size.x<1: return
	var extent: Vector2=_map_rect.size/_world_scale
	var forward: float=56.0 if size.x<700 else 0.0
	var desired: Vector2=player_position+Vector2(forward,-22)-extent*0.5
	_camera=Vector2(clampf(desired.x,0,maxf(0,WORLD_SIZE.x-extent.x)),clampf(desired.y,0,maxf(0,WORLD_SIZE.y-extent.y)))
	_world_layer.position=-_camera*_world_scale
	_world_layer.scale=Vector2.ONE*_world_scale
	if is_instance_valid(_goal_tease):
		# The next-step button is the one guide; a second floating "walk" card
		# competed with it on small screens and sent players to locked water.
		_goal_tease.visible=false

func _request(action: String,key: String="") -> void:
	if action=="move": return
	if action=="next":
		if waiting: return
		var step: Dictionary=_guided_step
		var next_action: String=str(step.get("action","cross"))
		var next_key: String=str(step.get("key",""))
		if not next_key.is_empty() and POSITIONS.has(next_key):
			walk_to(POSITIONS[next_key]+Vector2(-12,40),next_action,next_key if next_action in ["inspect_parent","moonbell","discovery"] else "")
		else: _request(next_action,str(step.get("argument","")))
		return
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

func pause_walking() -> void:
	_held_direction=Vector2.ZERO
	_waypoints.clear()
	_walk_action=""
	_walk_key=""

func celebrate_site(key: String) -> void:
	_celebration_site=key
	_celebration_until=_time+2.6
	queue_redraw()

func companion_can_help(key: String) -> bool:
	if not key in DISCOVERY_IDS or state==null: return false
	var party: Array=state.travel_party()
	if party.is_empty(): return false
	var preview: Dictionary=state.adventure_discovery_preview(key,str(party[0].id))
	return bool(preview.get("eligible",false)) and (not _site_solved(key) or (bool(preview.get("combined",false)) and not _site_combined(key)))

func interact() -> void:
	if waiting: return
	var target: Dictionary=nearest_hotspot()
	if target.is_empty():
		_hint_override="Walk closer to a plant, the riverbank, or the old gate."
		_update_hint()
		return
	var key: String=str(target.key)
	if companion_can_help(key):
		_request("quick_discovery",key)
		return
	if key in ["crossing","gate"] and state!=null:
		var party: Array=state.travel_party()
		var goal: String="stream" if key=="crossing" else "lantern"
		if not party.is_empty() and bool(state.adventure_preview(str(party[0].id),goal).get("eligible",false)):
			_request("quick_crossing",goal)
			return
	var action: String="discovery" if key in DISCOVERY_IDS else (key if key in ["crossing","gate","moonbell"] else "inspect_parent")
	_request(action,key if action in ["inspect_parent","moonbell","discovery"] else "")

func walk_to(point: Vector2,action: String="",key: String="") -> void:
	if waiting: return
	grab_focus()
	_held_direction=Vector2.ZERO
	_hint_override=""
	_waypoints.clear()
	_walk_action=action
	_walk_key=key
	var destination:=Vector2(clampf(point.x,45,WORLD_SIZE.x-45),clampf(point.y,85,WORLD_SIZE.y-45))
	if Rect2(1076,170,320,485).has_point(destination) and str(_info.get("stage","shore"))!="restored":
		destination=POSITIONS.gate+Vector2(-5,15)
		_walk_action="gate"
		_walk_key=""
	var start: Vector2i=_nearest_navigation_cell(player_position)
	var finish: Vector2i=_nearest_navigation_cell(destination)
	var path: PackedVector2Array=_pathfinder.get_point_path(start,finish)
	if path.is_empty() and destination.x>_stream_center(destination.y) and player_position.x<_stream_center(player_position.y):
		destination=POSITIONS.crossing+Vector2(0,35)
		_walk_action="crossing"
		_walk_key=""
		finish=_nearest_navigation_cell(destination)
		path=_pathfinder.get_point_path(start,finish)
	if path.is_empty():
		_hint_override="A different path leads around this landmark."
		_update_hint()
		return
	# First reach the grid's safe center; subsequent orthogonal segments cannot
	# cut a corner through a boulder, water, or a closed courtyard wall.
	for waypoint: Vector2 in path: _waypoints.append(waypoint)
	if _segment_walkable(Vector2(finish)*NAV_CELL,destination) and destination.distance_to(Vector2(finish)*NAV_CELL)<NAV_CELL*0.75: _waypoints.append(destination)

func _move(direction: Vector2,distance: float) -> bool:
	if direction.length_squared()<0.0001: return false
	var previous: Vector2=player_position
	_last_move_direction=direction.normalized()
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
	_stride_distance+=player_position.distance_to(previous)
	if state!=null and not player_position.is_equal_approx(previous):
		state.adventure["position"]=[player_position.x,player_position.y]
	if _stride_distance>=30:
		_stride_distance=0
		terrain_step.emit("step" if absf(player_position.x-_stream_center(player_position.y))<110 else "grass")
	return not player_position.is_equal_approx(previous)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_sync_language()
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
	_update_companion(minf(delta,0.06))
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
		KEY_P: _request("party");get_viewport().set_input_as_handled()
		KEY_I: _request("bag");get_viewport().set_input_as_handled()
		KEY_G: _request("garden");get_viewport().set_input_as_handled()
		KEY_T: _request("experiments");get_viewport().set_input_as_handled()
		KEY_R: _request("rest");get_viewport().set_input_as_handled()

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
		var action: String="discovery" if found in DISCOVERY_IDS else (found if found in ["crossing","gate","moonbell"] else "inspect_parent")
		walk_to(POSITIONS[found]+Vector2(-12,40),action,found if action in ["inspect_parent","moonbell","discovery"] else "")
	accept_event()

func _next_step() -> Dictionary:
	if bool(_info.get("cross_ready",false)):
		return {"button":"Meet the two seeds →","action":"cross","argument":"bench"}
	if bool(_info.get("cross_growing",false)):
		return {"button":"Fruit growing · %ds","action":"cross","argument":"bench","timer":true}
	if not bool(_rows.get("river_fan",{}).get("claimed",false)):
		return {"button":"Meet River Fan →","action":"inspect_parent","key":"river_fan"}
	if str(_info.get("route","")).is_empty():
		return {"button":"What could float here? →","action":"crossing","key":"crossing"}
	if not bool(_rows.get("moonbell",{}).get("claimed",false)):
		return {"button":"Meet the glowing flower →","action":"moonbell","key":"moonbell"}
	var closest: String=""
	var distance: float=INF
	for key: String in DISCOVERY_IDS:
		var row: Dictionary=_sites.get(key,{})
		if bool(row.get("enhanced",false)): continue
		var score: float=player_position.distance_to(POSITIONS[key])+(700 if _site_solved(key) else 0)
		if score<distance: distance=score; closest=key
	if not closest.is_empty():
		return {"button":str(_sites.get(closest,{}).get("question","What could grow here?")),"action":"discovery","key":closest}
	return {"button":"Try a new plant experiment →","action":"experiments"}

func _update_hint() -> void:
	if not is_instance_valid(_target_label): return
	var nearby: Dictionary=nearest_hotspot()
	var key: String=str(nearby.get("key",""))
	var context: String="Riverside path"
	var interact_text: String="Move closer [E]"
	if key=="crossing":
		context="The riverbank"
		interact_text="Cross the stream [E]" if not str(_info.get("route","")).is_empty() else "Try a plant [E]"
	elif key=="gate":
		context="The sleeping courtyard" if str(_info.get("stage","shore"))!="restored" else "Your restored courtyard"
		interact_text="Enter the courtyard [E]" if str(_info.get("stage","shore"))=="restored" else "Light the gate [E]"
	elif key in DISCOVERY_IDS:
		var site: Dictionary=_sites.get(key,{})
		context=str(site.get("name",PLACE_NAMES.get(key,key)))
		interact_text="Visit this place [E]" if _site_solved(key) else "Try a plant here [E]"
		if companion_can_help(key): interact_text="Use companion here [E]"
	elif _rows.has(key):
		var row: Dictionary=_rows[key]
		context=str(row.get("name",key))
		interact_text="View plant [E]" if bool(row.get("claimed",false)) else "Meet plant [E]"
	var place: String=_place_name()
	if place!=_place_seen:
		_place_seen=place
		_set_text(_title,place)
	_target_label.text=context
	_interact_button.text=interact_text
	_interact_button.disabled=waiting or nearby.is_empty()
	var step: Dictionary=_guided_step
	var label: String=str(step.get("button","Meet River Fan →"))
	if bool(step.get("timer",false)):
		label=label % maxi(0,int(_info.get("cross_ready_at",0))-int(Time.get_unix_time_from_system()))
	_next_button.text="Hint: %s" % label
	_next_button.disabled=waiting
	_hint_label.text=_hint_override if not _hint_override.is_empty() else "Tap the map to walk. Tap a plant to meet it."
	_breed_button.disabled=waiting
	_breed_button.text="Cross [B]"
	if bool(_info.get("cross_ready",false)):
		_breed_button.text="Fruit ready"
	elif bool(_info.get("cross_growing",false)):
		_breed_button.text="Fruit · %ds" % maxi(0,int(_info.get("cross_ready_at",0))-int(Time.get_unix_time_from_system()))
	for button: Button in _menu_buttons: button.disabled=waiting
	_journal_button.disabled=waiting
	_routes_button.disabled=waiting
	Locale.apply_tree(_header)
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
	for crack: int in range(3):
		var start: Vector2=p+Vector2(-18+crack*13,-22+crack%2*10)*s
		draw_polyline(PackedVector2Array([start,start+Vector2(7,5)*s,start+Vector2(3,12)*s,start+Vector2(9,17)*s]),Color("708b81"),0.7,true)
	for index in range(5):
		var edge: Vector2=p+Vector2(11+index*2,-7+index*2)*s
		draw_line(edge,edge+Vector2(5,-4)*s,Color("718a80"),0.65,true)

func _bush(foot: Vector2,radius: float,color: Color) -> void:
	_ellipse(foot+Vector2(9,6),Vector2(radius*1.15,radius*0.43),Color(0.24,0.37,0.29,0.12))
	var outline:=PackedVector2Array()
	for index in range(64):
		var angle: float=TAU*float(index)/64
		var ripple: float=1+sin(angle*11+foot.x)*0.085+cos(angle*17)*0.04
		outline.append(foot+Vector2(cos(angle)*radius,sin(angle)*radius*0.65-radius*0.38)*ripple)
	_poly(outline,color,Color("476b50"),1)
	for index in range(7):
		var angle: float=float(index)*2.4+foot.y
		var point: Vector2=foot+Vector2(cos(angle)*radius*0.6,sin(angle)*radius*0.34-radius*0.4)
		draw_arc(point,3+float(index%3),PI*0.9,TAU,7,Color("658454"),0.8,true)

func _draw() -> void:
	if _map_rect.size.x<1: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("e6e7ce"))
	draw_rect(_map_rect.grow(2),Color("829578"),false,1.6,true)
	draw_set_transform(_map_rect.position-_camera*_world_scale,0,Vector2.ONE*_world_scale)
	_draw_landscape()
	_draw_stream()
	_draw_courtyard()
	_draw_discoveries()
	_draw_patches()
	if not _celebration_site.is_empty() and _time<_celebration_until:
		var origin: Vector2=POSITIONS.get(_celebration_site,player_position)
		var progress: float=1.0-(_celebration_until-_time)/2.6
		for index in range(18):
			var angle: float=TAU*float(index)/18
			var point: Vector2=origin+Vector2(cos(angle),sin(angle)*0.65)*(22+progress*85)+Vector2(0,-progress*55)
			var color:=Color("f1c783") if index%2 else Color("e9a396")
			color.a=1.0-progress
			_ellipse(point,Vector2(3,5)*(1-progress*0.5),color)
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

func _trail(points: Array[Vector2],width: float=42.0) -> void:
	var curve:=Curve2D.new()
	curve.bake_interval=9
	for index in range(points.size()):
		var before: Vector2=points[maxi(0,index-1)]
		var after: Vector2=points[mini(points.size()-1,index+1)]
		var tangent: Vector2=(after-before)*0.16
		curve.add_point(points[index],-tangent if index>0 else Vector2.ZERO,tangent if index<points.size()-1 else Vector2.ZERO)
	var line: PackedVector2Array=curve.get_baked_points()
	if line.size()<2: return
	draw_polyline(line,Color("9f9f78"),width+3,true)
	draw_polyline(line,Color("e6d4aa"),width,true)
	for point: Vector2 in line: draw_circle(point,width*0.48,Color("e6d4aa"),true,-1,true)
	for index in range(3,line.size()-3,9):
		var point: Vector2=line[index]
		var side: Vector2=(line[index+1]-line[index-1]).normalized().orthogonal()
		draw_line(point+side*(width*0.56),point+side*(width*0.56)+Vector2(4,-4),Color("8c9b6b"),0.85,true)

func _sward(center: Vector2,radius: Vector2,color: Color,phase: float) -> void:
	var points:=PackedVector2Array()
	for index in range(40):
		var angle: float=TAU*float(index)/40
		var ripple: float=1+sin(angle*5+phase)*0.09+sin(angle*11-phase)*0.045
		points.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y)*ripple)
	_poly(points,color,Color("869775"),0.8)

func _flower(foot: Vector2,color: Color,scale_value: float=1.0) -> void:
	var crown: Vector2=foot+Vector2(0,-22)*scale_value
	draw_line(foot,crown,INK,1.3,true)
	_leaf(foot+Vector2(0,-6)*scale_value,foot+Vector2(13,-15)*scale_value,4*scale_value,Color("9db58a"))
	for petal in range(5):
		var angle: float=TAU*float(petal)/5
		_ellipse(crown+Vector2(cos(angle),sin(angle))*5*scale_value,Vector2(4,5)*scale_value,color,Color("6e7660"))
	_ellipse(crown,Vector2.ONE*2.6*scale_value,Color("e4bc72"))

func _moth(point: Vector2,phase: float,glowing: bool=false) -> void:
	var flutter: float=0.55+absf(sin(_time*7+phase))*0.45
	var color:=Color("f6d4a9") if not glowing else Color("fff0a8")
	_ellipse(point+Vector2(-4*flutter,0),Vector2(4*flutter,2.6),color,Color("758774"))
	_ellipse(point+Vector2(4*flutter,0),Vector2(4*flutter,2.6),color,Color("758774"))
	draw_line(point+Vector2(0,-2),point+Vector2(0,3),INK,0.9,true)

func _draw_landscape() -> void:
	draw_rect(Rect2(Vector2.ZERO,WORLD_SIZE),Color("cfdbad"))
	_sward(Vector2(275,385),Vector2(300,310),Color("c7d4a6"),0.5)
	_sward(Vector2(280,900),Vector2(280,285),Color("d2cc9e"),2.1)
	_sward(Vector2(950,360),Vector2(225,265),Color("b9cda4"),0.8)
	_sward(Vector2(1000,760),Vector2(250,205),Color("b1c9b0"),4.4)
	_sward(Vector2(1050,1050),Vector2(255,160),Color("c1c8ae"),1.4)
	_sward(Vector2(1610,850),Vector2(245,275),Color("c5d29d"),3.4)
	# High sandstone and sage shelves establish distinct spaces without UI cards.
	_poly(PackedVector2Array([Vector2(1420,130),Vector2(1490,162),Vector2(1510,350),Vector2(1495,610),Vector2(1430,650),Vector2(1415,475)]),Color("a7b7a6"))
	for index in range(14):
		var y: float=170+index*31
		draw_polyline(PackedVector2Array([Vector2(1420,y),Vector2(1458,y+12),Vector2(1498,y+4)]),Color("72897d"),0.9,true)
		if index%3==0: _leaf(Vector2(1420,y+4),Vector2(1388,y-24),11,Color("a7bc87"))
	_poly(PackedVector2Array([Vector2(1430,1110),Vector2(1570,1140),Vector2(1810,1070),Vector2(1840,1190),Vector2(1640,1250),Vector2(1450,1230)]),Color("afb9a3"))
	for index in range(11):
		var x: float=1460+index*32
		draw_polyline(PackedVector2Array([Vector2(x,1130),Vector2(x+8,1190),Vector2(x-3,1230)]),Color("6c8276"),1,true)
	_trail([Vector2(80,440),Vector2(245,410),Vector2(415,450),Vector2(540,420)],46)
	_trail([Vector2(245,410),Vector2(270,295),Vector2(300,210),Vector2(335,155)],34)
	_trail([Vector2(245,410),Vector2(180,625),Vector2(230,760),Vector2(265,900),Vector2(400,1035),Vector2(555,980)],42)
	_trail([Vector2(555,980),Vector2(785,980),Vector2(970,1010)],40)
	_trail([Vector2(785,420),Vector2(890,465),Vector2(1040,420)],44)
	_trail([Vector2(890,465),Vector2(890,350),Vector2(910,280)],32)
	_trail([Vector2(890,465),Vector2(845,575),Vector2(935,675),Vector2(1080,750),Vector2(1280,850),Vector2(1450,880),Vector2(1580,870)],42)
	_trail([Vector2(935,675),Vector2(860,830),Vector2(970,1010),Vector2(1150,1110),Vector2(1390,1080),Vector2(1580,1000),Vector2(1580,870)],39)
	_trail([Vector2(1040,420),Vector2(1000,155),Vector2(1300,100),Vector2(1550,110),Vector2(1650,290),Vector2(1640,550),Vector2(1580,870)],34)
	# Ink specks and irregular plants belong to the walkable terrain itself.
	# The illustrated region paintings remain in the atlas rather than showing
	# buildings that the player cannot physically visit behind this landscape.
	for index in range(1250):
		var point:=Vector2(40+posmod(index*197,1840),80+posmod(index*131,1150))
		if absf(point.x-_stream_center(point.y))<88 or Rect2(1070,140,340,520).has_point(point): continue
		var tint:=Color("7b9270") if index%3 else Color("e4e6b9")
		draw_line(point,point+Vector2(1+index%3,-1-index%2),tint,0.65,true)
	for index in range(80):
		var point:=Vector2(55+posmod(index*293,1800),100+posmod(index*173,1090))
		var clear: bool=absf(point.x-_stream_center(point.y))>125 and not Rect2(1000,120,530,550).has_point(point)
		for site: Vector2 in POSITIONS.values():
			if point.distance_to(site)<110: clear=false
		if clear: _bush(point,13+index%4*6,Color("9ab97e") if index%3 else Color("b8ca87"))
	for index in range(170):
		var point:=Vector2(55+posmod(index*127,1800),95+posmod(index*83,1095))
		if absf(point.x-_stream_center(point.y))<100 or Rect2(1070,140,340,520).has_point(point): continue
		var color:=Color("809b74") if index%3 else Color("a0b581")
		draw_line(point,point+Vector2(3,-5),color,0.8,true)
		if index%4==0: draw_line(point+Vector2(3,0),point+Vector2(7,-7),color,0.8,true)
	for index in range(17):
		var y: float=94+index*68
		var center: float=_stream_center(y)
		_rock(Vector2(center-95,y),0.45+float(index%3)*0.16)
		_rock(Vector2(center+103,y+24),0.52+float(index%2)*0.18)
	for stone: Vector3 in BOULDERS:
		_rock(Vector2(stone.x,stone.y),stone.z/32)
		for index in range(3): _leaf(Vector2(stone.x-stone.z*0.4+index*19,stone.y-18),Vector2(stone.x-stone.z*0.6+index*24,stone.y-42-index*7),8,Color("a5ba82"))
	# Fern groves at the outer edge frame the paths; the central clearings stay legible.
	for index in range(15):
		var point:=Vector2(50+posmod(index*337,1800),85+posmod(index*211,1110))
		var clear: bool=true
		for site: Vector2 in POSITIONS.values():
			if point.distance_to(site)<160: clear=false
		if not clear or absf(point.x-_stream_center(point.y))<140 or Rect2(1000,120,530,550).has_point(point): continue
		for leaf_index in range(5):
			_leaf(point,point+Vector2(-62+leaf_index*31,-70-40*sin(leaf_index*0.8)),14+float(leaf_index%2)*4,Color("88a67b") if leaf_index%2 else Color("adc28d"))
	# Potting is part of the landscape, within the shelter of the first clearing.
	_poly(PackedVector2Array([Vector2(295,472),Vector2(379,457),Vector2(412,478),Vector2(326,495)]),Color("bf9873"))
	draw_line(Vector2(326,495),Vector2(327,530),INK,4,true)
	draw_line(Vector2(396,482),Vector2(396,516),INK,4,true)
	_ellipse(Vector2(349,476),Vector2(13,7),Color("e0b07b"),INK)
	draw_line(Vector2(348,473),Vector2(349,456),INK,1.2,true)
	_leaf(Vector2(349,463),Vector2(336,451),6,Color("8daf78"))

func _draw_discoveries() -> void:
	_draw_rain_nursery()
	_draw_seed_hollow()
	_draw_cistern()
	_draw_moth_garden()
	_draw_wind_terrace()

func _draw_rain_nursery() -> void:
	var foot: Vector2=POSITIONS.rain_nursery
	var solved: bool=_site_solved("rain_nursery")
	# A roofless little propagator: thin iron ribs, terracotta seed trays, rain.
	_poly(PackedVector2Array([foot+Vector2(-108,24),foot+Vector2(82,36),foot+Vector2(125,5),foot+Vector2(-63,-10)]),Color("c9b494"))
	for side: float in [-1,1]:
		var base: Vector2=foot+Vector2(side*89,5)
		draw_line(base,base+Vector2(0,-118),Color("657e6d"),3,true)
		draw_arc(foot+Vector2(0,-114),89,PI,TAU,36,Color("657e6d"),3,true)
	for row in range(2):
		for column in range(5):
			var pot: Vector2=foot+Vector2(-70+column*30,-6+row*24)
			_poly(PackedVector2Array([pot+Vector2(-11,-7),pot+Vector2(10,-7),pot+Vector2(7,5),pot+Vector2(-7,5)]),Color("c39373"))
			if solved: _leaf(pot+Vector2(0,-5),pot+Vector2(5,-24),5,Color("9cb881"))
	if _site_approach("rain_nursery")=="canopy" or _site_combined("rain_nursery"):
		for leaf_index in range(5):
			_leaf(foot+Vector2(0,-98),foot+Vector2(-112+leaf_index*55,-128-25*sin(leaf_index*0.8)),28,Color("a6bf8c"))
	for index in range(17):
		var point: Vector2=foot+Vector2(-135+posmod(index*43,270),-185+fposmod(index*31+_time*49,190))
		if solved and (_site_approach("rain_nursery")=="canopy" or _site_combined("rain_nursery")) and point.y>foot.y-120: continue
		draw_line(point,point+Vector2(-2,8),Color("8faeb0"),0.9,true)
	if _site_approach("rain_nursery")=="glow" or _site_combined("rain_nursery"):
		for index in range(8): _moth(foot+Vector2(sin(_time+index*1.1)*91,cos(_time*0.8+index)*30-70),index,true)

func _draw_seed_hollow() -> void:
	var foot: Vector2=POSITIONS.seed_catch
	var solved: bool=_site_solved("seed_catch")
	_ellipse(foot+Vector2(0,18),Vector2(113,48),Color("dbd1a7"),Color("9d9d77"))
	for index in range(7):
		var root: Vector2=foot+Vector2(-110+index*35,15+sin(index)*24)
		var top: Vector2=root+Vector2(15+sin(_time*1.4+index)*4,-62-index%3*11)
		draw_line(root,top,Color("6c8763"),1.4,true)
		_ellipse(top,Vector2(8,10),Color("d8c69d"),Color("839271"))
	if _site_approach("seed_catch")=="coil":
		for side: float in [-1,1]: draw_line(foot+Vector2(side*93,12),foot+Vector2(side*93,-100),Color("8d755b"),4,true)
		for index in range(7):
			var x: float=-90+index*30
			draw_polyline(PackedVector2Array([foot+Vector2(x,-95),foot+Vector2(x+sin(index)*9,-45),foot+Vector2(x,0)]),Color("76996e"),2,true)
		for index in range(5):
			var y: float=-93+index*23
			draw_polyline(PackedVector2Array([foot+Vector2(-92,y),foot+Vector2(0,y+16),foot+Vector2(92,y)]),Color("76996e"),2,true)
	elif solved:
		for index in range(4): _leaf(foot+Vector2(-54+index*36,4),foot+Vector2(-78+index*45,-50-index%2*18),24,Color("a7c28b"))
	for index in range(15):
		var x: float=-180+fposmod(index*41+_time*29,365)
		if solved: x=clampf(x,-85,85)
		var point: Vector2=foot+Vector2(x,-42+sin(_time+index*1.9)*34)
		draw_line(point,point+Vector2(3,5),Color("8e896c"),0.8,true)
		_ellipse(point+Vector2(0,-2),Vector2(4,2),Color("fbf0ca") if not _site_combined("seed_catch") else Color("fff4a6"))

func _draw_cistern() -> void:
	var foot: Vector2=POSITIONS.cistern
	var solved: bool=_site_solved("cistern")
	# The feeder channel and broken stepping route advertise a second loop.
	var channel:=PackedVector2Array([Vector2(740,980),Vector2(810,1010),Vector2(860,990),foot+Vector2(-90,6)])
	draw_polyline(channel,Color("879b8a"),28,true)
	draw_polyline(channel,Color("90b8aa") if solved else Color("c0b79a"),20,true)
	_ellipse(foot+Vector2(0,24),Vector2(118,67),Color("9ba994"),INK)
	_ellipse(foot+Vector2(0,5),Vector2(118,63),Color("d6d1b6"),INK)
	_ellipse(foot+Vector2(0,3),Vector2(96,48),Color("79b9ac") if solved else Color("b8b599"),INK)
	for index in range(11):
		var angle: float=TAU*float(index)/11
		draw_line(foot+Vector2(cos(angle)*98,sin(angle)*50),foot+Vector2(cos(angle)*116,sin(angle)*61),Color("7d8d7a"),1,true)
	if solved:
		for index in range(3): draw_arc(foot+Vector2(0,4),24+fposmod(_time*9+index*21,63),0.08,2.9,28,Color("c0dfc6"),0.9,true)
		if _site_approach("cistern")=="coil":
			for side: float in [-1,1]:
				draw_polyline(PackedVector2Array([Vector2(540,980+side*23),Vector2(650,970+side*23),Vector2(790,980+side*23),foot+Vector2(-25,8)]),Color("79976c"),6,true)
			for index in range(12): draw_line(Vector2(548+index*20,957),Vector2(551+index*20,1003),Color("a5b986"),4,true)
		else:
			for index in range(5): _leaf(Vector2(548+index*47,1000),Vector2(601+index*47,965),25,Color("9abc90"))
	if _site_combined("cistern"):
		for index in range(10): _ellipse(Vector2(770+index*20,1000+sin(index)*7),Vector2(2,2),Color("f4e6a3"))

func _draw_moth_garden() -> void:
	var foot: Vector2=POSITIONS.moth_garden
	var solved: bool=_site_solved("moth_garden")
	_ellipse(foot+Vector2(0,8),Vector2(136,65),Color("b1c2aa"),Color("879d8b"))
	for index in range(16):
		var angle: float=TAU*float(index)/16
		var point: Vector2=foot+Vector2(cos(angle)*119,sin(angle)*52)
		_rock(point,0.25+float(index%3)*0.07)
		if index%2==0: _flower(point+Vector2(-10,-2),Color("e5b0a3"),1.1)
	for index in range(7):
		var point: Vector2=foot+Vector2(-64+index*23,24+sin(index)*17)
		_flower(point,Color("ecd8b1") if not solved else Color("f4c0ac"),0.9+float(index%2)*0.25)
	if _site_combined("moth_garden"):
		for index in range(3): _leaf(foot+Vector2(0,-72),foot+Vector2(-84+index*79,-100-index%2*28),35,Color("a4bd8f"))
	var count: int=16 if solved else 3
	for index in range(count):
		var point: Vector2=foot+Vector2(sin(_time*0.6+index*1.4)*(95 if solved else 145),cos(_time*0.8+index)*35-43)
		_moth(point,index,solved)
	if solved:
		for index in range(11):
			var point:=Vector2(1010+index*43,735+index*9+sin(_time+index)*9)
			_moth(point,index,true)

func _draw_wind_terrace() -> void:
	var foot: Vector2=POSITIONS.wind_terrace
	_poly(PackedVector2Array([foot+Vector2(-165,46),foot+Vector2(-40,72),foot+Vector2(155,24),foot+Vector2(160,61),foot+Vector2(5,117),foot+Vector2(-150,84)]),Color("b1baa0"))
	for index in range(10):
		var x: float=-143+index*31
		draw_line(foot+Vector2(x,55-absf(x)*0.1),foot+Vector2(x+5,89-absf(x)*0.1),Color("788c79"),1,true)
	for side: float in [-1,1]:
		var base: Vector2=foot+Vector2(side*110,9)
		draw_line(base,base+Vector2(0,-94),Color("7c8b6d"),3,true)
		var flag:=PackedVector2Array([base+Vector2(0,-94),base+Vector2(28+sin(_time*2)*5,-90),base+Vector2(46,-72+sin(_time*2+1)*4),base+Vector2(4,-76)])
		_poly(flag,Color("dba18a"),Color("7d8770"),1)
	if _site_approach("wind_terrace")=="coil":
		var arch:=PackedVector2Array()
		for index in range(25):
			var angle: float=PI+PI*float(index)/24
			arch.append(foot+Vector2(cos(angle)*87,sin(angle)*122))
		draw_polyline(arch,INK,10,true)
		draw_polyline(arch,Color("88a87b"),6,true)
		for index in range(9):
			var angle: float=PI+PI*float(index)/8
			var point: Vector2=foot+Vector2(cos(angle)*87,sin(angle)*122)
			_leaf(point,point+Vector2(22,-12),9,Color("b1c691"))
			if _site_combined("wind_terrace"): _ellipse(point+Vector2(7,-8),Vector2(3,3),Color("fff0ae"))
	elif _site_solved("wind_terrace"):
		for index in range(5): _leaf(foot+Vector2(-80+index*40,10),foot+Vector2(-96+index*40,-84-index%2*27),25,Color("a7c18b"))
	for index in range(14):
		var point: Vector2=foot+Vector2(-168+fposmod(index*39+_time*43,330),-15+sin(index+_time)*34)
		draw_line(point,point+Vector2(16,2),Color("dbe1bc"),0.85,true)

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
	for section in range(8):
		var y: float=100+section*73
		if restored and y+78>338 and y<502: continue
		_poly(PackedVector2Array([Vector2(1076,y),Vector2(1093,y-12),Vector2(1110,y-2),Vector2(1110,y+66),Vector2(1092,y+78),Vector2(1076,y+68)]),Color("c1c6aa"))
		for seam in range(3):
			draw_line(Vector2(1077,y+16+seam*18),Vector2(1092,y+25+seam*18),Color("7d8c77"),0.9,true)
			draw_line(Vector2(1092,y+25+seam*18),Vector2(1109,y+14+seam*18),Color("7d8c77"),0.9,true)
	for side in range(3):
		var wall_start: Vector2=Vector2(1110,185) if side==0 else (Vector2(1380,185) if side==1 else Vector2(1380,640))
		var wall_end: Vector2=Vector2(1380,185) if side==0 else (Vector2(1380,640) if side==1 else Vector2(1110,640))
		draw_line(wall_start,wall_end,INK,20,true)
		draw_line(wall_start,wall_end,Color("bac4a5"),16,true)
		for segment in range(10):
			var point: Vector2=wall_start.lerp(wall_end,float(segment)/10)
			if side==1: draw_line(point+Vector2(-8,0),point+Vector2(8,0),Color("7b8e78"),0.9,true)
			else: draw_line(point+Vector2(0,-8),point+Vector2(0,8),Color("7b8e78"),0.9,true)
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
		if key in ["crossing","gate"] or key in DISCOVERY_IDS: continue
		var p: Vector2=POSITIONS[key]
		_ellipse(p+Vector2(0,5),Vector2(39,13),Color("bec999"),Color("87996c"))
		if key=="moonbell":
			for i in range(5):
				var angle: float=_time*0.45+float(i)*TAU/5.0
				var q:=p+Vector2(cos(angle)*45,sin(angle)*14-44)
				_ellipse(q,Vector2(2.4,2.4),Color("fff2b8"))
		if _rows.get(key,{}).get("claimed",false):
			_poly(PackedVector2Array([p+Vector2(28,-12),p+Vector2(34,-8),p+Vector2(44,-21),p+Vector2(47,-17),p+Vector2(35,-3),p+Vector2(26,-8)]),Color("b1c389"),INK,0.8)
	var guide: String=str(_guided_step.get("key",""))
	if POSITIONS.has(guide):
		var marker: Vector2=POSITIONS[guide]
		var marker_y: float=-126 if guide in _rows else -34
		var bounce: float=sin(_time*3.5)*3
		_poly(PackedVector2Array([marker+Vector2(-8,marker_y+bounce),marker+Vector2(8,marker_y+bounce),marker+Vector2(0,marker_y+11+bounce)]),Color("e6b46a"),INK,1.2)
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
