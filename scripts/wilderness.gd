extends Control
class_name Wilderness
## Original handheld-style field exploration. The map and collisions share one
## deterministic tile field; finding a plant never changes the home garden.
signal returned_home()
signal encounter_requested(biome: String, site_id: String)
signal supplies_requested()
signal display_requested()
signal position_changed()
signal sfx_requested(event: String)

const MAP_WIDTH: int = 160
const MAP_HEIGHT: int = 128
const CHUNK_TILES := Vector2i(16,12)
const CHUNK_LIMIT: int = 16
const AtlasCanvas = preload("res://scripts/world_atlas.gd")
const BotanicalArt = preload("res://scripts/plant_portrait.gd")
const TILE: int = 16
const DETAIL: int = 6
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
	{"id":"glade_04","x":36,"y":10,"biome":"Sunken Glade"},
	{"id":"field_049_008","x":49,"y":8,"biome":"Amber Hollow"},
	{"id":"field_059_009","x":59,"y":9,"biome":"Amber Hollow"},
	{"id":"field_069_007","x":69,"y":7,"biome":"Amber Hollow"},
	{"id":"field_079_008","x":79,"y":8,"biome":"Amber Hollow"},
	{"id":"field_089_009","x":89,"y":9,"biome":"Sunken Glade"},
	{"id":"field_099_007","x":99,"y":7,"biome":"Sunken Glade"},
	{"id":"field_109_008","x":109,"y":8,"biome":"Sunken Glade"},
	{"id":"field_119_009","x":119,"y":9,"biome":"Sunken Glade"},
	{"id":"field_129_007","x":129,"y":7,"biome":"Glassfall Coast"},
	{"id":"field_139_008","x":139,"y":8,"biome":"Glassfall Coast"},
	{"id":"field_149_009","x":149,"y":9,"biome":"Glassfall Coast"},
	{"id":"field_047_017","x":47,"y":17,"biome":"Amber Hollow"},
	{"id":"field_057_018","x":57,"y":18,"biome":"Amber Hollow"},
	{"id":"field_067_019","x":67,"y":19,"biome":"Amber Hollow"},
	{"id":"field_077_017","x":77,"y":17,"biome":"Amber Hollow"},
	{"id":"field_087_018","x":87,"y":18,"biome":"Sunken Glade"},
	{"id":"field_097_019","x":97,"y":19,"biome":"Sunken Glade"},
	{"id":"field_107_017","x":107,"y":17,"biome":"Sunken Glade"},
	{"id":"field_117_018","x":117,"y":18,"biome":"Sunken Glade"},
	{"id":"field_127_019","x":127,"y":19,"biome":"Glassfall Coast"},
	{"id":"field_137_017","x":137,"y":17,"biome":"Glassfall Coast"},
	{"id":"field_147_018","x":147,"y":18,"biome":"Glassfall Coast"},
	{"id":"field_048_029","x":48,"y":29,"biome":"Amber Hollow"},
	{"id":"field_058_027","x":58,"y":27,"biome":"Amber Hollow"},
	{"id":"field_068_028","x":68,"y":28,"biome":"Amber Hollow"},
	{"id":"field_078_029","x":78,"y":29,"biome":"Amber Hollow"},
	{"id":"field_088_027","x":88,"y":27,"biome":"Sunken Glade"},
	{"id":"field_098_028","x":98,"y":28,"biome":"Sunken Glade"},
	{"id":"field_108_029","x":108,"y":29,"biome":"Sunken Glade"},
	{"id":"field_118_027","x":118,"y":27,"biome":"Sunken Glade"},
	{"id":"field_128_028","x":128,"y":28,"biome":"Glassfall Coast"},
	{"id":"field_138_029","x":138,"y":29,"biome":"Glassfall Coast"},
	{"id":"field_148_027","x":148,"y":27,"biome":"Glassfall Coast"},
	{"id":"field_009_037","x":9,"y":37,"biome":"Mosswood"},
	{"id":"field_029_039","x":29,"y":39,"biome":"Mosswood"},
	{"id":"field_039_037","x":39,"y":37,"biome":"Mosswood"},
	{"id":"field_049_038","x":49,"y":38,"biome":"Amber Hollow"},
	{"id":"field_059_039","x":59,"y":39,"biome":"Amber Hollow"},
	{"id":"field_069_037","x":69,"y":37,"biome":"Amber Hollow"},
	{"id":"field_079_038","x":79,"y":38,"biome":"Amber Hollow"},
	{"id":"field_089_039","x":89,"y":39,"biome":"Sunken Glade"},
	{"id":"field_099_037","x":99,"y":37,"biome":"Sunken Glade"},
	{"id":"field_109_038","x":109,"y":38,"biome":"Sunken Glade"},
	{"id":"field_119_039","x":119,"y":39,"biome":"Sunken Glade"},
	{"id":"field_129_037","x":129,"y":37,"biome":"Glassfall Coast"},
	{"id":"field_149_039","x":149,"y":39,"biome":"Glassfall Coast"},
	{"id":"field_007_049","x":7,"y":49,"biome":"Mosswood"},
	{"id":"field_017_047","x":17,"y":47,"biome":"Mosswood"},
	{"id":"field_027_048","x":27,"y":48,"biome":"Mosswood"},
	{"id":"field_037_049","x":37,"y":49,"biome":"Mosswood"},
	{"id":"field_047_047","x":47,"y":47,"biome":"Amber Hollow"},
	{"id":"field_057_048","x":57,"y":48,"biome":"Amber Hollow"},
	{"id":"field_067_049","x":67,"y":49,"biome":"Amber Hollow"},
	{"id":"field_077_047","x":77,"y":47,"biome":"Amber Hollow"},
	{"id":"field_087_048","x":87,"y":48,"biome":"Sunken Glade"},
	{"id":"field_097_049","x":97,"y":49,"biome":"Sunken Glade"},
	{"id":"field_107_047","x":107,"y":47,"biome":"Sunken Glade"},
	{"id":"field_117_048","x":117,"y":48,"biome":"Sunken Glade"},
	{"id":"field_127_049","x":127,"y":49,"biome":"Glassfall Coast"},
	{"id":"field_137_047","x":137,"y":47,"biome":"Glassfall Coast"},
	{"id":"field_147_048","x":147,"y":48,"biome":"Glassfall Coast"},
	{"id":"field_008_058","x":8,"y":58,"biome":"Mosswood"},
	{"id":"field_018_059","x":18,"y":59,"biome":"Mosswood"},
	{"id":"field_028_057","x":28,"y":57,"biome":"Mosswood"},
	{"id":"field_038_058","x":38,"y":58,"biome":"Mosswood"},
	{"id":"field_048_059","x":48,"y":59,"biome":"Amber Hollow"},
	{"id":"field_058_057","x":58,"y":57,"biome":"Amber Hollow"},
	{"id":"field_068_058","x":68,"y":58,"biome":"Amber Hollow"},
	{"id":"field_078_059","x":78,"y":59,"biome":"Amber Hollow"},
	{"id":"field_088_057","x":88,"y":57,"biome":"Sunken Glade"},
	{"id":"field_098_058","x":98,"y":58,"biome":"Sunken Glade"},
	{"id":"field_108_059","x":108,"y":59,"biome":"Sunken Glade"},
	{"id":"field_118_057","x":118,"y":57,"biome":"Sunken Glade"},
	{"id":"field_128_058","x":128,"y":58,"biome":"Glassfall Coast"},
	{"id":"field_138_059","x":138,"y":59,"biome":"Glassfall Coast"},
	{"id":"field_148_057","x":148,"y":57,"biome":"Glassfall Coast"},
	{"id":"field_009_067","x":9,"y":67,"biome":"Sporefen"},
	{"id":"field_019_068","x":19,"y":68,"biome":"Sporefen"},
	{"id":"field_029_069","x":29,"y":69,"biome":"Sporefen"},
	{"id":"field_039_067","x":39,"y":67,"biome":"Sporefen"},
	{"id":"field_049_068","x":49,"y":68,"biome":"Ember Ridge"},
	{"id":"field_059_069","x":59,"y":69,"biome":"Ember Ridge"},
	{"id":"field_069_067","x":69,"y":67,"biome":"Ember Ridge"},
	{"id":"field_079_068","x":79,"y":68,"biome":"Ember Ridge"},
	{"id":"field_089_069","x":89,"y":69,"biome":"Moonfen"},
	{"id":"field_099_067","x":99,"y":67,"biome":"Moonfen"},
	{"id":"field_109_068","x":109,"y":68,"biome":"Moonfen"},
	{"id":"field_119_069","x":119,"y":69,"biome":"Moonfen"},
	{"id":"field_129_067","x":129,"y":67,"biome":"Ancient Grove"},
	{"id":"field_139_068","x":139,"y":68,"biome":"Ancient Grove"},
	{"id":"field_149_069","x":149,"y":69,"biome":"Ancient Grove"},
	{"id":"field_007_079","x":7,"y":79,"biome":"Sporefen"},
	{"id":"field_017_077","x":17,"y":77,"biome":"Sporefen"},
	{"id":"field_027_078","x":27,"y":78,"biome":"Sporefen"},
	{"id":"field_037_079","x":37,"y":79,"biome":"Sporefen"},
	{"id":"field_047_077","x":47,"y":77,"biome":"Ember Ridge"},
	{"id":"field_057_078","x":57,"y":78,"biome":"Ember Ridge"},
	{"id":"field_067_079","x":67,"y":79,"biome":"Ember Ridge"},
	{"id":"field_077_077","x":77,"y":77,"biome":"Ember Ridge"},
	{"id":"field_087_078","x":87,"y":78,"biome":"Moonfen"},
	{"id":"field_097_079","x":97,"y":79,"biome":"Moonfen"},
	{"id":"field_107_077","x":107,"y":77,"biome":"Moonfen"},
	{"id":"field_117_078","x":117,"y":78,"biome":"Moonfen"},
	{"id":"field_127_079","x":127,"y":79,"biome":"Ancient Grove"},
	{"id":"field_137_077","x":137,"y":77,"biome":"Ancient Grove"},
	{"id":"field_147_078","x":147,"y":78,"biome":"Ancient Grove"},
	{"id":"field_008_088","x":8,"y":88,"biome":"Sporefen"},
	{"id":"field_018_089","x":18,"y":89,"biome":"Sporefen"},
	{"id":"field_028_087","x":28,"y":87,"biome":"Sporefen"},
	{"id":"field_038_088","x":38,"y":88,"biome":"Sporefen"},
	{"id":"field_048_089","x":48,"y":89,"biome":"Ember Ridge"},
	{"id":"field_058_087","x":58,"y":87,"biome":"Ember Ridge"},
	{"id":"field_068_088","x":68,"y":88,"biome":"Ember Ridge"},
	{"id":"field_078_089","x":78,"y":89,"biome":"Ember Ridge"},
	{"id":"field_088_087","x":88,"y":87,"biome":"Moonfen"},
	{"id":"field_108_089","x":108,"y":89,"biome":"Moonfen"},
	{"id":"field_118_087","x":118,"y":87,"biome":"Moonfen"},
	{"id":"field_128_088","x":128,"y":88,"biome":"Ancient Grove"},
	{"id":"field_138_089","x":138,"y":89,"biome":"Ancient Grove"},
	{"id":"field_148_087","x":148,"y":87,"biome":"Ancient Grove"},
	{"id":"field_009_097","x":9,"y":97,"biome":"Sporefen"},
	{"id":"field_019_098","x":19,"y":98,"biome":"Sporefen"},
	{"id":"field_029_099","x":29,"y":99,"biome":"Sporefen"},
	{"id":"field_039_097","x":39,"y":97,"biome":"Sporefen"},
	{"id":"field_049_098","x":49,"y":98,"biome":"Ember Ridge"},
	{"id":"field_069_097","x":69,"y":97,"biome":"Ember Ridge"},
	{"id":"field_079_098","x":79,"y":98,"biome":"Ember Ridge"},
	{"id":"field_089_099","x":89,"y":99,"biome":"Moonfen"},
	{"id":"field_099_097","x":99,"y":97,"biome":"Moonfen"},
	{"id":"field_109_098","x":109,"y":98,"biome":"Moonfen"},
	{"id":"field_119_099","x":119,"y":99,"biome":"Moonfen"},
	{"id":"field_129_097","x":129,"y":97,"biome":"Ancient Grove"},
	{"id":"field_139_098","x":139,"y":98,"biome":"Ancient Grove"},
	{"id":"field_149_099","x":149,"y":99,"biome":"Ancient Grove"},
	{"id":"field_007_109","x":7,"y":109,"biome":"Sporefen"},
	{"id":"field_017_107","x":17,"y":107,"biome":"Sporefen"},
	{"id":"field_027_108","x":27,"y":108,"biome":"Sporefen"},
	{"id":"field_037_109","x":37,"y":109,"biome":"Sporefen"},
	{"id":"field_047_107","x":47,"y":107,"biome":"Ember Ridge"},
	{"id":"field_057_108","x":57,"y":108,"biome":"Ember Ridge"},
	{"id":"field_067_109","x":67,"y":109,"biome":"Ember Ridge"},
	{"id":"field_077_107","x":77,"y":107,"biome":"Ember Ridge"},
	{"id":"field_087_108","x":87,"y":108,"biome":"Moonfen"},
	{"id":"field_097_109","x":97,"y":109,"biome":"Moonfen"},
	{"id":"field_107_107","x":107,"y":107,"biome":"Moonfen"},
	{"id":"field_117_108","x":117,"y":108,"biome":"Moonfen"},
	{"id":"field_127_109","x":127,"y":109,"biome":"Ancient Grove"},
	{"id":"field_137_107","x":137,"y":107,"biome":"Ancient Grove"},
	{"id":"field_147_108","x":147,"y":108,"biome":"Ancient Grove"},
	{"id":"field_008_118","x":8,"y":118,"biome":"Sporefen"},
	{"id":"field_018_119","x":18,"y":119,"biome":"Sporefen"},
	{"id":"field_028_117","x":28,"y":117,"biome":"Sporefen"},
	{"id":"field_038_118","x":38,"y":118,"biome":"Sporefen"},
	{"id":"field_048_119","x":48,"y":119,"biome":"Ember Ridge"},
	{"id":"field_058_117","x":58,"y":117,"biome":"Ember Ridge"},
	{"id":"field_068_118","x":68,"y":118,"biome":"Ember Ridge"},
	{"id":"field_078_119","x":78,"y":119,"biome":"Ember Ridge"},
	{"id":"field_088_117","x":88,"y":117,"biome":"Moonfen"},
	{"id":"field_098_118","x":98,"y":118,"biome":"Moonfen"},
	{"id":"field_108_119","x":108,"y":119,"biome":"Moonfen"},
	{"id":"field_118_117","x":118,"y":117,"biome":"Moonfen"},
	{"id":"field_128_118","x":128,"y":118,"biome":"Ancient Grove"},
	{"id":"field_138_119","x":138,"y":119,"biome":"Ancient Grove"},
	{"id":"field_148_117","x":148,"y":117,"biome":"Ancient Grove"}
]
const LANDMARKS: Array = [
	{"id":"home","name":"Conservatory","x":15,"y":18,"biome":"Mosswood"},
	{"id":"moss_gate","name":"Mosswood Gate","x":20,"y":40,"biome":"Mosswood"},
	{"id":"amber_camp","name":"Amber Camp","x":56,"y":36,"biome":"Amber Hollow"},
	{"id":"glade_observatory","name":"Glade Observatory","x":95,"y":24,"biome":"Sunken Glade"},
	{"id":"glass_landing","name":"Glassfall Landing","x":141,"y":38,"biome":"Glassfall Coast"},
	{"id":"fen_boardwalk","name":"Fen Boardwalk","x":23,"y":91,"biome":"Sporefen"},
	{"id":"ember_outpost","name":"Ember Outpost","x":61,"y":99,"biome":"Ember Ridge"},
	{"id":"moon_shelter","name":"Moonfen Shelter","x":98,"y":86,"biome":"Moonfen"},
	{"id":"ancient_heart","name":"Ancient Heart","x":143,"y":105,"biome":"Ancient Grove"}
]
var state = null
var waiting: bool = false
var player_tile := Vector2i(15, 18)
var map_seed: int = 8149
var _terrain: PackedInt32Array = []
var _map_texture: ImageTexture
var _chunk_cache: Dictionary = {}
var _chunk_origin := Vector2i.ZERO
var _pathfinder := AStarGrid2D.new()
var _route: Array[Vector2i] = []
var _atlas_texture: ImageTexture
var _atlas: PanelContainer
var _atlas_canvas: Control
var _camp_list: VBoxContainer
var _map_button: Button
var _atlas_title: Label
var chunks_built: int = 0
var chunk_build_msec: float = 0.0
var _map_image: Image
var _trees: Array[Vector2i] = []
var _blocked: Dictionary = {}
var _camera := Vector2.ZERO
var _map_rect := Rect2()
var _pixel_scale: float = 3.0
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
var _display_button: Button
var _last_biome: String = ""
var _message: String = "Follow the north path. A wild specimen is growing nearby."
var _font: Font
var _sprite_image: Image
var _sprite_cache: Dictionary = {}
var _wild_previews: Dictionary = {}
var _wild_preview_generation: String = ""
var map_build_msec: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	_build_atlas_ui()
	resized.connect(_layout)
	_layout()
	refresh()
	_check_landmarks()
	_warm_visible_chunks()
	grab_focus()

