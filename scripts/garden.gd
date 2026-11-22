extends Control
const State = preload("res://scripts/garden_state.gd")
const Portrait = preload("res://scripts/plant_portrait.gd")
const Cell = preload("res://scripts/plant_cell.gd")
const Ecology = preload("res://scripts/ecology.gd")
const Bench = preload("res://scripts/bench_surface.gd")
const Display = preload("res://scripts/display_settings.gd")
const Locale = preload("res://scripts/localization.gd")
const Sound = preload("res://scripts/soundscape.gd")
const DNA = preload("res://scripts/plant_dna.gd")
const GeneticsUI = preload("res://scripts/genetics_panel.gd")
const Guide = preload("res://scripts/genetics_guide.gd")
const CareUI = preload("res://scripts/plant_care_panel.gd")
const CareSpark = preload("res://scripts/care_tool_icon.gd")
const MarketUI = preload("res://scripts/market_panel.gd")
const PlantingUI = preload("res://scripts/planting_panel.gd")
const FairUI = preload("res://scripts/garden_fair_panel.gd")
const Habitat = preload("res://scripts/habitat_catalog.gd")
const HabitatScene = preload("res://scripts/habitat_scene.gd")
const AdventureUI = preload("res://scripts/adventure_panel.gd")
const INK := Color("284838")
const MUTED := Color("617957")
const AMBER := Color("a4542b")
var state = State.new()
var selected_id: String = ""
var moving: bool = false
var parent_a: String = ""
var parent_b: String = ""
var lab_mode: String = "Crossbreed"
var modal: Control
var modal_content: VBoxContainer
var modal_scroll: ScrollContainer
var modal_kind: String = ""
var resources_label: Label
var score_label: Label
var status_label: Label
var garden_column: VBoxContainer
var main_row: HBoxContainer
var sidebar: PanelContainer
var side_content: VBoxContainer
var display_grid: GridContainer
var bed_grid: GridContainer
var tray_row: HBoxContainer
var tray_scroll: ScrollContainer
var tray_panel: PanelContainer
var primary_button: Button
var garden_hint_label: Label
var heading: Label
var helper_label: Label
var display_caption: Button
var display_heading: HBoxContainer
var title_row: HBoxContainer
var footer_row: GridContainer
var toast_label: Label
var toast_panel: PanelContainer
var cells: Dictionary = {}
var save_timer: float = 0
var toast_time: float = 0
var ui_margin: MarginContainer
var serif: Font
var sans: Font
var small_layout: bool = false
var lab_pick_a: OptionButton
var lab_pick_b: OptionButton
var lab_result: Label
var action_picker: OptionButton
var last_log: String = "Roots settle. The garden is listening."
var root_column: VBoxContainer
var brand_label: Label
var collection_box: VBoxContainer
var tray_hint: Label
var explore_button: Button
var wilderness: Control
var exploring: bool = false
var wild_encounter_open: bool = false
var display_settings = Display.new()
var display_settings_button: Button
var display_output_label: Label
var soundscape: Node
var language_picker: OptionButton
var locale_timer: float = 0.0
var last_audio_biome: String = ""
var breeding_button: Button
var nursery_button: Button
var nursery_tab: String = "plants"
var seed_page: int = 0
var active_parent_slot: int = 0
var reproduction_labels: Array[Label] = []
var reproduction_buttons: Array[Button] = []
var reproduction_signature: String = ""
var lifecycle_meters: Array[ProgressBar] = []
var life_save_timer: float = 0.0
var care_button: Button
var care_buttons: Array[Button] = []
var care_labels: Array[Label] = []
var market_button: Button
var market_tab: String = "plants"
var market_page: int = 0
var market_buttons: Array[Button] = []
var market_labels: Array[Label] = []
var plant_button: Button
var planting_page: int = 0
var planting_buttons: Array[Button] = []
var planting_labels: Array[Label] = []
var tagline_label: Label
var fair_tab: String = "requests"
var fair_buttons: Array[Button] = []
var fair_labels: Array[Label] = []
var celebrated_fair_key: String = ""
var adventure_field: Control
var adventuring: bool = false
var adventure_mother: String = ""
var adventure_father: String = ""
var adventure_entry: Button

func _ready() -> void:
	if state.save_path == State.SAVE_PATH and DisplayServer.get_name() != "headless": Locale.load_settings()
	# Test/preview SceneTrees own their viewport. The actual main scene adapts to
	# the monitor and renders directly at the larger physical window size.
	if get_tree().current_scene == self or (state.save_path == State.SAVE_PATH and not OS.get_cmdline_args().has("--script")):
		display_settings.configure(get_window())
		if display_settings.enabled: print("DISPLAY INITIALIZED: ",display_settings.description())
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Avenir Next","Trebuchet MS","Verdana"])
	title_font.font_weight = 700
	serif = title_font
	var body_font := SystemFont.new()
	body_font.font_names = PackedStringArray(["Helvetica Neue","Arial","DejaVu Sans"])
	body_font.font_weight = 400
	sans = body_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_theme()
	if not state.load_game(): state.new_game()
	state.tick_growth()
	soundscape = Sound.new()
	soundscape.preview_muted = state.save_path != State.SAVE_PATH
	if soundscape.preview_muted: soundscape.settings_path = state.save_path.get_basename()+".audio.cfg"
	add_child(soundscape)
	soundscape.set_context("garden")
	_build_ui()
	_refresh()
	resized.connect(_responsive)
	call_deferred("_responsive")
	adventure_entry.grab_focus()
	get_tree().auto_accept_quit = false
	call_deferred("_localize_ui")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		state.save_game()
		get_tree().quit()

func _build_theme() -> void:
	var t := Theme.new()
	t.default_font = sans
	t.default_font_size = 14
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color("203d2a"))
	t.set_color("font_disabled_color", "Button", Color("849279"))
	for kind in ["Button", "OptionButton"]:
		t.set_color("font_color",kind,INK)
		t.set_color("font_hover_color",kind,INK)
		t.set_color("font_focus_color",kind,INK)
		t.set_color("font_pressed_color",kind,INK)
		t.set_color("font_hover_pressed_color",kind,INK)
		t.set_stylebox("normal", kind, _style(Color("e8efb7"), Color("8ca96a"), 5, 14, 10))
		t.set_stylebox("hover", kind, _style(Color("fff0a7"), Color("c79b50"), 5, 14, 10))
		t.set_stylebox("pressed", kind, _style(Color("bddd91"), Color("6c9756"), 5, 14, 10))
		t.set_stylebox("focus", kind, _style(Color.TRANSPARENT, Color("e19354"), 5, 14, 10))
		t.set_stylebox("disabled", kind, _style(Color("e4e7cf"), Color("b3bca2"), 5, 14, 10))
	t.set_stylebox("normal", "LineEdit", _style(Color("fffbea"), Color("8aa569"), 5, 12, 10))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_stylebox("panel", "PopupMenu", _style(Color("fff9df"), Color("8ca96a"), 5, 8, 8))
	t.set_color("font_hover_color","PopupMenu",INK)
	t.set_stylebox("panel", "TooltipPanel", _style(Color("fff5ca"), Color("bd9f63"), 4, 12, 10))
	t.set_color("font_color", "TooltipLabel", INK)
	for kind in ["CheckButton","CheckBox"]:
		for state_name in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]: t.set_color(state_name,kind,INK)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 12)
	theme = t

func _style(bg: Color, border: Color = Color("344d3c"), radius: int = 5, horizontal: int = 16, vertical: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	# Keep older feature panels in the same sunny paper-and-leaf palette.
	# Pigment swatches and plant shaders never pass through this UI helper.
	s.bg_color = Color("fff7da").lerp(Color("e5efc6"),clampf((bg.v-0.08)*3.0,0,1)) if bg.v<0.50 and bg.a>0 else bg
	s.bg_color.a = bg.a
	s.border_color = Color("9eb77d") if border.v<0.57 and border.a>0 else border
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	s.shadow_color = Color(0.30,0.43,0.20,0.18)
	s.shadow_size = 3
	s.shadow_offset = Vector2(3,3)
	s.content_margin_left = horizontal
	s.content_margin_right = horizontal
	s.content_margin_top = vertical
	s.content_margin_bottom = vertical
	return s

func _label(text: String, font_size: int = 14, color: Color = INK, use_serif: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	var readable: Color = color
	if color!=INK and color!=MUTED and color!=AMBER and color.v>0.60:
		readable = Color("8e592d") if color.r>color.g*1.05 else Color("4b6d43")
	l.add_theme_color_override("font_color", readable)
	if use_serif: l.add_theme_font_override("font", serif)
	return l

func _wrap(text: String, font_size: int = 14, color: Color = MUTED) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _button(text: String, action: Callable, minimum: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minimum
	b.pressed.connect(func(): _play_sound("ui"); action.call())
	return b

func _spacer(parent: Node, vertical: bool = false) -> Control:
	var c := Control.new()
	if vertical: c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else: c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c

func _line(parent: Node) -> void:
	var line := HSeparator.new()
	line.modulate = Color("b3c88c")
	parent.add_child(line)

func _build_ui() -> void:
	var world := Ecology.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(world)
	ui_margin = MarginContainer.new()
	ui_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: ui_margin.add_theme_constant_override("margin_" + edge, 38)
	for edge in ["top", "bottom"]: ui_margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(ui_margin)
	var root := VBoxContainer.new()
	root_column = root
	root.add_theme_constant_override("separation", 10)
	ui_margin.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var brand := _label("SPROUT · GROW · DISCOVER", 13, INK)
	brand_label = brand
	brand.tooltip_text = "The Quiet Conservatory · grow, explore, and make plant friends"
	top.add_child(brand)
	adventure_entry=_button("Stream story →",_open_adventure,Vector2(132,30))
	adventure_entry.set_meta("adventure_action","open")
	adventure_entry.tooltip_text="Grow a way across the stream."
	adventure_entry.add_theme_stylebox_override("normal",_style(Color("ffd399"),Color("ba925b"),0,10,5))
	top.add_child(adventure_entry)
	_spacer(top)
	resources_label = _label("", 14, Color("c4cbb2"))
	top.add_child(resources_label)
	display_settings_button = _button("Settings", _open_settings, Vector2(82,26))
	display_settings_button.add_theme_font_size_override("font_size",12)
	display_settings_button.add_theme_stylebox_override("normal",_style(Color("1c3128"),Color("4b6250"),0,8,4))
	top.add_child(display_settings_button)
	_line(root)
	title_row = HBoxContainer.new()
	root.add_child(title_row)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 3)
	title_row.add_child(titles)
	tagline_label = _label("A LITTLE SUNSHINE. A LOT OF POSSIBILITIES.",10,MUTED)
	titles.add_child(tagline_label)
	heading = _label("Quiet Conservatory", 36, INK, true)
	titles.add_child(heading)
	helper_label = _label("Tap an empty plot to plant a seed. Tap a plant to care for it.", 13, MUTED)
	titles.add_child(helper_label)
	_spacer(title_row)
	var score_box := VBoxContainer.new()
	collection_box = score_box
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_child(score_box)
	score_box.add_child(_label("LIVING COLLECTION", 10, MUTED))
	score_label = _label("", 22, AMBER, true)
	score_box.add_child(score_label)
	main_row = HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 22)
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_row)
	garden_column = VBoxContainer.new()
	garden_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garden_column.add_theme_constant_override("separation", 9)
	main_row.add_child(garden_column)
	var cap_row := HBoxContainer.new()
	display_heading = cap_row
	garden_column.add_child(cap_row)
	cap_row.add_child(_label("YOUR SHOW-OFF SHELF", 11, INK))
	_spacer(cap_row)
	display_caption = _button("Garden stars · Collect rewards", _open_display_notes)
	display_caption.add_theme_font_size_override("font_size",10)
	display_caption.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),2,4,4))
	cap_row.add_child(display_caption)
	display_grid = GridContainer.new()
	display_grid.columns = 6
	display_grid.add_theme_constant_override("h_separation", 7)
	display_grid.custom_minimum_size.y = 108
	garden_column.add_child(display_grid)
	var bed_header := HBoxContainer.new()
	garden_column.add_child(bed_header)
	bed_header.add_child(_label("THE GROW PATCH", 11, INK))
	_spacer(bed_header)
	garden_hint_label = _label("", 11, MUTED)
	bed_header.add_child(garden_hint_label)
	plant_button = _button("Plant a seed",func(): planting_page=0; _open_planting(),Vector2(100,28))
	plant_button.set_meta("planting_action","open")
	plant_button.add_theme_font_size_override("font_size",12)
	plant_button.add_theme_stylebox_override("normal",_style(Color("ffbe8e"),Color("c9874e"),0,10,3))
	plant_button.add_theme_stylebox_override("hover",_style(Color("ffd7a4"),Color("c9874e"),0,10,3))
	bed_header.add_child(plant_button)
	var board_panel := PanelContainer.new()
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _style(Color(0.09,0.14,0.115,0.9), Color("4a5c43"), 12, 13, 12))
	garden_column.add_child(board_panel)
	var board_inner := HBoxContainer.new()
	board_inner.add_theme_constant_override("separation", 8)
	board_panel.add_child(board_inner)
	var bed_wrap := VBoxContainer.new()
	bed_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_inner.add_child(bed_wrap)
	bed_grid = GridContainer.new()
	bed_grid.columns = 3
	bed_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bed_grid.add_theme_constant_override("h_separation", 7)
	bed_grid.add_theme_constant_override("v_separation", 6)
	bed_wrap.add_child(bed_grid)
	sidebar = PanelContainer.new()
	sidebar.custom_minimum_size.x = 302
	sidebar.add_theme_stylebox_override("panel", _style(Color(0.065,0.115,0.091,0.95), Color("3f5541"), 8, 21, 19))
	main_row.add_child(sidebar)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(side_scroll)
	side_content = VBoxContainer.new()
	side_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_content.add_theme_constant_override("separation", 12)
	side_scroll.add_child(side_content)
	status_label = _label("", 12, MUTED)
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(status_label)
	tray_panel = Bench.new()
	tray_panel.benched.connect(func(id): _drop_plant(id, "tray", 0))
	tray_panel.add_theme_stylebox_override("panel", _style(Color(0.065,0.115,0.095,0.95), Color("3c5340"), 8, 13, 10))
	root.add_child(tray_panel)
	var tray_column := VBoxContainer.new()
	tray_column.add_theme_constant_override("separation", 7)
	tray_panel.add_child(tray_column)
	var tray_heading := HBoxContainer.new()
	tray_column.add_child(tray_heading)
	tray_heading.add_child(_label("YOUR PLANT PALS", 10, INK))
	_spacer(tray_heading)
	tray_hint = _label("DRAG TO PLANT · TAP TO SAY HELLO", 10, MUTED)
	tray_heading.add_child(tray_hint)
	tray_scroll = ScrollContainer.new()
	tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tray_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray_scroll.custom_minimum_size.y = 132
	tray_column.add_child(tray_scroll)
	tray_row = HBoxContainer.new()
	tray_row.add_theme_constant_override("separation", 10)
	tray_scroll.add_child(tray_row)
	footer_row = GridContainer.new()
	footer_row.columns = 6
	root.add_child(footer_row)
	breeding_button = _button("Crossbreeding", func(): lab_mode = "Crossbreed"; _open_lab(), Vector2(205,48))
	breeding_button.set_meta("reproduction_action","open_breeding")
	breeding_button.add_theme_stylebox_override("normal",_style(Color("ffb08c"),Color("cf855d"),0,14,14))
	breeding_button.add_theme_stylebox_override("hover",_style(Color("ffc9a3"),Color("cf855d"),0,14,14))
	breeding_button.add_theme_color_override("font_color",Color("182c22"))
	breeding_button.add_theme_color_override("font_hover_color",Color("14281c"))
	footer_row.add_child(breeding_button)
	nursery_button = _button("Fruit & seeds",_open_seeds,Vector2(150,48))
	nursery_button.set_meta("reproduction_action","open_nursery")
	footer_row.add_child(nursery_button)
	care_button = _button("Tool shed",func(): _open_care(),Vector2(100,48))
	care_button.set_meta("reproduction_action","open_care")
	care_button.add_theme_stylebox_override("normal",_style(Color("ffe58d"),Color("cba355"),0,14,12))
	footer_row.add_child(care_button)
	market_button = _button("Market",func(): market_page=0; _open_market(),Vector2(100,48))
	market_button.set_meta("reproduction_action","open_market")
	market_button.add_theme_stylebox_override("normal",_style(Color("cce9d8"),Color("86b29c"),0,12,10))
	footer_row.add_child(market_button)
	explore_button = _button("Explore wilds →", _open_wilderness, Vector2(175,48))
	explore_button.add_theme_color_override("font_color",AMBER)
	footer_row.add_child(explore_button)
	primary_button = _button("Garden Fair", _open_fair, Vector2(180, 48))
	primary_button.set_meta("fair_action","open")
	primary_button.add_theme_stylebox_override("normal",_style(Color("ffc88e"),Color("c88a4e"),0,12,12))
	primary_button.add_theme_stylebox_override("hover",_style(Color("ffdda7"),Color("c88a4e"),0,12,12))
	footer_row.add_child(primary_button)
	for action in footer_row.get_children(): action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _style(Color("2c4030"), Color("8d9e6f"), 6, 22, 14))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	add_child(toast_panel)
	toast_label = _wrap("", 14, INK)
	toast_label.custom_minimum_size.x = 340
	toast_panel.add_child(toast_label)

