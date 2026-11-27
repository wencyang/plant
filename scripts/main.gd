extends Node2D
## Bloomward — main flow: title → garden map → level (grow, lure, prune,
## pollinate, replant) → bloom. Seed vault persists between sessions.

const Session := preload("res://scripts/session.gd")
const Levels := preload("res://scripts/levels.gd")
const Genome := preload("res://scripts/genome.gd")
const PlantSim := preload("res://scripts/plant_sim.gd")
const SaveData := preload("res://scripts/save_data.gd")
const Guidance := preload("res://scripts/garden_guidance.gd")
const LevelView := preload("res://scripts/view/level_view.gd")
const PlantView := preload("res://scripts/view/plant_view.gd")
const Sfx := preload("res://scripts/sfx.gd")

const INK := Color("e9efe6")
const DIM := Color(0.75, 0.8, 0.78, 0.75)
const PANEL := Color(0.035, 0.05, 0.065, 0.96)

var save
var sfx
var font: Font
var title_font: FontVariation
var mode := "title"
var session
var level_index := 0
var current_seed: Dictionary
var view: Node2D
var ui: CanvasLayer
var ui_root: Control
var hud: Control
var hud_title: Label
var hud_hint: Label
var hud_meter: Control
var toast: Label
var overlay: Control = null
var paused := false
var fast := false
var time_scale := 1.0
var won_shown := false
var stuck_shown := false
var stuck_panel: Control = null
var reasons: Dictionary = {}
var press_pos := Vector2.ZERO
var pressing := false
var swiping := false
var drag_lure := -1
var swipe_pts: Array = []
var demo_lure_t := 0.0
var pending_cross: Array = []
var save_path: String=SaveData.PATH
var quiet_preview: bool=false
var hud_why: Label
var hud_progress: Label
var hud_gifts: Label
var growth_button: Button
var guide_button: Button
var latest_guidance: Dictionary={}
var guidance_elapsed: float=0.0
var selected_seed: Dictionary={}
var seed_selection_label: Label
var seed_plan_label: Label
var seed_start_button: Button
var seed_card_nodes: Array[Control]=[]
var cross_origin: Dictionary={}
var explanation_until: float=0.0
var breeding_random:=RandomNumberGenerator.new()
var undo_button: Button
var drag_lure_changed: bool=false
var earned_crosses: Dictionary={}
var drag_lure_origin:=Vector2.INF

const STOP_TEXT := {
	"droop": "drooped — no rock to lean on",
	"slick": "slipped on glass",
	"blocked": "blocked",
	"burn": "withered in the heat",
	"edge": "left the garden",
	"stuck": "wedged — no way forward",
}

func _ready() -> void:
	randomize()
	breeding_random.randomize()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Avenir Next", "Futura", "Helvetica Neue", "Arial"])
	f.font_weight = 500
	font = f
	title_font = FontVariation.new()
	var tf := SystemFont.new()
	tf.font_names = PackedStringArray(["Futura", "Avenir Next", "Helvetica Neue"])
	tf.font_weight = 500
	title_font.base_font = tf
	title_font.spacing_glyph = 16
	ThemeDB.fallback_font = f
	save = SaveData.new(save_path)
	sfx = Sfx.new()
	add_child(sfx)
	sfx.muted = save.muted or quiet_preview
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.background_canvas_max_layer = 2
	e.glow_enabled = true
	e.glow_intensity = 0.85
	e.glow_strength = 1.0
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.set_glow_level(1, 0.6)
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.9)
	e.set_glow_level(4, 0.6)
	e.set_glow_level(5, 0.4)
	env.environment = e
	add_child(env)
	view = LevelView.new()
	add_child(view)
	var cam := Camera2D.new()
	cam.position = Vector2(800, 500)
	add_child(cam)
	var vig := CanvasLayer.new()
	vig.layer = 1
	add_child(vig)
	var vr := ColorRect.new()
	vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://shaders/vignette.gdshader")
	vr.material = vm
	vig.add_child(vr)
	ui = CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _theme()
	ui.add_child(ui_root)
	_build_hud()
	show_title()

# ================================================================== theme / widgets

func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 20
	for state in ["normal", "hover", "pressed", "disabled"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(1, 1, 1, 0.06), "hover": Color(1, 1, 1, 0.14), "pressed": Color(1, 1, 1, 0.2), "disabled": Color(1, 1, 1, 0.02)}[state]
		b.border_color = Color(0.85, 1.0, 0.92, 0.35 if state != "hover" else 0.7)
		b.set_border_width_all(1)
		b.set_corner_radius_all(22)
		b.content_margin_left = 22
		b.content_margin_right = 22
		b.content_margin_top = 9
		b.content_margin_bottom = 10
		th.set_stylebox(state, "Button", b)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	th.set_color("font_color", "Label", INK)
	var p := StyleBoxFlat.new()
	p.bg_color = PANEL
	p.border_color = Color(0.8, 1.0, 0.9, 0.18)
	p.set_border_width_all(1)
	p.set_corner_radius_all(18)
	p.content_margin_left = 26
	p.content_margin_right = 26
	p.content_margin_top = 22
	p.content_margin_bottom = 22
	th.set_stylebox("panel", "PanelContainer", p)
	th.set_color("default_color", "RichTextLabel", INK)
	th.set_font_size("normal_font_size", "RichTextLabel", 19)
	th.set_font_size("bold_font_size", "RichTextLabel", 20)
	return th

func _button(text: String, cb: Callable, size_px := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size_px)
	b.pressed.connect(func():
		sfx.play("ui", 1.2, -6)
		cb.call())
	b.pressed.connect(func():
		if is_instance_valid(b) and b.is_inside_tree(): b.release_focus())
	return b

func _label(text: String, size_px: int, col := INK, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = f if f != null else font
	ls.font_size = size_px
	ls.font_color = col
	ls.shadow_color = Color(0, 0, 0, 0.5)
	ls.shadow_size = 6
	ls.shadow_offset = Vector2(0, 2)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _new_overlay(dim := 0.55, hide_world := false) -> Control:
	if pressing and mode=="play": _cancel_gesture(false)
	_close_overlay()
	view.visible = not hide_world
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(shade)
	ui_root.add_child(o)
	overlay = o
	o.modulate.a = 0.0
	o.create_tween().tween_property(o, "modulate:a", 1.0, 0.35)
	return o

func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay): overlay.queue_free()
	overlay = null
	view.visible = true

func _toast(text: String, dur := 2.6) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	var tw := toast.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(toast, "modulate:a", 0.0, 0.6)