func _style(background: Color, border: Color, padding: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("fff7d8") if background.a>0 and maxf(background.r,maxf(background.g,background.b))<0.45 else background
	s.border_color = Color("9fb979") if border.a>0 and maxf(border.r,maxf(border.g,border.b))<0.65 else border
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
	l.add_theme_color_override("font_color",Color("284838") if (color.r+color.g+color.b)>1.7 else color)
	return l

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.add_theme_font_override("font",_font)
	b.add_theme_font_size_override("font_size",14)
	b.add_theme_color_override("font_color",Color("284838"))
	b.add_theme_color_override("font_hover_color",Color("284838"))
	b.add_theme_color_override("font_pressed_color",Color("284838"))
	b.add_theme_color_override("font_disabled_color",Color("7f916d"))
	b.add_theme_stylebox_override("normal",_style(Color("e8f0ba"),Color("9fb979"),8))
	b.add_theme_stylebox_override("hover",_style(Color("fff0a9"),Color("d1a259"),8))
	b.add_theme_stylebox_override("pressed",_style(Color("e8bd75"),Color("b38c4c"),8))
	b.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),Color("cf8f4b"),8))
	b.pressed.connect(func(): sfx_requested.emit("ui"); action.call())
	return b

func _build_ui() -> void:
	_header = PanelContainer.new()
	_header.add_theme_stylebox_override("panel",_style(Color("fff7d8"),Color("78927a"),12))
	add_child(_header)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation",6)
	_header.add_child(top)
	_top_row = HBoxContainer.new()
	top.add_child(_top_row)
	_header_title = _label("PLANT SAFARI",16,Color("e1d9ae"))
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_row.add_child(_header_title)
	_supplies_button = _button("Supplies",func(): supplies_requested.emit())
	_top_row.add_child(_supplies_button)
	_display_button = _button("Settings",func(): display_requested.emit())
	_top_row.add_child(_display_button)
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
	_footer.add_theme_stylebox_override("panel",_style(Color("fff7d8"),Color("78927a"),12))
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
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation",6)
	action_column.add_child(action_row)
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(_action_button)
	_map_button = _button("Map [M]",_open_atlas)
	_map_button.custom_minimum_size.y = 44
	action_row.add_child(_map_button)
	_hint_label = _label("",14,Color("a2bba2"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_column.add_child(_hint_label)
	_legend_label = _label("WASD / arrows to stroll · E to meet a plant · M for map · Tap to walk",12,Color("8eaa94"))
	column.add_child(_legend_label)

func _layout() -> void:
	var compact: bool = size.x < 700
	_pixel_scale = 2.0 if compact else clampf(size.x/640.0,2.5,3.5)
	_fit_panels()
	_header_title.text = "PLANT SAFARI" if compact else "PLANT SAFARI / THE OUTER GARDENS"
	_header_title.add_theme_font_size_override("font_size",13 if compact else 16)
	_location_label.add_theme_font_size_override("font_size",12 if compact else 14)
	_resources_label.add_theme_font_size_override("font_size",12 if compact else 13)
	_legend_label.visible = not compact
	_update_camera()
	_layout_atlas()
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
	_location_label.text = biome.to_upper()+" / ROUTE "+"%02d" % (["Mosswood","Amber Hollow","Sporefen","Sunken Glade","Glassfall Coast","Ember Ridge","Moonfen","Ancient Grove"].find(biome)+1)
	var site: Dictionary = nearest_site()
	var distance: int = _distance(player_tile,Vector2i(site.x,site.y)) if not site.is_empty() else 0
	if not site.is_empty() and distance <= 2:
		_target_label.text = "WILD GROWTH / " + str(site.biome).to_upper()
		_action_button.text = "Investigate [E]"
		_hint_label.text = "A new plant pal! Bring a field kit and say hello."
	elif _distance(player_tile,HOME) <= 2:
		_target_label.text = "YOUR CONSERVATORY / HOME"
		_action_button.text = "Return home [E]"
		_hint_label.text = "Home sweet greenhouse. Bring your wild finds home and see what grows!"
	else:
		var camp: Dictionary = _nearby_landmark()
		_target_label.text = str(camp.name).to_upper()+" / FIELD CAMP" if not camp.is_empty() else "%s / %d steps to wild growth" % [biome.to_upper(),distance]
		_action_button.text = "Rest at camp [E]" if not camp.is_empty() else "Look around [E]"
		_hint_label.text = "Eight habitats, so many plant pals! Open the map to pick your next adventure."
	_action_button.disabled = waiting
	if is_instance_valid(_atlas_canvas): _atlas_canvas.queue_redraw()
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
				if _route.is_empty() or _route[0] != player_tile:
					_route = _find_path(player_tile,_touch_goal)
				if _route.size()>1:
					var next: Vector2i = _route[1]
					_route.pop_front()
					_try_step(next-player_tile)
				else: _touch_goal = Vector2i(-1,-1)
	_fit_panels()
	_update_camera()
	_layout_atlas()
	_warm_visible_chunks()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if is_instance_valid(_atlas) and _atlas.visible:
			if event.physical_keycode in [KEY_M,KEY_ESCAPE]: _close_atlas(); get_viewport().set_input_as_handled()
			return
		if waiting: return
		if event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:
			interact()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_M:
			_open_atlas()
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
			_route.clear()
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
	_check_landmarks()
	if state != null and state.has_method("register_biome"): state.register_biome(biome)
	sfx_requested.emit("step" if _terrain[target.y*MAP_WIDTH+target.x] == 1 else "grass")
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
	elif not _nearby_landmark().is_empty():
		_check_landmarks()
		_open_atlas()
	else:
		_message = "No wild plant within reach. Look for a tall marked specimen beside the paths."
		refresh()

func encounter_closed() -> void:
	waiting = is_instance_valid(_atlas) and _atlas.visible
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
	# The familiar founding routes remain exactly where existing saves left them.
	if tile.x < 40 and tile.y < 32:
		if tile.y < 11 and tile.x >= 23: return "Sunken Glade"
		if tile.x >= 25 and tile.y >= 11: return "Sporefen"
		if tile.x < 12 and tile.y < 15: return "Amber Hollow"
		return "Mosswood"
	var regions: Array = [["Mosswood","Amber Hollow","Sunken Glade","Glassfall Coast"],["Sporefen","Ember Ridge","Moonfen","Ancient Grove"]]
	return str(regions[clampi(tile.y/64,0,1)][clampi(tile.x/40,0,3)])

func is_walkable(tile: Vector2i) -> bool:
	if tile.x<1 or tile.x>=MAP_WIDTH-1 or tile.y<1 or tile.y>=MAP_HEIGHT-1: return false
	if _terrain.is_empty(): return true
	return _terrain[tile.y*MAP_WIDTH+tile.x] != 2 and not _blocked.has(tile)

func _find_path(start: Vector2i,target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_walkable(target) or not is_walkable(start): return result
	var points: Array[Vector2i] = _pathfinder.get_id_path(start,target)
	result.assign(points)
	return result

func _hash(x: int,y: int, salt: int = 0) -> int:
	return posmod(x*73856093 ^ y*19349663 ^ map_seed ^ salt*83492791,2147483647)

func _water(tile: Vector2i) -> bool:
	for pond: Vector4 in [Vector4(22,7,3,2),Vector4(33,26,4,2),Vector4(34,19,3,3),Vector4(6,27,4,2),Vector4(30,52,7,4),Vector4(50,22,6,4),Vector4(69,50,8,5),Vector4(93,16,6,5),Vector4(118,45,9,6),Vector4(142,19,7,4),Vector4(19,77,7,5),Vector4(34,112,8,5),Vector4(68,88,8,4),Vector4(104,111,9,5),Vector4(135,76,8,5),Vector4(148,119,8,4)]:
		var dx: float = float(tile.x-pond.x)/pond.z
		var dy: float = float(tile.y-pond.y)/pond.w
		if dx*dx+dy*dy<1: return true
	if tile.y > 34 and absi(tile.x-roundi(79+sin(tile.y*0.085)*6)) <= 1: return true
	if tile.x > 151+roundi(sin(tile.y*0.15)*2) and tile.y < 62: return true
	return false

func _carve_line(a: Vector2i,b: Vector2i) -> void:
	var p: Vector2i = a
	while p != b:
		_terrain[p.y*MAP_WIDTH+p.x] = 1
		if p.x != b.x: p.x += 1 if b.x>p.x else -1
		else: p.y += 1 if b.y>p.y else -1
	_terrain[b.y*MAP_WIDTH+b.x] = 1

func _build_map() -> void:
	var build_started: int = Time.get_ticks_usec()
	_terrain.resize(MAP_WIDTH*MAP_HEIGHT)
	_trees.clear()
	_blocked.clear()
	_chunk_cache.clear()
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH): _terrain[y*MAP_WIDTH+x] = 2 if _water(Vector2i(x,y)) else 0
	for road: Array in [[Vector2i(15,2),Vector2i(15,44)],[Vector2i(3,14),Vector2i(37,14)],[Vector2i(8,4),Vector2i(8,14)],[Vector2i(30,4),Vector2i(30,28)],[Vector2i(15,21),Vector2i(30,21)],[Vector2i(15,44),Vector2i(148,44)],[Vector2i(12,96),Vector2i(148,96)]]:
		_carve_line(road[0],road[1])
	for x in [20,60,100,140]: _carve_line(Vector2i(x,7),Vector2i(x,120))
	var safe: Dictionary = {}
	for site: Dictionary in SITES:
		var p := Vector2i(site.x,site.y)
		var hub: Vector2i = Vector2i(30,p.y) if p.x>=25 and p.x<40 and p.y<32 else Vector2i(15,p.y)
		if p.x>=40 or p.y>=32: hub = Vector2i(clampi(roundi((p.x-20)/40.0)*40+20,20,140),p.y)
		_carve_line(p,hub)
		_terrain[p.y*MAP_WIDTH+p.x] = 0
		for yy in range(p.y-2,p.y+3):
			for xx in range(p.x-2,p.x+3): safe[Vector2i(xx,yy)] = true
	for landmark: Dictionary in LANDMARKS:
		var p := Vector2i(landmark.x,landmark.y)
		var hub := Vector2i(clampi(roundi((p.x-20)/40.0)*40+20,20,140),p.y)
		_carve_line(p,hub)
		for yy in range(p.y-2,p.y+3):
			for xx in range(p.x-2,p.x+3):
				_terrain[yy*MAP_WIDTH+xx] = 1
				safe[Vector2i(xx,yy)] = true
	for y in range(17,22):
		for x in range(12,19): _terrain[y*MAP_WIDTH+x] = 1
	for y in range(2,MAP_HEIGHT-2):
		for x in range(2,MAP_WIDTH-2):
			var tile := Vector2i(x,y)
			var density: int = 17 if x<40 and y<32 else 19
			if _terrain[y*MAP_WIDTH+x] != 0 or _hash(x,y,1)%density != 0 or safe.has(tile): continue
			if _distance(tile,Vector2i(15,19))<6: continue
			_trees.append(tile)
			_blocked[tile] = true
	for x in range(13,18): _blocked[Vector2i(x,19)] = true
	_blocked.erase(Vector2i(15,19))
	_pathfinder.region = Rect2i(0,0,MAP_WIDTH,MAP_HEIGHT)
	_pathfinder.cell_size = Vector2.ONE
	_pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_pathfinder.update()
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH): _pathfinder.set_point_solid(Vector2i(x,y),not is_walkable(Vector2i(x,y)))
	_build_atlas_texture()
	map_build_msec = float(Time.get_ticks_usec()-build_started)/1000.0

func _visible_chunks() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visible := Rect2(_camera,_map_rect.size/maxf(1,_pixel_scale))
	var first := Vector2i(floori(visible.position.x/(CHUNK_TILES.x*TILE)),floori(visible.position.y/(CHUNK_TILES.y*TILE)))
	var last := Vector2i(floori((visible.end.x-1)/(CHUNK_TILES.x*TILE)),floori((visible.end.y-1)/(CHUNK_TILES.y*TILE)))
	for y in range(maxi(0,first.y),mini(ceili(float(MAP_HEIGHT)/CHUNK_TILES.y)-1,last.y)+1):
		for x in range(maxi(0,first.x),mini(ceili(float(MAP_WIDTH)/CHUNK_TILES.x)-1,last.x)+1): result.append(Vector2i(x,y))
	return result

func _warm_visible_chunks() -> void:
	if _map_rect.size.x<1: return
	for chunk in _visible_chunks(): _get_chunk(chunk)

func _get_chunk(chunk: Vector2i) -> ImageTexture:
	if _chunk_cache.has(chunk):
		var cached: ImageTexture = _chunk_cache[chunk]
		_chunk_cache.erase(chunk)
		_chunk_cache[chunk] = cached
		return cached
	var started: int = Time.get_ticks_usec()
	var origin: Vector2i = chunk*CHUNK_TILES
	var limit := Vector2i(mini(CHUNK_TILES.x,MAP_WIDTH-origin.x),mini(CHUNK_TILES.y,MAP_HEIGHT-origin.y))
	_chunk_origin = origin*TILE-Vector2i.ONE
	_map_image = Image.create((limit.x*TILE+2)*DETAIL,(limit.y*TILE+2)*DETAIL,false,Image.FORMAT_RGBA8)
	_map_image.fill(Color("8abe68"))
	for y in range(maxi(0,origin.y-1),mini(MAP_HEIGHT,origin.y+limit.y+1)):
		for x in range(maxi(0,origin.x-1),mini(MAP_WIDTH,origin.x+limit.x+1)):
			_paint_tile(Vector2i(x,y))
			_paint_tile_detail(Vector2i(x,y))
	var tree_bounds := Rect2i(origin-Vector2i(3,3),limit+Vector2i(6,6))
	for tile: Vector2i in _trees:
		if tree_bounds.has_point(tile): _paint_tree(tile); _paint_tree_detail(tile)
	if tree_bounds.has_point(Vector2i(15,20)): _paint_home(); _paint_home_detail()
	for landmark: Dictionary in LANDMARKS:
		if landmark.id != "home" and tree_bounds.has_point(Vector2i(landmark.x,landmark.y)): _paint_camp(landmark)
	_map_image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(_map_image)
	_map_image = null
	_map_texture = texture
	while _chunk_cache.size() >= CHUNK_LIMIT: _chunk_cache.erase(_chunk_cache.keys()[0])
	_chunk_cache[chunk] = texture
	chunks_built += 1
	chunk_build_msec = float(Time.get_ticks_usec()-started)/1000.0
	return texture

func _rect(x: int,y: int,w: int,h: int,color: Color) -> void:
	_fine_rect(x*DETAIL,y*DETAIL,w*DETAIL,h*DETAIL,color)

func _paint_tile(tile: Vector2i) -> void:
	var x: int = tile.x*TILE
	var y: int = tile.y*TILE
	var value: int = _hash(tile.x,tile.y)
	var biome: String = biome_at(tile)
	var palettes: Dictionary = {
		"Mosswood":[Color("7bb865"),Color("8bc573"),Color("669d4e"),Color("bddc85")],
		"Amber Hollow":[Color("c1bb6a"),Color("d0c876"),Color("9ea153"),Color("e5dd93")],
		"Sporefen":[Color("72af99"),Color("82bba5"),Color("5b9381"),Color("b6d8a5")],
		"Sunken Glade":[Color("7db9bf"),Color("8cc7c7"),Color("58969f"),Color("beded1")],
		"Glassfall Coast":[Color("add2a1"),Color("bbdcad"),Color("86b58b"),Color("e2edbd")],
		"Moonfen":[Color("95b9cd"),Color("a7cad7"),Color("7293ac"),Color("d6e3e3")],
		"Ember Ridge":[Color("c9ac72"),Color("d8bc83"),Color("aa8b59"),Color("ecd29a")],
		"Ancient Grove":[Color("6da367"),Color("7db472"),Color("518350"),Color("b7d697")]
	}
	var palette: Array = palettes[biome]
	var terrain: int = _terrain[tile.y*MAP_WIDTH+tile.x]
	if terrain == 2:
		_rect(x,y,TILE,TILE,Color("68b7c5"))
		_rect(x,y+2,TILE,2,Color("7dc9d1"))
		_rect(x+value%7,y+8,6,1,Color("b3e7e2"))
		_rect(x+((value/7)%8),y+12,4,1,Color("4e9eaf"))
		if not _water(tile+Vector2i.UP): _rect(x,y,TILE,2,Color("b7d295"))
		if not _water(tile+Vector2i.LEFT): _rect(x,y,2,TILE,Color("b7d295"))
		if value%5==0:
			_rect(x+5,y+5,5,3,Color("82b68d"))
			_rect(x+6,y+4,3,1,Color("b7d59d"))
		return
	_rect(x,y,TILE,TILE,(palette[0] as Color).lerp(palette[1],float(value%5)*0.065))
	if terrain == 1:
		if _water(tile):
			_rect(x,y,TILE,TILE,Color("b7a16e"))
			for yy in range(1,16,4):
				_rect(x,y+yy,TILE,1,Color("e5ce95"))
				_rect(x+1,y+yy+1,1,2,Color("897c58"))
		else:
			_rect(x+1,y+1,14,14,Color("dcc18b"))
			_rect(x,y+3,16,10,Color("dcc18b"))
			_rect(x+3,y,10,16,Color("dcc18b"))
			_rect(x+value%11+2,y+(value/13)%11+2,2,1,Color("f1dba5"))
			_rect(x+(value/5)%12+1,y+(value/29)%11+2,2,1,Color("bda16e"))
	else:
		for i in range(4):
			var xx: int = x+2+_hash(tile.x,tile.y,i+2)%12
			var yy: int = y+3+_hash(tile.x,tile.y,i+9)%11
			_rect(xx,yy,1,2,palette[2])
			_rect(xx-1,yy-1,1,1,palette[3])
			_rect(xx+1,yy-2,1,2,palette[3])
		if value%9 == 0:
			var c: Color = Color("d2e6b2") if biome=="Sporefen" else Color("f3d78d")
			_rect(x+5,y+8,2,2,c)
			_rect(x+6,y+7,1,1,Color("fff0bf"))
	# The boundary is an irregular, impassable hedge rather than empty void.
	if tile.x==0 or tile.y==0 or tile.x==MAP_WIDTH-1 or tile.y==MAP_HEIGHT-1:
		_rect(x,y,16,16,Color("64924f"))
		_rect(x+2,y+2,12,10,Color("78ad5d"))
		_rect(x+4,y+1,7,2,Color("a8ca79"))

func _paint_tree(tile: Vector2i) -> void:
	var x: float = tile.x*TILE+8
	var y: float = tile.y*TILE+10
	var glade: bool = biome_at(tile)=="Sunken Glade"
	var dark := Color("5d918c") if glade else Color("467b46")
	var middle := Color("84b9a0") if glade else Color("78ad54")
	var light := Color("bed998") if glade else Color("b9d777")
	_map_ellipse(Vector2(x+1,y+4),Vector2(13.5,3.5),Color("739f62"),false)
	_micro_rect(x-2,y-8,4,15,Color("625f43"))
	_micro_rect(x-1.5,y-7,0.75,13,Color("9d9366"))
	_micro_rect(x+1,y-6,0.5,11,Color("454e39"))
	_micro_line(Vector2(x-1,y+4),Vector2(x-5,y+6),Color("79784e"),0.5)
	_micro_line(Vector2(x+1,y+4),Vector2(x+5,y+6.5),Color("4d5e40"),0.5)
	# Overlapping grown lobes create a canopy, rather than a rectangular icon.
	for lobe in [Vector3(-7,-14,8),Vector3(7,-14,8),Vector3(0,-20,9),Vector3(-5,-8,8),Vector3(5,-8,8)]:
		_map_ellipse(Vector2(x+lobe.x,y+lobe.y),Vector2(lobe.z,lobe.z*0.83),dark)
	for lobe in [Vector3(-6,-16,7.6),Vector3(5.5,-15,7.6),Vector3(0,-21,7.7),Vector3(-2,-9,8.4)]:
		_map_ellipse(Vector2(x+lobe.x,y+lobe.y),Vector2(lobe.z,lobe.z*0.76),middle)
	_map_ellipse(Vector2(x-3.5,y-22),Vector2(5.9,3.8),light)
	_map_ellipse(Vector2(x-9,y-15),Vector2(4.1,2.4),light.darkened(0.08))

func _paint_home() -> void:
	var x: int = 12*TILE
	var y: int = 19*TILE
	_rect(x+2,y+7,92,48,Color("6b9873"))
	_rect(x+7,y+21,82,27,Color("d5d09b"))
	_rect(x+3,y+11,90,13,Color("70aa9b"))
	_rect(x+8,y+5,80,9,Color("70aa9b"))
	_rect(x+15,y,66,7,Color("70aa9b"))
	_rect(x+12,y+10,72,2,Color("a7b49a"))
	for xx in range(15,87,14):
		_rect(x+xx,y+3,2,18,Color("7e9c8b"))
		_rect(x+xx-2,y+24,9,16,Color("81bca3"))
		_rect(x+xx-1,y+25,6,8,Color("b7dfc2"))
	_rect(x+44,y+25,12,25,Color("719d75"))
	_rect(x+46,y+27,8,18,Color("9cb775"))
	_rect(x+51,y+36,1,2,Color("e1c287"))
	_rect(x+40,y+48,20,4,Color("bbb083"))
	_rect(x+39,y+53,22,3,Color("75815a"))
	# Two tiny specimen boxes beside the door make this a botanist's station.
	_rect(x+13,y+42,18,5,Color("a1a569"))
	_rect(x+17,y+35,3,7,Color("bbd985"))
	_rect(x+16,y+34,6,3,Color("d2b578"))
	_rect(x+68,y+42,15,5,Color("a1a569"))
	_rect(x+74,y+33,2,9,Color("aac677"))
	_rect(x+71,y+30,7,4,Color("bd9db0"))

func _update_camera() -> void:
	if _map_rect.size.x<=0 or _map_rect.size.y<=0: return
	var visible: Vector2 = _map_rect.size/float(_pixel_scale)
	var desired: Vector2 = Vector2(player_tile*TILE)+Vector2(8,8)-visible*0.5
	_camera = Vector2(floorf(clampf(desired.x,0,maxf(0,MAP_WIDTH*TILE-visible.x))),floorf(clampf(desired.y,0,maxf(0,MAP_HEIGHT*TILE-visible.y))))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("c6e8c9"))
	if _terrain.is_empty() or _map_rect.size.x<1: return
	draw_rect(_map_rect.grow(2),Color("9ebf7d"),false,2)
	# Clip the map independently of interface panels.
	draw_set_transform(_map_rect.position,0,Vector2(_pixel_scale,_pixel_scale))
	var visible := Rect2(_camera,_map_rect.size/float(_pixel_scale))
	var available: Vector2 = Vector2(MAP_WIDTH*TILE,MAP_HEIGHT*TILE)-_camera
	var destination := Rect2(Vector2.ZERO,Vector2(minf(visible.size.x,available.x),minf(visible.size.y,available.y)))
	for chunk: Vector2i in _visible_chunks():
		var chunk_start: Vector2 = Vector2(chunk*CHUNK_TILES*TILE)
		var chunk_extent := Vector2(mini(CHUNK_TILES.x,MAP_WIDTH-chunk.x*CHUNK_TILES.x)*TILE,mini(CHUNK_TILES.y,MAP_HEIGHT-chunk.y*CHUNK_TILES.y)*TILE)
		var overlap: Rect2 = Rect2(chunk_start,chunk_extent).intersection(visible)
		if overlap.size.x>0 and overlap.size.y>0:
			draw_texture_rect_region(_get_chunk(chunk),Rect2(overlap.position-_camera,overlap.size),Rect2((overlap.position-chunk_start+Vector2.ONE)*DETAIL,overlap.size*DETAIL))
	# Small water ripples and field motes advance in discrete animation frames.
	var frame: int = int(_time*2.0)%3
	for y in range(maxi(0,int(_camera.y/TILE)),mini(MAP_HEIGHT,int(visible.end.y/TILE)+1)):
		for x in range(maxi(0,int(_camera.x/TILE)),mini(MAP_WIDTH,int(visible.end.x/TILE)+1)):
			if _terrain[y*MAP_WIDTH+x]==2 and _hash(x,y)%3==0:
				var p := Vector2(x*TILE+4+frame,y*TILE+7)-_camera
				if destination.encloses(Rect2(p,Vector2(5,1))): draw_rect(Rect2(p+Vector2(0,0.5),Vector2(4,0.5)),Color("b5e5df"))
	for site: Dictionary in SITES:
		if _site_unavailable(str(site.id)): continue
		var point := Vector2(int(site.x)*TILE+8,int(site.y)*TILE+10)-_camera
		if destination.encloses(Rect2(point-Vector2(13,31),Vector2(26,33))):
			_draw_wild(point,str(site.biome),_hash(int(site.x),int(site.y))%3,str(site.id))
			if _distance(player_tile,Vector2i(site.x,site.y))<=2 and point.y > 39:
				_draw_marker(point-Vector2(0,35+int(_time*2)%2))
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
	if _sprite_image != null:
		var bounds := Rect2i(Vector2i((position*DETAIL).floor()),Vector2i((dimensions*DETAIL).round()))
		bounds = bounds.intersection(Rect2i(Vector2i.ZERO,_sprite_image.get_size()))
		if bounds.size.x>0 and bounds.size.y>0: _sprite_image.fill_rect(bounds,color)
	else:
		draw_rect(Rect2(position.snapped(Vector2(0.25,0.25)),dimensions.snapped(Vector2(0.25,0.25))),color)