func _responsive() -> void:
	small_layout = size.x < 900
	var short_window: bool = not small_layout and size.y < 960
	var very_short: bool = not small_layout and size.y < 850
	display_settings_button.visible = true
	display_settings_button.text = "···" if small_layout else "Settings"
	display_settings_button.custom_minimum_size.x = 32 if small_layout else 82
	adventure_entry.text="Adventure" if small_layout else "Stream story →"
	adventure_entry.custom_minimum_size.x=94 if small_layout else 132
	adventure_entry.add_theme_font_size_override("font_size",12 if small_layout else 13)
	sidebar.visible = not small_layout
	heading.add_theme_font_size_override("font_size", 24 if small_layout or very_short else (30 if short_window else 34))
	root_column.add_theme_constant_override("separation", 5 if small_layout else (6 if very_short else (8 if short_window else 10)))
	tagline_label.visible = not small_layout
	display_grid.custom_minimum_size.y = 82 if small_layout else (72 if short_window else 108)
	display_heading.visible = true
	brand_label.visible = not small_layout
	collection_box.visible = not small_layout
	tray_hint.visible = not small_layout
	tray_scroll.custom_minimum_size.y = 116 if small_layout or short_window else 132
	helper_label.visible = size.x > 700 and not very_short
	display_caption.visible = true
	if small_layout: display_caption.text = "Beauty %d · Observe" % int(state.display_score().get("total",0))
	else: display_caption.text = "Garden stars · Collect rewards"
	for edge in ["left", "right"]: ui_margin.add_theme_constant_override("margin_" + edge, 14 if small_layout else 38)
	for edge in ["top", "bottom"]: ui_margin.add_theme_constant_override("margin_" + edge, 14 if small_layout or very_short else (16 if short_window else 22))
	resources_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if small_layout else Control.SIZE_SHRINK_END
	resources_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if small_layout else HORIZONTAL_ALIGNMENT_RIGHT
	resources_label.add_theme_font_size_override("font_size", 11 if small_layout else 14)
	_refresh_reproduction_counters()
	for c in display_grid.get_children(): c.custom_minimum_size = Vector2(0,82 if small_layout else (72 if short_window else 108))
	for c in tray_row.get_children(): c.custom_minimum_size = Vector2(116,110) if small_layout else Vector2(130,110 if short_window else 128)
	for c in bed_grid.get_children(): c.custom_minimum_size = Vector2(0,60 if small_layout else (76 if short_window else 108))
	for b in footer_row.get_children():
		if b is Button:
			b.custom_minimum_size.x = 0 if small_layout else (160 if b == breeding_button else (130 if b == nursery_button else (150 if b == primary_button else 100)))
			b.add_theme_font_size_override("font_size", 11 if small_layout else 14)
	footer_row.columns = 3 if small_layout else 6
	footer_row.add_theme_constant_override("h_separation",6 if small_layout else 12)
	footer_row.add_theme_constant_override("v_separation",6)
	care_button.text = "Tools" if small_layout else "Tool shed"
	care_button.disabled = false
	care_button.visible = true
	plant_button.visible = true
	plant_button.disabled = false
	garden_hint_label.visible = not small_layout
	market_button.disabled = false
	breeding_button.text = "Breed" if small_layout else "Crossbreeding"
	breeding_button.disabled = false
	_refresh_reproduction_counters()
	explore_button.text = "Explore" if small_layout else "Explore wilds →"
	explore_button.visible = true
	explore_button.disabled = false
	_refresh_fair_counters()
	if is_instance_valid(modal): _position_modal()
	var toast_width: float = minf(480,size.x-24)
	toast_label.custom_minimum_size.x = minf(340,maxf(1,toast_width-44))
	toast_panel.size.x = toast_width
	toast_panel.position = Vector2(maxf(12,(size.x-toast_width)*0.5),maxf(12,footer_row.position.y-maxf(72,toast_panel.get_combined_minimum_size().y)-10))

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	_refresh_reproduction_counters()
	var score: Dictionary = state.display_score()
	score_label.text = "%03d  /  beauty" % int(score.get("total", 0))
	status_label.text = last_log
	_refresh_cells()
	_refresh_side()
	_refresh_garden_hint()
	# Rebuilt cells must immediately inherit the current window's layout, too.
	# Waiting for a window resize left fresh mobile seedlings in desktop rows.
	_responsive()

func _make_cell(id: String, zone: String, index: int) -> Control:
	var c := Cell.new()
	c.plant = state.get_plant(id) if id != "" else {}
	c.zone = zone
	c.index = index
	c.selected = id == selected_id and id != ""
	c.custom_minimum_size = Vector2(130, 128) if zone == "tray" else Vector2(0, 108 if zone == "display" else 110)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.chosen.connect(_choose_plant)
	c.inspected.connect(_open_detail)
	c.dropped.connect(_drop_plant)
	return c

func _refresh_cells() -> void:
	cells.clear()
	_clear(display_grid)
	_clear(bed_grid)
	_clear(tray_row)
	for i in range(6): display_grid.add_child(_make_cell(str(state.display_bed[i]), "display", i))
	for i in range(9):
		var c := _make_cell(str(state.bed[i]), "bed", i)
		bed_grid.add_child(c)
		if not c.plant.is_empty(): cells[str(c.plant.id)] = c
	for id in state.plant_order:
		if state.plants.has(id): tray_row.add_child(_make_cell(str(id), "tray", 0))

func _refresh_garden_hint() -> void:
	var empty: int = state.bed.count("")
	garden_hint_label.text = "%d spots for new sprouts" % empty if empty>0 else "A patch full of plant pals!"

func _lineage_text(p: Dictionary) -> String:
	var mix: Dictionary = state.lineage_composition(p)
	var ordered: Array = mix.keys()
	ordered.sort_custom(func(a,b): return float(mix[a])>float(mix[b]))
	var parts: Array[String] = []
	for type_name: String in ordered:
		parts.append("%s %d%%" % [type_name,roundi(float(mix[type_name])*100)])
	return " · ".join(parts)

func _fruit_note(id: String) -> String:
	var p: Dictionary = state.get_plant(id)
	if p.is_empty(): return ""
	var now: int = int(Time.get_unix_time_from_system())
	if p.get("withered",false):
		return "Final fruit ready · harvest to preserve this DNA" if int(state.fruit_status(id).get("ready_count",0))>0 else "Withered · continue this lineage from its stored seeds"
	if not p.get("mature",false): return "Seedling · mature in %d seconds" % maxi(0,int(p.get("ready_at",now))-now)
	var status: Dictionary = state.fruit_status(id)
	if int(status.get("ready_count",0))>0: return "%d ripe fruit ready to harvest" % int(status.ready_count)
	var cross: Dictionary = status.get("pollination",{})
	if not cross.is_empty(): return "Hybrid fruit developing · %d seconds" % maxi(0,int(cross.get("ready_at",now))-now)
	return "Natural fruit developing · %d seconds" % maxi(0,int(status.get("natural_ready_at",now))-now)

func _live_fruit_label(id: String, font_size: int = 12) -> Label:
	var note: Label = _wrap(_fruit_note(id),font_size,AMBER)
	note.set_meta("fruit_plant_id",id)
	reproduction_labels.append(note)
	return note

func _life_note(id: String) -> String:
	var life: Dictionary = state.life_profile(id)
	var remaining: int = maxi(0,int(life.get("remaining",0)))
	match str(life.get("stage","mature")):
		"seedling": return "Seedling · growing toward maturity"
		"aging": return "Aging · %02d:%02d until natural withering" % [remaining/60,remaining%60]
		"withered": return "Withered · DNA and pedigree remain in the archive"
		_:
			remaining = maxi(0,ceili(float(life.get("aging_at",State.AGING_SECONDS))-float(life.get("age",0))))
			return "Mature · %02d:%02d until aging" % [remaining/60,remaining%60]

func _live_life_label(id: String) -> Label:
	var note: Label = _wrap(_life_note(id),12,MUTED)
	note.set_meta("life_plant_id",id)
	reproduction_labels.append(note)
	return note

