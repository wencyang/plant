extends Control
class_name Wilderness
## Original handheld-style field exploration. The map and collisions share one
## deterministic tile field; finding a plant never changes the home garden.
signal returned_home()
signal encounter_requested(biome: String, site_id: String)
signal supplies_requested()
signal position_changed()

const MAP_WIDTH: int = 40
const MAP_HEIGHT: int = 32
const TILE: int = 16
const DETAIL: int = 2
const STEP_TIME: float = 0.15
const HOME := Vector2i(15, 20)
const SITES: Array = [
	{"id":"moss_01","x":15,"y":15,"biome":"Mosswood"},
	{"id":"moss_02","x":18,"y":17,"biome":"Mosswood"},
	{"id":"moss_03","x":20,"y":23,"biome":"Mosswood"},
	{"id":"moss_04","x":10,"y":23,"biome":"Mosswood"},
	{"id":"moss_05","x":16,"y":28,"biome":"Mosswood"},
	{"id":"moss_06","x":21,"y":12,"biome":"Mosswood"},
	{"id":"fen_01","x":29,"y":17,"biome":"Sporefen"},
	{"id":"fen_02","x":34,"y":22,"biome":"Sporefen"},
	{"id":"fen_03","x":28,"y":27,"biome":"Sporefen"},
	{"id":"fen_04","x":36,"y":15,"biome":"Sporefen"},
	{"id":"amber_01","x":8,"y":12,"biome":"Amber Hollow"},
	{"id":"amber_02","x":5,"y":8,"biome":"Amber Hollow"},
	{"id":"amber_03","x":10,"y":4,"biome":"Amber Hollow"},
	{"id":"amber_04","x":3,"y":14,"biome":"Amber Hollow"},
	{"id":"glade_01","x":29,"y":8,"biome":"Sunken Glade"},
	{"id":"glade_02","x":35,"y":5,"biome":"Sunken Glade"},
	{"id":"glade_03","x":25,"y":4,"biome":"Sunken Glade"},
	{"id":"glade_04","x":36,"y":10,"biome":"Sunken Glade"}
]
var state = null
var waiting: bool = false
var player_tile := Vector2i(15, 18)
var map_seed: int = 8149
var _terrain: PackedInt32Array = []
var _map_texture: ImageTexture
var _map_image: Image
var _trees: Array[Vector2i] = []
var _blocked: Dictionary = {}
var _camera := Vector2.ZERO
var _map_rect := Rect2()
var _pixel_scale: int = 2
var _time: float = 0
var _step_cooldown: float = 0
var _facing := Vector2i(0, 1)
var _walk_phase: int = 0
var _held_direction := Vector2i.ZERO
var _touch_goal := Vector2i(-1, -1)
var _location_label: Label
var _resources_label: Label
var _hint_label: Label
var _target_label: Label
var _action_button: Button
var _header: PanelContainer
var _footer: PanelContainer
var _header_title: Label
var _top_row: HBoxContainer
var _legend_label: Label
var _dpad: GridContainer
var _home_button: Button
var _supplies_button: Button
var _last_biome: String = ""
var _message: String = "Follow the north path. A wild specimen is growing nearby."
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var crisp_font := SystemFont.new()
	crisp_font.font_names = PackedStringArray(["Helvetica Neue","Arial","DejaVu Sans"])
	crisp_font.font_weight = 400
	_font = crisp_font
	if state != null:
		map_seed = int(state.expedition.get("map_seed",8149))
		var saved: Array = state.expedition.get("position",[15,18])
		player_tile = Vector2i(clampi(int(saved[0]),1,MAP_WIDTH-2),clampi(int(saved[1]),1,MAP_HEIGHT-2))
	_build_map()
	if not is_walkable(player_tile): player_tile = Vector2i(15,18)
	_build_ui()
	resized.connect(_layout)
	_layout()
	refresh()
	grab_focus()

func _style(background: Color, border: Color, padding: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = background
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font",_font)
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	return l

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.add_theme_font_override("font",_font)
	b.add_theme_font_size_override("font_size",14)
	b.add_theme_stylebox_override("normal",_style(Color("284d3d"),Color("779976"),8))
	b.add_theme_stylebox_override("hover",_style(Color("38634b"),Color("bdd19a"),8))
	b.add_theme_stylebox_override("pressed",_style(Color("1b382e"),Color("d9c38e"),8))
	b.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),Color("e5d6a2"),8))
	b.pressed.connect(action)
	return b