func _draw_wild(p: Vector2,biome: String,variant: int,site_id: String = "") -> void:
	# Use the same organism as the encounter, without opening it or touching its
	# collection record. Eight authored silhouettes now replace the field icons.
	if state != null and not site_id.is_empty():
		var generation: String = "%s/%s/%s" % [state.expedition.get("map_seed",0),state.expedition.get("respawn_day",0),int(state.expedition.get("captures",0))>=10]
		if generation != _wild_preview_generation:
			_wild_previews.clear()
			_wild_preview_generation = generation
		if not _wild_previews.has(site_id): _wild_previews[site_id] = state.preview_wild_plant(biome,site_id)
		var organism: Dictionary = _wild_previews[site_id]
		var artwork: Texture2D = BotanicalArt.hybrid_texture(organism)
		if artwork != null:
			var frame_size: Vector2 = artwork.get_size()
			var factor: float = minf(25.0/frame_size.x,30.0/frame_size.y)
			var dimensions: Vector2 = frame_size*factor
			# One short shadow keeps roots anchored in the map's existing soil.
			_px(p+Vector2(-5,0),Vector2(10,1.5),Color("233f2d"))
			draw_texture_rect(artwork,Rect2(p+Vector2(-dimensions.x*0.5,1-dimensions.y),dimensions),false)
			return
	var key: String = "wild:%s:%d" % [biome,variant]
	if not _sprite_cache.has(key):
		_sprite_image = Image.create(20*DETAIL,32*DETAIL,false,Image.FORMAT_RGBA8)
		_sprite_image.fill(Color.TRANSPARENT)
		_paint_wild_sprite(Vector2(10,28),biome,variant)
		_paint_sprite_finish(false)
		_sprite_image.generate_mipmaps()
		_sprite_cache[key] = ImageTexture.create_from_image(_sprite_image)
		_sprite_image = null
	draw_texture_rect(_sprite_cache[key],Rect2(p+Vector2(-10,-28),Vector2(20,32)),false)