# ================================================================== HUD

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud)
	hud_title = _label("", 30, INK, title_font)
	hud_title.position = Vector2(36, 26)
	hud.add_child(hud_title)
	hud_hint = _label("", 18, DIM)
	hud_hint.position = Vector2(38, 72)
	hud_hint.size = Vector2(1060, 28)
	hud_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hud.add_child(hud_hint)
	hud_why=_label("",14,DIM)
	hud_why.position=Vector2(38,102)
	hud_why.size=Vector2(1060,31)
	hud_why.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud_why.max_lines_visible=2
	hud.add_child(hud_why)
	hud_progress=_label("",17,Color(1.0,0.89,0.58))
	hud_progress.position=Vector2(1120,82)
	hud_progress.size=Vector2(440,26)
	hud_progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(hud_progress)
	hud_gifts=_label("",13,DIM)
	hud_gifts.position=Vector2(1170,109)
	hud_gifts.size=Vector2(390,45)
	hud_gifts.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud_gifts.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(hud_gifts)
	undo_button=_button("Undo [Z]",_undo_action,16)
	undo_button.position=Vector2(1116,25)
	undo_button.custom_minimum_size=Vector2(117,40)
	undo_button.set_meta("game_action","undo")
	undo_button.tooltip_text="Rewind growth since the last lure action or cut. Earned seeds stay in your vault."
	hud.add_child(undo_button)
	hud_meter = Control.new()
	hud_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_meter.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_meter.draw.connect(_draw_meter)
	hud.add_child(hud_meter)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -790
	row.offset_right = -36
	row.offset_top = -80
	row.offset_bottom = -30
	row.alignment = BoxContainer.ALIGNMENT_END
	hud.add_child(row)
	growth_button=_button("Pause",_toggle_growth)
	growth_button.set_meta("game_action","growth")
	row.add_child(growth_button)
	var help:=_button("Show me", _toggle_hint)
	guide_button=help
	help.set_meta("game_action","show_me")
	row.add_child(help)
	row.add_child(_button("Seeds", func(): show_vault(true)))
	row.add_child(_button("Fast", _toggle_fast))
	row.add_child(_button("Restart", func(): _start_level(level_index, current_seed,true)))
	row.add_child(_button("Map", show_map))
	row.name = "Buttons"
	toast = _label("", 24, Color(1.0, 0.95, 0.85))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-500, 120)
	toast.size = Vector2(1000, 40)
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast.size.y=70
	toast.max_lines_visible=2
	toast.modulate.a = 0.0
	ui_root.add_child(toast)

func _draw_meter() -> void:
	if mode != "play" or session == null: return
	var size := hud_meter.size
	var pl = session.plant
	var w := 300.0
	var x := size.x - w - 40.0
	var y := 40.0
	var frac: float = clampf(pl.energy / max(1.0, pl.energy_max), 0.0, 1.0)
	hud_meter.draw_string(font, Vector2(x, y - 8), "SAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	hud_meter.draw_string(font, Vector2(x + w - 60, y - 8), str(int(max(0.0, pl.energy))), HORIZONTAL_ALIGNMENT_RIGHT, 60, 14, DIM)
	hud_meter.draw_rect(Rect2(x, y, w, 10), Color(1, 1, 1, 0.08))
	var col := Color(0.55, 1.0, 0.7)
	hud_meter.draw_rect(Rect2(x, y, w * frac, 10), Color(col.r * 1.6, col.g * 1.6, col.b * 1.6))
	var dt: int = session.dew_total()
	if dt > 0:
		hud_meter.draw_string(font, Vector2(x, y + 34), "DEW  %d / %d" % [session.dew_taken(), dt], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.65, 0.9, 1.0) if session.dew_taken() == dt else DIM)
	var par: int = int(session.def.get("par", 99))
	if par < 99:
		var over: bool = session.tools_used > par
		hud_meter.draw_string(font, Vector2(x + w - 150, y + 34), "TOOLS  %d / par %d" % [session.tools_used, par], HORIZONTAL_ALIGNMENT_RIGHT, 150, 14, Color(1.0, 0.6, 0.5) if over else DIM)
	# tools
	var bx := 40.0
	var by := 150.0
	hud_meter.draw_string(font, Vector2(bx, by - 18), "LURES  click to place · drag to move · right-click to recall", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	for i in int(session.def.get("lures", 0)):
		var c := Vector2(bx + 12 + i * 30, by + 6)
		var have: bool = i < session.lures_left
		hud_meter.draw_circle(c, 9, Color(0.55, 1.0, 0.95, 0.12 if have else 0.04))
		hud_meter.draw_circle(c, 4.5, Color(0.8, 2.2, 2.1) if have else Color(1, 1, 1, 0.15))
	var px := bx + 470.0
	hud_meter.draw_string(font, Vector2(px, by - 18), "PRUNES  swipe across a stem", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	for i in int(session.def.get("prunes", 0)):
		var c := Vector2(px + 12 + i * 30, by + 6)
		var have: bool = i < session.prunes_left
		var col2 := Color(1.6, 1.5, 1.2) if have else Color(1, 1, 1, 0.15)
		hud_meter.draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), col2, 2.0, true)
		hud_meter.draw_line(c + Vector2(-8, 8), c + Vector2(8, -8), col2, 2.0, true)

# ================================================================== title / demo

func _demo_level() -> Dictionary:
	return {"id": "demo", "palette": ["night", "teal", "dusk", "violet", "aurora", "coral", "jungle", "mist"][randi() % 8], "seed": Vector2(800, 900), "energy": 999999.0, "lures": 1, "prunes": 0,
		"rocks": [{"poly": Levels.ground(912, 10, 3), "soil": true}, {"poly": Levels.blob(330, 760, 150, 46, 3)}, {"poly": Levels.blob(1300, 720, 140, 44, 5)}],
		"goals": [], "wilds": _demo_wilds()}

func _demo_wilds() -> Array:
	var sp: Array = Levels.SPECIES.duplicate()
	sp.shuffle()
	return [{"pos": Vector2(250, 718), "genome": sp[0], "energy": 320.0}, {"pos": Vector2(1360, 680), "genome": sp[1], "energy": 300.0},
		{"pos": Vector2(1500, 906), "genome": sp[2], "energy": 280.0}, {"pos": Vector2(90, 906), "genome": sp[3], "energy": 260.0}]

func _demo_genome() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var names: Array = Levels.SPECIES.duplicate()
	names.shuffle()
	var a: Dictionary = Genome.cross(Levels.starter(), Levels.wild(names[0]), rng)[0]
	return Genome.cross(a, Levels.wild(names[1]), rng)[rng.randi_range(0, 1)]

func show_title() -> void:
	mode = "title"
	paused = false
	_start_demo()
	hud.visible = false
	sfx.music("shop")
	var o := _new_overlay(0.0)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _label("BLOOMWARD", 104, Color(0.92, 1.0, 0.95), title_font)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(-700, 150)
	t.size = Vector2(1400, 140)
	o.add_child(t)
	var sub := _label("grow toward the light  ·  prune to split  ·  cross-pollinate the strange", 22, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-700, 280)
	sub.size = Vector2(1400, 40)
	o.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.position = Vector2(-400, 350)
	row.size = Vector2(800, 50)
	o.add_child(row)
	row.add_child(_button("Begin", show_map, 24))
	row.add_child(_button("Seed Vault  (%d)" % save.seeds.size(), func(): show_vault(false), 20))
	row.add_child(_button("Sound: " + ("off" if save.muted else "on"), _toggle_sound, 20))