func _life_meter(id: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.show_percentage = false
	bar.set_meta("life_plant_id",id)
	bar.add_theme_stylebox_override("background",_style(Color("24392d"),Color.TRANSPARENT,0,0,0))
	bar.add_theme_stylebox_override("fill",_style(Color("a3b782"),Color.TRANSPARENT,0,0,0))
	bar.value = (1.0-float(state.life_profile(id).get("progress",0)))*100
	lifecycle_meters.append(bar)
	return bar

func _action_button(text: String, action: Callable, kind: String, plant_id: String = "") -> Button:
	var button: Button = _button(text,action)
	button.set_meta("reproduction_action",kind)
	if not plant_id.is_empty(): button.set_meta("plant_id",plant_id)
	return button

func _harvest_button(id: String) -> Button:
	var button: Button = _action_button("Harvest fruit",func(): _harvest_fruit(id),"harvest",id)
	button.disabled = int(state.fruit_status(id).get("ready_count",0))==0
	reproduction_buttons.append(button)
	return button

func _refresh_reproduction_counters() -> void:
	var overview: Dictionary = state.fruit_overview()
	var stored: int = int(overview.get("fruits",0))
	resources_label.text = ("LIGHT %d · FRUIT %d · SEEDS %d" if small_layout else "Gathered light  %d    /    Fruit  %d    /    Seeds  %d") % [state.resources.sunlight,stored,state.seed_bank.size()]
	Locale.apply_tree(resources_label)
	if is_instance_valid(market_button):
		market_button.text = "Market" if small_layout else "Market · %d coins" % state.market_wallet()
		Locale.apply_tree(market_button)
	if is_instance_valid(nursery_button):
		var ready: int = int(overview.get("ready",0))
		nursery_button.text = ("Harvest %d" if small_layout else "Fruit & seeds · %d ripe") % ready if ready>0 else ("Harvest" if small_layout else "Fruit & seeds")
		nursery_button.add_theme_color_override("font_color",AMBER if ready>0 else INK)
		Locale.apply_tree(nursery_button)
	for index in range(reproduction_labels.size()-1,-1,-1):
		var note: Label = reproduction_labels[index]
		if not is_instance_valid(note): reproduction_labels.remove_at(index); continue
		note.text = _life_note(str(note.get_meta("life_plant_id"))) if note.has_meta("life_plant_id") else _fruit_note(str(note.get_meta("fruit_plant_id","")))
		Locale.apply_tree(note)
	for index in range(reproduction_buttons.size()-1,-1,-1):
		var button: Button = reproduction_buttons[index]
		if not is_instance_valid(button): reproduction_buttons.remove_at(index); continue
		var id: String = str(button.get_meta("plant_id",""))
		match str(button.get_meta("reproduction_action","")):
			"next_cross": button.disabled = not _owns_plant(id) or not state.get_plant(id).get("mature",false) or state.get_plant(id).get("withered",false)
			"dna_use_pair":
				var mate: Dictionary = state.get_plant(str(button.get_meta("parent_b","")))
				button.disabled = not _owns_plant(id) or not _owns_plant(str(button.get_meta("parent_b",""))) or not state.get_plant(id).get("mature",false) or state.get_plant(id).get("withered",false) or not mate.get("mature",false) or mate.get("withered",false)
			"harvest_all": button.disabled = int(overview.get("ready",0))==0
			"extract_all": button.disabled = state.fruit_inventory.is_empty()
			_: button.disabled = int(state.fruit_status(id).get("ready_count",0))==0
	for index in range(lifecycle_meters.size()-1,-1,-1):
		var bar: ProgressBar = lifecycle_meters[index]
		if not is_instance_valid(bar): lifecycle_meters.remove_at(index); continue
		var life: Dictionary = state.life_profile(str(bar.get_meta("life_plant_id","")))
		bar.value = (1.0-float(life.get("progress",0)))*100
	_refresh_care_counters()
	_refresh_market_counters()
	_refresh_planting_counters()
	_refresh_fair_counters()

func _open_fair(tab: String = "requests",feedback: String = "") -> void:
	FairUI.show(self,tab,feedback)

func _show_fair_request(key: String,plant_id: String = "") -> void:
	FairUI.request_view(self,key,plant_id)

func _claim_fair_request(key: String,plant_id: String) -> void:
	if modal_kind=="fair_reward" and celebrated_fair_key=="visit:"+key: return
	var result: Dictionary = state.fair_claim(key,plant_id)
	if result.get("ok",false):
		celebrated_fair_key="visit:"+key
		_play_sound("fair_claim")
		_refresh()
		FairUI.celebrate(self,result,"requests")
		_care_sparkles()
	else: FairUI.request_view(self,key,plant_id,str(result.get("message","")))

func _claim_fair_ribbon(key: String) -> void:
	if modal_kind=="fair_reward" and celebrated_fair_key=="ribbon:"+key: return
	var result: Dictionary = state.fair_claim_ribbon(key)
	if result.get("ok",false):
		celebrated_fair_key="ribbon:"+key
		_play_sound("fair_ribbon")
		_refresh()
		FairUI.celebrate(self,result,"ribbons")
		_care_sparkles()
	else: _open_fair("ribbons",str(result.get("message","")))

func _refresh_fair_counters() -> void:
	if is_instance_valid(primary_button):
		var ready: int = 0
		for request: Dictionary in state.fair_requests():
			if not request.claimed and not request.eligible_ids.is_empty(): ready+=1
		primary_button.text = (("Fair · %d" if small_layout else "Garden Fair · %d ready") % ready) if ready>0 else ("Fair" if small_layout else "Garden Fair")
		Locale.apply_tree(primary_button)
	var ribbons: Dictionary = {}
	for ribbon: Dictionary in state.fair_ribbons(): ribbons[str(ribbon.key)]=ribbon
	for index in range(fair_buttons.size()-1,-1,-1):
		var button: Button = fair_buttons[index]
		if not is_instance_valid(button): fair_buttons.remove_at(index); continue
		if button.get_meta("fair_action","")=="claim_request":
			button.disabled = not state.fair_preview(str(button.get_meta("request_key","")),str(button.get_meta("plant_id",""))).get("eligible",false)
		elif button.get_meta("fair_action","")=="claim_ribbon":
			var entry: Dictionary = ribbons.get(str(button.get_meta("ribbon_key","")),{})
			button.disabled = entry.get("earned",false) or not entry.get("eligible",false)
	for index in range(fair_labels.size()-1,-1,-1):
		var note: Label = fair_labels[index]
		if not is_instance_valid(note): fair_labels.remove_at(index); continue
		var preview: Dictionary = state.fair_preview(str(note.get_meta("request_key","")),str(note.get_meta("plant_id","")))
		note.text = "A perfect match! Let's introduce you." if preview.get("eligible",false) else str(preview.reason)
		Locale.apply_tree(note)

func _talents_text(skills: Array) -> String:
	var names: Array[String] = []
	for skill: String in skills: names.append(Guide.talent_name(skill))
	return " / ".join(names)

func _say_hello(id: String) -> void:
	if not _owns_plant(id): return
	var p: Dictionary = state.get_plant(id)
	if p.get("withered",false):
		_open_planting()
		return
	if cells.has(id) and is_instance_valid(cells[id].portrait): cells[id].portrait.activity=1.0
	_wiggle_plant(self,id)
	_play_sound("bloom")
	_care_sparkles()
	_toast("%s gives its leaves a happy little wiggle!" % str(p.name))

func _wiggle_plant(node: Node,id: String) -> void:
	if node is Portrait and str(node.plant.get("id",""))==id:
		node.pivot_offset=node.size*0.5
		node.activity=1.0
		var wobble: Tween = node.create_tween()
		wobble.tween_property(node,"rotation_degrees",3.5,0.12)
		wobble.tween_property(node,"rotation_degrees",-3.5,0.18)
		wobble.tween_property(node,"rotation_degrees",0.0,0.16)
	for child: Node in node.get_children(): _wiggle_plant(child,id)

func _open_planting(cell: int = -1,reference: Variant = null) -> void:
	PlantingUI.show(self,cell,reference)

func _sow_at(reference: Variant,cell: int) -> void:
	var result: Dictionary = state.plant_seed_at(reference,cell)
	if not result.get("ok",false):
		PlantingUI.show(self,cell,reference,str(result.get("message","Choose another empty plot.")))
		return
	var p: Dictionary = result.plant
	selected_id = str(p.id)
	moving = false
	last_log = "%s planted in plot %d. It grows automatically!" % [p.name,cell+1]
	_play_sound("seed")
	_refresh()
	PlantingUI.planted(self,p,cell)
	_care_sparkles()

func _focus_planted(id: String) -> void:
	if not _owns_plant(id): return
	selected_id = id
	moving = false
	if cells.has(id) and is_instance_valid(cells[id]): cells[id].grab_focus()
	last_log = PlantingUI.countdown(self,id) if state.bed.has(id) else "This seedling is growing on your bench. Move it into a plot when it has grown."
	status_label.text = last_log
	Locale.apply_tree(status_label)

func _place_from_picker(id: String,zone: String,cell: int) -> void:
	var target: Array = state.display_bed if zone=="display" else state.bed
	if cell<0 or cell>=target.size() or not str(target[cell]).is_empty():
		_toast("That spot is now occupied. Choose another empty spot.")
		_close_modal()
		return
	_close_modal()
	_drop_plant(id,zone,cell)

func _refresh_planting_counters() -> void:
	for index in range(planting_labels.size()-1,-1,-1):
		var note: Label = planting_labels[index]
		if not is_instance_valid(note): planting_labels.remove_at(index); continue
		note.text = PlantingUI.countdown(self,str(note.get_meta("plant_id","")))
		Locale.apply_tree(note)
	for index in range(planting_buttons.size()-1,-1,-1):
		var button: Button = planting_buttons[index]
		if not is_instance_valid(button): planting_buttons.remove_at(index); continue
		var cell: int = int(button.get_meta("bed_index",-1))
		button.disabled = int(state.resources.sunlight)<10 or cell<0 or cell>=9 or not str(state.bed[cell]).is_empty() or state._market_resolve("seed",button.get_meta("seed_ref",{})).is_empty()

func _open_market(tab: String = "plants",feedback: String = "") -> void:
	MarketUI.show(self,tab,feedback)

func _review_market_sale(kind: String,reference: Variant) -> void:
	market_tab = {"plant":"plants","fruit":"fruits","seed":"seeds"}.get(kind,market_tab)
	MarketUI.review(self,kind,reference)

func _confirm_market_sale(kind: String,reference: Variant,quote_id: String) -> void:
	var result: Dictionary = state.market_sell(kind,reference,quote_id)
	var message: String = str(result.get("message",""))
	if result.get("ok",false):
		if kind=="plant":
			if selected_id==str(reference): selected_id=""; moving=false
			if parent_a==str(reference): parent_a=""
			if parent_b==str(reference): parent_b=""
		_play_sound("collect_success")
		_refresh()
		_open_market(market_tab,message)
		_care_sparkles()
	else: MarketUI.review(self,kind,reference,message)
	_toast(message)

func _market_buy(stock_key: String) -> void:
	var result: Dictionary = state.market_buy(stock_key)
	var message: String = str(result.get("message",""))
	if result.get("ok",false): _play_sound("collect_success"); _refresh()
	_open_market("shop",message)
	_toast(message)

func _refresh_market_counters() -> void:
	for index in range(market_labels.size()-1,-1,-1):
		var label: Label = market_labels[index]
		if not is_instance_valid(label): market_labels.remove_at(index); continue
		if label.has_meta("market_wallet"): label.text = "%d coins" % state.market_wallet()
		Locale.apply_tree(label)
	for index in range(market_buttons.size()-1,-1,-1):
		var button: Button = market_buttons[index]
		if not is_instance_valid(button): market_buttons.remove_at(index); continue
		match str(button.get_meta("market_action","")):
			"buy": button.disabled = state.market_wallet()<int(button.get_meta("market_cost",0))
			"confirm_sale", "refresh_offer":
				var quote: Dictionary = state.market_quote(str(button.get_meta("item_kind","")),button.get_meta("item_ref"))
				var changed: bool = str(quote.get("quote_id",""))!=str(button.get_meta("quote_id",""))
				if button.get_meta("market_action")=="refresh_offer":
					button.visible = changed and quote.get("ok",false)
					button.disabled = false
				else:
					button.disabled = not quote.get("eligible",false) or changed
					button.tooltip_text = "The offer changed. Refresh it before selling." if changed else str(quote.get("reason",""))
					if is_instance_valid(modal):
						for note in modal_content.get_children():
							if note is Label and note.has_meta("market_review_notice"):
								note.visible = changed
								note.text = "The offer changed. Refresh it before selling." if quote.get("ok",false) else "This item is no longer at your stall. Return to the market to choose another."
								Locale.apply_tree(note)

func _owns_plant(id: String) -> bool:
	return state.owns_plant(id)

func _refresh_care_counters() -> void:
	for index in range(care_buttons.size()-1,-1,-1):
		var button: Button = care_buttons[index]
		if not is_instance_valid(button): care_buttons.remove_at(index); continue
		var id: String = str(button.get_meta("plant_id",""))
		var tool_key: String = str(button.get_meta("care_tool",""))
		var status: Dictionary = state.care_status(id,tool_key)
		button.disabled = not status.get("allowed",false)
		button.tooltip_text = str(status.get("reason",""))
	for index in range(care_labels.size()-1,-1,-1):
		var note: Label = care_labels[index]
		if not is_instance_valid(note): care_labels.remove_at(index); continue
		var id: String = str(note.get_meta("care_plant_id",""))
		if note.has_meta("care_tool_note"):
			var status: Dictionary = state.care_status(id,str(note.get_meta("care_tool_note")))
			note.text = CareUI.status_text(status)
		elif note.get_meta("care_measurement","")=="life": note.text = CareUI.life_text(self,id)
		elif note.get_meta("care_measurement","")=="height": note.text = "%s cm" % CareUI._number(float(state.plant_measurements(id).get("height_cm",0)))
		elif note.get_meta("care_measurement","")=="weight": note.text = "%s g" % CareUI._number(float(state.plant_measurements(id).get("weight_g",0)))
		Locale.apply_tree(note)

func _measurement_label(id: String) -> Label:
	var label: Label = _wrap(CareUI.measurement_text(state.plant_measurements(id)),14,INK)
	label.set_meta("plant_measurements",id)
	return label

func _care_entry(id: String) -> Button:
	var button: Button = _action_button("Give this plant some love",func(): _open_care(id),"open_care",id)
	button.add_theme_stylebox_override("normal",_style(Color("ffe58e"),Color("c7a25d"),0,12,10))
	return button

func _open_care(id: String = "",feedback: String = "") -> void:
	CareUI.show(self,id,feedback)

func _apply_care(id: String,tool_key: String) -> void:
	var before: Dictionary = state.plant_measurements(id)
	var scroll_position: int = modal_scroll.scroll_vertical if is_instance_valid(modal_scroll) else 0
	var result: Dictionary = state.apply_care(id,tool_key)
	var message: String = str(result.get("message",""))
	if result.get("ok",false):
		var after: Dictionary = state.plant_measurements(id)
		match tool_key:
			"growth": message = "%s stretched from %s to %s cm!" % [state.get_plant(id).name,CareUI._number(float(before.height_cm)),CareUI._number(float(after.height_cm))]
			"compost": message = "%s grew from %s to %s g!" % [state.get_plant(id).name,CareUI._number(float(before.weight_g)),CareUI._number(float(after.weight_g))]
			"water": message = "A refreshing drink! %s gets one more minute of life." % state.get_plant(id).name
			"longevity": message = "Ten more minutes of growing together with %s!" % state.get_plant(id).name
			"sunlamp": message = "%s is all grown up and ready to breed!" % state.get_plant(id).name
			"ripening": message = "Fruit's ready! Time to harvest %s's fruit." % state.get_plant(id).name
		_play_sound("bloom" if tool_key in ["growth","sunlamp","ripening"] else "ui")
		_refresh()
	_open_care(id,message)
	modal_scroll.set_deferred("scroll_vertical",scroll_position)
	_toast(message)
	if result.get("ok",false): _care_sparkles()

func _care_sparkles() -> void:
	var center := Vector2(size.x*0.5,size.y*0.42)
	for index in range(9):
		var spark := CareSpark.new()
		spark.tool = "spark"
		spark.size = Vector2(24,24)
		spark.position = center
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)
		var direction := Vector2.from_angle(float(index)*TAU/9.0)
		var tw := spark.create_tween().set_parallel(true)
		tw.tween_property(spark,"position",center+direction*(75+index%3*23)-Vector2(0,45),0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark,"modulate:a",0.0,0.45).set_delay(0.2)
		tw.chain().tween_callback(spark.queue_free)