func _draw_player(p: Vector2) -> void:
	var foot: int = _walk_phase if _step_cooldown>0.02 else 0
	var key: String = "player:%d:%d:%d" % [_facing.x,_facing.y,foot]
	if not _sprite_cache.has(key):
		_sprite_image = Image.create(20*DETAIL,32*DETAIL,false,Image.FORMAT_RGBA8)
		_sprite_image.fill(Color.TRANSPARENT)
		_paint_player_sprite(Vector2(10,28),foot)
		_paint_sprite_finish(true)
		_sprite_image.generate_mipmaps()
		_sprite_cache[key] = ImageTexture.create_from_image(_sprite_image)
		_sprite_image = null
	draw_texture_rect(_sprite_cache[key],Rect2(p+Vector2(-10,-28),Vector2(20,32)),false)

func _draw_marker(p: Vector2) -> void:
	_px(p-Vector2(3,3),Vector2(7,7),Color("213c31"))
	_px(p-Vector2(2,2),Vector2(5,5),Color("e2cd93"))
	_px(p-Vector2(0,1),Vector2(1,2),Color("425545"))
	_px(p+Vector2(0,2),Vector2(1,1),Color("425545"))

func _paint_wild_sprite(p: Vector2,biome: String,variant: int) -> void:
	var stem := Color("436b42")
	var leaf := Color("9ab979")
	_px(p-Vector2(7,0),Vector2(15,4),Color("2c503b"))
	if biome in ["Sporefen","Moonfen"]:
		_px(p-Vector2(1,12),Vector2(3,14),Color("b1ba98"))
		_px(p-Vector2(7,14),Vector2(15,4),Color("829e9a"))
		_px(p-Vector2(5,17),Vector2(11,4),Color("bbd1b1"))
		_px(p-Vector2(3,19),Vector2(7,3),Color("cbd9ba"))
		_px(p-Vector2(3,15),Vector2(2,2),Color("6d8c80"))
		_px(p+Vector2(3,-17),Vector2(2,2),Color("6d8c80"))
		_px(p-Vector2(8,6),Vector2(6,3),Color("aa9baf"))
	elif biome in ["Sunken Glade","Ancient Grove"]:
		_px(p-Vector2(1,18),Vector2(2,19),Color("b6c6b0"))
		for i in range(4):
			var yy: int = -i*4-4
			_px(p+Vector2(-6,yy),Vector2(6,2),Color("b6c6b0"))
			_px(p+Vector2(1,yy-2),Vector2(5,2),Color("d4d2b3"))
			_px(p+Vector2(-7,yy-3),Vector2(2,3),Color("97aba2"))
		_px(p-Vector2(3,21),Vector2(6,3),Color("aa8ca3"))
	elif biome in ["Amber Hollow","Ember Ridge"] or variant==1:
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

