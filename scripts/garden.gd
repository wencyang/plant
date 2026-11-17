extends Control
const State = preload("res://scripts/garden_state.gd")
const Portrait = preload("res://scripts/plant_portrait.gd")
const Cell = preload("res://scripts/plant_cell.gd")
const Combat = preload("res://scripts/battle_sim.gd")
const Ecology = preload("res://scripts/ecology.gd")
const Bench = preload("res://scripts/bench_surface.gd")
const INK := Color("dce0ce")
const MUTED := Color("8d9f91")
const AMBER := Color("d5b67b")
var state = State.new()
var sim = null
var speed: float = 1.0
var paused: bool = false
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
var opponent_grid: GridContainer
var opponent_panel: VBoxContainer
var tray_row: HBoxContainer
var tray_scroll: ScrollContainer
var tray_panel: PanelContainer
var battle_controls: GridContainer
var primary_button: Button
var burst_button: Button
var pause_button: Button
var speed_button: Button
var timer_label: Label
var synergy_label: Label
var heading: Label
var helper_label: Label
var display_caption: Button
var display_heading: HBoxContainer
var title_row: HBoxContainer
var footer_row: HBoxContainer
var toast_label: Label
var toast_panel: PanelContainer
var cells: Dictionary = {}
var enemy_cells: Dictionary = {}
var save_timer: float = 0
var combat_ui_timer: float = 0
var toast_time: float = 0
var ui_margin: MarginContainer
var serif: SystemFont
var sans: SystemFont
var small_layout: bool = false
var effects: Control
var fx: Array = []
var lab_pick_a: OptionButton
var lab_pick_b: OptionButton
var lab_result: Label
var action_picker: OptionButton
var last_log: String = "Roots settle. The garden is listening."
var battle_health_label: Label
var battle_event_label: Label
var battle_player_meter: ProgressBar
var battle_enemy_meter: ProgressBar
var seen_events: int = 0
var root_column: VBoxContainer
var brand_label: Label
var collection_box: VBoxContainer
var tray_hint: Label

func _ready() -> void:
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["Helvetica Neue", "Arial", "DejaVu Sans"])
	sans.font_weight = 400
	_build_theme()
	if not state.load_game(): state.new_game()
	state.tick_growth()
	_build_ui()
	_refresh()
	resized.connect(_responsive)
	call_deferred("_responsive")
	primary_button.grab_focus()
	get_tree().auto_accept_quit = false

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
	t.set_color("font_hover_color", "Button", Color("f0e8cf"))
	t.set_color("font_disabled_color", "Button", Color("64746a"))
	for kind in ["Button", "OptionButton"]:
		t.set_stylebox("normal", kind, _style(Color("23382d"), Color("4b6250"), 5, 14, 10))
		t.set_stylebox("hover", kind, _style(Color("304737"), Color("809277"), 5, 14, 10))
		t.set_stylebox("pressed", kind, _style(Color("344c38"), Color("b0ae82"), 5, 14, 10))
		t.set_stylebox("focus", kind, _style(Color(0,0,0,0), Color("b5c29d"), 5, 14, 10))
		t.set_stylebox("disabled", kind, _style(Color("18271f"), Color("304237"), 5, 14, 10))
	t.set_stylebox("normal", "LineEdit", _style(Color("14251f"), Color("52684e"), 5, 12, 10))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_stylebox("panel", "PopupMenu", _style(Color("1b3026"), Color("6b7e61"), 5, 8, 8))
	t.set_stylebox("panel", "TooltipPanel", _style(Color("172a22"), Color("697e62"), 4, 12, 10))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 12)
	theme = t