func _append_reproduction_block(target: VBoxContainer,p: Dictionary) -> void:
	target.add_child(_measurement_label(str(p.id)))
	target.add_child(_care_entry(str(p.id)))
	var offer: Button = _button("See this plant's market offer",func(): _review_market_sale("plant",str(p.id)))
	offer.set_meta("market_action","review_sale")
	offer.set_meta("item_kind","plant")
	offer.set_meta("item_ref",str(p.id))
	target.add_child(offer)
	target.add_child(_wrap("Combined lineages: %s" % _lineage_text(p),12,Color("b8c9a3")))
	target.add_child(_live_life_label(str(p.id)))
	target.add_child(_life_meter(str(p.id)))
	target.add_child(_live_fruit_label(str(p.id)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	target.add_child(row)
	row.add_child(_harvest_button(str(p.id)))
	row.add_child(_action_button("Fruit & seeds",_open_seeds,"open_nursery"))
	target.add_child(_action_button("Traits & breeding",func(): _open_dna(str(p.id)),"view_dna",str(p.id)))

func _refresh_side() -> void:
	_clear(side_content)
	if selected_id != "" and _owns_plant(selected_id):
		var p: Dictionary = state.get_plant(selected_id)
		side_content.add_child(_label("SAY HELLO TO YOUR PLANT", 10, MUTED))
		var art := Portrait.new()
		art.plant = p
		art.custom_minimum_size = Vector2(240, 228)
		side_content.add_child(art)
		side_content.add_child(_label(str(p.name), 25, INK, true))
		side_content.add_child(_button("Say hello to this plant",func(): _say_hello(str(p.id))))
		side_content.add_child(_label("%s · %s · GENERATION %d" % [p.type, p.rarity, p.generation], 11, AMBER))
		side_content.add_child(_wrap("%s tissue · %s pattern" % [_gene(p,"texture"), _gene(p,"pattern")], 13))
		_append_reproduction_block(side_content,p)
		_line(side_content)
		side_content.add_child(_wrap(_talents_text(p.get("skills",[])), 13, Color("b6c5a3")))
		side_content.add_child(_wrap("Vitality %d   Growth %d   Bloom %d" % [p.stats.vitality, p.stats.growth, p.stats.bloom], 12))
		var actions := HBoxContainer.new()
		side_content.add_child(actions)
		actions.add_child(_button("Examine", func(): _open_detail(selected_id)))
		actions.add_child(_button("Breed", func(): _breed_from(selected_id)))
		actions.add_child(_button("Move", func(): moving = true; _toast("Choose a soil cell or display slot for " + str(p.name))))
		if not p.get("mature", true): side_content.add_child(_button("Nurture · 5 light", func(): _perform_nurture(selected_id)))
		if state.display_bed.has(selected_id): side_content.add_child(_button("Lift from display bed",func(): state.remove_from_display(selected_id); selected_id = ""; _refresh()))
		side_content.add_child(_button("Return to garden notes", func(): selected_id = ""; moving = false; _refresh_side()))
	else:
		side_content.add_child(_label("LET'S GROW SOMETHING WONDERFUL", 10, MUTED))
		side_content.add_child(_label("Grow your way\nacross the stream.",25,INK,true))
		side_content.add_child(_wrap("An unusual flower waits on the far bank. Could your next plant family grow a way across?",14))
		var stream_adventure: Button=_button("Start the stream adventure →",_open_adventure)
		stream_adventure.set_meta("adventure_action","open")
		stream_adventure.add_theme_stylebox_override("normal",_style(Color("ffca92"),Color("bc8958"),0,12,12))
		side_content.add_child(stream_adventure)
		side_content.add_child(_wrap("Find four plant friends, grow two surprising siblings, and put their inherited traits to work in the landscape.",13,AMBER))
		var start_planting: Button = _button("Plant a seed →",func(): planting_page=0; _open_planting())
		start_planting.set_meta("planting_action","open")
		start_planting.add_theme_stylebox_override("normal",_style(Color("ffcf94"),Color("cb9258"),0,12,12))
		side_content.add_child(start_planting)
		side_content.add_child(_wrap("Tap an empty plot → choose a seed → Plant here. Your seedling grows automatically in 12 seconds.",13,INK))
		side_content.add_child(_button("Meet the Garden Fair visitors →",_open_fair))
		side_content.add_child(_wrap("Mira, Jun, and Pip would love to meet your plant pals. Show a plant, bring home gifts, and collect ribbons.",13,AMBER))
		side_content.add_child(_action_button("Open the tool shed",func(): _open_care(),"open_care"))
		side_content.add_child(_action_button("Visit the Sprout Market",func(): market_page=0; _open_market(),"open_market"))
		var records: Dictionary = CareUI.garden_records(self)
		if not str(records.tallest).is_empty():
			side_content.add_child(_label("YOUR GARDEN GIANTS",11,AMBER))
			side_content.add_child(_wrap("Tallest: %s · %s cm" % [state.get_plant(str(records.tallest)).name,CareUI._number(float(records.height))],13,INK))
			side_content.add_child(_wrap("Heaviest: %s · %s g" % [state.get_plant(str(records.heaviest)).name,CareUI._number(float(records.weight))],13,INK))
		else:
			side_content.add_child(_wrap("Your seeds are ready for a fresh start.",14,INK))
			side_content.add_child(_button("Choose a seed to plant",func(): _open_planting()))
		side_content.add_child(_wrap("Mix two plants → pick their fruit → plant the seeds → meet your new plant pals!",14,INK))
		var overview: Dictionary = state.fruit_overview()
		side_content.add_child(_wrap("%d ripe fruit · %d harvested fruit · %d seeds" % [overview.get("ready",0),overview.get("fruits",0),state.seed_bank.size()],13,AMBER))
		side_content.add_child(_action_button("Choose two parents →",func(): lab_mode="Crossbreed"; _open_lab(),"open_breeding"))
		side_content.add_child(_action_button("Harvest fruit & sow seeds",_open_seeds,"open_nursery"))
		_line(side_content)
		var s: Dictionary = state.display_score()
		for key in ["diversity", "harmony", "rarity"]:
			var row := HBoxContainer.new()
			side_content.add_child(row)
			row.add_child(_label(key.capitalize(), 13, MUTED))
			_spacer(row)
			row.add_child(_label("%02d" % int(s.get(key,0)), 17, Color("bdc99e"), true))
			side_content.add_child(_meter(float(s.get(key,0)) / 100.0, Color("80936a")))
		_line(side_content)
		side_content.add_child(_wrap("Next observation: %d beauty" % state.next_display_threshold() if state.next_display_threshold() > 0 else "Every display milestone recorded.",11,AMBER))
		side_content.add_child(_button("Gather display rewards", _claim_display))
		side_content.add_child(_button("Collect daily growth", _collect_daily))
		side_content.add_child(_button("Field guide",_open_guide))
		side_content.add_child(_button("Collection book",_open_codex))
		side_content.add_child(_button("Sound & language",_open_settings))
		side_content.add_child(_button("Display & resolution",_open_display_settings))
		side_content.add_child(_wrap("Tap a plant to say hello. Drag it into the grow patch, or grab a tool and help it flourish!", 12))

func _meter(value: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 3
	bar.show_percentage = false
	bar.value = value * 100
	bar.add_theme_stylebox_override("background", _style(Color("24392d"), Color.TRANSPARENT, 0, 0, 0))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 0, 0, 0))
	return bar

func _gene(p: Dictionary, key: String) -> String:
	return str(p.get("genes", {}).get(key, {}).get("dominant", "—"))

func _choose_plant(id: String, zone: String, index: int) -> void:
	_play_sound("ui")
	if selected_id != "" and moving and zone != "tray":
		_drop_plant(selected_id, zone, index)
		return
	if id == "":
		if zone=="bed": planting_page=0; _open_planting(index)
		elif zone=="display": PlantingUI.show_move_picker(self,zone,index)
		return
	if not _owns_plant(id): _open_detail(id); return
	selected_id = id
	moving = zone == "tray"
	last_log = "%s selected. %s" % [state.get_plant(id).name, "Choose a soil or display cell to plant." if moving else "Examine its genes, breed, or move it."]
	_refresh()
	if small_layout: _compact_plant(id)

func _drop_plant(id: String, zone: String, index: int) -> void:
	var ok: bool = false
	match zone:
		"bed": ok = state.place_in_bed(id, index)
		"display": ok = state.place_in_display(id, index)
		"tray": state.bench(id); ok = true
	if ok:
		_play_sound("seed")
		selected_id = ""
		moving = false
		last_log = "A new arrangement. Roots begin to find one another."
		state.save_game()
		_refresh()
	else: _toast("Withered plants remain in the archive. Sow their seeds to continue the lineage." if state.get_plant(id).get("withered",false) else "This specimen is still growing. Let it mature before planting.")

func _compact_plant(id: String) -> void:
	if not _owns_plant(id): _open_detail(id); return
	var p: Dictionary = state.get_plant(id)
	_open_modal(str(p.name), "specimen")
	modal_content.add_child(_measurement_label(id))
	modal_content.add_child(_button("Say hello to this plant",func(): _say_hello(id)))
	modal_content.add_child(_care_entry(id))
	modal_content.add_child(_wrap("%s · %s · G%d\n%s pattern · %s\nVitality %d · Growth %d · Bloom %d" % [p.type,p.rarity,p.generation,_gene(p,"pattern"),_talents_text(p.skills),p.stats.vitality,p.stats.growth,p.stats.bloom], 14, INK))
	modal_content.add_child(_live_life_label(id))
	modal_content.add_child(_live_fruit_label(id))
	var row := HBoxContainer.new()
	modal_content.add_child(row)
	row.add_child(_button("Detail", func(): _open_detail(id)))
	row.add_child(_button("Breed", func(): _breed_from(id)))
	row.add_child(_button("Move", func(): moving = true; _close_modal(); _toast("Choose a soil cell or display slot.")))
	modal_content.add_child(_action_button("Traits & breeding",func(): _open_dna(id),"view_dna",id))
	modal_content.add_child(_harvest_button(id))
	if state.display_bed.has(id): modal_content.add_child(_button("Lift from display bed",func(): state.remove_from_display(id); selected_id = ""; _close_modal(); _refresh()))

func _toast(message: String) -> void:
	toast_label.text = message
	toast_panel.visible = true
	toast_panel.move_to_front()
	toast_time = 5.5
	_responsive()

func _open_modal(title: String, kind: String = "") -> void:
	_close_modal()
	if adventuring and is_instance_valid(adventure_field): adventure_field.waiting=true
	modal_kind = kind
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.22,0.36,0.20,0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	shade.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: _close_modal())
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", _style(Color("14271f"), Color("788b66"), 12, 28, 24))
	modal.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var modal_title := _label(title, 23 if small_layout else 30, INK, true)
	modal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(modal_title)
	var close := _button("Close ×", _close_modal)
	header.add_child(close)
	close.grab_focus()
	_line(column)
	modal_scroll = ScrollContainer.new()
	modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	modal_scroll.custom_minimum_size.y = 0
	column.add_child(modal_scroll)
	modal_content = VBoxContainer.new()
	modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_content.add_theme_constant_override("separation", 15)
	modal_scroll.add_child(modal_content)
	_position_modal()
	panel.modulate.a = 0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	call_deferred("_localize_ui")

func _position_modal() -> void:
	if not is_instance_valid(modal): return
	var panel: Control = modal.get_node("Panel")
	var width: float = minf(860 if modal_kind == "wild_encounter" else 820, size.x - 28)
	var height: float = minf(820, size.y - 50)
	if modal_kind == "specimen": height = minf(470,size.y-50)
	panel.position = Vector2((size.x-width)*0.5, (size.y-height)*0.5)
	panel.size = Vector2(width, height)

func _close_modal() -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null
	modal_kind = ""
	if adventuring and is_instance_valid(adventure_field): adventure_field.waiting=false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_play_sound("back")
		if is_instance_valid(modal): _close_modal()
		else:
			selected_id = ""
			moving = false
			_refresh_side()
		get_viewport().set_input_as_handled()

func _inspection_plant(id: String) -> Dictionary:
	var owned: Dictionary = state.get_plant(id)
	if not owned.is_empty(): return owned
	var active: Dictionary = state.expedition.get("active_encounter",{})
	if str(active.get("plant",{}).get("id",""))==id: return active.plant
	for seed: Dictionary in state.seed_bank:
		var genome: Dictionary = seed.get("genome",{})
		if str(genome.get("id",""))==id: return genome
	return {}

func _open_dna(id: String) -> void:
	GeneticsUI.show_traits(self,id)

func _open_dna_compare(id: String,mate_id: String = "",goal_key: String = "pattern",goal_value: Variant = null) -> void:
	GeneticsUI.show_cross(self,id,mate_id,goal_key,goal_value)

func _use_dna_pair(id: String,mate_id: String) -> void:
	var a: Dictionary = state.get_plant(id)
	var b: Dictionary = state.get_plant(mate_id)
	if not _owns_plant(id) or not _owns_plant(mate_id) or a.is_empty() or b.is_empty() or id==mate_id or not a.get("mature",false) or not b.get("mature",false) or a.get("withered",false) or b.get("withered",false):
		_toast("Choose two living, mature plants for this cross.")
		return
	parent_a = id
	parent_b = mate_id
	lab_mode = "Crossbreed"
	_open_lab()

func _open_detail(id: String) -> void:
	var p: Dictionary = _inspection_plant(id)
	if p.is_empty(): return
	_open_modal(str(p.name), "detail")
	var top: BoxContainer = VBoxContainer.new() if small_layout else HBoxContainer.new()
	modal_content.add_child(top)
	var art := Portrait.new()
	art.plant = p
	art.custom_minimum_size = Vector2(180 if small_layout else 270, 260 if small_layout else 310)
	top.add_child(art)
	var bio := VBoxContainer.new()
	bio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(bio)
	bio.add_child(_label("%s / GENERATION %d" % [p.get("rarity","Common").to_upper(), p.generation], 11, AMBER))
	bio.add_child(_wrap("%s\n%s%s" % [p.species,p.type," × " + str(p.secondary_type) if p.get("secondary_type", "") != "" else ""], 17, INK))
	bio.add_child(_wrap(_talents_text(p.get("skills",[])), 13, Color("b5caa3")))
	bio.add_child(_wrap("Mature specimen" if p.get("mature",true) else "Unfurling · mature in a few moments", 12))
	if p.get("sold",false): bio.add_child(_wrap("This plant has a new home. Its family history stays in your archive.",13,AMBER))
	if p.get("origin",{}).get("kind","") == "wild":
		bio.add_child(_wrap("Wild-collected in %s\nField patch %s" % [p.origin.get("biome","the wilds"),p.origin.get("site","unknown")],12,AMBER))
		var origin_habitat: Dictionary=Habitat.patch(str(p.origin.get("biome","Mosswood")),str(p.origin.get("site","")))
		bio.add_child(_wrap(str(p.origin.get("habitat",origin_habitat.get("name",""))),14,INK))
	modal_content.add_child(_button("Where this family grows →",func(): _open_plant_habitats(id)))
	if _owns_plant(id):
		var rename := LineEdit.new()
		rename.text = p.name
		rename.placeholder_text = "Name this plant"
		rename.max_length = 30
		bio.add_child(rename)
		bio.add_child(_button("Save name", func(): state.rename_plant(id,rename.text); _refresh(); _open_detail(id)))
		bio.add_child(_button("Unpin favorite" if p.get("favorite",false) else "Keep as favorite", func(): state.toggle_favorite(id); _refresh(); _open_detail(id)))
		bio.add_child(_button("Choose as parent", func(): _breed_from(id)))
	if _owns_plant(id): _append_reproduction_block(modal_content,p)
	else: modal_content.add_child(_action_button("Traits & breeding",func(): _open_dna(id),"view_dna",id))
	_line(modal_content)
	modal_content.add_child(_label("THE EXPRESSED GENOME", 11, AMBER))
	modal_content.add_child(_wrap("Each column is inherited independently. Carried genes can reappear in a later generation.", 12))
	var genes := GridContainer.new()
	genes.columns = 3
	genes.add_theme_constant_override("h_separation", 25)
	genes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_content.add_child(genes)
	for head in ["TRAIT", "SHOWN", "HIDDEN COPY"]: genes.add_child(_label(head, 10, MUTED))
	for key in p.get("genes", {}):
		var gene: Dictionary = p.genes[key]
		genes.add_child(_label(str(key).capitalize(), 12, MUTED))
		genes.add_child(_label(Guide.trait_value(str(key),gene.get("dominant","—")), 12, INK))
		genes.add_child(_label(Guide.trait_value(str(key),gene.get("recessive","—")), 12, Color("a2b69a")))
	_line(modal_content)
	modal_content.add_child(_label("VITAL SIGNS", 11, AMBER))
	var stats_row := GridContainer.new()
	stats_row.columns = 3
	modal_content.add_child(stats_row)
	for key in p.get("stats", {}):
		stats_row.add_child(_label("%s  %d" % [str(key).capitalize(), int(p.stats[key])], 13))
	_line(modal_content)
	modal_content.add_child(_label("THE LINEAGE / THREE GENERATIONS", 11, AMBER))
	_append_ancestry(p, 0, p.get("pedigree",{}))
	modal_content.add_child(_label("DESCENDANTS", 10, MUTED))
	_append_descendants(id, 0)
	if p.get("graft_history",[]).size() > 0:
		modal_content.add_child(_label("GRAFT RECORD", 11, AMBER))
		for record in p.graft_history: modal_content.add_child(_wrap(_history_note(record,"graft"), 12))
	if p.get("graft_attempts",[]).size() > 0:
		modal_content.add_child(_label("REJECTED JOINS",11,AMBER))
		for record in p.graft_attempts: modal_content.add_child(_wrap(_history_note(record,"rejected"),12))
	if p.get("mutation_history",[]).size() > 0:
		modal_content.add_child(_label("MUTATION RECORD", 11, AMBER))
		for record in p.mutation_history: modal_content.add_child(_wrap(_history_note(record,"mutation"), 12))