func _build_ui() -> void:
	_header = PanelContainer.new()
	_header.add_theme_stylebox_override("panel",_style(Color("122c27"),Color("78927a"),12))
	add_child(_header)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation",6)
	_header.add_child(top)
	_top_row = HBoxContainer.new()
	top.add_child(_top_row)
	_header_title = _label("FIELD EXPEDITION",16,Color("e1d9ae"))
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_row.add_child(_header_title)
	_supplies_button = _button("Supplies",func(): supplies_requested.emit())
	_top_row.add_child(_supplies_button)
	_home_button = _button("Home",func(): returned_home.emit())
	_top_row.add_child(_home_button)
	var info := HBoxContainer.new()
	top.add_child(info)
	_location_label = _label("MOSSWOOD / ROUTE 01",14,Color("b9ccad"))
	_location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_location_label)
	_resources_label = _label("",13,Color("d7c494"))
	info.add_child(_resources_label)
	_footer = PanelContainer.new()
	_footer.add_theme_stylebox_override("panel",_style(Color("122c27"),Color("78927a"),12))
	add_child(_footer)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",7)
	_footer.add_child(column)
	_target_label = _label("",15,Color("e3d9ac"))
	_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_target_label)
	var row := HBoxContainer.new()
	column.add_child(row)
	_dpad = GridContainer.new()
	_dpad.columns = 3
	_dpad.add_theme_constant_override("h_separation",3)
	_dpad.add_theme_constant_override("v_separation",3)
	row.add_child(_dpad)
	for direction in [Vector2i.ZERO,Vector2i.UP,Vector2i.ZERO,Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT]:
		if direction == Vector2i.ZERO:
			var blank := Control.new()
			blank.custom_minimum_size = Vector2(38,32)
			_dpad.add_child(blank)
		else:
			var text: String = "W" if direction == Vector2i.UP else ("A" if direction == Vector2i.LEFT else ("S" if direction == Vector2i.DOWN else "D"))
			var key := _button(text,func(): pass)
			key.custom_minimum_size = Vector2(38,32)
			key.button_down.connect(func(): _held_direction = direction; _try_step(direction))
			key.button_up.connect(func(): _held_direction = Vector2i.ZERO)
			_dpad.add_child(key)
	# Main action occupies the right side of the walking controls.
	var action_column := VBoxContainer.new()
	action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(action_column)
	_action_button = _button("Investigate [E]",interact)
	_action_button.custom_minimum_size.y = 44
	action_column.add_child(_action_button)
	_hint_label = _label("",14,Color("a2bba2"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_column.add_child(_hint_label)
	_legend_label = _label("WASD / ARROWS: WALK    E / SPACE: INVESTIGATE    TAP: WALK",12,Color("8eaa94"))
	column.add_child(_legend_label)

func _layout() -> void:
	var compact: bool = size.x < 700
	_pixel_scale = 2
	_fit_panels()
	_header_title.text = "FIELD JOURNAL" if compact else "FIELD EXPEDITION / THE OUTER GARDENS"
	_header_title.add_theme_font_size_override("font_size",13 if compact else 16)
	_location_label.add_theme_font_size_override("font_size",12 if compact else 14)
	_resources_label.add_theme_font_size_override("font_size",12 if compact else 13)
	_legend_label.visible = not compact
	_update_camera()
	queue_redraw()

func _fit_panels() -> void:
	# Containers may temporarily grow during narrow first-frame text wrapping.
	# Reapply the viewport bounds once their final minimum sizes have settled.
	var compact: bool = size.x < 700
	var margin: float = 8 if compact else 18
	_header.position = Vector2(margin,margin)
	_header.size = Vector2(maxf(1,size.x-margin*2),86 if compact else 88)
	_footer.size = Vector2(maxf(1,size.x-margin*2),164 if compact else 152)
	_footer.position = Vector2(margin,size.y-_footer.size.y-margin)
	var field_width: float = minf(size.x-margin*2,MAP_WIDTH*TILE*_pixel_scale)
	_map_rect = Rect2(Vector2((size.x-field_width)*0.5,_header.position.y+_header.size.y+8),Vector2(maxf(1,field_width),maxf(1,_footer.position.y-_header.position.y-_header.size.y-16)))

func refresh() -> void:
	if not is_instance_valid(_resources_label): return
	var collected: int = 0
	if state != null:
		collected = state.expedition.get("collected_sites",[]).size()
		_resources_label.text = "%d KITS / %d FOUND" % [int(state.field_kits),collected]
	var biome: String = biome_at(player_tile)
	_location_label.text = biome.to_upper() + " / ROUTE " + ("01" if biome=="Mosswood" else ("02" if biome=="Amber Hollow" else ("03" if biome=="Sporefen" else "04")))
	var site: Dictionary = nearest_site()
	if not site.is_empty() and _distance(player_tile,Vector2i(site.x,site.y)) <= 2:
		_target_label.text = "WILD GROWTH / " + str(site.biome).to_upper()
		_action_button.text = "Investigate [E]"
		_action_button.disabled = waiting
		_hint_label.text = "Something unfamiliar is growing here. Approach with a field kit."
	elif _distance(player_tile,HOME) <= 2:
		_target_label.text = "YOUR CONSERVATORY / HOME"
		_action_button.text = "Return home [E]"
		_action_button.disabled = waiting
		_hint_label.text = "Bring your discoveries back to breed, display, and battle."
	else:
		_target_label.text = "FOLLOW THE PATH / FIND WILD SPECIMENS"
		_action_button.text = "Look around [E]"
		_action_button.disabled = waiting
		_hint_label.text = _message
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_time += delta
	_step_cooldown = maxf(0,_step_cooldown-delta)
	if not waiting and _step_cooldown <= 0:
		var direction: Vector2i = _held_direction
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction = Vector2i.UP
		elif Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction = Vector2i.DOWN
		elif Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction = Vector2i.LEFT
		elif Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction = Vector2i.RIGHT
		if direction != Vector2i.ZERO:
			_touch_goal = Vector2i(-1,-1)
			_try_step(direction)
		elif _touch_goal.x >= 0:
			if _touch_goal == player_tile: _touch_goal = Vector2i(-1,-1)
			else:
				var path: Array[Vector2i] = _find_path(player_tile,_touch_goal)
				if path.size()>1: _try_step(path[1]-player_tile)
				else: _touch_goal = Vector2i(-1,-1)
	_fit_panels()
	_update_camera()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or waiting: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:
			interact()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE:
			returned_home.emit()
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if waiting: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _map_rect.has_point(event.position):
		var world: Vector2 = (event.position-_map_rect.position)/float(_pixel_scale)+_camera
		var tile := Vector2i(floori(world.x/TILE),floori(world.y/TILE))
		if is_walkable(tile):
			_touch_goal = tile
			_message = "Walking to the marked patch."
			refresh()
		accept_event()

func _try_step(direction: Vector2i) -> bool:
	if waiting or direction == Vector2i.ZERO: return false
	_facing = direction
	_step_cooldown = STEP_TIME
	var target: Vector2i = player_tile+direction
	if not is_walkable(target): return false
	player_tile = target
	_walk_phase = 1-_walk_phase
	if state != null: state.move_explorer(player_tile.x,player_tile.y)
	var biome: String = biome_at(player_tile)
	if biome != _last_biome:
		_last_biome = biome
		_message = {"Mosswood":"Fern trails and sheltered blooms. Follow the north path.","Amber Hollow":"Warm soil shelters bright blooms and bitter orchids.","Sporefen":"The wet ground breathes. Look for pale spore caps.","Sunken Glade":"Pale tendrils live in the old canopy's shadow."}.get(biome,"")
	refresh()
	position_changed.emit()
	return true

func interact() -> void:
	if waiting: return
	_held_direction = Vector2i.ZERO
	_touch_goal = Vector2i(-1,-1)
	var site: Dictionary = nearest_site()
	if not site.is_empty() and _distance(player_tile,Vector2i(site.x,site.y)) <= 2:
		waiting = true
		refresh()
		encounter_requested.emit(str(site.biome),str(site.id))
	elif _distance(player_tile,HOME) <= 2:
		returned_home.emit()
	else:
		_message = "No wild plant within reach. Look for a tall marked specimen beside the paths."
		refresh()

func encounter_closed() -> void:
	waiting = false
	_held_direction = Vector2i.ZERO
	_step_cooldown = 0.2
	refresh()
	grab_focus()

func nearest_site() -> Dictionary:
	var nearest: Dictionary = {}
	var best: int = 100000
	for site: Dictionary in SITES:
		if _site_unavailable(str(site.id)): continue
		var distance: int = _distance(player_tile,Vector2i(site.x,site.y))
		if distance < best:
			best = distance
			nearest = site
	return nearest

func teleport_to_site(site_id: String) -> void:
	for site: Dictionary in SITES:
		if str(site.id) == site_id:
			player_tile = Vector2i(site.x,site.y+1)
			if not is_walkable(player_tile): player_tile = Vector2i(site.x,site.y)
			if state != null: state.move_explorer(player_tile.x,player_tile.y)
			_update_camera()
			refresh()
			return

func _site_unavailable(id: String) -> bool:
	if state == null: return false
	if id in state.expedition.get("collected_sites",[]): return true
	var record: Dictionary = state.expedition.get("site_records",{}).get(id,{})
	return bool(record.get("fled",false))

func _distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

func biome_at(tile: Vector2i) -> String:
	if tile.y < 11 and tile.x >= 23: return "Sunken Glade"
	if tile.x >= 25 and tile.y >= 11: return "Sporefen"
	if tile.x < 12 and tile.y < 15: return "Amber Hollow"
	return "Mosswood"

func is_walkable(tile: Vector2i) -> bool:
	if tile.x<1 or tile.x>=MAP_WIDTH-1 or tile.y<1 or tile.y>=MAP_HEIGHT-1: return false
	if _terrain.is_empty(): return true
	return _terrain[tile.y*MAP_WIDTH+tile.x] != 2 and not _blocked.has(tile)

func _find_path(start: Vector2i,target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_walkable(target): return result
	var pending: Array[Vector2i] = [start]
	var previous: Dictionary = {start:Vector2i(-1,-1)}
	var cursor: int = 0
	while cursor < pending.size():
		var current: Vector2i = pending[cursor]
		cursor += 1
		if current == target: break
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = current+direction
			if is_walkable(next) and not previous.has(next):
				previous[next] = current
				pending.append(next)
	if not previous.has(target): return result
	var point: Vector2i = target
	while point.x >= 0:
		result.push_front(point)
		point = previous[point]
	return result

func _hash(x: int,y: int, salt: int = 0) -> int:
	return posmod(x*73856093 ^ y*19349663 ^ map_seed ^ salt*83492791,2147483647)

func _water(tile: Vector2i) -> bool:
	for pond: Vector4 in [Vector4(22,7,3,2),Vector4(33,26,4,2),Vector4(34,19,3,3),Vector4(6,27,4,2)]:
		var dx: float = float(tile.x-pond.x)/pond.z
		var dy: float = float(tile.y-pond.y)/pond.w
		if dx*dx+dy*dy<1: return true
	return false

func _carve_line(a: Vector2i,b: Vector2i) -> void:
	var p: Vector2i = a
	while p != b:
		_terrain[p.y*MAP_WIDTH+p.x] = 1
		if p.x != b.x: p.x += 1 if b.x>p.x else -1
		else: p.y += 1 if b.y>p.y else -1
	_terrain[b.y*MAP_WIDTH+b.x] = 1

func _build_map() -> void:
	_terrain.resize(MAP_WIDTH*MAP_HEIGHT)
	_trees.clear()
	_blocked.clear()
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH): _terrain[y*MAP_WIDTH+x] = 2 if _water(Vector2i(x,y)) else 0
	_carve_line(Vector2i(15,2),Vector2i(15,29))
	_carve_line(Vector2i(3,14),Vector2i(37,14))
	_carve_line(Vector2i(8,4),Vector2i(8,14))
	_carve_line(Vector2i(30,4),Vector2i(30,28))
	_carve_line(Vector2i(15,21),Vector2i(30,21))
	for site: Dictionary in SITES:
		var p := Vector2i(site.x,site.y)
		var hub: Vector2i = Vector2i(30,p.y) if p.x>=25 else Vector2i(15,p.y)
		_carve_line(p,hub)
		_terrain[p.y*MAP_WIDTH+p.x] = 0
	# A tended clearing and the door of the home conservatory.
	for y in range(17,22):
		for x in range(12,19): _terrain[y*MAP_WIDTH+x] = 1
	for y in range(2,MAP_HEIGHT-2):
		for x in range(2,MAP_WIDTH-2):
			var tile := Vector2i(x,y)
			if _terrain[y*MAP_WIDTH+x] != 0 or _hash(x,y,1)%17 != 0: continue
			var safe: bool = _distance(tile,Vector2i(15,19))<6
			for site: Dictionary in SITES:
				if _distance(tile,Vector2i(site.x,site.y))<3: safe = true
			if safe: continue
			# Canopy trunks block one tile; branches float above neighboring ground.
			_trees.append(tile)
			_blocked[tile] = true
	# The home greenhouse occupies only its own back wall, never its entrance.
	for x in range(13,18): _blocked[Vector2i(x,19)] = true
	_blocked.erase(Vector2i(15,19))
	_map_image = Image.create(MAP_WIDTH*TILE*DETAIL,MAP_HEIGHT*TILE*DETAIL,false,Image.FORMAT_RGBA8)
	_map_image.fill(Color("325f49"))
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			_paint_tile(Vector2i(x,y))
			_paint_tile_detail(Vector2i(x,y))
	for tile: Vector2i in _trees:
		_paint_tree(tile)
		_paint_tree_detail(tile)
	_paint_home()
	_paint_home_detail()
	_map_texture = ImageTexture.create_from_image(_map_image)

func _rect(x: int,y: int,w: int,h: int,color: Color) -> void:
	var rect := Rect2i(x*DETAIL,y*DETAIL,w*DETAIL,h*DETAIL).intersection(Rect2i(0,0,_map_image.get_width(),_map_image.get_height()))
	if rect.size.x>0 and rect.size.y>0: _map_image.fill_rect(rect,color)

func _paint_tile(tile: Vector2i) -> void:
	var x: int = tile.x*TILE
	var y: int = tile.y*TILE
	var value: int = _hash(tile.x,tile.y)
	var biome: String = biome_at(tile)
	var palettes: Dictionary = {
		"Mosswood":[Color("37634a"),Color("416e50"),Color("2d563f"),Color("71965c")],
		"Amber Hollow":[Color("6e7445"),Color("7a8050"),Color("5c653c"),Color("aaa35c")],
		"Sporefen":[Color("345d55"),Color("416c60"),Color("294d47"),Color("7caa83")],
		"Sunken Glade":[Color("3b5c65"),Color("456c71"),Color("2d4b56"),Color("8ba99b")]
	}
	var palette: Array = palettes[biome]
	var terrain: int = _terrain[tile.y*MAP_WIDTH+tile.x]
	if terrain == 2:
		_rect(x,y,TILE,TILE,Color("284c59"))
		_rect(x,y+2,TILE,2,Color("2d5f68"))
		_rect(x+value%7,y+8,6,1,Color("4a8186"))
		_rect(x+((value/7)%8),y+12,4,1,Color("386b77"))
		if not _water(tile+Vector2i.UP): _rect(x,y,TILE,2,Color("779b7a"))
		if not _water(tile+Vector2i.LEFT): _rect(x,y,2,TILE,Color("779b7a"))
		if value%5==0:
			_rect(x+5,y+5,5,3,Color("53866a"))
			_rect(x+6,y+4,3,1,Color("80aa7b"))
		return
	_rect(x,y,TILE,TILE,(palette[0] as Color).lerp(palette[1],float(value%5)*0.065))
	if terrain == 1:
		if _water(tile):
			_rect(x,y,TILE,TILE,Color("777850"))
			for yy in range(1,16,4):
				_rect(x,y+yy,TILE,1,Color("b1a371"))
				_rect(x+1,y+yy+1,1,2,Color("4f6048"))
		else:
			_rect(x+1,y+1,14,14,Color("a79c6c"))
			_rect(x,y+3,16,10,Color("a79c6c"))
			_rect(x+3,y,10,16,Color("a79c6c"))
			_rect(x+value%11+2,y+(value/13)%11+2,2,1,Color("c3b585"))
			_rect(x+(value/5)%12+1,y+(value/29)%11+2,2,1,Color("8e8b5e"))
	else:
		for i in range(4):
			var xx: int = x+2+_hash(tile.x,tile.y,i+2)%12
			var yy: int = y+3+_hash(tile.x,tile.y,i+9)%11
			_rect(xx,yy,1,2,palette[2])
			_rect(xx-1,yy-1,1,1,palette[3])
			_rect(xx+1,yy-2,1,2,palette[3])
		if value%9 == 0:
			var c: Color = Color("a5c3a1") if biome=="Sporefen" else Color("d3bc81")
			_rect(x+5,y+8,2,2,c)
			_rect(x+6,y+7,1,1,Color("e4dbaf"))
	# The boundary is an irregular, impassable hedge rather than empty void.
	if tile.x==0 or tile.y==0 or tile.x==MAP_WIDTH-1 or tile.y==MAP_HEIGHT-1:
		_rect(x,y,16,16,Color("214237"))
		_rect(x+2,y+2,12,10,Color("375a41"))
		_rect(x+4,y+1,7,2,Color("527a4d"))

func _paint_tree(tile: Vector2i) -> void:
	var x: int = tile.x*TILE+8
	var y: int = tile.y*TILE+10
	var glade: bool = biome_at(tile)=="Sunken Glade"
	var dark: Color = Color("263e45") if glade else Color("203f34")
	var middle: Color = Color("456b65") if glade else Color("3f714c")
	var light: Color = Color("739687") if glade else Color("6c955b")
	_rect(x-11,y+3,22,5,Color("2a4c3b"))
	_rect(x-2,y-7,4,14,Color("6f7050"))
	_rect(x-1,y-5,1,10,Color("b2a273"))
	_rect(x-12,y-22,24,19,dark)
	_rect(x-15,y-18,30,10,dark)
	_rect(x-9,y-26,18,26,dark)
	_rect(x-11,y-21,22,15,middle)
	_rect(x-14,y-16,27,7,middle)
	_rect(x-7,y-25,14,24,middle)
	_rect(x-6,y-24,12,3,light)
	_rect(x-11,y-19,8,3,light)
	_rect(x+3,y-12,7,2,light)
	_rect(x-8,y-5,5,2,dark)
	_rect(x+2,y-18,2,2,Color("90aa76"))
	if biome_at(tile)=="Amber Hollow":
		_rect(x+4,y-20,4,4,Color("bc9a5e"))
		_rect(x-10,y-12,3,3,Color("b7a164"))

func _paint_home() -> void:
	var x: int = 12*TILE
	var y: int = 19*TILE
	_rect(x+2,y+7,92,48,Color("1d3e34"))
	_rect(x+7,y+21,82,27,Color("8b956a"))
	_rect(x+3,y+11,90,13,Color("426d64"))
	_rect(x+8,y+5,80,9,Color("426d64"))
	_rect(x+15,y,66,7,Color("426d64"))
	_rect(x+12,y+10,72,2,Color("a7b49a"))
	for xx in range(15,87,14):
		_rect(x+xx,y+3,2,18,Color("7e9c8b"))
		_rect(x+xx-2,y+24,9,16,Color("285546"))
		_rect(x+xx-1,y+25,6,8,Color("72a28c"))
	_rect(x+44,y+25,12,25,Color("244939"))
	_rect(x+46,y+27,8,18,Color("475e42"))
	_rect(x+51,y+36,1,2,Color("e1c287"))
	_rect(x+40,y+48,20,4,Color("bbb083"))
	_rect(x+39,y+53,22,3,Color("75815a"))
	# Two tiny specimen boxes beside the door make this a botanist's station.
	_rect(x+13,y+42,18,5,Color("696f4b"))
	_rect(x+17,y+35,3,7,Color("91ad6c"))
	_rect(x+16,y+34,6,3,Color("d2b578"))
	_rect(x+68,y+42,15,5,Color("696f4b"))
	_rect(x+74,y+33,2,9,Color("7d9e65"))
	_rect(x+71,y+30,7,4,Color("bd9db0"))

func _update_camera() -> void:
	if _map_rect.size.x<=0 or _map_rect.size.y<=0: return
	var visible: Vector2 = _map_rect.size/float(_pixel_scale)
	var desired: Vector2 = Vector2(player_tile*TILE)+Vector2(8,8)-visible*0.5
	_camera = Vector2(floorf(clampf(desired.x,0,maxf(0,MAP_WIDTH*TILE-visible.x))),floorf(clampf(desired.y,0,maxf(0,MAP_HEIGHT*TILE-visible.y))))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0c211d"))
	if _map_texture==null or _map_rect.size.x<1: return
	draw_rect(_map_rect.grow(2),Color("7c9775"),false,2)
	# Clip the map independently of interface panels.
	draw_set_transform(_map_rect.position,0,Vector2(_pixel_scale,_pixel_scale))
	var visible := Rect2(_camera,_map_rect.size/float(_pixel_scale))
	var available: Vector2 = Vector2(MAP_WIDTH*TILE,MAP_HEIGHT*TILE)-_camera
	var destination := Rect2(Vector2.ZERO,Vector2(minf(visible.size.x,available.x),minf(visible.size.y,available.y)))
	draw_texture_rect_region(_map_texture,destination,Rect2(_camera*DETAIL,destination.size*DETAIL))
	# Small water ripples and field motes advance in discrete animation frames.
	var frame: int = int(_time*2.0)%3
	for y in range(maxi(0,int(_camera.y/TILE)),mini(MAP_HEIGHT,int(visible.end.y/TILE)+1)):
		for x in range(maxi(0,int(_camera.x/TILE)),mini(MAP_WIDTH,int(visible.end.x/TILE)+1)):
			if _terrain[y*MAP_WIDTH+x]==2 and _hash(x,y)%3==0:
				var p := Vector2(x*TILE+4+frame,y*TILE+7)-_camera
				if destination.encloses(Rect2(p,Vector2(5,1))): draw_rect(Rect2(p+Vector2(0,0.5),Vector2(4,0.5)),Color("649798"))
	for site: Dictionary in SITES:
		if _site_unavailable(str(site.id)): continue
		var point := Vector2(int(site.x)*TILE+8,int(site.y)*TILE+10)-_camera
		if destination.encloses(Rect2(point-Vector2(8,22),Vector2(16,28))):
			_draw_wild(point,str(site.biome),_hash(int(site.x),int(site.y))%3)
			if _distance(player_tile,Vector2i(site.x,site.y))<=2:
				_draw_marker(point-Vector2(0,27+int(_time*2)%2))
	var player_point := Vector2(player_tile*TILE)+Vector2(8,12)-_camera
	_draw_player(player_point)
	if _touch_goal.x>=0:
		var target := Vector2(_touch_goal*TILE)+Vector2(8,8)-_camera
		if destination.encloses(Rect2(target-Vector2(3,3),Vector2(6,6))):
			_px(target-Vector2(3,0),Vector2(2,1),Color("e1d8ac"))
			_px(target+Vector2(2,0),Vector2(2,1),Color("e1d8ac"))
			_px(target-Vector2(0,3),Vector2(1,2),Color("e1d8ac"))
			_px(target+Vector2(0,2),Vector2(1,2),Color("e1d8ac"))
	draw_set_transform(Vector2.ZERO)

func _px(position: Vector2,dimensions: Vector2,color: Color) -> void:
	draw_rect(Rect2(position.snapped(Vector2(0.5,0.5)),dimensions.snapped(Vector2(0.5,0.5))),color)

func _draw_marker(p: Vector2) -> void:
	_px(p-Vector2(3,3),Vector2(7,7),Color("213c31"))
	_px(p-Vector2(2,2),Vector2(5,5),Color("e2cd93"))
	_px(p-Vector2(0,1),Vector2(1,2),Color("425545"))
	_px(p+Vector2(0,2),Vector2(1,1),Color("425545"))

func _draw_wild(p: Vector2,biome: String,variant: int) -> void:
	var stem := Color("436b42")
	var leaf := Color("9ab979")
	_px(p-Vector2(7,0),Vector2(15,4),Color("2c503b"))
	if biome=="Sporefen":
		_px(p-Vector2(1,12),Vector2(3,14),Color("b1ba98"))
		_px(p-Vector2(7,14),Vector2(15,4),Color("829e9a"))
		_px(p-Vector2(5,17),Vector2(11,4),Color("bbd1b1"))
		_px(p-Vector2(3,19),Vector2(7,3),Color("cbd9ba"))
		_px(p-Vector2(3,15),Vector2(2,2),Color("6d8c80"))
		_px(p+Vector2(3,-17),Vector2(2,2),Color("6d8c80"))
		_px(p-Vector2(8,6),Vector2(6,3),Color("aa9baf"))
	elif biome=="Sunken Glade":
		_px(p-Vector2(1,18),Vector2(2,19),Color("b6c6b0"))
		for i in range(4):
			var yy: int = -i*4-4
			_px(p+Vector2(-6,yy),Vector2(6,2),Color("b6c6b0"))
			_px(p+Vector2(1,yy-2),Vector2(5,2),Color("d4d2b3"))
			_px(p+Vector2(-7,yy-3),Vector2(2,3),Color("97aba2"))
		_px(p-Vector2(3,21),Vector2(6,3),Color("aa8ca3"))
	elif biome=="Amber Hollow" or variant==1:
		_px(p-Vector2(1,17),Vector2(2,19),stem)
		_px(p-Vector2(6,8),Vector2(6,3),leaf)
		_px(p+Vector2(1,-12),Vector2(5,3),leaf)
		var bloom: Color = Color("d8ad70") if variant!=2 else Color("bb8f9f")
		_px(p-Vector2(4,20),Vector2(9,4),bloom)
		_px(p-Vector2(7,17),Vector2(15,4),bloom)
		_px(p-Vector2(4,14),Vector2(9,3),bloom)
		_px(p-Vector2(2,17),Vector2(5,4),Color("efe0a7"))
	else:
		_px(p-Vector2(1,19),Vector2(2,21),stem)
		for i in range(4):
			_px(p+Vector2(-6-i%2,-i*4-3),Vector2(6,3),leaf)
			_px(p+Vector2(1,-i*4-5),Vector2(6,3),Color("6d9b68"))
		_px(p-Vector2(2,22),Vector2(4,4),Color("bdd198"))
	_draw_wild_detail(p,biome,variant)
	# A bright seed body makes collection sites distinct from scenery.
	_px(p+Vector2(6,-3),Vector2(2,2),Color("e1d2a0"))

func _draw_player(p: Vector2) -> void:
	var foot: int = _walk_phase if _step_cooldown>0.02 else 0
	_px(p-Vector2(5,1),Vector2(11,3),Color("203f34"))
	_px(p-Vector2(4,6),Vector2(3,6-foot),Color("263b38"))
	_px(p+Vector2(1,-6),Vector2(3,5+foot),Color("263b38"))
	_px(p-Vector2(5,13),Vector2(11,8),Color("b89562"))
	_px(p-Vector2(3,14),Vector2(7,7),Color("c9b787"))
	_px(p-Vector2(6,13),Vector2(2,5),Color("7e9b79"))
	_px(p+Vector2(5,-13),Vector2(2,5),Color("7e9b79"))
	_px(p-Vector2(3,20),Vector2(7,7),Color("d5b894"))
	_px(p-Vector2(4,22),Vector2(9,3),Color("826b4f"))
	_px(p-Vector2(6,20),Vector2(13,3),Color("dbca98"))
	_px(p-Vector2(3,23),Vector2(7,3),Color("d6bd80"))
	_px(p-Vector2(3,19),Vector2(7,1),Color("a89265"))
	# A moss cloak, specimen satchel, and field hat belong to this botanist.
	if _facing.y<0:
		_px(p-Vector2(4,14),Vector2(9,8),Color("4d785c"))
		_px(p-Vector2(2,12),Vector2(5,5),Color("bc9565"))
	elif _facing.x!=0:
		_px(p+Vector2(-4 if _facing.x>0 else 3,-14),Vector2(3,7),Color("4d785c"))
		_px(p+Vector2(2 if _facing.x>0 else -2,-17),Vector2(1,1),Color("514c3c"))
	else:
		_px(p-Vector2(2,17),Vector2(1,1),Color("514c3c"))
		_px(p+Vector2(2,-17),Vector2(1,1),Color("514c3c"))
		_px(p+Vector2(3,-12),Vector2(3,5),Color("668970"))

	_draw_player_detail(p,foot)

# The collision field remains sixteen logical units per tile. These details use
# the doubled texture grid, which maps one source pixel to one screen pixel.
func _fine_rect(x: int,y: int,w: int,h: int,color: Color) -> void:
	var area := Rect2i(x,y,w,h).intersection(Rect2i(0,0,_map_image.get_width(),_map_image.get_height()))
	if area.size.x>0 and area.size.y>0: _map_image.fill_rect(area,color)

func _paint_tile_detail(tile: Vector2i) -> void:
	var x: int = tile.x*TILE*DETAIL
	var y: int = tile.y*TILE*DETAIL
	var terrain: int = _terrain[tile.y*MAP_WIDTH+tile.x]
	var biome: String = biome_at(tile)
	if terrain == 2:
		for i in range(5):
			var xx: int = x+2+_hash(tile.x,tile.y,61+i)%25
			var yy: int = y+3+_hash(tile.x,tile.y,72+i)%26
			_fine_rect(xx,yy,2+i%3,1,Color("467d84"))
			if i%2==0: _fine_rect(xx+2,yy+1,2,1,Color("345f6b"))
		if not _water(tile+Vector2i.UP):
			for i in range(16):
				_fine_rect(x+i*2,y+2+_hash(tile.x,tile.y,i+91)%3,1,2,Color("8aa384"))
		return
	if terrain == 1:
		if _water(tile):
			for i in range(4):
				_fine_rect(x+4,y+3+i*8,12+_hash(tile.x,tile.y,i)%7,1,Color("929069"))
				_fine_rect(x+2,y+2+i*8,1,1,Color("474e3b"))
				_fine_rect(x+29,y+2+i*8,1,1,Color("474e3b"))
		else:
			for i in range(8):
				var xx: int = x+3+_hash(tile.x,tile.y,100+i)%26
				var yy: int = y+3+_hash(tile.x,tile.y,113+i)%26
				_fine_rect(xx,yy,1,1,Color("b8ab7d") if i%2==0 else Color("979064"))
				if i%4==0: _fine_rect(xx+1,yy,1,1,Color("c6b889"))
		return
	var blade_dark: Color = Color("31583e")
	var blade_light: Color = Color("7c9e65")
	var blade_mid: Color = Color("608453")
	if biome=="Amber Hollow":
		blade_dark = Color("5d683c")
		blade_light = Color("adb36d")
		blade_mid = Color("8c9954")
	elif biome=="Sporefen":
		blade_dark = Color("2e5149")
		blade_light = Color("86afa0")
		blade_mid = Color("5b8e77")
	elif biome=="Sunken Glade":
		blade_dark = Color("354f59")
		blade_light = Color("91aca3")
		blade_mid = Color("688c87")
	for i in range(10):
		var xx: int = x+2+_hash(tile.x,tile.y,21+i)%27
		var yy: int = y+5+_hash(tile.x,tile.y,35+i)%23
		_fine_rect(xx,yy,1,3,blade_dark)
		_fine_rect(xx-1,yy-1,1,3,blade_mid)
		_fine_rect(xx+1,yy-2,1,2,blade_light)
		if i%3==0: _fine_rect(xx+2,yy-3,1,1,blade_light)
	if _hash(tile.x,tile.y,7)%5==0:
		var xx: int = x+8+_hash(tile.x,tile.y,82)%16
		var yy: int = y+9+_hash(tile.x,tile.y,83)%16
		_fine_rect(xx,yy,3,1,Color("a4b48c"))
		_fine_rect(xx+1,yy-1,1,3,Color("d5c79b"))
		_fine_rect(xx+1,yy,1,1,Color("e2d3a8"))

func _paint_tree_detail(tile: Vector2i) -> void:
	var x: int = (tile.x*TILE+8)*DETAIL
	var y: int = (tile.y*TILE+10)*DETAIL
	var glade: bool = biome_at(tile)=="Sunken Glade"
	var middle: Color = Color("456b65") if glade else Color("3f714c")
	var light: Color = Color("739687") if glade else Color("6c955b")
	var bright: Color = Color("8baa96") if glade else Color("8eaa6d")
	var shadow: Color = Color("34594c") if glade else Color("31583e")
	for i in range(45):
		var px: int = x-25+_hash(tile.x,tile.y,150+i)%51
		var py: int = y-47+_hash(tile.x,tile.y,206+i)%42
		if px<0 or py<0 or px>=_map_image.get_width() or py>=_map_image.get_height(): continue
		var pigment: Color = _map_image.get_pixel(px,py)
		if pigment!=middle and pigment!=light: continue
		_fine_rect(px,py,4,1,light if i%2==0 else shadow)
		_fine_rect(px+1,py-1,3,1,light)
		_fine_rect(px+2,py-2,1,1,bright)
		if i%3==0: _fine_rect(px+1,py+1,2,1,shadow)
	for i in range(5):
		_fine_rect(x-2+i%3,y-9+i*3,1,3,Color("8b845a"))

func _paint_home_detail() -> void:
	var x: int = 12*TILE*DETAIL
	var y: int = 19*TILE*DETAIL
	# Thin glazing bars and diagonal reflected sky break up the old large panes.
	for pane in range(5):
		var xx: int = x+31+pane*28
		for i in range(9):
			_fine_rect(xx+i,y+13+i*2,1,2,Color("6b9588"))
			if i%3==0: _fine_rect(xx+i+1,y+13+i*2,1,1,Color("a1b8a4"))
		_fine_rect(xx-3,y+24,23,1,Color("2f5b53"))
		_fine_rect(xx+8,y+51,1,24,Color("b4bd91"))
		_fine_rect(xx+2,y+52,8,1,Color("a2be9e"))
	for row in range(4):
		var yy: int = y+53+row*9
		_fine_rect(x+16,yy,68,1,Color("77865e"))
		_fine_rect(x+115,yy,59,1,Color("77865e"))
		for i in range(3):
			_fine_rect(x+19+i*23+(row%2)*7,yy,1,7,Color("9da479"))
			_fine_rect(x+120+i*17+(row%2)*6,yy,1,7,Color("9da479"))
	_fine_rect(x+91,y+55,1,33,Color("76865e"))
	_fine_rect(x+106,y+57,1,30,Color("263e2e"))
	_fine_rect(x+101,y+72,2,2,Color("e8d2a0"))
	for i in range(7):
		_fine_rect(x+82+i*5,y+99,3,1,Color("d1c397"))
	_fine_rect(x+31,y+81,23,1,Color("9d986e"))
	_fine_rect(x+139,y+81,20,1,Color("9d986e"))

func _draw_wild_detail(p: Vector2,biome: String,variant: int) -> void:
	var light := Color("b9d29c")
	if biome=="Sporefen":
		for i in range(5):
			_px(p+Vector2(-4+i*2,-16.5+float(i%2)),Vector2(0.5,0.5),Color("e0e2be"))
			_px(p+Vector2(-5+i*2,-12.5),Vector2(0.5,1),Color("5d807a"))
		_px(p+Vector2(0,-10),Vector2(0.5,9),Color("d5d8b5"))
	elif biome=="Sunken Glade":
		for i in range(4):
			_px(p+Vector2(-5,-i*4-3.5),Vector2(3.5,0.5),Color("e2dfbd"))
			_px(p+Vector2(2,-i*4-4.5),Vector2(2.5,0.5),Color("a1c4b7"))
		_px(p+Vector2(0.5,-17),Vector2(0.5,16),Color("e4dfba"))
	elif biome=="Amber Hollow" or variant==1:
		for i in range(5):
			_px(p+Vector2(-5+i*2,-16.5+float(i%2)),Vector2(0.5,1),Color("f0d7a1"))
		_px(p+Vector2(-1.5,-17),Vector2(2,0.5),Color("fff0ba"))
		_px(p+Vector2(-5,-7.5),Vector2(4,0.5),light)
		_px(p+Vector2(1.5,-11.5),Vector2(3,0.5),light)
	else:
		for i in range(4):
			_px(p+Vector2(-5.5,-i*4-2.5),Vector2(4,0.5),light)
			_px(p+Vector2(1.5,-i*4-4.5),Vector2(4,0.5),Color("9dbf83"))
		_px(p+Vector2(0.5,-19),Vector2(0.5,19),Color("6a8b51"))

func _draw_player_detail(p: Vector2,foot: int) -> void:
	# Half-unit marks become individual screen pixels rather than enlarged blocks.
	_px(p+Vector2(-4.5,-20),Vector2(9,0.5),Color("e8dab0"))
	_px(p+Vector2(-2.5,-22.5),Vector2(5,0.5),Color("ead6a2"))
	_px(p+Vector2(2.5,-22),Vector2(0.5,2),Color("baa06a"))
	_px(p+Vector2(-3,-18.5),Vector2(6.5,0.5),Color("8a7753"))
	_px(p+Vector2(-2.5,-15),Vector2(5,0.5),Color("b69272"))
	_px(p+Vector2(-5.5,-12.5),Vector2(0.5,3.5),Color("a2b28d"))
	_px(p+Vector2(5,-12.5),Vector2(0.5,3.5),Color("52785b"))
	_px(p+Vector2(-3,-5.5),Vector2(0.5,3-foot),Color("4b5550"))
	_px(p+Vector2(2,-5.5),Vector2(0.5,3+foot),Color("4b5550"))
	if _facing.y<0:
		_px(p+Vector2(-3.5,-13.5),Vector2(7,0.5),Color("7f9b73"))
		_px(p+Vector2(-2,-10.5),Vector2(4,0.5),Color("dcc092"))
		_px(p+Vector2(0,-9.5),Vector2(0.5,1.5),Color("6b6549"))
		_px(p+Vector2(-1.5,-12.5),Vector2(0.5,1.5),Color("e3c89e"))
	elif _facing.x!=0:
		_px(p+Vector2(-3 if _facing.x>0 else 3.5,-13.5),Vector2(0.5,6),Color("7d9b73"))
		_px(p+Vector2(0,-12),Vector2(0.5,5),Color("a48b61"))
	else:
		_px(p+Vector2(-2.5,-13.5),Vector2(0.5,6),Color("8c7954"))
		_px(p+Vector2(-1,-10.5),Vector2(0.5,0.5),Color("716544"))
		_px(p+Vector2(-1,-8.5),Vector2(0.5,0.5),Color("716544"))
		_px(p+Vector2(3.5,-11.5),Vector2(2,0.5),Color("9cb28b"))
		_px(p+Vector2(4,-9.5),Vector2(0.5,1.5),Color("d2b17c"))