func _style(bg: Color, border: Color = Color("344d3c"), radius: int = 5, horizontal: int = 16, vertical: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = horizontal
	s.content_margin_right = horizontal
	s.content_margin_top = vertical
	s.content_margin_bottom = vertical
	return s

func _label(text: String, font_size: int = 14, color: Color = INK, use_serif: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
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
	b.pressed.connect(action)
	return b

func _spacer(parent: Node, vertical: bool = false) -> Control:
	var c := Control.new()
	if vertical: c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else: c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c

func _line(parent: Node) -> void:
	var line := HSeparator.new()
	line.modulate = Color("546c53")
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
	var brand := _label("H E R B A R I U M", 14, Color("c3cfac"))
	brand_label = brand
	brand.tooltip_text = "The Quiet Conservatory · a plant breeding auto-battler"
	top.add_child(brand)
	_spacer(top)
	resources_label = _label("", 14, Color("c4cbb2"))
	top.add_child(resources_label)
	_line(root)
	title_row = HBoxContainer.new()
	root.add_child(title_row)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 3)
	title_row.add_child(titles)
	titles.add_child(_label("FIELD STATION  /  001     ·     DUSK BIOME", 10, Color("8b9f87")))
	heading = _label("The quiet conservatory", 36, INK, true)
	titles.add_child(heading)
	helper_label = _label("Strange things take root here. Grow something worth keeping.", 13, MUTED)
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
	cap_row.add_child(_label("01  /  THE DISPLAY BED", 11, Color("afbd9d")))
	_spacer(cap_row)
	display_caption = _button("Six specimens. One ecology. · Observe", _open_display_notes)
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
	bed_header.add_child(_label("02  /  THE ROOTING BED", 11, Color("afbd9d")))
	_spacer(bed_header)
	synergy_label = _label("", 11, MUTED)
	bed_header.add_child(synergy_label)
	var board_panel := PanelContainer.new()
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _style(Color(0.09,0.14,0.115,0.9), Color("4a5c43"), 12, 13, 12))
	garden_column.add_child(board_panel)
	var board_inner := HBoxContainer.new()
	board_inner.add_theme_constant_override("separation", 8)
	board_panel.add_child(board_inner)
	# Soil is always the same physical board; opponents unfold above it during battle.
	var bed_wrap := VBoxContainer.new()
	bed_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_inner.add_child(bed_wrap)
	opponent_panel = VBoxContainer.new()
	opponent_panel.visible = false
	bed_wrap.add_child(opponent_panel)
	opponent_panel.add_child(_label("THE FERAL CONSERVATORY  /  OPPOSING ROOTS", 10, Color("b6a58b")))
	opponent_grid = GridContainer.new()
	opponent_grid.columns = 3
	opponent_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opponent_grid.add_theme_constant_override("h_separation", 5)
	opponent_grid.add_theme_constant_override("v_separation", 3)
	opponent_panel.add_child(opponent_grid)
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
	tray_heading.add_child(_label("YOUR LIVING SPECIMENS", 10, Color("afbd9d")))
	_spacer(tray_heading)
	tray_hint = _label("DRAG TO PLANT  ·  HOLD TO EXAMINE", 10, MUTED)
	tray_heading.add_child(tray_hint)
	tray_scroll = ScrollContainer.new()
	tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tray_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray_scroll.custom_minimum_size.y = 132
	tray_column.add_child(tray_scroll)
	tray_row = HBoxContainer.new()
	tray_row.add_theme_constant_override("separation", 10)
	tray_scroll.add_child(tray_row)
	battle_controls = GridContainer.new()
	battle_controls.columns = 5
	battle_controls.custom_minimum_size.y = 160
	battle_controls.visible = false
	tray_column.add_child(battle_controls)
	timer_label = _label("00:00 / 02:30", 25, INK, true)
	battle_controls.add_child(timer_label)
	pause_button = _button("Pause", _toggle_pause)
	battle_controls.add_child(pause_button)
	speed_button = _button("Speed · 1×",_toggle_speed)
	battle_controls.add_child(speed_button)
	burst_button = _button("Bloom Burst · gathering", _bloom_burst, Vector2(210, 54))
	battle_controls.add_child(burst_button)
	footer_row = HBoxContainer.new()
	root.add_child(footer_row)
	footer_row.add_child(_button("Laboratory", func(): _open_lab(), Vector2(130, 48)))
	footer_row.add_child(_button("Seed bank", _open_seeds, Vector2(120, 48)))
	footer_row.add_child(_button("Codex", _open_codex, Vector2(100, 48)))
	_spacer(footer_row)
	footer_row.add_child(_button("Field guide", _open_guide, Vector2(100, 48)))
	primary_button = _button("Let the gardens meet   →", _prepare_battle, Vector2(265, 48))
	primary_button.add_theme_stylebox_override("normal", _style(Color("a9b68a"), Color("d0d5a9"), 5, 24, 14))
	primary_button.add_theme_stylebox_override("hover", _style(Color("c3ca9d"), Color("dfe2bb"), 5, 24, 14))
	primary_button.add_theme_color_override("font_color", Color("182c22"))
	primary_button.add_theme_color_override("font_hover_color", Color("14281c"))
	footer_row.add_child(primary_button)
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
	sidebar.visible = not small_layout
	heading.add_theme_font_size_override("font_size", 25 if small_layout else 36)
	root_column.add_theme_constant_override("separation", 6 if small_layout else 10)
	display_grid.custom_minimum_size.y = 72 if small_layout else 108
	display_heading.visible = sim == null
	brand_label.visible = not small_layout
	collection_box.visible = not small_layout
	tray_hint.visible = not small_layout
	tray_scroll.custom_minimum_size.y = 116 if small_layout else 132
	battle_controls.columns = 2 if small_layout else 5
	burst_button.custom_minimum_size.x = 155 if small_layout else 210
	helper_label.visible = size.x > 700
	display_caption.visible = true
	if small_layout: display_caption.text = "Beauty %d · Observe" % int(state.display_score().get("total",0))
	else: display_caption.text = "Six specimens. One ecology. · Observe"
	for edge in ["left", "right"]: ui_margin.add_theme_constant_override("margin_" + edge, 14 if small_layout else 38)
	for edge in ["top", "bottom"]: ui_margin.add_theme_constant_override("margin_" + edge, 14 if small_layout else 22)
	resources_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if small_layout else Control.SIZE_SHRINK_END
	resources_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if small_layout else HORIZONTAL_ALIGNMENT_RIGHT
	resources_label.add_theme_font_size_override("font_size", 10 if small_layout else 14)
	timer_label.add_theme_font_size_override("font_size", 20 if small_layout else 25)
	resources_label.text = ("LIGHT %d · SEEDS %d · AGENTS %d · GRAFTS %d" if small_layout else "Gathered light  %d    /    Seeds  %d    /    Agents  %d    /    Graft  %d") % [state.resources.sunlight, state.seed_bank.size(), state.resources.agents, state.resources.grafts]
	for c in display_grid.get_children(): c.custom_minimum_size = Vector2(0, 72 if small_layout else 108)
	for c in tray_row.get_children(): c.custom_minimum_size = Vector2(116,110) if small_layout else Vector2(130,128)
	for c in opponent_grid.get_children(): c.custom_minimum_size = Vector2(0,55 if small_layout else 72)
	for c in bed_grid.get_children(): c.custom_minimum_size = Vector2(0, (55 if small_layout else 72) if sim != null else (72 if small_layout else 110))
	for b in footer_row.get_children():
		if b is Button:
			b.custom_minimum_size.x = 0 if small_layout else (265 if b == primary_button else 100)
			b.add_theme_font_size_override("font_size", 11 if small_layout else 14)
	footer_row.get_child(4).visible = not small_layout
	primary_button.text = "Battle →" if small_layout else "Let the gardens meet   →"
	if sim != null: primary_button.text = "In bloom" if small_layout else "Gardens in bloom"
	if is_instance_valid(modal): _position_modal()
	toast_panel.position = Vector2(maxf(12, (size.x - 390) / 2), size.y - 145)
	toast_panel.size.x = minf(480, size.x - 24)

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	resources_label.text = "Gathered light  %d    /    Seeds  %d    /    Agents  %d    /    Graft  %d" % [state.resources.sunlight, state.seed_bank.size(), state.resources.agents, state.resources.grafts]
	var score: Dictionary = state.display_score()
	score_label.text = "%03d  /  beauty" % int(score.get("total", 0))
	status_label.text = last_log
	_refresh_cells()
	_refresh_side()
	_refresh_synergies()
	_responsive()