func _append_ancestry(p: Dictionary, depth: int, pedigree: Dictionary = {}) -> void:
	if depth > 3: return
	var indent: String = "    ".repeat(depth)
	modal_content.add_child(_label("%s%s%s · G%d · %s" % [indent,"↳ " if depth > 0 else "",p.get("name","Unknown ancestor"),p.get("generation",1),_gene(p,"pattern")], 13, INK if depth == 0 else MUTED))
	for parent in p.get("parents",[]):
		var ancestor: Dictionary = state.get_plant(str(parent))
		if ancestor.is_empty(): ancestor = pedigree.get(str(parent),{})
		if not ancestor.is_empty(): _append_ancestry(ancestor, depth + 1, pedigree)
	if depth == 0 and p.get("parents",[]).is_empty(): modal_content.add_child(_label("    Founding specimen · wild-collected lineage", 12, MUTED))

func _append_descendants(id: String, depth: int) -> void:
	if depth >= 3: return
	var found: bool = false
	for child_id in state.plants:
		var child: Dictionary = state.plants[child_id]
		if id in child.get("parents",[]):
			found = true
			modal_content.add_child(_label("%s↳ %s · G%d · %s" % ["    ".repeat(depth),child.name,child.generation,_gene(child,"pattern")], 12, MUTED))
			_append_descendants(str(child_id), depth + 1)
	if depth == 0 and not found: modal_content.add_child(_label("A lineage waiting to unfold.", 12, MUTED))

func _breed_from(id: String) -> void:
	if not _owns_plant(id):
		_toast("This plant has a new home. Its family history stays in your archive.")
		return
	if exploring: _return_from_wilderness()
	var selected: Dictionary = state.get_plant(id)
	if selected.get("withered",false):
		_toast("This plant has naturally withered. Grow its seeds to continue the lineage.")
		return
	if not selected.get("mature",false):
		_toast("Let this seedling mature before using it as a parent.")
		return
	parent_a = id
	if parent_b == id: parent_b = ""
	lab_mode = "Crossbreed"
	_open_lab()

func _open_lab() -> void:
	var mature: Array = []
	for id in state.plant_order:
		if state.get_plant(str(id)).get("mature",false) and not state.get_plant(str(id)).get("withered",false): mature.append(str(id))
	if mature.is_empty():
		_toast("Raise a seedling or collect a living plant before choosing mature parents. Archived plants keep their traits in seeds.")
		return
	if parent_a == "" or not mature.has(parent_a): parent_a = str(mature[0])
	if parent_b == "" or not mature.has(parent_b):
		for id in mature:
			if id != parent_a: parent_b = str(id); break
	_open_modal("The propagation laboratory", "lab")
	modal_content.add_child(_wrap("Any two mature plants can cross. Hybrids can cross with other hybrids, wild plants, or either founding lineage. There is no species pairing lock.",14))
	modal_content.add_child(_wrap("Light %d · Grafting material %d · Mutation agents %d" % [state.resources.sunlight,state.resources.grafts,state.resources.agents],11,AMBER))
	var tabs := HBoxContainer.new()
	modal_content.add_child(tabs)
	for mode in ["Crossbreed","Graft","Mutate"]:
		var b := _button(mode, func(): lab_mode = mode; _open_lab())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if mode == lab_mode: b.add_theme_color_override("font_color", AMBER)
		tabs.add_child(b)
	var parents: BoxContainer = VBoxContainer.new() if small_layout else HBoxContainer.new()
	modal_content.add_child(parents)
	for which in range(2 if lab_mode != "Mutate" else 1):
		var parent_id: String = parent_a if which == 0 else parent_b
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parents.add_child(column)
		var slot_label: String = ("HOST" if lab_mode == "Graft" else "MOTHER / FRUIT BEARER") if which==0 else ("DONOR" if lab_mode == "Graft" else "FATHER / POLLEN")
		var choose_slot: Button = _button(slot_label,func(): active_parent_slot=which; _open_lab())
		choose_slot.add_theme_font_size_override("font_size",10)
		choose_slot.set_meta("parent_slot",which)
		choose_slot.set_meta("reproduction_action","select_parent_slot")
		if active_parent_slot==which: choose_slot.add_theme_color_override("font_color",AMBER)
		column.add_child(choose_slot)
		var portrait := Cell.new()
		portrait.plant = state.get_plant(parent_id)
		portrait.zone = "parent"
		portrait.index = which
		portrait.custom_minimum_size = Vector2(100, 150 if small_layout else 190)
		portrait.dropped.connect(func(id,_zone,slot_index):
			if slot_index == 0: parent_a = id
			else: parent_b = id
			_open_lab())
		column.add_child(portrait)
		var pick := OptionButton.new()
		pick.clip_text = true
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id in mature:
			var p: Dictionary = state.get_plant(str(id))
			pick.add_item("%s · %s · G%d" % [p.name,p.type,p.generation])
			pick.set_item_metadata(pick.item_count-1, id)
			if id == parent_id: pick.select(pick.item_count-1)
		column.add_child(pick)
		pick.set_meta("parent_slot",which)
		if which == 0: lab_pick_a = pick
		else: lab_pick_b = pick
		pick.item_selected.connect(func(i):
			if which == 0: parent_a = str(pick.get_item_metadata(i))
			else: parent_b = str(pick.get_item_metadata(i))
			_open_lab())
		var specimen: Dictionary = state.get_plant(parent_id)
		if not specimen.is_empty():
			column.add_child(_wrap("G%d · %s" % [specimen.generation,_lineage_text(specimen)],11,AMBER))
			column.add_child(_action_button("Traits & breeding",func(): _open_dna(parent_id),"view_dna",parent_id))
		# A portrait is also a drag target for choosing a parent from the garden.
	var specimen_scroll := ScrollContainer.new()
	specimen_scroll.custom_minimum_size.y = 118
	specimen_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_content.add_child(_label("DRAG A SPECIMEN INTO A PARENT SLOT, OR USE THE SELECTORS",9,MUTED))
	modal_content.add_child(specimen_scroll)
	var candidates := HBoxContainer.new()
	specimen_scroll.add_child(candidates)
	for candidate_id in mature:
		var candidate := Cell.new()
		candidate.plant = state.get_plant(candidate_id)
		candidate.zone = "candidate"
		candidate.custom_minimum_size = Vector2(112,110)
		candidate.chosen.connect(func(id,_zone,_index):
			if active_parent_slot==0: parent_a = id
			else: parent_b = id
			active_parent_slot = 1-active_parent_slot
			_open_lab())
		candidates.add_child(candidate)
	var a: Dictionary = state.get_plant(parent_a)
	var b: Dictionary = state.get_plant(parent_b)
	_line(modal_content)
	match lab_mode:
		"Crossbreed":
			modal_content.add_child(_label("RECOMBINATION / POSSIBLE INHERITANCE", 11, AMBER))
			modal_content.add_child(_wrap("%s × %s → generation %d\nColor, pattern, shape, size, and skills recombine independently. Each locus carries an expressed allele and a hidden allele.\nBoth lineages remain in the descendants and can recombine again." % [a.get("name","?"),b.get("name","?"),maxi(int(a.get("generation",1)),int(b.get("generation",1)))+1],14,INK))
			modal_content.add_child(_wrap("Pollinate → fruit ripens in %d seconds → harvest → extract 2 seeds → sow → mature in %d seconds → cross again. Both parents are kept." % [State.FRUIT_GROW_SECONDS,State.GROW_SECONDS],13,Color("b8c9a3")))
			modal_content.add_child(_wrap("Preview their offspring to compare colors, hidden traits, abilities, and the chance of getting the trait you want.",12,MUTED))
			var preview: Button = _action_button("Preview offspring traits",func(): _open_dna_compare(parent_a,parent_b),"dna_compare",parent_a)
			preview.disabled = a.is_empty() or b.is_empty() or parent_a==parent_b
			modal_content.add_child(preview)
			var pollinate: Button = _lab_action("Pollinate & grow fruit · %d light" % State.POLLINATION_COST,_crossbreed,"Harvested hybrid fruit gives 2 seeds and 30 light. Plant each seed for 10 light; the breeding cycle can sustain itself.")
			pollinate.set_meta("reproduction_action","pollinate")
			pollinate.set_meta("parent_a",parent_a)
			pollinate.set_meta("parent_b",parent_b)
			pollinate.disabled = a.is_empty() or b.is_empty() or parent_a==parent_b or int(state.resources.sunlight)<State.POLLINATION_COST or not state.fruit_status(parent_a).get("pollination",{}).is_empty()
			if parent_a==parent_b: modal_content.add_child(_wrap("Choose two different plants. Every species and hybrid combination is allowed.",12,AMBER))
			elif not state.fruit_status(parent_a).get("pollination",{}).is_empty():
				modal_content.add_child(_live_fruit_label(parent_a))
				modal_content.add_child(_action_button("Open fruit & seeds",_open_seeds,"open_nursery"))
		"Graft":
			var odds: int = roundi(state.graft_odds(parent_a,parent_b)*100)
			modal_content.add_child(_label("A PRECISE, IMPERFECT JOIN", 11, AMBER))
			modal_content.add_child(_wrap("%d%% success · %d%% rejection for this exact graft.\nAt most two grafts per host. The donor rests on a long cooldown; the host is unharmed on failure. Favorites cannot be used as donors.\nA seam and donor-colored tissue remain part of the organism." % [odds,100-odds], 14, INK))
			action_picker = OptionButton.new()
			for trait_name in ["feature","skill","stat"]: action_picker.add_item(trait_name.capitalize()); action_picker.set_item_metadata(action_picker.item_count-1, trait_name)
			modal_content.add_child(action_picker)
			var graft_button: Button = _lab_action("Attempt graft · 1 grafting material",_graft,"%d%% success / %d%% rejection · Host unharmed · Donor rests · Material spent either way" % [odds,100-odds])
			graft_button.set_meta("reproduction_action","graft")
		"Mutate":
			modal_content.add_child(_label("LET THE GENOME WANDER", 11, AMBER))
			modal_content.add_child(_wrap("70% new trait · 20% no change · 10% visible deformity.\nRadiation: broad change; an 8% carnivorous reversion chance within the new-trait outcome (5.6% overall).\nChemical: rerolls the pattern slot. An agent is consumed in every outcome. Mutation is permanent and inheritable.", 14, INK))
			action_picker = OptionButton.new()
			action_picker.add_item("Radiation · broad mutation")
			action_picker.add_item("Chemical · pattern-focused")
			modal_content.add_child(action_picker)
			_lab_action("Apply mutation · 1 agent",_mutate,"70% changed / 20% unchanged / 10% deformity · Radiation: 5.6% overall carnivorous reversion")
	lab_result = _wrap("Every experiment writes a permanent entry in the lineage.", 12)
	modal_content.add_child(lab_result)

func _lab_action(text: String, action: Callable, odds: String) -> Button:
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	modal.get_node("Panel").get_child(0).add_child(footer)
	footer.add_child(_wrap(odds,11,AMBER))
	var button: Button = _button(text,action,Vector2(0,48))
	footer.add_child(button)
	return button

func _crossbreed() -> void:
	var result: Dictionary = state.pollinate(parent_a,parent_b)
	if result.get("ok",false):
		_play_sound("breed")
		_refresh()
		_open_modal("A new lineage is forming","pollination")
		modal_content.add_child(_wrap("%s × %s" % [state.get_plant(parent_a).name,state.get_plant(parent_b).name],23,INK))
		modal_content.add_child(_wrap(str(result.get("message","Pollination recorded.")),14,Color("b8c9a3")))
		modal_content.add_child(_live_fruit_label(parent_a,18))
		modal_content.add_child(_wrap("The mother carries the fruit. Its two seeds already contain independently recombined DNA from both parents. Harvest, extract the seeds, and plant them to meet the descendants.",14))
		modal_content.add_child(_wrap("Parents stay alive. Every descendant can become a parent in the next cross.",14,AMBER))
		modal_content.add_child(_harvest_button(parent_a))
		modal_content.add_child(_action_button("Open fruit & seeds",func(): nursery_tab="plants"; _open_seeds(),"open_nursery"))
		modal_content.add_child(_button("Plan another cross",_open_lab))
		modal_content.add_child(_button("Return to my garden",_close_modal))
	else: lab_result.text = str(result.get("message","Choose two different mature parents."))

func _graft() -> void:
	var trait_name: String = str(action_picker.get_item_metadata(action_picker.selected))
	var result: Dictionary = state.graft(parent_a, parent_b, trait_name)
	_play_sound("graft" if result.get("success",false) else "collect_fail")
	_refresh()
	_toast(str(result.get("message","The graft is recorded.")))
	_open_lab()

func _mutate() -> void:
	var result: Dictionary = state.mutate(parent_a, "radiation" if action_picker.selected == 0 else "chemical", "pattern")
	if result.get("ok",false): _play_sound("mutate")
	_refresh()
	if result.get("ok",false): _reveal(state.get_plant(parent_a), str(result.get("message","The genome shifts.")))
	else: lab_result.text = str(result.get("message","Mutation unavailable."))