func _start_demo() -> void:
	session = Session.new()
	session.start(_demo_level(), _demo_genome(), randi())
	session.add_lure(Vector2(800, 500))
	view.build(session)
	view.show_guide = false
	demo_lure_t = 0.0

func _toggle_sound() -> void:
	save.muted = not save.muted
	save.save()
	sfx.set_muted(save.muted)
	if not save.muted:
		sfx.current_music = ""
		sfx.music("shop" if mode != "play" else "battle")
	if mode == "title": show_title()

# ================================================================== map

func show_map() -> void:
	mode = "map"
	paused = false
	if is_instance_valid(stuck_panel): stuck_panel.queue_free()
	stuck_panel=null
	hud.visible = false
	if session == null or session.def.id != "demo":
		_start_demo()
	sfx.music("shop")
	var o := _new_overlay(0.45)
	var head := _label("THE GARDENS", 46, Color(0.92, 1.0, 0.95), title_font)
	head.position = Vector2(80, 60)
	o.add_child(head)
	var sub := _label("Wake every sunwell to open the next garden. Extra stars are optional.   ✦ %d / %d" % [save.total_stars(), Levels.all().size() * 3], 19, DIM)
	sub.position = Vector2(84, 124)
	o.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	grid.position = Vector2(80, 190)
	o.add_child(grid)
	var all := Levels.all()
	for i in all.size():
		var L: Dictionary = all[i]
		var open: bool = save.unlocked(i)
		var done: bool = save.completed.has(L.id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(196, 120)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not open
		b.text = ""
		grid.add_child(b)
		var num := _label("%02d" % (i + 1), 13, DIM)
		num.position = Vector2(16, 12)
		b.add_child(num)
		var tl := _label(L.title if open else "Locked", 19, INK if open else Color(1, 1, 1, 0.3))
		tl.position = Vector2(16, 36)
		tl.size = Vector2(170, 50)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.add_child(tl)
		var sc: int = save.star_count(L.id)
		var stxt := "✦".repeat(sc) + "✧".repeat(3 - sc) if done else ("Open" if open else "")
		var st := _label(stxt, 18 if done else 14, Color(1.0, 0.85, 0.5) if done else DIM)
		st.position = Vector2(16, 88)
		b.add_child(st)
		var idx := i
		b.pressed.connect(func():
			sfx.play("ui", 1.1, -6)
			show_level_intro(idx))
	var back := _button("Back", show_title)
	back.position = Vector2(80, 620)
	o.add_child(back)
	var vault := _button("Seed Vault", func(): show_vault(false))
	vault.position = Vector2(190, 620)
	o.add_child(vault)

# ================================================================== level intro + seed choice

func show_level_intro(index: int) -> void:
	mode="intro"
	paused=true
	if is_instance_valid(stuck_panel): stuck_panel.queue_free()
	stuck_panel=null
	level_index=index
	var L: Dictionary=Levels.all()[index]
	var info: Dictionary=Guidance.level_info(L)
	var recommended: Dictionary=Guidance.recommend_seed(L,save.seeds)
	selected_seed=recommended.get("seed",save.seeds[0])
	var o:=_new_overlay(0.94,true)
	var title:=_label(L.title.to_upper(),42,Color(0.92,1,0.95),title_font)
	title.position=Vector2(80,44)
	o.add_child(title)
	var goal:=_label(str(info.get("objective","Wake every sunwell to bloom this garden.")),23,Color(1,0.9,0.6))
	goal.position=Vector2(84,111)
	o.add_child(goal)
	var brief:=_label(str(info.get("brief",L.intro)),19,INK)
	brief.position=Vector2(84,153)
	brief.size=Vector2(1430,58)
	brief.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	o.add_child(brief)
	var gifts:=HBoxContainer.new()
	gifts.position=Vector2(84,219)
	gifts.add_theme_constant_override("separation",10)
	o.add_child(gifts)
	gifts.add_child(_label("GIFTS FOR THIS GARDEN",13,DIM))
	var needed: Array=info.get("required_gifts",[])
	if needed.is_empty(): gifts.add_child(_chip("Any seed · learn "+str(info.get("learning_focus","steering")),Color(0.6,0.9,0.8)))
	for key: String in needed:
		var chip:=_chip(Genome.TRAIT_INFO[key].name,Genome.TRAIT_INFO[key].color)
		chip.tooltip_text=str(info.get("gift_reasons",{}).get(key,Genome.TRAIT_INFO[key].desc))
		gifts.add_child(chip)
	var pick:=_label("Select a seed below. You can place lures before starting growth.",16,DIM)
	pick.position=Vector2(84,272)
	o.add_child(pick)
	_seed_grid(o,Vector2(80,310),_select_seed,true)
	var footer:=PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left=80
	footer.offset_right=-80
	footer.offset_top=-116
	footer.offset_bottom=-22
	o.add_child(footer)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	footer.add_child(row)
	row.add_child(_button("Back",show_map,18))
	var summary:=VBoxContainer.new()
	summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(summary)
	seed_selection_label=_label("",19,INK)
	summary.add_child(seed_selection_label)
	seed_plan_label=_label("",14,DIM)
	seed_plan_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(seed_plan_label)
	seed_start_button=_button("Plant & plan",func(): _start_level(index,selected_seed,true),20)
	seed_start_button.set_meta("game_action","plant_selected")
	seed_start_button.custom_minimum_size=Vector2(255,54)
	row.add_child(seed_start_button)
	_select_seed(selected_seed)

func _select_seed(gnm: Dictionary) -> void:
	selected_seed=gnm
	var fit: Dictionary=Guidance.seed_fit(Levels.all()[level_index],gnm)
	if is_instance_valid(seed_selection_label): seed_selection_label.text=str(gnm.name)+" · "+str(fit.get("summary",""))
	if is_instance_valid(seed_plan_label): seed_plan_label.text=str(fit.get("source_explanation",fit.get("why",""))) if not bool(fit.get("ready",false)) else str(fit.get("why",""))
	for node: Control in seed_card_nodes:
		if not is_instance_valid(node): continue
		var chosen: bool=node.get_meta("seed_genome",{})==gnm
		node.modulate=Color.WHITE if chosen else Color(0.8,0.85,0.84)
		if chosen:
			var border:=StyleBoxFlat.new()
			border.bg_color=Color(0.14,0.25,0.2,0.85)
			border.border_color=Color(0.65,1.0,0.8)
			border.set_border_width_all(2)
			border.set_corner_radius_all(22)
			node.add_theme_stylebox_override("normal",border)
		else: node.remove_theme_stylebox_override("normal")

func _seed_grid(parent: Control,at: Vector2,on_pick: Callable,for_level: bool=false) -> void:
	var scroll:=ScrollContainer.new()
	scroll.position=at
	scroll.size=Vector2(minf(1460,maxf(280,ui_root.size.x-at.x-60)),minf(680,maxf(200,ui_root.size.y-at.y-130)))
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=maxi(1,floori((scroll.size.x-18+16)/286))
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	scroll.add_child(grid)
	seed_card_nodes.clear()
	var entries: Array=save.seeds.duplicate()
	if for_level:
		var best: Dictionary=Guidance.recommend_seed(Levels.all()[level_index],entries).get("seed",{})
		entries.sort_custom(func(a: Dictionary,b: Dictionary):
			var a_score: int=-1 if a==best else Guidance.seed_fit(Levels.all()[level_index],a).get("missing",[]).size()
			var b_score: int=-1 if b==best else Guidance.seed_fit(Levels.all()[level_index],b).get("missing",[]).size()
			return a_score<b_score)
	for gnm: Dictionary in entries:
		var card: Control=_seed_card(gnm,on_pick,270,330,for_level)
		grid.add_child(card)
		seed_card_nodes.append(card)

func _seed_card(gnm: Dictionary, on_pick: Callable, w := 270.0, h := 330.0, for_level: bool=false) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_ALL
	b.set_meta("seed_genome",gnm)
	b.set_meta("game_action","select_seed")
	b.clip_contents = true
	var holder := Node2D.new()
	holder.position = Vector2(w * 0.5, h - 128)
	b.add_child(holder)
	var pv := _preview_view(gnm, 0.56)
	holder.add_child(pv)
	var nl := _label(gnm.name, 22, INK)
	nl.position = Vector2(16, 10)
	b.add_child(nl)
	var gl := _label("G%d" % int(gnm.gen), 14, DIM)
	gl.position = Vector2(w - 44, 16)
	b.add_child(gl)
	var chips := GridContainer.new()
	chips.columns=3
	chips.position = Vector2(14, h - 116)
	chips.add_theme_constant_override("separation", 6)
	b.add_child(chips)
	var traits := Genome.traits(gnm)
	if traits.is_empty(): chips.add_child(_chip("no gifts", Color(1, 1, 1, 0.35)))
	for tr in traits: chips.add_child(_chip(Genome.TRAIT_INFO[tr].name, Genome.TRAIT_INFO[tr].color))
	var feat := _label("%s leaves · %s flowers\n%s · %s stem" % [Genome.LEAF_NAMES[int(gnm.leaf_shape)], Genome.FLOWER_NAMES[int(gnm.flower)], Genome.PATTERN_NAMES[int(gnm.pattern)], Genome.STEM_NAMES[int(gnm.stem)]], 13, DIM)
	feat.position = Vector2(16, h - 60)
	b.add_child(feat)
	if for_level:
		var fit: Dictionary=Guidance.seed_fit(Levels.all()[level_index],gnm)
		var badge:=_label(str(fit.get("summary","")),12,Color(0.65,1,0.8) if bool(fit.get("ready",false)) else Color(1,0.82,0.52))
		badge.position=Vector2(16,42)
		badge.size=Vector2(w-30,25)
		badge.clip_text=true
		b.add_child(badge)
		b.tooltip_text=str(fit.get("why",""))
	elif gnm.get("parents", []).size() == 2:
		var par := _label("%s × %s" % [gnm.parents[0], gnm.parents[1]], 12, Color(1, 1, 1, 0.45))
		par.position = Vector2(16, 40)
		b.add_child(par)
	b.pressed.connect(func():
		sfx.play("ui", 1.0, -6)
		on_pick.call(gnm))
	return b

func _chip(text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.18)
	sb.border_color = Color(col, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, 13, col.lightened(0.3))
	l.label_settings.shadow_size = 0
	p.add_child(l)
	return p

func _preview_view(gnm: Dictionary, k: float) -> Node2D:
	var sim = PlantSim.new()
	sim.setup(gnm, null, 300.0, hash(str(gnm.name)) % 1000 + 3, true)
	sim.grow_wild(300.0, Vector2.ZERO)
	var v := PlantView.new()
	v.setup(sim, true)
	v.preview = true
	v.scale = Vector2(k, k)
	return v

func show_vault(in_level: bool) -> void:
	var was_paused: bool=paused
	paused=true
	var o:=_new_overlay(0.94,true)
	var title:=_label("SEED VAULT",40,Color(0.92,1.0,0.95),title_font)
	title.position=Vector2(80,45)
	o.add_child(title)
	var sub:=_label("Your reusable seeds. Select one to read its gifts; seeds are never spent.",18,DIM)
	sub.position=Vector2(84,105)
	o.add_child(sub)
	var note:=_label("Replanting starts this garden over with the selected seed. Your vault and earned stars stay safe." if in_level else "Grow into a wild plant to breed more seeds. The first child keeps every gift from both parents.",16,Color(1,0.88,0.6))
	note.position=Vector2(84,144)
	o.add_child(note)
	var recommendation: Dictionary=Guidance.recommend_seed(Levels.all()[level_index],save.seeds)
	selected_seed=recommendation.get("seed",save.seeds[0]) if in_level else save.seeds[0]
	_seed_grid(o,Vector2(80,194),func(g: Dictionary):
		if in_level: _select_seed(g)
		else:
			selected_seed=g
			seed_selection_label.text=str(g.name)
			var descriptions: Array[String]=[]
			for gift: String in Genome.traits(g): descriptions.append(str(Genome.TRAIT_INFO[gift].desc))
			seed_plan_label.text=" ".join(descriptions) if not descriptions.is_empty() else "No special gifts. Steer with light lures and split stems by pruning.",in_level)
	var footer:=PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left=80
	footer.offset_right=-80
	footer.offset_top=-116
	footer.offset_bottom=-22
	o.add_child(footer)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	footer.add_child(row)
	row.add_child(_button("Keep current plant" if in_level else "Close",func():
		_close_overlay()
		paused=was_paused
		if not in_level and mode=="title": show_title()
		elif not in_level and mode=="map": show_map()
		elif not pending_cross.is_empty(): call_deferred("_show_cross"),18))
	var summary:=VBoxContainer.new()
	summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(summary)
	seed_selection_label=_label(str(selected_seed.name),18,INK)
	summary.add_child(seed_selection_label)
	seed_plan_label=_label("Select a seed to read what its gifts do.",14,DIM)
	seed_plan_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(seed_plan_label)
	if in_level:
		var replant:=_button("Replant this garden",func(): _start_level(level_index,selected_seed,true),20)
		replant.set_meta("game_action","replant_selected")
		row.add_child(replant)
		_select_seed(selected_seed)

# ================================================================== play

func _start_level(index: int, gnm: Dictionary,plan_first: bool=false) -> void:
	_close_overlay()
	if stuck_panel != null and is_instance_valid(stuck_panel): stuck_panel.queue_free()
	stuck_panel = null
	level_index = index
	current_seed = gnm
	mode = "play"
	paused = plan_first
	explanation_until=0.0
	won_shown = false
	stuck_shown = false
	reasons.clear()
	pending_cross.clear()
	earned_crosses.clear()
	drag_lure = -1
	drag_lure_changed=false
	pressing = false
	swiping = false
	swipe_pts = []
	var L: Dictionary = Levels.all()[index]
	session = Session.new()
	session.start(L, gnm, 1 + index * 17)
	view.build(session)
	view.set_label_safe_rect(Rect2(24,180,1552,695))
	view.plant_view.show_reach = true
	view.show_guide = index <= 1 or not save.completed.has(L.id) and int(save.get_meta("fails_" + L.id, 0)) >= 1
	hud.visible = true
	hud_title.text = L.title.to_upper()
	_update_guidance()
	sfx.music("battle")
	sfx.play("start", 1.0, -8)
	_toast("Plan your route, then press Grow." if plan_first else "Planted %s" % gnm.name, 2.0)

func _toggle_hint() -> void:
	if session==null or mode!="play": return
	_update_guidance()
	var kind: String=str(latest_guidance.get("target_kind",""))
	var index: int=int(latest_guidance.get("target_index",-1))
	if kind in ["vault","fruit"]:
		show_vault(true)
		return
	if kind=="garden":
		if index>=0 and save.unlocked(index): show_level_intro(index)
		else: show_map()
		return
	view.show_guide=true
	if kind in ["goal","wild","switch","lure","decoy"] and index>=0: view.focus_target(kind,index,8.0)
	else:
		var target: Vector2=latest_guidance.get("target",Vector2.INF)
		if target.is_finite(): view.focus_position(target,str(latest_guidance.get("title","")),8.0)
	explanation_until=Time.get_ticks_msec()/1000.0+6.0
	hud_why.text=str(latest_guidance.get("why",""))

func _toggle_growth() -> void:
	if mode!="play" or overlay!=null: return
	paused=not paused
	_update_guidance()
	_toast("Paused · move lures or prune, then press Grow." if paused else "Growing · guide the leading shoot toward light.",1.8)

func _update_guidance() -> void:
	if session==null or mode!="play": return
	latest_guidance=Guidance.next_step(session,save.seeds)
	hud_progress.text=str(latest_guidance.get("progress",""))
	hud_hint.text=("PLAN · " if paused and session.world.time<0.1 else ("PAUSED · " if paused else "NEXT · "))+str(latest_guidance.get("title",""))
	hud_why.text=str(latest_guidance.get("why","")) if Time.get_ticks_msec()/1000.0<explanation_until else str(latest_guidance.get("action",""))
	if paused and session.world.time<0.1:
		if level_index==0: hud_why.text="Place a light lure beside the rock, then press Grow. Drag the lure to steer the leading shoot."
		elif level_index==1: hud_why.text="Press Grow. Once a stem appears, swipe across it to make two leading shoots."
		else: hud_why.text="Arrange a light lure toward the marked target, then press Grow. You can pause and adjust at any time."
	growth_button.text="Grow [Space]" if paused else "Pause [Space]"
	guide_button.text="Choose seed" if str(latest_guidance.get("target_kind","")) in ["vault","fruit"] else ("Find source" if str(latest_guidance.get("target_kind",""))=="garden" else "Show me [H]")
	guide_button.tooltip_text=str(latest_guidance.get("why",""))
	var gifts: Array=Genome.traits(current_seed)
	hud_gifts.text="Growing %s · %s" % [current_seed.name,Guidance.gift_names(gifts) if not gifts.is_empty() else "no special gifts"]
	undo_button.disabled=not session.can_undo() or won_shown or session.won() or pressing
	undo_button.tooltip_text=("Undo %s. Growth since that action also rewinds; earned seeds stay kept." % session.undo_label()) if session.can_undo() else "Place, move or recall a lure, or prune a stem, to make an undo point."
	growth_button.disabled=pressing or won_shown
	if pressing:
		hud_hint.text="AIMING · move the light lure" if drag_lure>=0 else ("PRUNING · preview the cut" if swiping else "AIMING · growth is waiting")
		hud_why.text="Growth waits while you aim. Release to apply; right-click or Esc to cancel without spending a tool."

func _toggle_fast() -> void:
	fast = not fast
	_toast("Growth ×2" if fast else "Growth ×1", 1.0)

func _process(delta: float) -> void:
	if session == null: return
	if mode == "title" or mode == "map":
		demo_lure_t += delta
		session.world.lures[0] = Vector2(800 + sin(demo_lure_t * 0.23) * 560, 430 + sin(demo_lure_t * 0.31) * 170)
		session.step(delta)
		_drain_events()
		if session.plant.pos.size() > 1100 or session.stuck():
			_start_demo()
		return
	if mode != "play": return
	hud_meter.queue_redraw()
	guidance_elapsed+=delta
	if guidance_elapsed>=0.25:
		guidance_elapsed=0
		_update_guidance()
	if paused or pressing: return
	var steps := 2 if fast else 1
	for i in steps:
		session.step(delta)
	_drain_events()
	if session.plant.energy <= 0.0 and not reasons.has("sap"):
		reasons["sap"] = 1
		for tip in session.plant.tips:
			if tip.kind == 0 and tip.state == "grow" and int(tip.get("rank", 0)) == 0:
				view.fx.label(session.plant.pos[tip.node], "out of sap", Color(1.0, 0.8, 0.5), 4.0)
				break
		hud_meter.modulate = Color(1.6, 0.6, 0.6)
		hud_meter.create_tween().tween_property(hud_meter, "modulate", Color.WHITE, 1.2)
	if session.won() and not won_shown:
		won_shown = true
		_on_win()
	elif session.stuck() and not stuck_shown and not won_shown and pending_cross.is_empty():
		stuck_shown = true
		_on_stuck()

func _drain_events() -> void:
	var evs: Array = session.plant.events
	if evs.is_empty(): return
	session.plant.events = []
	var demo: bool = mode != "play"
	for e in evs:
		match e.t:
			"goal":
				view.fx.burst(e.pos, view.pal.sun, 50, 260.0, 0.0, 3.0, 1.6)
				view.fx.ring(e.pos, view.pal.sun, 220.0, 1.2)
				sfx.play("bloom", 1.0)
				_toast("A sunwell awakens")
			"pollinate":
				var w = session.world.wilds[e.i]
				view.fx.pollen_stream(w.pos + Vector2(0, -80), e.pos, Color(1.0, 0.9, 0.5))
				view.fx.burst(e.pos, Color(1.0, 0.9, 0.5), 24, 120.0, -20.0, 2.0, 1.4)
				if demo: continue
				sfx.play("cross", 1.0)
				save.species_met[w.genome.species] = true
				if _queue_cross(w.genome,int(e.i)):
					_toast("Pollinated %s!" % w.genome.name)
					var cross_session=session
					get_tree().create_timer(1.5).timeout.connect(func():
						if session==cross_session: _show_cross())
				else: _toast("The seeds from %s are already safe in your vault." % w.genome.name)
			"crystal":
				view.fx.burst(e.pos, Color(0.6, 1.0, 1.0), 60, 300.0, 300.0, 2.6, 1.4)
				view.fx.ring(e.pos, Color(0.6, 1.0, 1.0), 140.0, 0.6)
				sfx.play("zap", 0.8)
				if not demo: _toast("Crystal shattered!")
			"stop":
				reasons[e.why] = int(reasons.get(e.why, 0)) + 1
				if e.why == "burn": view.fx.burst(e.pos, Color(1.0, 0.5, 0.2), 14, 80.0, -60.0, 1.8, 1.0)
				else: view.fx.burst(e.pos, Color(0.9, 0.8, 0.6), 6, 40.0, 30.0, 1.5, 0.8)
				if not demo and e.leader:
					var msg: String = STOP_TEXT.get(e.why, "")
					if msg != "": view.fx.label(e.pos, msg, Color(1.0, 0.75, 0.6))
			"lean":
				if not demo: view.fx.ring(e.pos, Color(0.5, 1.0, 0.65), 26.0, 0.5)
			"dew":
				view.fx.burst(e.pos, Color(0.5, 0.9, 1.0), 26, 140.0, 40.0, 2.2, 1.2)
				view.fx.ring(e.pos, Color(0.6, 0.95, 1.0), 60.0, 0.6)
				sfx.play("pop", 1.6, -2)
				if not demo: view.fx.label(e.pos, "+ sap  (%d/%d dew)" % [session.dew_taken(), session.dew_total()], Color(0.7, 0.95, 1.0), 1.8)
			"switch":
				view.fx.burst(e.pos, Color(1.0, 0.85, 0.4), 40, 200.0, 0.0, 2.4, 1.4)
				view.fx.ring(e.pos, Color(1.0, 0.85, 0.4), 120.0, 0.9)
				sfx.play("zap", 1.3)
				if not demo:
					_toast("A stone gate grinds open")
					for ri in e.opened: view.open_gate(ri)
			"drink":
				view.fx.burst(e.pos, Color(0.5, 0.85, 1.0), 3, 30.0, -40.0, 1.6, 0.9)
	if not demo:
		for tip in session.plant.tips:
			if tip.state == "stalled": reasons["dark"] = 1

# ================================================================== input

func _event_world_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return get_canvas_transform().affine_inverse()*event.position
	return get_global_mouse_position()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and pressing and mode=="play": _cancel_gesture(false)

# Finish a gesture even when its release falls over a HUD button. A release
# must never leave the simulation waiting for a mouse button no longer held.
func _input(event: InputEvent) -> void:
	if mode!="play" or overlay!=null or not pressing: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_gesture()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_gesture()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_Z]:
		_cancel_gesture()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if mode!="play" or overlay!=null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if pressing: return
		match event.keycode:
			KEY_R: _start_level(level_index,current_seed,true)
			KEY_ESCAPE: show_map()
			KEY_F: _toggle_fast()
			KEY_S: show_vault(true)
			KEY_H: _toggle_hint()
			KEY_SPACE: _toggle_growth()
			KEY_Z: _undo_action()
		return
	var pos: Vector2=_event_world_position(event)
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			var index: int=_lure_at(pos)
			if index>=0 and session.remove_lure(index):
				sfx.play("back",1.2,-6)
				view.show_lure_feedback(pos,"Lure recalled · ready to place again",true,1.8)
				_update_guidance()
			return
		if event.button_index!=MOUSE_BUTTON_LEFT: return
		if event.pressed:
			pressing=true
			press_pos=pos
			swiping=false
			swipe_pts=[pos]
			drag_lure=_lure_at(pos)
			drag_lure_changed=false
			drag_lure_origin=session.world.lures[drag_lure] if drag_lure>=0 else Vector2.INF
			undo_button.disabled=true
		else: _finish_gesture()
	elif event is InputEventMouseMotion:
		view.set_pointer_world(pos)
		view.hover_lure=_lure_at(pos)
		if not pressing: return
		if drag_lure>=session.world.lures.size(): drag_lure=-1
		if drag_lure>=0:
			if not session.world.in_dark(pos) and session.world.bounds.has_point(pos):
				if session.move_lure(drag_lure,pos,drag_lure_changed): drag_lure_changed=true
				view.set_lure_preview(pos,true,"Release to keep this lure here · right-click to cancel")
			else:
				view.set_lure_preview(pos,false,"Darkness blocks this spot" if session.world.in_dark(pos) else "Keep the lure inside this garden")
			return
		if not swiping and pos.distance_to(press_pos)>14.0: swiping=true
		if swiping:
			if swipe_pts.is_empty() or pos.distance_to(swipe_pts.back())>6.0: swipe_pts.append(pos)
			view.fx.trail=swipe_pts.duplicate()
			view.set_prune_preview(swipe_pts)