func _make_cell(id: String, zone: String, index: int) -> Control:
	var c := Cell.new()
	c.plant = state.get_plant(id) if id != "" else {}
	c.zone = zone
	c.index = index
	c.selected = id == selected_id and id != ""
	c.battle_locked = sim != null
	c.custom_minimum_size = Vector2(130, 128) if zone == "tray" else Vector2(0, 108 if zone == "display" else 110)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.chosen.connect(_choose_plant)
	c.inspected.connect(_open_detail)
	c.dropped.connect(_drop_plant)
	return c

func _refresh_cells() -> void:
	if sim != null: return
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

func _refresh_synergies() -> void:
	var counts: Dictionary = {}
	for id in state.bed:
		if id == "": continue
		var p: Dictionary = state.get_plant(str(id))
		for t in [p.get("type", ""), p.get("secondary_type", "")]:
			if t != "": counts[t] = int(counts.get(t, 0)) + 1
	var active: Array = []
	for type in counts:
		if int(counts[type]) >= 3: active.append("%s network" % type)
	synergy_label.text = " · ".join(active) if not active.is_empty() else "Three of a type intertwine."

func _refresh_side() -> void:
	_clear(side_content)
	if sim != null:
		_build_battle_notes()
		return
	if selected_id != "" and state.plants.has(selected_id):
		var p: Dictionary = state.get_plant(selected_id)
		side_content.add_child(_label("SPECIMEN / %s" % selected_id.to_upper().right(6), 10, MUTED))
		var art := Portrait.new()
		art.plant = p
		art.custom_minimum_size = Vector2(240, 172)
		side_content.add_child(art)
		side_content.add_child(_label(str(p.name), 25, INK, true))
		side_content.add_child(_label("%s · %s · GENERATION %d" % [p.type, p.rarity, p.generation], 11, AMBER))
		side_content.add_child(_wrap("%s tissue · %s pattern" % [_gene(p,"texture"), _gene(p,"pattern")], 13))
		_line(side_content)
		side_content.add_child(_wrap(" / ".join(p.get("skills", [])), 13, Color("b6c5a3")))
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
		side_content.add_child(_label("A STUDY IN COEXISTENCE", 10, MUTED))
		side_content.add_child(_label("Beauty has\nits own ecology.", 29, INK, true))
		side_content.add_child(_wrap("Different forms. Shared pigments. An improbable family, slowly finding its balance.", 14))
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
		side_content.add_child(_wrap("FIELD NOTE  /  01\nSelect a specimen, then touch an empty soil cell. Or drag it directly into the bed.", 12))

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
	if sim != null:
		if id != "": _open_detail(id)
		return
	if selected_id != "" and moving and zone != "tray":
		_drop_plant(selected_id, zone, index)
		return
	if id == "":
		_toast("Select a specimen from the tray, then choose its place in the soil.")
		return
	selected_id = id
	moving = zone == "tray"
	last_log = "%s selected. %s" % [state.get_plant(id).name, "Choose a soil or display cell to plant." if moving else "Examine its genes, breed, or move it."]
	_refresh()
	if small_layout: _compact_plant(id)

func _drop_plant(id: String, zone: String, index: int) -> void:
	if sim != null: return
	var ok: bool = false
	match zone:
		"bed": ok = state.place_in_bed(id, index)
		"display": ok = state.place_in_display(id, index)
		"tray": state.bench(id); ok = true
	if ok:
		selected_id = ""
		moving = false
		last_log = "A new arrangement. Roots begin to find one another."
		state.save_game()
		_refresh()
	else: _toast("This specimen is still growing. Let it mature before planting.")