func _reveal(p: Dictionary, message: String) -> void:
	if p.is_empty():
		_toast(message)
		_close_modal()
		return
	selected_id = str(p.id)
	_open_modal("Something unfamiliar unfolds", "reveal")
	modal_content.add_child(_wrap(message, 15, INK))
	var art := Portrait.new()
	art.plant = p
	art.reveal = 0
	art.custom_minimum_size = Vector2(240,300)
	modal_content.add_child(art)
	var tw := art.create_tween()
	tw.tween_property(art,"reveal",1.0,1.6).set_trans(Tween.TRANS_SINE)
	modal_content.add_child(_label(str(p.name), 32, INK, true))
	var gene_notes := _wrap("", 15, AMBER)
	modal_content.add_child(gene_notes)
	for key in ["color","pattern","shape","form"]:
		tw.tween_callback(func():
			if is_instance_valid(gene_notes):
				var raw: String = str(gene_notes.get_meta("reveal_source",""))+"%s  /  %s\n" % [str(Guide.LABELS.get(key,key.capitalize())),Guide.trait_value(key,_gene(p,key))]
				gene_notes.set_meta("reveal_source",raw)
				gene_notes.text = raw
				Locale.apply_tree(gene_notes))
		tw.tween_interval(0.35)
	var planted_cell: int = state.bed.find(str(p.id))
	modal_content.add_child(_wrap("Already planted in plot %d. It grows automatically in 12 seconds." % [planted_cell+1] if planted_cell>=0 and not p.get("mature",false) else ("Already planted in plot %d." % [planted_cell+1] if planted_cell>=0 else "This plant is on your bench. Move it into an empty plot when it has grown."),13))
	if not p.get("mature",false):
		var growing: Label = _wrap(PlantingUI.countdown(self,str(p.id)),17,AMBER)
		growing.set_meta("planting_countdown",true)
		growing.set_meta("plant_id",str(p.id))
		planting_labels.append(growing)
		modal_content.add_child(growing)
	modal_content.add_child(_wrap("Combined lineages: %s" % _lineage_text(p),13,AMBER))
	modal_content.add_child(_live_life_label(str(p.id)))
	modal_content.add_child(_action_button("Traits & breeding",func(): _open_dna(str(p.id)),"view_dna",str(p.id)))
	var next_cross: Button = _action_button("Use for the next cross",func(): _breed_from(str(p.id)),"next_cross",str(p.id))
	next_cross.disabled = not p.get("mature",false) or p.get("withered",false)
	reproduction_buttons.append(next_cross)
	modal_content.add_child(next_cross)
	if not p.get("mature",false): modal_content.add_child(_button("Nurture · 5 light",func(): _perform_nurture(str(p.id))))
	var watch: Button = _button("Watch it grow →" if not p.get("mature",false) else "Return to my garden",func(): _close_modal(); _refresh(); _focus_planted(str(p.id)))
	watch.set_meta("planting_action","watch_grow")
	modal_content.add_child(watch)
	modal_content.add_child(_button("Read the genome", func(): _open_detail(str(p.id))))

func _perform_nurture(id: String) -> void:
	var result: Dictionary = state.mature_plant(id)
	_toast(str(result.get("message","The leaves gather light.")))
	_refresh()

func _open_seeds() -> void:
	if exploring: _return_from_wilderness()
	_open_modal("Fruit & seed nursery","seeds")
	var planting: Button = _button("Plant a seed →",func(): planting_page=0; _open_planting())
	planting.set_meta("planting_action","open")
	modal_content.add_child(planting)
	var overview: Dictionary = state.fruit_overview()
	modal_content.add_child(_wrap("Pollinate → harvest fruit → extract seeds → sow → grow → cross again. Each seed preserves its own complete inherited DNA.",14))
	modal_content.add_child(_wrap("%d ripe fruit · %d harvested fruit · %d seeds" % [overview.get("ready",0),overview.get("fruits",0),state.seed_bank.size()],13,AMBER))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",6)
	modal_content.add_child(tabs)
	for tab: String in ["plants","fruits","seeds"]:
		var title: String = {"plants":"Plants","fruits":"Fruit basket","seeds":"Seeds"}[tab]
		var button: Button = _button(title,func(): nursery_tab=tab; _open_seeds())
		button.set_meta("reproduction_action","nursery_tab")
		button.set_meta("nursery_tab",tab)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		if tab==nursery_tab: button.add_theme_color_override("font_color",AMBER)
		tabs.add_child(button)
	match nursery_tab:
		"plants": _nursery_plants()
		"fruits": _nursery_fruits()
		_: _nursery_seeds()
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation",6)
	modal.get_node("Panel").get_child(0).add_child(footer)
	if nursery_tab=="plants":
		var harvest: Button = _action_button("Harvest all ripe fruit",_harvest_all_fruit,"harvest_all")
		harvest.disabled = int(overview.get("ready",0))==0
		reproduction_buttons.append(harvest)
		footer.add_child(harvest)
	elif nursery_tab=="fruits":
		var extract: Button = _action_button("Extract all seeds",_extract_all_fruit,"extract_all")
		extract.disabled = state.fruit_inventory.is_empty()
		reproduction_buttons.append(extract)
		footer.add_child(extract)
	footer.add_child(_action_button("Choose parents for the next cross",func(): lab_mode="Crossbreed"; _open_lab(),"open_breeding"))

func _nursery_card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(Color("1b3025"),Color("4a6249"),0,12,12))
	modal_content.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	return column

func _nursery_plants() -> void:
	modal_content.add_child(_wrap("Mature plants bear natural fruit every 45 seconds. A selected mother can also carry one hybrid fruit from any other mature plant.",12))
	for id: String in state.plant_order:
		var p: Dictionary = state.get_plant(id)
		var card: VBoxContainer = _nursery_card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		card.add_child(row)
		var art := Portrait.new()
		art.plant = p
		art.custom_minimum_size = Vector2(70,86)
		row.add_child(art)
		var notes := VBoxContainer.new()
		notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(notes)
		notes.add_child(_wrap(str(p.name),19,INK))
		notes.add_child(_wrap("G%d · %s" % [p.generation,_lineage_text(p)],11,MUTED))
		notes.add_child(_live_fruit_label(id))
		notes.add_child(_live_life_label(id))
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation",6)
		card.add_child(actions)
		actions.add_child(_harvest_button(id))
		actions.add_child(_action_button("Traits & breeding",func(): _open_dna(id),"view_dna",id))
		if not p.get("mature",true) and not p.get("withered",false): card.add_child(_button("Nurture · 5 light",func(): _perform_nurture(id); _open_seeds()))

func _nursery_fruits() -> void:
	if state.fruit_inventory.is_empty():
		modal_content.add_child(_wrap("Your fruit basket is empty. Harvest ripe fruit from your plants, then extract its seeds here.",14))
		return
	for index in range(state.fruit_inventory.size()-1,-1,-1):
		var fruit: Dictionary = state.fruit_inventory[index]
		var fruit_id: String = str(fruit.id)
		var names: Array = fruit.get("parent_names",[])
		var card: VBoxContainer = _nursery_card()
		card.add_child(_wrap("Hybrid fruit" if fruit.get("kind","")=="hybrid" else "Natural fruit",20,AMBER))
		card.add_child(_wrap(" × ".join(PackedStringArray(names)),17,INK))
		card.add_child(_wrap("Generation %d · %d seeds inside" % [fruit.get("generation",1),fruit.get("seeds",[]).size()],12))
		card.add_child(_wrap("The stored embryos keep both expressed and hidden alleles, their parent identities, and the complete mixed lineage.",12,MUTED))
		var extract: Button = _action_button("Extract seeds",func(): _extract_fruit(fruit_id),"extract")
		extract.set_meta("fruit_id",fruit_id)
		extract.disabled = false
		card.add_child(extract)
		var offer: Button = _button("See fruit's market offer",func(): _review_market_sale("fruit",fruit_id))
		offer.set_meta("market_action","review_sale")
		offer.set_meta("item_kind","fruit")
		offer.set_meta("item_ref",fruit_id)
		card.add_child(offer)

func _nursery_seeds() -> void:
	modal_content.add_child(_wrap("Hybrid and harvested lineage seeds preserve their exact DNA. Sowing costs 10 light; seedlings mature in 12 seconds and can cross again.",12))
	if state.seed_bank.is_empty():
		modal_content.add_child(_wrap("No seeds stored. Harvest and open a fruit to continue a lineage.",14))
		return
	const PAGE_SIZE: int = 12
	var pages: int = maxi(1,ceili(state.seed_bank.size()/float(PAGE_SIZE)))
	seed_page = clampi(seed_page,0,pages-1)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation",6)
	modal_content.add_child(navigation)
	var previous: Button = _button("Previous",func(): seed_page-=1; _open_seeds())
	previous.disabled = seed_page==0
	navigation.add_child(previous)
	var page: Label = _wrap("Page %d / %d · newest first" % [seed_page+1,pages],12,MUTED)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(page)
	var next: Button = _button("Next",func(): seed_page+=1; _open_seeds())
	next.disabled = seed_page>=pages-1
	navigation.add_child(next)
	for offset in range(seed_page*PAGE_SIZE,mini(state.seed_bank.size(),(seed_page+1)*PAGE_SIZE)):
		var seed_index: int = state.seed_bank.size()-1-offset
		var seed_data: Dictionary = state.seed_bank[seed_index]
		var genome: Dictionary = seed_data.get("genome",{})
		var card: VBoxContainer = _nursery_card()
		card.add_child(_wrap(str(seed_data.get("name",seed_data.get("species","Uncatalogued seed"))),19,INK))
		if not genome.is_empty():
			card.add_child(_wrap("G%d · %s" % [genome.get("generation",1),_lineage_text(genome)],12,AMBER))
			card.add_child(_wrap("%s pattern · %s shape · %s form" % [_gene(genome,"pattern"),_gene(genome,"shape"),_gene(genome,"form")],12))
			card.add_child(_wrap("Shows %s; carries %s as an alternative." % [Guide.trait_value("pattern",genome.genes.pattern.dominant),Guide.trait_value("pattern",genome.genes.pattern.recessive)],12,Color("b8c9a3")))
			var inspect: Button = _action_button("View inherited traits",func(): _open_dna(str(genome.id)),"view_seed_dna")
			inspect.set_meta("seed_index",seed_index)
			card.add_child(inspect)
		else:
			card.add_child(_wrap("%s · %s · %s tendency" % [seed_data.get("rarity","Common"),seed_data.get("type","Wild"),seed_data.get("pattern","Unresolved")],12))
			card.add_child(_wrap("Founding seed · a new expression of its archived lineage.",11,MUTED))
		var plant: Button = _action_button("Plant seed · 10 light",func(): _plant_saved_seed(seed_index),"plant_seed")
		plant.set_meta("seed_index",seed_index)
		plant.disabled = int(state.resources.sunlight)<10
		card.add_child(plant)
		var reference: Variant = state.market_ref("seed",seed_index)
		var offer: Button = _button("See seed's market offer",func(): _review_market_sale("seed",reference))
		offer.set_meta("market_action","review_sale")
		offer.set_meta("item_kind","seed")
		offer.set_meta("item_ref",reference)
		card.add_child(offer)

func _harvest_fruit(id: String) -> void:
	var result: Dictionary = state.harvest_fruit(id)
	_toast(str(result.get("message","No ripe fruit yet.")))
	if not result.get("ok",false): return
	_play_sound("collect_success")
	nursery_tab = "fruits"
	_refresh()
	_open_seeds()

func _harvest_all_fruit() -> void:
	var result: Dictionary = state.harvest_all_fruit()
	_toast(str(result.get("message","No ripe fruit yet.")))
	if result.get("ok",false): _play_sound("collect_success")
	nursery_tab = "fruits" if not state.fruit_inventory.is_empty() else "plants"
	_refresh()
	_open_seeds()

func _extract_fruit(fruit_id: String) -> void:
	var result: Dictionary = state.extract_seeds(fruit_id)
	_toast(str(result.get("message","No seeds to extract.")))
	if result.get("ok",false): _play_sound("seed")
	nursery_tab = "seeds"
	seed_page = 0
	_refresh()
	_open_seeds()

func _extract_all_fruit() -> void:
	var result: Dictionary = state.extract_all_seeds()
	_toast(str(result.get("message","No seeds to extract.")))
	if result.get("ok",false): _play_sound("seed")
	nursery_tab = "seeds"
	seed_page = 0
	_refresh()
	_open_seeds()

func _plant_saved_seed(index: int) -> void:
	var result: Dictionary = state.plant_seed(index)
	if result.get("ok",false): _play_sound("seed"); _refresh(); _reveal(result.get("plant",{}),str(result.get("message","A seed opens.")))
	else: _toast(str(result.get("message","Not enough gathered light.")))

func _open_codex() -> void:
	_open_modal("An atlas of living things", "codex")
	modal_content.add_child(_wrap("Seven founding lineages. Countless possible descendants. The silhouettes are things you have yet to meet.", 14))
	var progress: Dictionary = state.collection_progress()
	modal_content.add_child(_wrap("Complete a species page with three patterns. Discover all six patterns or all seven founding lineages for archive rewards. Discoveries stay recorded after mutation.",12))
	modal_content.add_child(_button("Gather collection rewards · %d ready" % int(progress.unclaimed), _claim_collection))
	modal_content.add_child(_wrap("Atlas %d / 7   ·   Pattern family %d / 6" % [progress.species_count,progress.pattern_count],12,AMBER))
	var found: Dictionary = {}
	var patterns: Dictionary = {}
	var colors: Dictionary = {}
	for id in state.plants:
		var p: Dictionary = state.plants[id]
		found[str(p.species)] = int(found.get(str(p.species),0)) + 1
		patterns[_gene(p,"pattern")] = true
		colors[_gene(p,"color")] = true
	modal_content.add_child(_wrap("%d / 7 LINEAGES    ·    %d PATTERNS    ·    %d PIGMENTS" % [mini(7,state.discovered.size()),patterns.size(),colors.size()], 11, AMBER))
	for species in State.SPECIES:
		var discovered: bool = state.discovered.has(str(species.name))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color("192e24"), Color("3d5540"), 5, 12, 12))
		modal_content.add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var art := Portrait.new()
		art.plant = {"type":species.type,"seed": abs(str(species.name).hash()),"genes":{"color":{"dominant":species.color},"accent":{"dominant":species.accent}}}
		art.silhouette = not discovered
		art.custom_minimum_size = Vector2(100,100)
		row.add_child(art)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var species_title := _label(str(species.name) if discovered else "Uncatalogued organism", 20 if small_layout else 23, INK if discovered else MUTED, true)
		species_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(species_title)
		info.add_child(_wrap("%s · %s" % [species.type,species.description] if discovered else "A silhouette beyond the edge of the tended bed.", 13))
		if discovered:
			info.add_child(_wrap("%d specimens recorded · %s" % [int(found.get(str(species.name),0)),species.skill], 11, AMBER))
			for page in progress.species_pages:
				if str(page.name) == str(species.name): info.add_child(_wrap("Pattern study %d / %d%s" % [mini(int(page.patterns),int(page.total)),page.total," · collected" if page.claimed else (" · complete" if page.complete else "")],11,MUTED))
	modal_content.add_child(_label("A LINEAGE OUTSIDE THE ATLAS", 11, AMBER))
	modal_content.add_child(_wrap("Carnivorous forms are never starting specimens. Seek them through patient crosses or radiation. A trap is a leaf that learned another way to live.", 14))