func _clear_gesture() -> void:
	pressing=false
	swiping=false
	drag_lure=-1
	drag_lure_changed=false
	drag_lure_origin=Vector2.INF
	swipe_pts=[]
	if is_instance_valid(view):
		view.clear_lure_preview()
		view.clear_prune_preview()
		if is_instance_valid(view.fx): view.fx.trail=[]

func _finish_gesture() -> void:
	if not pressing: return
	if drag_lure>=0:
		if drag_lure_changed and session.world.lures[drag_lure].is_equal_approx(drag_lure_origin): session.cancel_lure_move()
		else: session.finish_lure_move()
	elif swiping: _finish_swipe()
	else: _place_lure(press_pos)
	_clear_gesture()
	_update_guidance()
	if not pending_cross.is_empty(): call_deferred("_show_cross")

func _cancel_gesture(feedback: bool=true) -> void:
	if drag_lure>=0 and drag_lure_changed: session.cancel_lure_move()
	_clear_gesture()
	_update_guidance()
	if feedback: _toast("Cancelled · no tool spent. Your garden is unchanged.",1.8)
	if not pending_cross.is_empty(): call_deferred("_show_cross")

func _undo_action() -> void:
	if mode!="play" or overlay!=null: return
	if pressing:
		_cancel_gesture()
		return
	if won_shown or session.won(): return
	var result: Dictionary=session.undo()
	if not bool(result.get("ok",false)): return
	# Earned offspring live in SaveData and the attempt ledger. Rewinding the
	# physical world neither deletes those seeds nor creates another reward.
	pending_cross.clear()
	session.plant.events=[]
	stuck_shown=false
	reasons.clear()
	if is_instance_valid(stuck_panel): stuck_panel.queue_free()
	stuck_panel=null
	var hints: bool=view.show_guide
	view.build(session)
	view.plant_view.show_reach=true
	view.show_guide=hints
	paused=true
	_update_guidance()
	sfx.play("back",1.0,-6)
	_toast("Undid %s · back in planning. Earned seeds stay kept." % str(result.action),2.5)