func _compact_plant(id: String) -> void:
	var p: Dictionary = state.get_plant(id)
	_open_modal(str(p.name), "specimen")
	modal_content.add_child(_wrap("%s · %s · G%d\n%s pattern · %s\nVitality %d · Growth %d · Bloom %d" % [p.type,p.rarity,p.generation,_gene(p,"pattern")," / ".join(p.skills),p.stats.vitality,p.stats.growth,p.stats.bloom], 14, INK))
	var row := HBoxContainer.new()
	modal_content.add_child(row)
	row.add_child(_button("Detail", func(): _open_detail(id)))
	row.add_child(_button("Breed", func(): _breed_from(id)))
	row.add_child(_button("Move", func(): moving = true; _close_modal(); _toast("Choose a soil cell or display slot.")))
	if state.display_bed.has(id): modal_content.add_child(_button("Lift from display bed",func(): state.remove_from_display(id); selected_id = ""; _close_modal(); _refresh()))

func _toast(message: String) -> void:
	toast_label.text = message
	toast_panel.visible = true
	toast_panel.move_to_front()
	toast_time = 5.5
	_responsive()

func _open_modal(title: String, kind: String = "") -> void:
	_close_modal()
	modal_kind = kind
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.035,0.028,0.86)
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

func _position_modal() -> void:
	if not is_instance_valid(modal): return
	var panel: Control = modal.get_node("Panel")
	var width: float = minf(820, size.x - 28)
	var height: float = minf(820, size.y - 50)
	if modal_kind == "specimen": height = 280
	panel.position = Vector2((size.x-width)*0.5, (size.y-height)*0.5)
	panel.size = Vector2(width, height)

func _close_modal() -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null
	modal_kind = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal): _close_modal()
		else:
			selected_id = ""
			moving = false
			_refresh_side()
		get_viewport().set_input_as_handled()

func _open_detail(id: String) -> void:
	var p: Dictionary = state.get_plant(id)
	if p.is_empty() and sim != null:
		for f in sim.fighters:
			if str(f.id) == id: p = f.plant
	if p.is_empty(): return
	_open_modal(str(p.name), "detail")
	var top: BoxContainer = VBoxContainer.new() if small_layout else HBoxContainer.new()
	modal_content.add_child(top)
	var art := Portrait.new()
	art.plant = p
	art.custom_minimum_size = Vector2(180 if small_layout else 250, 250)
	top.add_child(art)
	var bio := VBoxContainer.new()
	bio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(bio)
	bio.add_child(_label("%s / GENERATION %d" % [p.get("rarity","Common").to_upper(), p.generation], 11, AMBER))
	bio.add_child(_wrap("%s\n%s%s" % [p.species,p.type," × " + str(p.secondary_type) if p.get("secondary_type", "") != "" else ""], 17, INK))
	bio.add_child(_wrap(" / ".join(p.get("skills",[])), 13, Color("b5caa3")))
	bio.add_child(_wrap("Mature specimen" if p.get("mature",true) else "Unfurling · mature in a few moments", 12))
	if state.plants.has(id):
		var rename := LineEdit.new()
		rename.text = p.name
		rename.placeholder_text = "Name this plant"
		rename.max_length = 30
		bio.add_child(rename)
		bio.add_child(_button("Save name", func(): state.rename_plant(id,rename.text); _refresh(); _open_detail(id)))
		bio.add_child(_button("Unpin favorite" if p.get("favorite",false) else "Keep as favorite", func(): state.toggle_favorite(id); _refresh(); _open_detail(id)))
		bio.add_child(_button("Choose as parent", func(): _breed_from(id)))
	_line(modal_content)
	modal_content.add_child(_label("THE EXPRESSED GENOME", 11, AMBER))
	modal_content.add_child(_wrap("Each column is inherited independently. Carried genes can reappear in a later generation.", 12))
	var genes := GridContainer.new()
	genes.columns = 3
	genes.add_theme_constant_override("h_separation", 25)
	genes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_content.add_child(genes)
	for head in ["TRAIT", "EXPRESSED", "CARRIED"]: genes.add_child(_label(head, 10, MUTED))
	for key in p.get("genes", {}):
		var gene: Dictionary = p.genes[key]
		genes.add_child(_label(str(key).capitalize(), 12, MUTED))
		genes.add_child(_label(str(gene.get("dominant","—")), 12, INK))
		genes.add_child(_label(str(gene.get("recessive","—")), 12, Color("a2b69a")))
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
		for record in p.graft_history: modal_content.add_child(_wrap(str(record), 12))
	if p.get("graft_attempts",[]).size() > 0:
		modal_content.add_child(_label("REJECTED JOINS",11,AMBER))
		for record in p.graft_attempts: modal_content.add_child(_wrap(str(record),12))
	if p.get("mutation_history",[]).size() > 0:
		modal_content.add_child(_label("MUTATION RECORD", 11, AMBER))
		for record in p.mutation_history: modal_content.add_child(_wrap(str(record), 12))

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
	if sim != null:
		_toast("Let the gardens settle before breeding.")
		return
	if parent_a == "" or parent_a == id: parent_a = id
	else: parent_b = id
	_open_lab()