func _open_display_notes() -> void:
	_open_modal("An ecology worth observing", "display")
	var score: Dictionary = state.display_score()
	modal_content.add_child(_label("%d / BEAUTY" % int(score.total),36,AMBER,true))
	modal_content.add_child(_wrap("Pick six grown plants for your show-off shelf. Mix colors and shapes, collect beauty rewards, and keep breeding your favorites.",14))
	for key in ["diversity","harmony","rarity"]:
		modal_content.add_child(_label("%s / %d" % [str(key).capitalize(),int(score.get(key,0))],23,INK,true))
		var explanation: String = "Distinct types, species, patterns and pigments."
		if key == "harmony": explanation = "Shared muted pigments and repeated tissue markings."
		if key == "rarity": explanation = "Rare patterns, advanced lineages and unusual forms."
		modal_content.add_child(_wrap(explanation,13))
	_line(modal_content)
	modal_content.add_child(_wrap("Each beauty threshold grants 30 light, an agent, a grafting material and a seed. Thresholds: 100, 180, 260, 340, 420 and 500.",13))
	modal_content.add_child(_wrap("Next observation at %d beauty." % state.next_display_threshold() if state.next_display_threshold()>0 else "Every beauty milestone has been recorded.",14,AMBER))
	modal_content.add_child(_button("Gather display rewards",_claim_display))
	modal_content.add_child(_button("Collect daily growth",_collect_daily))

func _claim_collection() -> void:
	var result: Dictionary = state.claim_collection()
	_toast(str(result.get("message","The atlas is observed.")))
	_refresh()
	_open_codex()

func _claim_display() -> void:
	var result: Dictionary = state.claim_display()
	_toast(str(result.get("message","The garden is observed.")))
	_refresh()

func _collect_daily() -> void:
	var result: Dictionary = state.collect_daily()
	_toast(str(result.get("message","The garden gathers light.")))
	_refresh()

func _open_guide() -> void:
	_open_modal("Your little garden adventure","guide")
	for entry: Array in [
		["Grow your next adventure","Visit the stream, meet four unusual plants, and cross their real inherited traits. Grow a floating leaf raft or a climbing vine bridge, then meet Moonbell and discover a glowing third generation."],
		["Plant a little wonder","Tap an empty plot, choose a seed, and press Plant here. It costs 10 light and grows automatically in 12 seconds. Your new plant gets its own look, height, weight, and family story."],
		["Meet the fair visitors","Mira, Jun, and Pip bring three friendly requests each day. Pick a matching grown plant and show it to earn gifts. You keep the plant! Collect permanent ribbons for your growing milestones."],
		["Make a new plant family","Choose two grown plants in Crossbreeding. Pollinate for 10 light, wait for their fruit, harvest it, take out the seeds, then plant them. Mix their children again for more surprises. Traits & breeding shows what can be inherited."],
		["Head out on a plant safari","Explore the wilds to find new colors, shapes, and plant families. Study a wild plant, take a cutting, and bring your new friend home. Your growing collection unlocks ribbons and new breeding ideas."],
		["A little care goes a long way","Water for a little extra life, add stretch feed for height, or try chunky compost for a fuller plant. Pin favorites, say hello, and find out which plant becomes your garden giant."],
		["Share your harvest","Show off six plants on the display shelf for beauty gifts. Trade spare plants, fruit, or seeds at the market, then buy supplies for your next adventure. Harvest fruit to keep planting and caring."],
		["Keep the family growing","Plants have a life cycle. Life tonic gives favorites more time; seeds carry their family story into a new generation. Plants rest while the game is closed or in the background."]
	]:
		modal_content.add_child(_wrap(str(entry[0]),19,AMBER))
		modal_content.add_child(_wrap(str(entry[1]),14,INK))
		_line(modal_content)
	modal_content.add_child(_button("Plant a seed →",func(): _open_planting()))
	AdventureUI.action(self,"Start the stream adventure →",_open_adventure,"open",modal_content)
	modal_content.add_child(_button("Meet the fair visitors →",_open_fair))

func _process(delta: float) -> void:
	locale_timer += delta
	if locale_timer >= 0.2:
		locale_timer = 0.0
		_localize_ui()
	if exploring and wild_encounter_open and not is_instance_valid(modal):
		state.leave_wild_encounter()
		wild_encounter_open = false
		if is_instance_valid(wilderness): wilderness.encounter_closed(); wilderness.refresh()
	if is_instance_valid(modal): _position_modal()
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0: toast_panel.visible = false
	save_timer += delta
	if save_timer >= 1.0:
		var active_seconds: float = save_timer
		save_timer = 0
		var grew: bool = state.tick_growth()
		# A plant's active-play clock rests when the game is in the background.
		# Fruit and seedling timers still use wall time, as before.
		var playing: bool = DisplayServer.get_name()=="headless" or get_window().has_focus()
		var life_changed: bool = state.advance_lifecycle(active_seconds if playing else 0.0)
		var fruit_changed: bool = state.tick_reproduction()
		life_save_timer += active_seconds
		if life_changed or life_save_timer>=10.0:
			life_save_timer = 0.0
			state.save_game()
		if grew:
			last_log = "A new specimen has unfurled. Its first mature leaves gather light."
		if grew or life_changed or fruit_changed: _refresh()
		else: _refresh_reproduction_counters()
		if adventuring:
			if is_instance_valid(adventure_field): adventure_field.refresh()
			AdventureUI.tick(self)

# Field expeditions stay in the same persistent game: collected genes enter the
# garden archive immediately, and returning home never regenerates the beds.
func _open_adventure() -> void:
	if exploring: _return_from_wilderness()
	_close_modal()
	adventuring=true
	ui_margin.visible=false
	if not is_instance_valid(adventure_field):
		adventure_field=load("res://scripts/adventure_field.gd").new()
		adventure_field.state=state
		adventure_field.action_requested.connect(_adventure_action)
		adventure_field.returned_home.connect(_return_from_adventure)
		add_child(adventure_field)
		adventure_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	adventure_field.visible=true
	adventure_field.process_mode=Node.PROCESS_MODE_INHERIT
	adventure_field.waiting=false
	adventure_field.refresh()
	adventure_field.move_to_front()
	adventure_field.grab_focus()
	if is_instance_valid(soundscape): soundscape.set_context("wild","Mosswood")
	_localize_ui()

func _return_from_adventure() -> void:
	_close_modal()
	adventuring=false
	if is_instance_valid(adventure_field):
		adventure_field.waiting=false
		adventure_field.visible=false
		adventure_field.process_mode=Node.PROCESS_MODE_DISABLED
	ui_margin.visible=true
	if is_instance_valid(soundscape): soundscape.set_context("garden")
	state.save_game()
	_refresh()
	_localize_ui()

func _adventure_back_to_field() -> void:
	_close_modal()
	if is_instance_valid(adventure_field):
		adventure_field.waiting=false
		adventure_field.refresh()
		adventure_field.grab_focus()

func _adventure_action(action: String,key: String="") -> void:
	match action:
		"inspect_parent","moonbell": _show_adventure_parent(key if not key.is_empty() else "moonbell")
		"cross":
			var info: Dictionary=state.adventure_info()
			var siblings: Array=info.get("siblings",[])
			var generation: int=0
			for id: String in siblings: generation=maxi(generation,int(state.get_plant(id).get("generation",0)))
			if key!="bench" and not siblings.is_empty() and (str(info.stage)=="shore" or (str(info.stage)=="lantern" and generation>=3)):
				_show_adventure_reveal(siblings)
			else: _show_adventure_cross()
		"crossing":
			if not str(state.adventure_info().get("route","")).is_empty(): _adventure_test_route("stream")
			else: _show_adventure_use("stream")
		"gate":
			if str(state.adventure_info().get("stage",""))=="restored": _adventure_test_route("lantern")
			else: _show_adventure_use("lantern")
		"journal": AdventureUI.journal(self)
		"garden","home": _return_from_adventure()

func _show_adventure_parent(key: String) -> void:
	AdventureUI.parent(self,key)

func _show_adventure_cross(a: String="",b: String="") -> void:
	AdventureUI.cross(self,a,b)

func _show_adventure_use(goal: String="stream",id: String="") -> void:
	AdventureUI.use(self,goal,id)

func _show_adventure_reveal(ids: Array) -> void:
	AdventureUI.reveal(self,ids)

func _adventure_collect(key: String) -> void:
	var result: Dictionary=state.adventure_collect(key)
	_toast(str(result.get("message","")))
	if result.get("ok",false):
		_play_sound("collect_success")
		_refresh()
		if is_instance_valid(adventure_field): adventure_field.refresh()
	_show_adventure_parent(key)

func _adventure_suggest_pair(first: String,second: String) -> void:
	var cuttings: Dictionary=state.adventure_info().get("cuttings",{})
	for key: String in [first,second]:
		var id: String=str(cuttings.get(key,""))
		if not state.owns_plant(id) or state.get_plant(id).get("withered",false):
			_show_adventure_parent(key)
			return
	_show_adventure_cross(str(cuttings[first]),str(cuttings[second]))

func _adventure_pollinate(a: String,b: String) -> void:
	var result: Dictionary=state.adventure_begin_cross(a,b)
	_toast(str(result.get("message","")))
	if result.get("ok",false): _play_sound("breed"); _refresh()
	_show_adventure_cross(a,b)

func _adventure_sow(mother_id: String) -> void:
	var result: Dictionary=state.adventure_siblings(mother_id)
	_toast(str(result.get("message","")))
	if not result.get("ok",false): return
	_play_sound("seed")
	_refresh()
	_show_adventure_reveal(result.get("plant_ids",[]))

func _adventure_apply(id: String,goal: String="stream",route: String="") -> void:
	var result: Dictionary=state.adventure_use(id,goal,route)
	if not result.get("ok",false):
		_toast(str(result.get("message","")))
		_show_adventure_use(goal,id)
		return
	_play_sound("bloom")
	if is_instance_valid(adventure_field): adventure_field.refresh()
	AdventureUI.success(self,result,goal)

func _adventure_test_route(goal: String="stream") -> void:
	_adventure_back_to_field()
	if not is_instance_valid(adventure_field): return
	var destination:=Vector2(1180,420) if goal=="lantern" else (Vector2(820,420) if adventure_field.player_position.x<650 else Vector2(520,420))
	adventure_field.walk_to(destination)

func _adventure_name(id: String,plant_name: String) -> void:
	if not state.owns_plant(id): return
	state.rename_plant(id,plant_name)
	_refresh()
	if is_instance_valid(adventure_field): adventure_field.refresh()
	_toast("A new name for your growing story.")

func _open_wilderness() -> void:
	if adventuring: _return_from_adventure()
	_close_modal()
	state.begin_expedition()
	exploring = true
	ui_margin.visible = false
	if not is_instance_valid(wilderness):
		wilderness = load("res://scripts/wilderness.gd").new()
		wilderness.state = state
		wilderness.returned_home.connect(_return_from_wilderness)
		wilderness.encounter_requested.connect(_begin_wild_encounter)
		wilderness.supplies_requested.connect(_open_field_supplies)
		wilderness.display_requested.connect(_open_settings)
		wilderness.sfx_requested.connect(_play_sound)
		wilderness.position_changed.connect(_field_audio_position)
		add_child(wilderness)
		wilderness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wilderness.visible = true
	wilderness.process_mode = Node.PROCESS_MODE_INHERIT
	wilderness.refresh()
	wilderness.move_to_front()
	_field_audio_position()
	if is_instance_valid(soundscape): soundscape.set_context("wild",wilderness.biome_at(wilderness.player_tile))
	if not state.expedition.active_encounter.is_empty():
		wild_encounter_open = true
		_show_wild_encounter("You return to the same wild organism. Its rhythm is familiar.")

func _return_from_wilderness() -> void:
	_close_modal()
	if is_instance_valid(soundscape): soundscape.set_context("garden")
	_play_sound("back")
	state.leave_wild_encounter()
	wild_encounter_open = false
	exploring = false
	if is_instance_valid(wilderness):
		wilderness.encounter_closed()
		wilderness.visible = false
		wilderness.process_mode = Node.PROCESS_MODE_DISABLED
	ui_margin.visible = true
	last_log = "Back home. %d wild specimens found their way into your living collection." % int(state.expedition.get("captures",0))
	state.save_game()
	_refresh()
	explore_button.grab_focus()

func _begin_wild_encounter(biome: String, site_id: String) -> void:
	var result: Dictionary = state.wild_encounter(biome,site_id)
	if not result.get("ok",false):
		_toast(str(result.get("message","This patch is resting.")))
		wilderness.encounter_closed()
		return
	wild_encounter_open = true
	_play_sound("encounter")
	_show_wild_encounter(str(result.message))

func _open_plant_habitats(id: String) -> void:
	var p: Dictionary=_inspection_plant(id)
	if p.is_empty(): return
	var from_encounter: bool=not state.expedition.get("active_encounter",{}).is_empty()
	if is_instance_valid(wilderness): wilderness.waiting=true
	_open_modal("Where this family grows","habitat_guide")
	modal.set_meta("plant_id",id)
	modal_content.add_child(_wrap("Follow the landscape, find a new plant friend.",21,INK))
	modal_content.add_child(_wrap("Different plant families favor different growing spots. The trail leads to a suitable patch; every wild individual still has its own DNA.",13,MUTED))
	var families: Array[String]=[str(p.get("type","Leaf"))]
	for family: String in p.get("lineage_mix",{}):
		if not families.has(family) and float(p.lineage_mix[family])>=0.1: families.append(family)
	var shown: Dictionary={}
	var cards: int=0
	for family: String in families:
		var choices: Array[Dictionary]=Habitat.preferred_habitats(family)
		for info: Dictionary in choices:
			if not bool(info.get("primary",false)) and not bool(info.get("rare",false)): continue
			var key: String=str(info.biome)+"/"+str(info.get("habitat_key",""))
			if shown.has(key): continue
			shown[key]=true
			var panel:=PanelContainer.new()
			panel.add_theme_stylebox_override("panel",_style(Color("f3efd9"),Color("9ba886"),0,12,12))
			modal_content.add_child(panel)
			var body:=VBoxContainer.new()
			body.add_theme_constant_override("separation",8)
			panel.add_child(body)
			if cards<3:
				var scene:=HabitatScene.new()
				scene.biome=str(info.biome)
				scene.custom_minimum_size=Vector2(0,100 if small_layout else 145)
				body.add_child(scene)
			body.add_child(_wrap("%s · %s" % [str(info.biome),family],16,AMBER))
			body.add_child(_wrap(str(info.habitat),18,INK))
			body.add_child(_wrap(str(info.clue),13,MUTED))
			var biome_name: String=str(info.biome)
			var habitat_key: String=str(info.get("habitat_key",""))
			var route:=_button("Follow this trail →",func(): _follow_habitat_trail(biome_name,habitat_key))
			route.set_meta("habitat_action","route")
			route.set_meta("biome",biome_name)
			route.set_meta("habitat_key",habitat_key)
			body.add_child(route)
			cards+=1
			if cards>=8: break
		if cards>=8: break
	if from_encounter: modal_content.add_child(_button("Back to the wild plant",func(): _show_wild_encounter()))
	elif exploring: modal_content.add_child(_button("Back to the trail",_continue_exploring))
	else: modal_content.add_child(_button("Back to this plant",func(): _open_detail(id)))