func _paint_player_sprite(p: Vector2,foot: int) -> void:
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

# Collision tiles stay at sixteen logical units. Materials are sampled directly
# on a six-times denser grid, then minified from real mipmaps at desktop scale.
func _fine_rect(x: int,y: int,w: int,h: int,color: Color) -> void:
	var area := Rect2i(x-_chunk_origin.x*DETAIL,y-_chunk_origin.y*DETAIL,w,h).intersection(Rect2i(0,0,_map_image.get_width(),_map_image.get_height()))
	if area.size.x>0 and area.size.y>0: _map_image.fill_rect(area,color)

func _micro_rect(x: float,y: float,w: float,h: float,color: Color) -> void:
	_fine_rect(roundi(x*DETAIL),roundi(y*DETAIL),maxi(1,roundi(w*DETAIL)),maxi(1,roundi(h*DETAIL)),color)

func _micro_line(a: Vector2,b: Vector2,color: Color,width: float = 0.25) -> void:
	var start := Vector2i((a*DETAIL).round())
	var end := Vector2i((b*DETAIL).round())
	var dx: int = absi(end.x-start.x)
	var dy: int = -absi(end.y-start.y)
	var sx: int = 1 if start.x<end.x else -1
	var sy: int = 1 if start.y<end.y else -1
	var error: int = dx+dy
	var p := start
	var thickness: int = maxi(1,roundi(width*DETAIL))
	while true:
		_fine_rect(p.x,p.y,thickness,thickness,color)
		if p == end: break
		var twice: int = error*2
		if twice>=dy: error+=dy; p.x+=sx
		if twice<=dx: error+=dx; p.y+=sy