func _open_lab() -> void:
	if sim != null:
		_toast("The laboratory is quiet while roots are meeting.")
		return
	var mature: Array = []
	for id in state.plant_order:
		if state.get_plant(str(id)).get("mature",false): mature.append(str(id))
	if mature.is_empty():
		_toast("Your plants are unfurling. Come back when one has matured.")
		return
	if parent_a == "" or not mature.has(parent_a): parent_a = str(mature[0])
	if parent_b == "" or not mature.has(parent_b) or parent_b == parent_a:
		for id in mature:
			if id != parent_a: parent_b = str(id); break
	_open_modal("The propagation laboratory", "lab")
	modal_content.add_child(_wrap("A new organism begins as a question. What might these two become?", 14))
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
		column.add_child(_label(("HOST" if lab_mode == "Graft" else "PARENT A") if which == 0 else ("DONOR" if lab_mode == "Graft" else "PARENT B"), 10, MUTED))
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
		if which == 0: lab_pick_a = pick
		else: lab_pick_b = pick
		pick.item_selected.connect(func(i):
			if which == 0: parent_a = str(pick.get_item_metadata(i))
			else: parent_b = str(pick.get_item_metadata(i))
			_open_lab())
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
			if parent_a == id: return
			parent_b = id
			_open_lab())
		candidates.add_child(candidate)
	var a: Dictionary = state.get_plant(parent_a)
	var b: Dictionary = state.get_plant(parent_b)
	_line(modal_content)
	match lab_mode:
		"Crossbreed":
			modal_content.add_child(_label("RECOMBINATION / POSSIBLE INHERITANCE", 11, AMBER))
			modal_content.add_child(_wrap("Types: %s or %s; a secondary type may emerge.\nPattern: %s or %s; carried recessives can reappear.\nGeneration %d · Each stat is the parental average ±10%%.\nEvery visual slot inherits independently.\nParents are kept. Offspring unfurl in 12 seconds." % [a.get("type","?"), b.get("type","?"), _gene(a,"pattern"), _gene(b,"pattern"), maxi(int(a.get("generation",1)), int(b.get("generation",1)))+1], 14, INK))
			modal_content.add_child(_wrap("ODDS BEFORE PROPAGATION\nPrimary lineage: 50% each parent. Different parent types: 45% secondary-type inheritance. Each parental allele: 50% chance of transmission, then 50% expression. Pigments: 15% blending. Different skill alleles: 30% dual expression. G3+ different pattern alleles: 8% rare combination. Each recorded graft: 20% inheritance.",12,MUTED))
			_lab_action("Crossbreed · 30 gathered light",_crossbreed,"Parents remain · 50/50 primary lineage · 45% secondary type · 15% pigment blending · ±10% stats")
		"Graft":
			var odds: int = roundi(state.graft_odds(parent_a,parent_b)*100)
			modal_content.add_child(_label("A PRECISE, IMPERFECT JOIN", 11, AMBER))
			modal_content.add_child(_wrap("%d%% success · %d%% rejection for this exact graft.\nAt most two grafts per host. The donor rests on a long cooldown; the host is unharmed on failure. Favorites cannot be used as donors.\nA seam and donor-colored tissue remain part of the organism." % [odds,100-odds], 14, INK))
			action_picker = OptionButton.new()
			for trait_name in ["feature","skill","stat"]: action_picker.add_item(trait_name.capitalize()); action_picker.set_item_metadata(action_picker.item_count-1, trait_name)
			modal_content.add_child(action_picker)
			_lab_action("Attempt graft · 1 grafting material",_graft,"%d%% success / %d%% rejection · Host unharmed · Donor rests · Material spent either way" % [odds,100-odds])
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

func _lab_action(text: String, action: Callable, odds: String) -> void:
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	modal.get_node("Panel").get_child(0).add_child(footer)
	footer.add_child(_wrap(odds,11,AMBER))
	footer.add_child(_button(text,action,Vector2(0,48)))

func _crossbreed() -> void:
	var result: Dictionary = state.crossbreed(parent_a, parent_b)
	if result.get("ok",false):
		_refresh()
		_reveal(result.get("plant",{}), str(result.get("message","A new lineage begins.")))
	else: lab_result.text = str(result.get("message","Choose two different mature parents."))

func _graft() -> void:
	var trait_name: String = str(action_picker.get_item_metadata(action_picker.selected))
	var result: Dictionary = state.graft(parent_a, parent_b, trait_name)
	_refresh()
	_toast(str(result.get("message","The graft is recorded.")))
	_open_lab()

func _mutate() -> void:
	var result: Dictionary = state.mutate(parent_a, "radiation" if action_picker.selected == 0 else "chemical", "pattern")
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
			if is_instance_valid(gene_notes): gene_notes.text += "%s  /  %s\n" % [key.capitalize(),_gene(p,key)])
		tw.tween_interval(0.35)
	modal_content.add_child(_wrap("Already growing in your specimen tray. Its parents, carried genes, and history have been preserved.", 13))
	modal_content.add_child(_button("Return to my garden", func(): _close_modal(); _refresh()))
	modal_content.add_child(_button("Read the genome", func(): _open_detail(str(p.id))))

func _perform_nurture(id: String) -> void:
	var result: Dictionary = state.mature_plant(id)
	_toast(str(result.get("message","The leaves gather light.")))
	_refresh()