func _follow_habitat_trail(biome: String,habitat_key: String) -> void:
	state.leave_wild_encounter()
	wild_encounter_open=false
	_open_wilderness()
	wilderness.encounter_closed()
	var target: Dictionary={}
	var best: int=100000
	for site: Dictionary in wilderness.SITES:
		if str(site.biome)!=biome or wilderness._site_unavailable(str(site.id)): continue
		if not habitat_key.is_empty() and str(Habitat.patch(biome,str(site.id)).get("id",""))!=habitat_key: continue
		var distance: int=wilderness._distance(wilderness.player_tile,Vector2i(site.x,site.y))
		if distance<best: target=site; best=distance
	if target.is_empty():
		_toast("These growing spots are resting today. Try another habitat or return tomorrow.")
		return
	var destination:=Vector2i(int(target.x),int(target.y)+1)
	if not wilderness.is_walkable(destination): destination=Vector2i(target.x,target.y)
	wilderness._route_to(destination)
	_toast("Following the trail to %s." % str(Habitat.patch(biome,str(target.id)).get("name",biome)))

func _show_wild_encounter(message: String = "") -> void:
	if is_instance_valid(wilderness): wilderness.waiting = true
	var encounter: Dictionary = state.expedition.get("active_encounter",{})
	if encounter.is_empty(): return
	var p: Dictionary = encounter.plant
	_open_modal("A wild %s!" % str(p.species),"wild_encounter")
	modal_content.add_child(_wrap("%s / WILD ENCOUNTER" % str(encounter.biome).to_upper(),11,AMBER))
	var info: Dictionary=Habitat.patch(str(encounter.biome),str(encounter.site_id))
	var scene := HabitatScene.new()
	scene.biome=str(encounter.biome)
	scene.site_id=str(encounter.site_id)
	scene.plant=p
	scene.custom_minimum_size=Vector2(0,220 if small_layout else 300)
	scene.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	modal_content.add_child(scene)
	var habitat_name: Label=_wrap(str(info.get("name","")),20,AMBER)
	habitat_name.set_meta("habitat_name",true)
	modal_content.add_child(habitat_name)
	var habitat_clue: Label=_wrap(str(info.get("clue","")),13,MUTED)
	habitat_clue.set_meta("habitat_clue",true)
	modal_content.add_child(habitat_clue)
	var bio := VBoxContainer.new()
	bio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_content.add_child(bio)
	bio.add_child(_wrap(str(p.name),23,INK))
	bio.add_child(_wrap("%s · %s · G%d" % [p.type,p.rarity,p.generation],13,AMBER))
	bio.add_child(_wrap("%s pattern · %s tissue\nVitality %d · Growth %d\n%s" % [_gene(p,"pattern"),_gene(p,"texture"),p.stats.vitality,p.stats.growth,_talents_text(p.skills)],13))
	bio.add_child(_action_button("Traits & breeding",func(): _open_dna(str(p.id)),"view_dna",str(p.id)))
	bio.add_child(_button("Where this family grows →",func(): _open_plant_habitats(str(p.id))))
	if not message.is_empty(): bio.add_child(_wrap(message,13,Color("bdcf9b")))
	modal_content.add_child(_wrap("Meet a wild plant, learn its quirks, and bring a cutting home. Your new friend keeps its own traits and can join your next plant family.",13))
	modal_content.add_child(_wrap("COLLECT  %d%%    /    VINE LURE  %d%%\nA failed cutting uses its kit. After failure there is a 25%% chance the plant withdraws until the next field day." % [roundi(state.capture_odds()*100),roundi(state.capture_odds("entangle")*100)],12,AMBER))
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	modal.get_node("Panel").get_child(0).add_child(footer)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",6)
	footer.add_child(actions)
	var observe := _button("Studied" if encounter.observed else "Study · free",func(): _wild_action("observe"))
	observe.disabled = bool(encounter.observed)
	observe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(observe)
	var collect := _button("Collect · %d%%" % roundi(state.capture_odds()*100),func(): _wild_action("gather"))
	collect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collect.disabled = state.field_kits <= 0
	actions.add_child(collect)
	var support := _button("Vine lure · %d%%" % roundi(state.capture_odds("entangle")*100),func(): _wild_action("entangle"))
	support.disabled = not bool(state.field_status().can_entangle) or state.field_kits <= 0 or int(state.resources.sunlight) < 5
	footer.add_child(support)
	footer.add_child(_wrap("%d FIELD KITS / Collect uses 1 kit. Vine lure uses 1 kit + 5 light and needs a mature Vine." % state.field_kits,10,MUTED))
	var extras := HBoxContainer.new()
	footer.add_child(extras)
	extras.add_child(_button("Supplies",_open_field_supplies))
	extras.add_child(_button("Leave it growing",_leave_wild))

func _wild_action(method: String) -> void:
	var result: Dictionary = state.resolve_wild_capture(method)
	if not result.get("ok",false):
		_toast(str(result.get("message","The collection could not be completed.")))
		return
	if result.get("caught",false):
		_play_sound("collect_success")
		_show_wild_capture(result.plant,str(result.message))
	elif result.get("fled",false):
		_play_sound("collect_fail")
		_close_modal()
		wild_encounter_open = false
		wilderness.encounter_closed()
		wilderness.refresh()
		_toast(str(result.message))
	else:
		_play_sound("observe" if method == "observe" else "collect_fail")
		_show_wild_encounter(str(result.message))
	wilderness.refresh()

func _show_wild_capture(p: Dictionary, message: String) -> void:
	selected_id = str(p.id)
	_open_modal("A new companion takes root","wild_capture")
	modal_content.add_child(_wrap("COLLECTED / %s / %s" % [str(p.species).to_upper(),str(p.rarity).to_upper()],12,AMBER))
	var art := Portrait.new()
	art.plant = p
	art.reveal = 0
	art.custom_minimum_size = Vector2(200,260)
	modal_content.add_child(art)
	var reveal_tween := art.create_tween()
	reveal_tween.tween_property(art,"reveal",1.0,0.65)
	modal_content.add_child(_wrap(str(p.name),26,INK))
	modal_content.add_child(_wrap(message,14,Color("c4d5a3")))
	modal_content.add_child(_wrap("%s · %s pattern\nFound in %s. This exact plant is now in your specimen tray and codex. Its wild traits can pass to a new generation." % [p.type,_gene(p,"pattern"),p.origin.biome],13))
	var footer := VBoxContainer.new()
	modal.get_node("Panel").get_child(0).add_child(footer)
	footer.add_child(_button("Keep exploring →",_continue_exploring,Vector2(0,46)))
	footer.add_child(_button("Return to garden",_return_from_wilderness))
	footer.add_child(_button("Read its genome",func(): _open_detail(str(p.id))))
	wilderness.refresh()

func _continue_exploring() -> void:
	state.leave_wild_encounter()
	_close_modal()
	wild_encounter_open = false
	wilderness.encounter_closed()
	wilderness.refresh()

func _leave_wild() -> void:
	state.leave_wild_encounter()
	_continue_exploring()

func _open_field_supplies() -> void:
	if is_instance_valid(wilderness): wilderness.waiting = true
	wild_encounter_open = true
	_open_modal("The field satchel","wild_supplies")
	var status: Dictionary = state.field_status()
	modal_content.add_child(_label("%d / FIELD KITS" % state.field_kits,30,AMBER,true))
	modal_content.add_child(_wrap("Field kits hold a safe cutting from a wild plant. Study is free. Each collection attempt uses one kit, including failed attempts.",14))
	modal_content.add_child(_wrap("Wild specimens collected: %d\nTiles walked: %d\nHabitats visited: %s" % [status.captures,status.steps,", ".join(status.discovered_biomes)],13))
	modal_content.add_child(_button("Pack 5 kits · 20 light",func():
		var result: Dictionary = state.restock_field_kits()
		_toast(str(result.message))
		if is_instance_valid(wilderness): wilderness.refresh()
		_open_field_supplies()))
	modal_content.add_child(_wrap("A vast wilderness spans eight habitats. Collected and withdrawn patches regrow each field day. Your map position and field notes save automatically.",13))
	if not state.expedition.active_encounter.is_empty(): modal_content.add_child(_button("Back to the wild plant",func(): _show_wild_encounter()))
	modal_content.add_child(_button("Back to the trail",_continue_exploring))


func _open_display_settings() -> void:
	if exploring and is_instance_valid(wilderness):
		wilderness.waiting = true
		wild_encounter_open = true
	_open_modal("Display & resolution", "display_settings")
	var win: Window = get_window()
	display_output_label = _wrap(display_settings.description() if display_settings.enabled else "%d × %d pixels" % [win.size.x,win.size.y],18,AMBER)
	modal_content.add_child(display_output_label)
	modal_content.add_child(_wrap("The game renders at the full window resolution. Interface scaling keeps text and controls readable on large displays.",14))
	if display_settings.enabled and DisplayServer.get_screen_count() > 1:
		var monitors := OptionButton.new()
		for index in range(DisplayServer.get_screen_count()):
			var dimensions: Vector2i = DisplayServer.screen_get_size(index)
			monitors.add_item("Display %d · %d × %d" % [index+1,dimensions.x,dimensions.y])
		monitors.select(get_window().current_screen)
		monitors.item_selected.connect(func(index): display_settings.set_screen(index); call_deferred("_refresh_display_readout"))
		modal_content.add_child(monitors)
	modal_content.add_child(_button("Large window · 2880 × 2000",func(): _apply_display_preset(Vector2i(2880,2000))))
	modal_content.add_child(_button("QHD window · 2560 × 1440",func(): _apply_display_preset(Vector2i(2560,1440))))
	modal_content.add_child(_button("HD window · 1920 × 1080",func(): _apply_display_preset(Vector2i(1920,1080))))
	modal_content.add_child(_button("Window · 1440 × 1000",func(): _apply_display_preset(Vector2i(1440,1000))))
	modal_content.add_child(_button("Return to window" if display_settings.is_fullscreen() else "Native-resolution fullscreen",_toggle_fullscreen,Vector2(0,48)))
	modal_content.add_child(_wrap("F11 switches fullscreen. Window sizes are fitted to your monitor, and display preferences are saved separately from your garden.",13))
	if exploring: modal_content.add_child(_button("Return to the trail",_continue_exploring))

func _apply_display_preset(dimensions: Vector2i) -> void:
	display_settings.set_preset(dimensions)
	call_deferred("_refresh_display_readout")

func _toggle_fullscreen() -> void:
	display_settings.toggle_fullscreen()
	call_deferred("_refresh_display_readout")

func _refresh_display_readout() -> void:
	if is_instance_valid(display_output_label) and display_settings.enabled:
		display_output_label.text = display_settings.description()
	_responsive()

func _play_sound(event: String) -> void:
	if is_instance_valid(soundscape): soundscape.play(event)

func _field_audio_position() -> void:
	if not is_instance_valid(wilderness) or not is_instance_valid(soundscape): return
	var biome: String = wilderness.biome_at(wilderness.player_tile)
	if biome != last_audio_biome:
		last_audio_biome = biome
		soundscape.set_context("wild",biome)

func _localize_ui() -> void:
	Locale.apply_tree(self)
	if state.save_path == State.SAVE_PATH and DisplayServer.get_name() != "headless":
		get_window().title = Locale.text("The Quiet Conservatory")

func _change_language(code: String) -> void:
	Locale.set_language(code)
	if state.save_path == State.SAVE_PATH: Locale.save_settings()
	else: Locale.save_settings(state.save_path.get_basename()+".language.cfg")
	_play_sound("ui")
	_localize_ui()
	_responsive()
	call_deferred("_localize_ui")

func _open_settings() -> void:
	if exploring and is_instance_valid(wilderness):
		wilderness.waiting = true
		wild_encounter_open = true
	_open_modal("Sound & language","settings")
	modal_content.add_child(_wrap("Choose your language and the sounds of your garden. Changes are saved automatically.",14))
	modal_content.add_child(_label("Language",13,AMBER))
	language_picker = OptionButton.new()
	language_picker.add_item("English")
	language_picker.set_item_metadata(0,"en")
	language_picker.add_item("简体中文")
	language_picker.set_item_metadata(1,"zh_CN")
	language_picker.select(1 if Locale.get_language() == "zh_CN" else 0)
	language_picker.item_selected.connect(func(index): _change_language(str(language_picker.get_item_metadata(index))))
	modal_content.add_child(language_picker)
	_line(modal_content)
	for channel in ["master","music","ambience","effects"]:
		var title: String = {"master":"Master volume","music":"Music","ambience":"Ambience","effects":"Sound effects"}[channel]
		modal_content.add_child(_label(title,13,AMBER))
		var row := HBoxContainer.new()
		modal_content.add_child(row)
		var slider := HSlider.new()
		slider.set_meta("sound_channel",channel)
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = roundi(soundscape.get_volume(channel)*100) if is_instance_valid(soundscape) else 65
		slider.custom_minimum_size = Vector2(120,26)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var amount := _label("%d%%" % int(slider.value),13,INK)
		amount.custom_minimum_size.x = 44
		row.add_child(amount)
		slider.value_changed.connect(func(value):
			if is_instance_valid(soundscape): soundscape.set_volume(channel,value/100.0)
			amount.text = "%d%%" % int(value))
	var mute := CheckButton.new()
	mute.text = "Mute all sound"
	mute.button_pressed = soundscape.is_muted() if is_instance_valid(soundscape) else false
	mute.toggled.connect(func(value):
		if is_instance_valid(soundscape): soundscape.set_muted(value)
		if not value: _play_sound("ui"))
	modal_content.add_child(mute)
	_line(modal_content)
	modal_content.add_child(_button("Display & resolution",_open_display_settings))
	modal_content.add_child(_wrap("Garden melodies follow you into the wild. Footsteps, discoveries, new sprouts, and happy fair visits each have their own sound.",13))
	if exploring: modal_content.add_child(_button("Return to the trail",_continue_exploring))
	call_deferred("_localize_ui")

func _history_note(record: Dictionary, kind: String) -> String:
	var generation: int = int(record.get("generation",1))
	if kind == "graft":
		return "G%d · %s graft from %s · %s" % [generation,str(record.get("trait","feature")),str(record.get("donor_name","Unknown donor")),str(record.get("value",""))]
	if kind == "rejected":
		return "G%d · Graft from %s rejected" % [generation,str(record.get("donor_name","Unknown donor"))]
	if str(record.get("outcome","")) == "No change":
		return "G%d · %s · No change" % [generation,str(record.get("agent","Mutation"))]
	return "G%d · %s · %s: %s → %s" % [generation,str(record.get("agent","Mutation")),str(record.get("slot","trait")),str(record.get("before","")),str(record.get("after",""))]