func _lure_at(pos: Vector2) -> int:
	if session == null: return -1
	for i in session.world.lures.size():
		if pos.distance_to(session.world.lures[i]) < 26.0: return i
	return -1

func _place_lure(pos: Vector2) -> void:
	if not session.world.bounds.has_point(pos):
		view.show_lure_feedback(pos,"Place the lure inside this garden",false,2.5)
		return
	if session.world.in_dark(pos):
		_toast("Lures fizzle out in the dark.")
		view.show_lure_feedback(pos,"Darkness blocks light lures · breed Glow to grow here",false,3.0)
		sfx.play("back", 1.0, -6)
		return
	if not session.add_lure(pos):
		_toast("No lures left — drag one to move it, right-click to recall it.")
		view.show_lure_feedback(pos,"Drag an existing lure, or right-click it to recall",false,3.0)
		sfx.play("back", 1.0, -6)
		return
	view.fx.ring(pos, Color(0.55, 1.0, 0.95), 70.0, 0.5)
	view.show_lure_feedback(pos,"Light lure · drag to steer; right-click to reclaim",true,2.2)
	_update_guidance()
	sfx.play("pop", 1.4, -4)

func _finish_swipe() -> void:
	if session.prunes_left <= 0:
		_toast("No prunes left.")
		view.fx.trail_fade.append([swipe_pts.duplicate(), 0.35])
		return
	var forecast: Dictionary=session.plant.preview_prune_path(swipe_pts)
	var removed: Array = session.prune_path(swipe_pts)
	view.fx.trail_fade.append([swipe_pts.duplicate(), 0.35])
	if removed.is_empty():
		_toast("No stem crossed. Swipe a short line across the green stem; no prune was spent.")
		view.show_action_feedback(swipe_pts.back(),"Swipe across a living stem, not empty air",false,3.0,"No cut made")
		return
	var segs: Array = []
	for r in removed: segs.append([r[0], r[1]])
	view.fx.add_debris(segs, view.plant_view.c_stem_tip)
	view.fx.burst(swipe_pts[swipe_pts.size() / 2], view.plant_view.c_leaf_b, 18, 140.0, 200.0, 2.0, 1.0)
	sfx.play("swish", 0.9)
	var shoots: int=int(forecast.get("new_shoots",0))
	_toast("Pruned · %d fresh shoots can take new paths." % shoots if shoots>0 else "Pruned · sap reclaimed from the cut growth.")
	_update_guidance()
	# pruning can wake a stalled plant
	stuck_shown = false
	if stuck_panel != null and is_instance_valid(stuck_panel):
		stuck_panel.queue_free()
		stuck_panel = null