func _map_ellipse(center: Vector2,radius: Vector2,color: Color,shaded: bool = true) -> void:
	var middle := Vector2i((center*DETAIL).round())
	var rx: int = maxi(1,roundi(radius.x*DETAIL))
	var ry: int = maxi(1,roundi(radius.y*DETAIL))
	for row in range(-ry,ry+1):
		var span: int = roundi(rx*sqrt(maxf(0,1.0-pow(float(row)/ry,2))))
		var pigment: Color = color
		if shaded:
			pigment = color.darkened(0.12) if row>ry/3 else (color.lightened(0.07) if row<-ry/3 else color)
		_fine_rect(middle.x-span,middle.y+row,span*2+1,1,pigment)

func _terrain_at(tile: Vector2i) -> int:
	if tile.x<0 or tile.y<0 or tile.x>=MAP_WIDTH or tile.y>=MAP_HEIGHT: return -1
	return _terrain[tile.y*MAP_WIDTH+tile.x]

func _paint_tile_detail(tile: Vector2i) -> void:
	var x: float = tile.x*TILE
	var y: float = tile.y*TILE
	var terrain: int = _terrain[tile.y*MAP_WIDTH+tile.x]
	var biome: String = biome_at(tile)
	if terrain == 2:
		# Long coherent ripples and silt edges replace a noisy field of dots.
		for i in range(5):
			var xx: float = x+float(_hash(tile.x,tile.y,61+i)%48)/4.0
			var yy: float = y+1.0+float(_hash(tile.x,tile.y,72+i)%52)/4.0
			_micro_line(Vector2(xx,yy),Vector2(minf(x+15.75,xx+2.0+i%3),yy),Color("99d7dc"))
			_micro_line(Vector2(xx+0.5,yy+0.5),Vector2(minf(x+15.75,xx+2.5),yy+0.5),Color("5da4b5"))
		for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if _water(tile+side): continue
			for j in range(16):
				var drift: float = float(_hash(tile.x,tile.y,j+81)%5)/4.0
				var p := Vector2(x+j,y+drift) if side==Vector2i.UP else Vector2(x+j,y+15.0-drift)
				if side==Vector2i.LEFT: p = Vector2(x+drift,y+j)
				if side==Vector2i.RIGHT: p = Vector2(x+15.0-drift,y+j)
				_micro_rect(p.x,p.y,0.75,0.5,Color("c8dca9"))
		return
	if terrain == 1:
		if _water(tile):
			for plank in range(4):
				for grain in range(3):
					var offset: float = float(_hash(tile.x,tile.y,grain+plank*9)%6)*0.25
					_micro_line(Vector2(x+1+offset,y+1+plank*4+grain*0.5),Vector2(x+13-offset,y+1+plank*4+grain*0.5),Color("99916a") if grain==0 else Color("6c7251"))
				_micro_rect(x+0.75,y+1+plank*4,0.5,0.5,Color("414e3c"))
				_micro_rect(x+14.25,y+1+plank*4,0.5,0.5,Color("414e3c"))
		else:
			for i in range(13):
				var xx: float = x+0.75+float(_hash(tile.x,tile.y,100+i)%56)/4.0
				var yy: float = y+0.75+float(_hash(tile.x,tile.y,113+i)%56)/4.0
				var pebble: bool = i%4==0
				_micro_rect(xx,yy,0.5 if pebble else 0.25,0.25,Color("8d8861"))
				if pebble: _micro_rect(xx,yy-0.25,0.5,0.25,Color("c1b58a"))
			for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				if _terrain_at(tile+side)==1: continue
				for j in range(7):
					var stretch: float = float(_hash(tile.x,tile.y,j+93)%4)*0.25
					var edge := Vector2(x+j*2+1,y+1) if side==Vector2i.UP else Vector2(x+j*2+1,y+14.5)
					if side==Vector2i.LEFT: edge=Vector2(x+1,y+j*2+1)
					if side==Vector2i.RIGHT: edge=Vector2(x+14.5,y+j*2+1)
					_micro_line(edge,edge+Vector2(stretch+0.5,0.5),Color("7d8459"))
		return
	var dark := Color("649646")
	var light := Color("c1dc86")
	var middle := Color("8bb65e")
	if biome=="Amber Hollow": dark=Color("9c9e50");light=Color("e1df92");middle=Color("b8c66d")
	elif biome in ["Sporefen","Moonfen"]: dark=Color("5a8f7c");light=Color("bedcc0");middle=Color("87b995")
	elif biome in ["Sunken Glade","Ancient Grove"]: dark=Color("648c94");light=Color("c7e1cf");middle=Color("96bdb0")
	# Four multi-blade tufts per tile. Each shares a root crown and directional
	# shading, avoiding the previous evenly scattered high-contrast speckle.
	for tuft in range(4):
		var xx: float = x+1.5+float(_hash(tile.x,tile.y,21+tuft)%48)/4.0
		var yy: float = y+3.5+float(_hash(tile.x,tile.y,35+tuft)%43)/4.0
		_micro_rect(xx-0.5,yy,2,0.25,dark)
		for blade in range(4):
			var reach: float = 1.25+float(_hash(tile.x,tile.y,blade+tuft*5)%7)*0.25
			var bend: float = float(blade-2)*0.5
			var base := Vector2(xx+blade*0.25,yy)
			var tip := base+Vector2(bend,-reach)
			_micro_line(base,tip,dark,0.5)
			_micro_line(base+Vector2(0.25,0),tip+Vector2(0.25,0),middle)
			_micro_rect(tip.x+0.25,tip.y,0.25,0.75,light)
	if _hash(tile.x,tile.y,7)%7==0:
		var flower := Vector2(x+7.5,y+8.25)
		_micro_line(flower+Vector2(0,2),flower,Color("71895d"))
		_map_ellipse(flower,Vector2(0.75,0.5),Color("c9bc91"),false)
		_micro_rect(flower.x,flower.y-0.25,0.25,0.25,Color("ecdeb0"))