func _open_seeds() -> void:
	_open_modal("The seed archive", "seeds")
	modal_content.add_child(_wrap("Each husk holds a tendency, never a promise. Plant a lineage and discover its expression. Planting costs 10 gathered light.", 14))
	var note := _label("%d SEEDS IN STORAGE" % state.seed_bank.size(), 11, AMBER)
	modal_content.add_child(note)
	if state.seed_bank.is_empty(): modal_content.add_child(_wrap("The archive is resting. Battles, beauty thresholds, and daily growth bring new seeds.", 15))
	for i in range(state.seed_bank.size()):
		var seed_data: Dictionary = state.seed_bank[i]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color("1b3025"), Color("4a6249"), 5, 16, 14))
		modal_content.add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var labels := VBoxContainer.new()
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(labels)
		labels.add_child(_label(str(seed_data.get("species",seed_data.get("lineage","Uncatalogued seed"))), 21, INK, true))
		labels.add_child(_wrap("%s · %s · %s tendency" % [seed_data.get("rarity","Common"),seed_data.get("type","Wild"),seed_data.get("pattern","Unresolved")], 12))
		labels.add_child(_wrap("Pattern: 65% expressed, always carried. Matures in 12 seconds.",11))
		row.add_child(_button("Plant", func():
			if sim != null: _toast("Plant seeds once the roots have settled."); return
			var result: Dictionary = state.plant_seed(i)
			if result.get("ok",false): _refresh(); _reveal(result.get("plant",{}),str(result.get("message","A seed opens.")))
			else: _toast(str(result.get("message","Not enough gathered light.")))))
	_line(modal_content)
	modal_content.add_child(_button("Gather daily growth", _collect_daily))

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
	modal_content.add_child(_wrap("Arrange six mature organisms in the display bed. They can still battle and breed. Scores change as you move specimens.",14))
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
	_open_modal("Notes for a patient botanist", "guide")
	for entry in [
		["01  /  Make a garden", "Drag a specimen into the 3 × 3 rooting bed. Or select a packet, close its inspection, then tap a soil cell. Drag a plant back to the tray to bench it. Use Move to swap occupied cells."],
		["02  /  Keep something beautiful", "The six display cells are a separate arrangement. A displayed plant can still breed and battle. Diversity rewards different organisms; harmony rewards related pigments and markings; rarity rewards unusual genes. Gather rewards at score thresholds."],
		["03  /  Begin a lineage", "Select a plant and choose Breed to carry it into the laboratory. Each gene has an expressed value and a carried recessive. Children recombine the parents, with ±10% stat variance. They mature in 12 seconds. Examine any plant for its full pedigree."],
		["04  /  Make a careful mistake", "Grafts add one feature, skill, or stat bias, with 90% same-type and 65% cross-type base success. Donors rest; hosts survive rejection. Mutation is 70% change, 20% unchanged, 10% deformity. Pin a favorite to protect it as a donor."],
		["05  /  Let roots meet", "Battle unfolds in the same soil. Inspect the rival before committing. Front rows contact first; three matching types activate a shared ecology. Roots sustain, vines entangle, spores drift, toxins seep. At 25 seconds, release your one team Bloom Burst. Switch to 2× or pause to inspect. Withered plants recover afterward."],
		["06  /  Return tomorrow", "Your plants, garden arrangement, discoveries, and full ancestry save automatically on this device. Daily growth, display rewards, and battles all replenish the archive. No account, shop, or payment is needed."]
	]:
		modal_content.add_child(_label(entry[0], 11, AMBER))
		modal_content.add_child(_wrap(entry[1], 14, INK))
		_line(modal_content)
	modal_content.add_child(_button("Gather display rewards", _claim_display))
	modal_content.add_child(_button("Collect daily growth", _collect_daily))

var scouted_plants: Array = []
var scouted_positions: Array = []

func _prepare_battle() -> void:
	if sim != null: return
	var team: Array = []
	for id in state.bed:
		if id != "":
			var p: Dictionary = state.get_plant(str(id))
			if not p.get("mature",false):
				_toast("An unfurling plant is in the rooting bed. Let it mature or move it to the tray.")
				return
			team.append(p)
	if team.is_empty():
		_toast("The soil is empty. Select a specimen and plant it before meeting another garden.")
		return
	scouted_plants = state.generate_opponent(team.size())
	scouted_positions.clear()
	for i in range(scouted_plants.size()): scouted_positions.append(i)
	_open_modal("Beyond the tended bed", "scout")
	modal_content.add_child(_wrap("RIVAL %02d  /  THE FERAL CONSERVATORY" % (state.battles+1), 11, AMBER))
	modal_content.add_child(_wrap("Another ecology has taken root nearby. Read its organisms before allowing your roots to meet. No plant is permanently lost in battle.", 14))
	var grid := GridContainer.new()
	grid.columns = 1 if small_layout else 3
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	modal_content.add_child(grid)
	for i in range(scouted_plants.size()):
		var p: Dictionary = scouted_plants[i]
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(col)
		var art := Portrait.new()
		art.plant = p
		art.custom_minimum_size = Vector2(85,130)
		col.add_child(art)
		col.add_child(_wrap(str(p.name),16,INK))
		col.add_child(_wrap("%s · G%d\n%s · %s\nVitality %d · Growth %d\n%s" % [p.type,p.generation,_gene(p,"pattern"),_gene(p,"form"),p.stats.vitality,p.stats.growth," / ".join(p.skills)],12))
		col.add_child(_button("Read genes", func(): _scout_detail(p)))
	_line(modal_content)
	modal_content.add_child(_wrap("Battle lasts up to 2½ minutes at 1×. Three matching types form a synergy. The front row has the shortest root reach. Your one team Bloom Burst becomes available at 25 seconds.", 13))
	modal_content.add_child(_button("Let the roots meet →", _start_battle, Vector2(0,52)))