# ================================================================== cross reveal

func _queue_cross(wild_g: Dictionary,wild_index: int=-1) -> bool:
	if wild_index>=0 and earned_crosses.has(wild_index): return false
	var parent: Dictionary=current_seed.duplicate(true)
	var kids: Array=Genome.cross(parent,wild_g,breeding_random)
	# Rewards are earned at contact, even if the player opens the map before
	# the reveal animation. A popup never creates or rerolls the offspring.
	for child: Dictionary in kids: save.add_seed(child)
	var fruit: Dictionary={"parent":parent,"wild":wild_g.duplicate(true),"kids":kids}
	if wild_index>=0: earned_crosses[wild_index]=fruit.duplicate(true)
	pending_cross.append(fruit)
	return true

func _show_cross() -> void:
	if pending_cross.is_empty() or mode != "play" or overlay!=null or pressing: return
	var fruit: Dictionary=pending_cross.pop_front()
	var wild_g: Dictionary=fruit.wild
	var parent: Dictionary=fruit.parent
	var kids: Array=fruit.kids
	cross_origin=parent
	var was_paused: bool=paused
	paused = true
	var o := _new_overlay(0.94, true)
	var t := _label("CROSS-POLLINATED", 40, Color(1.0, 0.95, 0.8), title_font)
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(-700, 40)
	t.size = Vector2(1400, 60)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o.add_child(t)
	var sub := _label("All three seeds are saved. Your current plant stays unchanged; replant a child to use its new gifts.", 18, DIM)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-700, 98)
	sub.size = Vector2(1400, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o.add_child(sub)
	# parents
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("separation", 30)
	prow.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prow.position = Vector2(-500, 140)
	prow.size = Vector2(1000, 250)
	o.add_child(prow)
	prow.add_child(_parent_card(parent, "your current plant"))
	var x := _label("×", 54, Color(1.0, 0.9, 0.6), title_font)
	prow.add_child(x)
	prow.add_child(_parent_card(wild_g, "wild"))
	# offspring
	var kid_scroll:=ScrollContainer.new()
	kid_scroll.set_anchors_preset(Control.PRESET_CENTER_TOP)
	kid_scroll.position=Vector2(-700,402)
	kid_scroll.size=Vector2(1400,502)
	kid_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	o.add_child(kid_scroll)
	var krow := HBoxContainer.new()
	krow.alignment = BoxContainer.ALIGNMENT_CENTER
	krow.add_theme_constant_override("separation", 22)
	krow.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	kid_scroll.add_child(krow)
	for i in kids.size():
		krow.add_child(_offspring_card(kids[i], parent, wild_g, i == 0))
	var keep := _button("Keep the current plant · use the new seeds later", func():
		_close_overlay()
		paused = was_paused
		_update_guidance()
		if not pending_cross.is_empty(): _show_cross(), 18)
	keep.set_meta("game_action","keep_current")
	keep.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	keep.position = Vector2(-220, -70)
	o.add_child(keep)

func _parent_card(gnm: Dictionary, role: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 240)
	var c := Control.new()
	c.custom_minimum_size = Vector2(250, 200)
	p.add_child(c)
	var holder := Node2D.new()
	holder.position = Vector2(125, 190)
	c.add_child(holder)
	holder.add_child(_preview_view(gnm, 0.62))
	var nl := _label(gnm.name, 22, INK)
	c.add_child(nl)
	var rl := _label(role, 13, DIM)
	rl.position = Vector2(0, 28)
	c.add_child(rl)
	var tr := Genome.traits(gnm)
	if not tr.is_empty():
		var ch := _chip(Genome.TRAIT_INFO[tr[0]].name if tr.size() == 1 else "%d gifts" % tr.size(), Genome.TRAIT_INFO[tr[0]].color)
		ch.position = Vector2(0, 50)
		c.add_child(ch)
	return p

func _offspring_card(kid: Dictionary, a: Dictionary, b: Dictionary, best: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(420, 460)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	p.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var nl := _label(kid.name, 24, INK)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nl)
	top.add_child(_label("G%d" % int(kid.gen), 15, DIM))
	var chips := GridContainer.new()
	chips.columns=3
	chips.add_theme_constant_override("separation", 6)
	box.add_child(chips)
	var tr := Genome.traits(kid)
	if tr.is_empty(): chips.add_child(_chip("no gifts", Color(1, 1, 1, 0.35)))
	for tt in tr: chips.add_child(_chip(Genome.TRAIT_INFO[tt].name, Genome.TRAIT_INFO[tt].color))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(380, 150)
	box.add_child(stage)
	var holder := Node2D.new()
	holder.position = Vector2(190, 146)
	stage.add_child(holder)
	holder.add_child(_preview_view(kid, 0.65))
	box.add_child(_label("Keeps both parents' gifts" if best else "A different inherited mix",13,DIM))
	var o: Dictionary = kid.get("origin", {})
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(370, 0)
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("bold_font_size",14)
	var lines: Array = []
	lines.append(_from_line("Leaves", Genome.LEAF_NAMES[int(kid.leaf_shape)], o.get("leaf_shape", "?"), a, b))
	lines.append(_from_line("Flowers", "%s ×%d" % [Genome.FLOWER_NAMES[int(kid.flower)], int(kid.petals)], o.get("flower", "?"), a, b))
	lines.append(_from_line("Colour", "body", o.get("hue", "?"), a, b) + "   " + _from_line("Petals", "tint", o.get("hue2", "?"), a, b))
	lines.append(_from_line("Pattern", Genome.PATTERN_NAMES[int(kid.pattern)], o.get("pattern", "?"), a, b) + "   " + _from_line("Stem", Genome.STEM_NAMES[int(kid.stem)], o.get("stem", "?"), a, b))
	for tt in tr:
		lines.append("[color=#%s]%s[/color] from %s" % [Genome.TRAIT_INFO[tt].color.to_html(false), Genome.TRAIT_INFO[tt].name, o.get(tt, "?")])
	rt.text = "\n".join(lines)
	box.add_child(rt)
	var fit: Dictionary=Guidance.seed_fit(Levels.all()[level_index],kid)
	var readiness:=_label(str(fit.summary),13,Color(0.65,1.0,0.8) if bool(fit.ready) else Color(1.0,0.8,0.5))
	box.add_child(readiness)
	var plant_btn := _button("Replant this garden", func(): _start_level(level_index, kid,true), 17)
	plant_btn.set_meta("game_action","replant_child")
	plant_btn.set_meta("seed_genome",kid)
	plant_btn.tooltip_text="Start this garden over with this exact child. All three seeds remain in the vault."
	box.add_child(plant_btn)
	# The decision stays in view even on a child with six inherited gifts.
	box.move_child(readiness,2)
	box.move_child(plant_btn,3)
	return p

func _from_line(label: String, value: String, origin: String, a: Dictionary, _b: Dictionary) -> String:
	var col := "9fe8c0" if origin == a.species else "ffd27a"
	return "%s: [b]%s[/b] [color=#%s]← %s[/color]" % [label, value, col, origin]

# ================================================================== win / stuck

func _on_win() -> void:
	var L: Dictionary = Levels.all()[level_index]
	var finished_session=session
	var got: Array=session.stars()
	save.completed[L.id] = true
	save.add_seed(current_seed)
	var best: Array=save.record_stars(L.id,got)
	sfx.play("win", 1.0)
	for tip in session.plant.tips:
		if tip.kind == 0 and session.plant.alive[tip.node] == 1:
			view.plant_view.flower_open[tip.node] = 0.0
			tip.state = "stopped"
	await get_tree().create_timer(2.2).timeout
	if mode != "play" or session!=finished_session: return
	while overlay!=null:
		await get_tree().create_timer(0.2).timeout
		if mode!="play" or session!=finished_session: return
	var o := _new_overlay(0.35)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-360, -230)
	box.custom_minimum_size = Vector2(720, 420)
	o.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	box.add_child(v)
	var t := _label("BLOOMED", 52, Color(1.0, 0.95, 0.8), title_font)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var msg := _label("%s woke every sunwell in %s.\nIts seed is safe in your vault." % [current_seed.name, L.title], 19, INK)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	var lines := ["Bloomed", "All dew collected  (%d / %d)" % [session.dew_taken(), session.dew_total()], "Within tool par  (%d / %d used)" % [session.tools_used, int(L.get("par", 99))]]
	for i in 3:
		var sl := _label(("✦  " if got[i] else "✧  ") + lines[i] + ("" if got[i] or not best[i] else "   (earned before)"), 19, Color(1.0, 0.88, 0.55) if got[i] else Color(1, 1, 1, 0.4))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sl)
	if not (got[1] and got[2]):
		var tip := _label("Try again for every star — collect the dew, use fewer tools.", 15, DIM)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	if level_index + 1 < Levels.all().size():
		row.add_child(_button("Next garden · unlocked", func(): show_level_intro(level_index + 1), 20))
	else:
		row.add_child(_button("You've woken every garden ✦", show_map, 20))
	row.add_child(_button("Replay", func(): _start_level(level_index, current_seed), 18))
	row.add_child(_button("Admire the garden", func():
		_close_overlay()), 18)
	row.add_child(_button("Map", show_map, 18))