func _paint_tree_detail(tile: Vector2i) -> void:
	var center := Vector2(tile.x*TILE+8,tile.y*TILE+10)
	var glade: bool = biome_at(tile)=="Sunken Glade"
	var shadow := Color("70a389") if glade else Color("64934d")
	var light := Color("b4d4b7") if glade else Color("b3cd7e")
	var bright := Color("d5e5bc") if glade else Color("dbe59e")
	for cluster in range(42):
		var offset := Vector2(-12.5+float(_hash(tile.x,tile.y,150+cluster)%101)/4.0,-23.5+float(_hash(tile.x,tile.y,206+cluster)%81)/4.0)
		if pow(offset.x/13.0,2)+pow((offset.y+14)/11.0,2)>1: continue
		var p: Vector2 = center+offset
		var slant: float = -0.5 if cluster%2 else 0.5
		_map_ellipse(p,Vector2(1.4,0.55),light if cluster%3 else shadow)
		_micro_line(p-Vector2(1,0),p+Vector2(0.75,slant*0.5),bright)
		_micro_line(p+Vector2(-0.25,0),p+Vector2(-0.5,-0.5),light.lightened(0.08))
	for stripe in range(6):
		_micro_line(center+Vector2(-0.75+stripe%3*0.5,-6+stripe*2),center+Vector2(-0.5+stripe%3*0.5,-4.5+stripe*2),Color("8e865c"))

func _paint_home_detail() -> void:
	var x: float = 12*TILE
	var y: float = 19*TILE
	for pane in range(5):
		var xx: float = x+15.5+pane*14
		# Each pane has a narrow frame, sky streaks and a reflected branch.
		_micro_line(Vector2(xx-1.5,y+12),Vector2(xx+10,y+12),Color("2e5c51"),0.25)
		_micro_line(Vector2(xx+4,y+25.5),Vector2(xx+4,y+38.5),Color("bcc69d"),0.25)
		_micro_line(Vector2(xx+0.5,y+6.5),Vector2(xx+5,y+16.5),Color("83a89a"),0.5)
		_micro_line(Vector2(xx+1.25,y+6.5),Vector2(xx+5.75,y+16.5),Color("b3c4ad"),0.25)
		_micro_line(Vector2(xx+0.5,y+31),Vector2(xx+3.5,y+27),Color("3d6a53"),0.25)
		_micro_line(Vector2(xx+2,y+30),Vector2(xx+0.75,y+28),Color("5c8668"),0.25)
		_micro_line(Vector2(xx+2.5,y+26),Vector2(xx+6.5,y+26),Color("c0c9a0"),0.25)
	for row in range(5):
		var yy: float = y+26.5+row*4.5
		for limits in [Vector2(8,42),Vector2(57.5,87)]:
			_micro_line(Vector2(x+limits.x,yy),Vector2(x+limits.y,yy),Color("78845e"))
			for joint in range(3):
				var jx: float = x+limits.x+3+joint*10+row%2*3.5
				_micro_line(Vector2(jx,yy),Vector2(jx,yy+3.5),Color("a5aa7b"))
	_micro_line(Vector2(x+45.5,y+27.5),Vector2(x+45.5,y+44),Color("8b9870"))
	_micro_rect(x+50.5,y+36,0.75,0.75,Color("efd3a0"))
	_micro_rect(x+50.75,y+36,0.25,0.25,Color("fff0bf"))
	for step in range(8): _micro_line(Vector2(x+40.5+step*2.5,y+49.5),Vector2(x+42+step*2.5,y+49.5),Color("d5c899"))

func _draw_wild_detail(p: Vector2,biome: String,variant: int) -> void:
	var light := Color("b9d29c")
	if biome in ["Sporefen","Moonfen"]:
		for i in range(5):
			_px(p+Vector2(-4+i*2,-16.5+float(i%2)),Vector2(0.5,0.5),Color("e0e2be"))
			_px(p+Vector2(-5+i*2,-12.5),Vector2(0.25,1.5),Color("5d807a"))
		_px(p+Vector2(0,-10),Vector2(0.25,9),Color("d5d8b5"))
	elif biome in ["Sunken Glade","Ancient Grove"]:
		for i in range(4):
			_px(p+Vector2(-5,-i*4-3.5),Vector2(3.5,0.25),Color("e2dfbd"))
			_px(p+Vector2(2,-i*4-4.5),Vector2(2.5,0.25),Color("a1c4b7"))
		_px(p+Vector2(0.5,-17),Vector2(0.25,16),Color("e4dfba"))
	elif biome in ["Amber Hollow","Ember Ridge"] or variant==1:
		for i in range(5): _px(p+Vector2(-5+i*2,-16.5+float(i%2)),Vector2(0.25,1.25),Color("f0d7a1"))
		_px(p+Vector2(-1.5,-17),Vector2(2,0.25),Color("fff0ba"))
		_px(p+Vector2(-5,-7.5),Vector2(4,0.25),light)
		_px(p+Vector2(1.5,-11.5),Vector2(3,0.25),light)
	else:
		for i in range(4):
			_px(p+Vector2(-5.5,-i*4-2.5),Vector2(4,0.25),light)
			_px(p+Vector2(1.5,-i*4-4.5),Vector2(4,0.25),Color("9dbf83"))
		_px(p+Vector2(0.5,-19),Vector2(0.25,19),Color("6a8b51"))

func _draw_player_detail(p: Vector2,foot: int) -> void:
	_px(p+Vector2(-4.5,-20),Vector2(9,0.25),Color("e8dab0"))
	_px(p+Vector2(-2.5,-22.5),Vector2(5,0.25),Color("ead6a2"))
	_px(p+Vector2(2.5,-22),Vector2(0.25,2),Color("baa06a"))
	_px(p+Vector2(-3,-18.5),Vector2(6.5,0.25),Color("8a7753"))
	_px(p+Vector2(-2.5,-15),Vector2(5,0.25),Color("b69272"))
	_px(p+Vector2(-5.5,-12.5),Vector2(0.25,3.5),Color("a2b28d"))
	_px(p+Vector2(5,-12.5),Vector2(0.25,3.5),Color("52785b"))
	_px(p+Vector2(-3,-5.5),Vector2(0.25,3-foot),Color("4b5550"))
	_px(p+Vector2(2,-5.5),Vector2(0.25,3+foot),Color("4b5550"))
	if _facing.y<0:
		_px(p+Vector2(-3.5,-13.5),Vector2(7,0.25),Color("7f9b73"))
		_px(p+Vector2(-2,-10.5),Vector2(4,0.25),Color("dcc092"))
		_px(p+Vector2(0,-9.5),Vector2(0.25,1.5),Color("6b6549"))
		_px(p+Vector2(-1.5,-12.5),Vector2(0.25,1.5),Color("e3c89e"))
	elif _facing.x!=0:
		_px(p+Vector2(-3 if _facing.x>0 else 3.5,-13.5),Vector2(0.25,6),Color("7d9b73"))
		_px(p+Vector2(0,-12),Vector2(0.25,5),Color("a48b61"))
	else:
		_px(p+Vector2(-2.5,-13.5),Vector2(0.25,6),Color("8c7954"))
		_px(p+Vector2(-1,-10.5),Vector2(0.25,0.25),Color("716544"))
		_px(p+Vector2(-1,-8.5),Vector2(0.25,0.25),Color("716544"))
		_px(p+Vector2(3.5,-11.5),Vector2(2,0.25),Color("9cb28b"))
		_px(p+Vector2(4,-9.5),Vector2(0.25,1.5),Color("d2b17c"))