func _scout_detail(p: Dictionary) -> void:
	# Scout stays an overlay on the player's own garden and never saves enemy data.
	_open_modal(str(p.name), "scout_detail")
	var art := Portrait.new()
	art.plant = p
	art.custom_minimum_size = Vector2(220,240)
	modal_content.add_child(art)
	modal_content.add_child(_wrap("%s · %s · G%d\n%s" % [p.species,p.type,p.generation," / ".join(p.skills)],16,INK))
	for key in p.genes:
		modal_content.add_child(_label("%s · %s / carries %s" % [str(key).capitalize(),p.genes[key].dominant,p.genes[key].recessive],12,MUTED))
	for key in p.stats: modal_content.add_child(_label("%s · %d" % [str(key).capitalize(),p.stats[key]],12))
	modal_content.add_child(_label("RIVAL LINEAGE",11,AMBER))
	_append_ancestry(p,0,p.get("pedigree",{}))
	modal_content.add_child(_button("Let the roots meet →", _start_battle, Vector2(0,48)))
	modal_content.add_child(_button("Back to scouting", _prepare_battle))

func _start_battle() -> void:
	_close_modal()
	var team: Array = []
	var positions: Array = []
	for i in range(9):
		if str(state.bed[i]) != "":
			team.append(state.get_plant(str(state.bed[i])))
			positions.append(i)
	if team.is_empty() or scouted_plants.is_empty(): return
	sim = Combat.new()
	sim.start(team,positions,scouted_plants,scouted_positions,1729+state.battles*131)
	paused = false
	speed = 1.0
	selected_id = ""
	moving = false
	seen_events = 0
	_clear(opponent_grid)
	enemy_cells.clear()
	for i in range(9):
		var cell := Cell.new()
		cell.zone = "enemy"
		cell.index = i
		cell.battle_locked = true
		cell.custom_minimum_size = Vector2(0,55 if small_layout else 72)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for f in sim.fighters:
			if int(f.side) == 1 and int(f.cell) == i:
				cell.plant = f.plant
				cell.fighter = f
				enemy_cells[str(f.id)] = cell
		cell.chosen.connect(func(id,_zone,_index):
			if id != "": _open_detail(id))
		opponent_grid.add_child(cell)
	for child in bed_grid.get_children():
		child.battle_locked = true
		child.custom_minimum_size.y = 55 if small_layout else 72
		child.refresh()
	for f in sim.fighters:
		if int(f.side) == 0 and cells.has(str(f.id)): cells[str(f.id)].fighter = f
	display_grid.visible = false
	opponent_panel.visible = true
	opponent_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray_scroll.visible = false
	battle_controls.visible = true
	battle_controls.custom_minimum_size.y = 64 if not small_layout else 105
	tray_panel.battle_locked = true
	primary_button.disabled = true
	primary_button.text = "In bloom" if small_layout else "Gardens in bloom"
	display_heading.visible = false
	pause_button.text = "Pause"
	speed_button.text = "Speed · 1×"
	last_log = "The roots meet. Every movement is growth."
	status_label.text = last_log
	_refresh_side()
	if not is_instance_valid(effects):
		effects = load("res://scripts/battle_effects.gd").new()
		effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(effects)
	effects.cell_lookup = cells.merged(enemy_cells)
	_update_combat_ui()
	_responsive()