func _on_stuck() -> void:
	sfx.play("back",0.8,-6)
	var L: Dictionary=Levels.all()[level_index]
	save.set_meta("fails_"+L.id,int(save.get_meta("fails_"+L.id,0))+1)
	view.show_guide=true
	_update_guidance()
	var advice: Dictionary=latest_guidance.duplicate(true)
	var panel:=PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position=Vector2(-465,-255)
	panel.custom_minimum_size=Vector2(930,160)
	ui_root.add_child(panel)
	stuck_panel=panel
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",9)
	panel.add_child(column)
	column.add_child(_label(str(advice.get("title","Try a new growing route")),22,Color(1,0.88,0.65)))
	var action:=_label(str(advice.get("action","Move a lure or prune to start fresh shoots.")),17,INK)
	action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	action.custom_minimum_size=Vector2(860,0)
	column.add_child(action)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	var help:=_button("Choose a useful seed" if str(advice.get("target_kind","")) in ["vault","fruit"] else "Show me what to try",_toggle_hint,17)
	help.set_meta("game_action","recover")
	row.add_child(help)
	if session.can_undo(): row.add_child(_button("Undo last action",_undo_action,17))
	row.add_child(_button("Replant this seed",func(): _start_level(level_index,current_seed,true),17))
	row.add_child(_button("Seed vault",func(): show_vault(true),17))

func _crystal_alive() -> bool:
	for c in session.world.crystals:
		if c.alive: return true
	return false