func _paint_sprite_finish(player: bool) -> void:
	# Restrained micro-shading follows existing material. It is deterministic
	# native detail, while alpha contours retain the intentional pixel silhouette.
	var source: Image = _sprite_image.duplicate()
	for y in range(2,source.get_height()-2):
		for x in range(2,source.get_width()-2):
			var c: Color = source.get_pixel(x,y)
			if c.a<0.5: continue
			var above: Color = source.get_pixel(x,y-1)
			var left: Color = source.get_pixel(x-1,y)
			var right: Color = source.get_pixel(x+1,y)
			if above.a<0.5:
				_sprite_image.set_pixel(x,y,c.lightened(0.08))
			elif right.a<0.5:
				_sprite_image.set_pixel(x,y,c.darkened(0.12))
			elif left.a>0.5 and x%7==0 and y%4==0:
				_sprite_image.set_pixel(x,y,c.darkened(0.035))
	if player:
		# Hat weave, satchel buckle, cloak seam and individual fingers are now
		# one native pixel wide, instead of a half-logical-unit rectangle.
		for i in range(9):
			_px(Vector2(7.0+i*0.5,5.25),Vector2(0.25,0.25),Color("bda675"))
		_px(Vector2(7.25,8),Vector2(6.5,0.25),Color("b49b70"))
		_px(Vector2(6.5,15),Vector2(0.25,4.5),Color("3d654e"))
		_px(Vector2(14.75,15.25),Vector2(0.25,3.5),Color("c6cda4"))
		_px(Vector2(14,18.25),Vector2(1.25,0.25),Color("c8a875"))
		_px(Vector2(14.5,18.5),Vector2(0.25,0.5),Color("e4cb97"))

func _paint_camp(camp: Dictionary) -> void:
	var x: float = int(camp.x)*TILE+8
	var y: float = int(camp.y)*TILE+10
	var roof := Color("9cbd7c")
	if str(camp.biome)=="Ember Ridge": roof=Color("aa7952")
	elif str(camp.biome) in ["Sunken Glade","Moonfen"]: roof=Color("778396")
	elif str(camp.biome)=="Glassfall Coast": roof=Color("a8b6a0")
	_map_ellipse(Vector2(x,y+5),Vector2(17,5),Color("729764"),false)
	_micro_rect(x-13,y-2,2,12,Color("786f4d"))
	_micro_rect(x+11,y-2,2,12,Color("786f4d"))
	_micro_rect(x-17,y-8,34,3,roof.darkened(0.18))
	_micro_rect(x-14,y-12,28,5,roof)
	_micro_rect(x-9,y-15,18,4,roof.lightened(0.10))
	_micro_rect(x-3,y-18,6,4,roof.lightened(0.18))
	for i in range(9):
		var xx: float = x-13+i*3
		_micro_line(Vector2(xx,y-8),Vector2(xx+2,y-5),roof.darkened(0.22),0.25)
	_micro_rect(x-9,y+5,18,3,Color("b29d6b"))
	_micro_rect(x+15,y-3,1,13,Color("8e815a"))
	_micro_rect(x+16,y-3,7,5,Color("d8c88d"))
	_micro_rect(x+17,y-2,5,0.5,Color("8a906c"))

func _build_atlas_texture() -> void:
	var image := Image.create(MAP_WIDTH,MAP_HEIGHT,false,Image.FORMAT_RGBA8)
	var pigments: Dictionary = {"Mosswood":Color("8ac171"),"Amber Hollow":Color("d9cb7a"),"Sporefen":Color("90c6ac"),"Sunken Glade":Color("92bdce"),"Glassfall Coast":Color("c5dda9"),"Moonfen":Color("b0bdd8"),"Ember Ridge":Color("d8b37d"),"Ancient Grove":Color("7eaf6d")}
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var terrain: int = _terrain[y*MAP_WIDTH+x]
			var color: Color = pigments[biome_at(Vector2i(x,y))]
			if terrain==1: color=Color("c4b17e")
			elif terrain==2: color=Color("79bdcf")
			elif _blocked.has(Vector2i(x,y)): color=color.darkened(0.18)
			image.set_pixel(x,y,color)
	_atlas_texture = ImageTexture.create_from_image(image)

func _build_atlas_ui() -> void:
	_atlas = PanelContainer.new()
	_atlas.visible = false
	_atlas.add_theme_stylebox_override("panel",_style(Color("fff7d8"),Color("a9bb8b"),16))
	add_child(_atlas)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	_atlas.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_atlas_title = _label("Wilderness atlas",23,Color("e4d8ad"))
	_atlas_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_atlas_title)
	header.add_child(_button("Close",_close_atlas))
	_atlas_canvas = AtlasCanvas.new()
	_atlas_canvas.world = self
	_atlas_canvas.custom_minimum_size = Vector2(0,360)
	_atlas_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_atlas_canvas.destination_selected.connect(_route_to)
	column.add_child(_atlas_canvas)
	var instructions := _label("Click the map to plan a route. Camps unlock after visiting them.",13,Color("b5c5a8"))
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(instructions)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 120
	column.add_child(scroll)
	_camp_list = VBoxContainer.new()
	_camp_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_camp_list)
	column.add_child(_button("Return to trail",_close_atlas))

func _layout_atlas() -> void:
	if not is_instance_valid(_atlas): return
	var compact: bool = size.x<700
	_atlas_canvas.custom_minimum_size.y = 225 if compact else 360
	_atlas_title.add_theme_font_size_override("font_size",18 if compact else 23)
	var dimensions := Vector2(minf(860,size.x-24),minf(780,size.y-32))
	_atlas.position = (size-dimensions)*0.5
	_atlas.size = dimensions

func _open_atlas() -> void:
	if waiting: return
	_held_direction = Vector2i.ZERO
	_touch_goal = Vector2i(-1,-1)
	_route.clear()
	waiting = true
	_atlas.visible = true
	_atlas.move_to_front()
	_rebuild_camp_list()
	_layout_atlas()
	_atlas_canvas.queue_redraw()
	sfx_requested.emit("ui")
	refresh()

func _close_atlas() -> void:
	if is_instance_valid(_atlas): _atlas.visible = false
	waiting = false
	_held_direction = Vector2i.ZERO
	_step_cooldown = 0.2
	refresh()
	grab_focus()

func _rebuild_camp_list() -> void:
	for child in _camp_list.get_children():
		_camp_list.remove_child(child)
		child.queue_free()
	var visited: Array = state.expedition.get("visited_landmarks",[]) if state!=null else []
	for camp: Dictionary in LANDMARKS:
		var known: bool = camp.id=="home" or visited.has(camp.id)
		var b := _button("Travel to %s" % str(camp.name) if known else "%s / Unvisited camp" % str(camp.name),func(): _travel_to(camp))
		b.disabled = not known
		_camp_list.add_child(b)

func _route_to(target: Vector2i) -> void:
	if not is_walkable(target):
		# Permit a click on a tree/shore icon to choose the nearest safe tile.
		var replacement := Vector2i(-1,-1)
		for radius in range(1,5):
			for offset in [Vector2i(radius,0),Vector2i(-radius,0),Vector2i(0,radius),Vector2i(0,-radius)]:
				if is_walkable(target+offset): replacement=target+offset;break
			if replacement.x>=0:break
		if replacement.x<0:return
		target=replacement
	_close_atlas()
	_touch_goal = target
	_route = _find_path(player_tile,target)
	_message = "Walking to the marked patch."
	sfx_requested.emit("ui")

func _travel_to(camp: Dictionary) -> void:
	var visited: Array = state.expedition.get("visited_landmarks",[]) if state!=null else []
	if camp.id!="home" and not visited.has(camp.id): return
	player_tile = Vector2i(camp.x,camp.y)
	if state!=null:
		# Camp travel is a journey, not extra walking steps.
		state.expedition.position = [player_tile.x,player_tile.y]
		if state.has_method("register_biome"): state.register_biome(str(camp.biome))
		state.save_game()
	_close_atlas()
	_check_landmarks()
	_update_camera()
	_warm_visible_chunks()
	refresh()
	position_changed.emit()
	sfx_requested.emit("ui")

func _nearby_landmark() -> Dictionary:
	for landmark: Dictionary in LANDMARKS:
		if landmark.id!="home" and _distance(player_tile,Vector2i(landmark.x,landmark.y))<=2:return landmark
	return {}

func _check_landmarks() -> void:
	if state==null:return
	for landmark: Dictionary in LANDMARKS:
		if _distance(player_tile,Vector2i(landmark.x,landmark.y))<=2:
			var visited: Array = state.expedition.get("visited_landmarks",[])
			if not visited.has(landmark.id) and state.has_method("visit_landmark"):
				state.visit_landmark(str(landmark.id),str(landmark.biome))
				_message = "%s / Field camp discovered" % str(landmark.name)
				sfx_requested.emit("ui")