func _build_battle_notes() -> void:
	side_content.add_child(_label("ROOTS IN CONVERSATION",10,AMBER))
	side_content.add_child(_label("A patient
contest.",32,INK,true))
	side_content.add_child(_wrap("The soil remembers your arrangement. Close roots reach first; related organisms lend each other strength.",14))
	_line(side_content)
	battle_health_label = _wrap("",13,INK)
	side_content.add_child(battle_health_label)
	side_content.add_child(_label("YOUR GARDEN / VITALITY",10,MUTED))
	battle_player_meter = _meter(1,Color("94a77a"))
	side_content.add_child(battle_player_meter)
	side_content.add_child(_label("FERAL GARDEN / VITALITY",10,MUTED))
	battle_enemy_meter = _meter(1,Color("a68b73"))
	side_content.add_child(battle_enemy_meter)
	_line(side_content)
	for side in [0,1]:
		var active: Array = []
		var synergies: Dictionary = sim.get_synergies(side)
		for type in synergies:
			if int(synergies[type]) >= 3: active.append(str(type))
		side_content.add_child(_wrap(("Your symbiosis: " if side == 0 else "Rival symbiosis: ") + (", ".join(active) if not active.is_empty() else "mixed ecology"),12))
	battle_event_label = _wrap("The first searching roots touch unfamiliar soil.",14,Color("b9c7a1"))
	side_content.add_child(battle_event_label)
	side_content.add_child(_wrap("One shared flowering. Release Bloom Burst once the garden has gathered enough light. Pause to read any organism.",12))

func _update_battle_event(event: Dictionary) -> void:
	if not is_instance_valid(battle_event_label) or sim == null: return
	var names: Dictionary = {}
	for fighter in sim.fighters: names[str(fighter.id)] = str(fighter.plant.name)
	var source: String = str(names.get(str(event.get("source","")),"The roots"))
	var target: String = str(names.get(str(event.get("target","")),"the soil"))
	var verb: String = "reaches toward"
	match str(event.get("kind","root")):
		"entangle": verb = "entangles"
		"toxin": verb = "seeps into"
		"spore": verb = "settles spores over"
		"parasite": verb = "draws vitality from"
		"shade": verb = "casts shade over"
		"devour": verb = "closes around"
		"bloom": verb = "opens its core toward"
		"wither": battle_event_label.text = target + " quietly folds into the soil."; return
	if float(event.get("amount",0)) < 0: verb = "shares vitality with"
	battle_event_label.text = "%s %s %s." % [source,verb,target]

func _toggle_pause() -> void:
	if sim == null: return
	paused = not paused
	pause_button.text = "Resume" if paused else "Pause"
	_toast("Roots rest. Inspect any plant." if paused else "Growth resumes.")

func _toggle_speed() -> void:
	if sim == null: return
	speed = 2.0 if speed == 1.0 else 1.0
	speed_button.text = "Speed · %d×" % int(speed)
	_toast("Time flows at %d×." % int(speed))

func _bloom_burst() -> void:
	if sim == null or paused: return
	if sim.team_burst():
		last_log = "The garden opens as one. A single, shared flowering."
		status_label.text = last_log
		for c in cells.values(): c.portrait.activity = 1.0
	else: _toast("The garden is gathering light. Bloom Burst is ready at 25 seconds, once per battle.")

func _update_combat_ui() -> void:
	if sim == null: return
	var seconds: int = int(sim.elapsed)
	timer_label.text = "%02d:%02d / 02:30" % [seconds/60,seconds%60]
	burst_button.disabled = sim.burst_used or float(sim.team_charge) < 100 or paused
	burst_button.text = "Bloom spent" if sim.burst_used else ("Release Bloom Burst" if float(sim.team_charge) >= 100 else "Bloom · gathering %d%%" % int(sim.team_charge))
	if is_instance_valid(battle_health_label):
		battle_health_label.text = "Your roots   %d     /     Rival   %d" % [int(sim.remaining(0)),int(sim.remaining(1))]
		var maximums: Array = [0.0,0.0]
		for fighter in sim.fighters: maximums[int(fighter.side)] += float(fighter.max_hp)
		battle_player_meter.value = sim.remaining(0)/maxf(1,maximums[0])*100
		battle_enemy_meter.value = sim.remaining(1)/maxf(1,maximums[1])*100
	for f in sim.fighters:
		var lookup: Dictionary = cells if int(f.side) == 0 else enemy_cells
		if lookup.has(str(f.id)):
			var cell: Control = lookup[str(f.id)]
			cell.fighter = f
			cell.queue_redraw()

func _finish_battle() -> void:
	var won: bool = int(sim.winner) == 0
	var draw: bool = int(sim.winner) == -1
	var summary_text: String = sim.summary()
	var result: Dictionary = state.battle_reward(won)
	sim = null
	paused = false
	if is_instance_valid(effects): effects.clear_effects()
	opponent_panel.visible = false
	display_grid.visible = true
	tray_scroll.visible = true
	battle_controls.visible = false
	tray_panel.battle_locked = false
	primary_button.disabled = false
	last_log = "The garden settles. Every specimen returns to its own soil."
	_refresh()
	_open_modal("A shared flowering" if won else ("A fragile equilibrium" if draw else "A lesson in coexistence"), "result")
	modal_content.add_child(_label("VICTORY" if won else ("EQUILIBRIUM" if draw else "THE OTHER GARDEN PREVAILS"),11,AMBER))
	modal_content.add_child(_wrap(summary_text,16,INK))
	modal_content.add_child(_wrap(str(result.get("message","New seeds settle into the archive.")),17,Color("bfd0a5")))
	modal_content.add_child(_wrap("All your plants recover. Their genes, arrangement, and full lineages are preserved. Use what you noticed to breed the next generation.",14))
	modal_content.add_child(_button("Return to my garden",func(): _close_modal(); _refresh(),Vector2(0,50)))
	modal_content.add_child(_button("Open the seed archive", _open_seeds))
	modal_content.add_child(_button("Breed the next generation",func(): _open_lab()))

func _process(delta: float) -> void:
	if is_instance_valid(modal): _position_modal()
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0: toast_panel.visible = false
	save_timer += delta
	if save_timer >= 1.0:
		save_timer = 0
		if state.tick_growth():
			last_log = "A new specimen has unfurled. Its first mature leaves gather light."
			if sim == null: _refresh()
		if state.last_seed_collection > 0 and int(Time.get_unix_time_from_system()) - state.last_seed_collection >= 180:
			var harvest: Dictionary = state.collect_mature_seeds()
			if harvest.get("ok",false):
				_toast(str(harvest.get("message","Mature plants have left new seeds.")))
				if sim == null: _refresh()
	if sim != null and not paused:
		sim.update(delta*speed)
		if not sim.events.is_empty():
			if is_instance_valid(effects): effects.add_events(sim.events)
			_update_battle_event(sim.events.back())
			for event in sim.events:
				var source: String = str(event.get("source",""))
				if cells.has(source) and is_instance_valid(cells[source].portrait): cells[source].portrait.activity = 0.55
				if enemy_cells.has(source) and is_instance_valid(enemy_cells[source].portrait): enemy_cells[source].portrait.activity = 0.55
		combat_ui_timer += delta
		if combat_ui_timer >= 0.12:
			combat_ui_timer = 0
			_update_combat_ui()
		if sim.finished: _finish_battle()
