extends Node2D
## Bloomward — main flow: title → garden map → level (grow, lure, prune,
## pollinate, replant) → bloom. Seed vault persists between sessions.

const Session := preload("res://scripts/session.gd")
const Levels := preload("res://scripts/levels.gd")
const Genome := preload("res://scripts/genome.gd")
const PlantSim := preload("res://scripts/plant_sim.gd")
const SaveData := preload("res://scripts/save_data.gd")
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

func _ready() -> void:
	randomize()
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
	save = SaveData.new()
	sfx = Sfx.new()
	add_child(sfx)
	sfx.muted = save.muted
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
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size_px)
	b.pressed.connect(func():
		sfx.play("ui", 1.2, -6)
		cb.call())
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
	hud_hint.size = Vector2(900, 40)
	hud_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hud.add_child(hud_hint)
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
	row.offset_left = -620
	row.offset_right = -36
	row.offset_top = -80
	row.offset_bottom = -30
	row.alignment = BoxContainer.ALIGNMENT_END
	hud.add_child(row)
	row.add_child(_button("Seeds", func(): show_vault(true)))
	row.add_child(_button("Fast", _toggle_fast))
	row.add_child(_button("Restart", func(): _start_level(level_index, current_seed)))
	row.add_child(_button("Map", show_map))
	row.name = "Buttons"
	toast = _label("", 24, Color(1.0, 0.95, 0.85))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-500, 120)
	toast.size = Vector2(1000, 40)
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
	# tools
	var bx := 40.0
	var by := 140.0
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
	return {"id": "demo", "palette": ["night", "teal", "dusk", "violet"][randi() % 4], "seed": Vector2(800, 900), "energy": 999999.0, "lures": 1, "prunes": 0,
		"rocks": [{"poly": Levels.ground(912, 10, 3), "soil": true}, {"poly": Levels.blob(330, 760, 150, 46, 3)}, {"poly": Levels.blob(1300, 720, 140, 44, 5)}],
		"goals": [], "wilds": [{"pos": Vector2(250, 718), "genome": "Lanternwort", "energy": 320.0}, {"pos": Vector2(1360, 680), "genome": "Hookvine", "energy": 300.0}, {"pos": Vector2(1500, 906), "genome": "Spinebrush", "energy": 280.0}]}

func _demo_genome() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var names := ["Spinebrush", "Lanternwort", "Hookvine", "Deeproot"]
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
	hud.visible = false
	if session == null or session.def.id != "demo":
		_start_demo()
	sfx.music("shop")
	var o := _new_overlay(0.45)
	var head := _label("THE GARDENS", 46, Color(0.92, 1.0, 0.95), title_font)
	head.position = Vector2(80, 60)
	o.add_child(head)
	var sub := _label("Each garden asks for a different gift. Breed it from what grows wild there.", 19, DIM)
	sub.position = Vector2(84, 124)
	o.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 4
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
		b.custom_minimum_size = Vector2(340, 150)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not open
		b.text = ""
		grid.add_child(b)
		var num := _label("%02d" % (i + 1), 15, DIM)
		num.position = Vector2(22, 18)
		b.add_child(num)
		var tl := _label(L.title if open else "Locked", 28, INK if open else Color(1, 1, 1, 0.3))
		tl.position = Vector2(22, 40)
		b.add_child(tl)
		var st := _label("Bloomed ✦" if done else ("Open" if open else "Bloom the garden before it"), 15, Color(1.0, 0.9, 0.6) if done else DIM)
		st.position = Vector2(22, 108)
		b.add_child(st)
		var idx := i
		b.pressed.connect(func():
			sfx.play("ui", 1.1, -6)
			show_level_intro(idx))
	var back := _button("Back", show_title)
	back.position = Vector2(80, 560)
	o.add_child(back)
	var vault := _button("Seed Vault", func(): show_vault(false))
	vault.position = Vector2(190, 560)
	o.add_child(vault)

# ================================================================== level intro + seed choice

func show_level_intro(index: int) -> void:
	level_index = index
	var L: Dictionary = Levels.all()[index]
	var o := _new_overlay(0.94, true)
	var t := _label(L.title.to_upper(), 46, Color(0.92, 1.0, 0.95), title_font)
	t.position = Vector2(80, 60)
	o.add_child(t)
	var intro := _label(L.intro, 21, INK)
	intro.position = Vector2(84, 128)
	intro.size = Vector2(1100, 70)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD
	o.add_child(intro)
	var pick := _label("Choose a seed to plant", 17, DIM)
	pick.position = Vector2(84, 206)
	o.add_child(pick)
	_seed_grid(o, Vector2(80, 240), func(g): _start_level(index, g))
	var back := _button("Back", show_map)
	back.position = Vector2(80, 40)
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.position = Vector2(80, -80)
	o.add_child(back)

func _seed_grid(parent: Control, at: Vector2, on_pick: Callable) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = at
	scroll.size = Vector2(1460, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	for gnm in save.seeds:
		grid.add_child(_seed_card(gnm, on_pick))

func _seed_card(gnm: Dictionary, on_pick: Callable, w := 270.0, h := 330.0) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	var holder := Node2D.new()
	holder.position = Vector2(w * 0.5, h - 112)
	b.add_child(holder)
	var pv := _preview_view(gnm, 0.56)
	holder.add_child(pv)
	var nl := _label(gnm.name, 22, INK)
	nl.position = Vector2(16, 10)
	b.add_child(nl)
	var gl := _label("G%d" % int(gnm.gen), 14, DIM)
	gl.position = Vector2(w - 44, 16)
	b.add_child(gl)
	var chips := HBoxContainer.new()
	chips.position = Vector2(14, h - 104)
	chips.add_theme_constant_override("separation", 6)
	b.add_child(chips)
	var traits := Genome.traits(gnm)
	if traits.is_empty(): chips.add_child(_chip("no gifts", Color(1, 1, 1, 0.35)))
	for tr in traits: chips.add_child(_chip(Genome.TRAIT_INFO[tr].name, Genome.TRAIT_INFO[tr].color))
	var feat := _label("%s leaves · %s flowers\n%s · %s stem" % [Genome.LEAF_NAMES[int(gnm.leaf_shape)], Genome.FLOWER_NAMES[int(gnm.flower)], Genome.PATTERN_NAMES[int(gnm.pattern)], Genome.STEM_NAMES[int(gnm.stem)]], 13, DIM)
	feat.position = Vector2(16, h - 70)
	b.add_child(feat)
	if gnm.get("parents", []).size() == 2:
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
	var was_paused := paused
	paused = true
	var o := _new_overlay(0.94, true)
	var t := _label("SEED VAULT", 40, Color(0.92, 1.0, 0.95), title_font)
	t.position = Vector2(80, 50)
	o.add_child(t)
	var sub := _label("Every seed you've bred. Gifts: Thorns break crystal · Glow grows in the dark · Tendrils climb glass · Roots drink.", 17, DIM)
	sub.position = Vector2(84, 108)
	o.add_child(sub)
	_seed_grid(o, Vector2(80, 150), func(g):
		if in_level:
			_start_level(level_index, g)
		else:
			pass)
	var close := _button("Close", func():
		_close_overlay()
		paused = was_paused
		if not in_level and mode == "title": show_title()
		elif not in_level and mode == "map": show_map())
	close.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	close.position = Vector2(80, -80)
	o.add_child(close)

# ================================================================== play

func _start_level(index: int, gnm: Dictionary) -> void:
	_close_overlay()
	if stuck_panel != null and is_instance_valid(stuck_panel): stuck_panel.queue_free()
	stuck_panel = null
	level_index = index
	current_seed = gnm
	mode = "play"
	paused = false
	won_shown = false
	stuck_shown = false
	reasons.clear()
	pending_cross.clear()
	var L: Dictionary = Levels.all()[index]
	session = Session.new()
	session.start(L, gnm, 1 + index * 17)
	view.build(session)
	hud.visible = true
	hud_title.text = L.title.to_upper()
	hud_hint.text = L.hint
	sfx.music("battle")
	sfx.play("start", 1.0, -8)
	_toast("Planted %s" % gnm.name, 1.8)

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
	if paused: return
	var steps := 2 if fast else 1
	for i in steps:
		session.step(delta)
	_drain_events()
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
				_toast("Pollinated %s!" % w.genome.name)
				pending_cross.append(w.genome)
				get_tree().create_timer(1.5).timeout.connect(_show_cross)
			"crystal":
				view.fx.burst(e.pos, Color(0.6, 1.0, 1.0), 60, 300.0, 300.0, 2.6, 1.4)
				view.fx.ring(e.pos, Color(0.6, 1.0, 1.0), 140.0, 0.6)
				sfx.play("zap", 0.8)
				if not demo: _toast("Crystal shattered!")
			"stop":
				reasons[e.why] = int(reasons.get(e.why, 0)) + 1
				view.fx.burst(e.pos, Color(0.9, 0.8, 0.6), 6, 40.0, 30.0, 1.5, 0.8)
			"droop":
				reasons["droop"] = int(reasons.get("droop", 0)) + 1
			"drink":
				view.fx.burst(e.pos, Color(0.5, 0.85, 1.0), 3, 30.0, -40.0, 1.6, 0.9)
	if not demo:
		for tip in session.plant.tips:
			if tip.state == "stalled": reasons["dark"] = 1

# ================================================================== input

func _unhandled_input(event: InputEvent) -> void:
	if mode != "play" or overlay != null: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: _start_level(level_index, current_seed)
			KEY_ESCAPE: show_map()
			KEY_F: _toggle_fast()
			KEY_S: show_vault(true)
			KEY_SPACE:
				paused = not paused
				_toast("Paused" if paused else "Growing", 0.8)
		return
	var pos := get_global_mouse_position()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var li := _lure_at(pos)
			if li >= 0:
				session.remove_lure(li)
				sfx.play("back", 1.2, -6)
			return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		if event.pressed:
			pressing = true
			press_pos = pos
			swiping = false
			swipe_pts = [pos]
			drag_lure = _lure_at(pos)
		else:
			if drag_lure >= 0:
				drag_lure = -1
			elif swiping:
				_finish_swipe()
			elif pressing:
				_place_lure(pos)
			pressing = false
			swiping = false
			view.fx.trail = []
	elif event is InputEventMouseMotion:
		view.hover_lure = _lure_at(pos)
		if not pressing: return
		if drag_lure >= 0:
			if not session.world.in_dark(pos):
				session.world.lures[drag_lure] = pos
			return
		if not swiping and pos.distance_to(press_pos) > 14.0:
			swiping = true
		if swiping:
			if swipe_pts.is_empty() or pos.distance_to(swipe_pts.back()) > 6.0:
				swipe_pts.append(pos)
			view.fx.trail = swipe_pts.duplicate()

func _lure_at(pos: Vector2) -> int:
	if session == null: return -1
	for i in session.world.lures.size():
		if pos.distance_to(session.world.lures[i]) < 26.0: return i
	return -1

func _place_lure(pos: Vector2) -> void:
	if session.world.in_dark(pos):
		_toast("Lures fizzle out in the dark.")
		sfx.play("back", 1.0, -6)
		return
	if not session.add_lure(pos):
		_toast("No lures left — drag one to move it, right-click to recall it.")
		sfx.play("back", 1.0, -6)
		return
	view.fx.ring(pos, Color(0.55, 1.0, 0.95), 70.0, 0.5)
	sfx.play("pop", 1.4, -4)

func _finish_swipe() -> void:
	if session.prunes_left <= 0:
		_toast("No prunes left.")
		view.fx.trail_fade.append([swipe_pts.duplicate(), 0.35])
		return
	var removed: Array = session.prune_path(swipe_pts)
	view.fx.trail_fade.append([swipe_pts.duplicate(), 0.35])
	if removed.is_empty(): return
	var segs: Array = []
	for r in removed: segs.append([r[0], r[1]])
	view.fx.add_debris(segs, view.plant_view.c_stem_tip)
	view.fx.burst(swipe_pts[swipe_pts.size() / 2], view.plant_view.c_leaf_b, 18, 140.0, 200.0, 2.0, 1.0)
	sfx.play("swish", 0.9)
	# pruning can wake a stalled plant
	stuck_shown = false
	if stuck_panel != null and is_instance_valid(stuck_panel):
		stuck_panel.queue_free()
		stuck_panel = null

# ================================================================== cross reveal

func _show_cross() -> void:
	if pending_cross.is_empty() or mode != "play": return
	var wild_g: Dictionary = pending_cross.pop_front()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var kids: Array = Genome.cross(current_seed, wild_g, rng)
	for k in kids: save.add_seed(k)
	paused = true
	var o := _new_overlay(0.94, true)
	var t := _label("CROSS-POLLINATED", 40, Color(1.0, 0.95, 0.8), title_font)
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(-700, 40)
	t.size = Vector2(1400, 60)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o.add_child(t)
	var sub := _label("A fruit ripened with three seeds. Each takes every feature from one parent or the other.", 18, DIM)
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
	prow.add_child(_parent_card(current_seed, "your plant"))
	var x := _label("×", 54, Color(1.0, 0.9, 0.6), title_font)
	prow.add_child(x)
	prow.add_child(_parent_card(wild_g, "wild"))
	# offspring
	var krow := HBoxContainer.new()
	krow.alignment = BoxContainer.ALIGNMENT_CENTER
	krow.add_theme_constant_override("separation", 22)
	krow.set_anchors_preset(Control.PRESET_CENTER_TOP)
	krow.position = Vector2(-700, 410)
	krow.size = Vector2(1400, 470)
	o.add_child(krow)
	for i in kids.size():
		krow.add_child(_offspring_card(kids[i], current_seed, wild_g, i == 0))
	var keep := _button("Keep growing  (seeds saved to your vault)", func():
		_close_overlay()
		paused = false
		if not pending_cross.is_empty(): _show_cross(), 18)
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
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	box.add_child(chips)
	var tr := Genome.traits(kid)
	if tr.is_empty(): chips.add_child(_chip("no gifts", Color(1, 1, 1, 0.35)))
	for tt in tr: chips.add_child(_chip(Genome.TRAIT_INFO[tt].name, Genome.TRAIT_INFO[tt].color))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(380, 200)
	box.add_child(stage)
	var holder := Node2D.new()
	holder.position = Vector2(190, 196)
	stage.add_child(holder)
	holder.add_child(_preview_view(kid, 0.72))
	var o: Dictionary = kid.get("origin", {})
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(370, 0)
	rt.add_theme_font_size_override("normal_font_size", 14)
	var lines: Array = []
	lines.append(_from_line("Leaves", Genome.LEAF_NAMES[int(kid.leaf_shape)], o.get("leaf_shape", "?"), a, b))
	lines.append(_from_line("Flowers", "%s ×%d" % [Genome.FLOWER_NAMES[int(kid.flower)], int(kid.petals)], o.get("flower", "?"), a, b))
	lines.append(_from_line("Colour", "body", o.get("hue", "?"), a, b) + "   " + _from_line("Petals", "tint", o.get("hue2", "?"), a, b))
	lines.append(_from_line("Pattern", Genome.PATTERN_NAMES[int(kid.pattern)], o.get("pattern", "?"), a, b) + "   " + _from_line("Stem", Genome.STEM_NAMES[int(kid.stem)], o.get("stem", "?"), a, b))
	for tt in tr:
		lines.append("[color=#%s]%s[/color] from %s" % [Genome.TRAIT_INFO[tt].color.to_html(false), Genome.TRAIT_INFO[tt].name, o.get(tt, "?")])
	rt.text = "\n".join(lines)
	box.add_child(rt)
	var plant_btn := _button(("Plant this — best pick" if best else "Plant this"), func(): _start_level(level_index, kid), 17)
	box.add_child(plant_btn)
	return p

func _from_line(label: String, value: String, origin: String, a: Dictionary, _b: Dictionary) -> String:
	var col := "9fe8c0" if origin == a.species else "ffd27a"
	return "%s: [b]%s[/b] [color=#%s]← %s[/color]" % [label, value, col, origin]

# ================================================================== win / stuck

func _on_win() -> void:
	var L: Dictionary = Levels.all()[level_index]
	save.completed[L.id] = true
	save.add_seed(current_seed)
	save.save()
	sfx.play("win", 1.0)
	for tip in session.plant.tips:
		if tip.kind == 0 and session.plant.alive[tip.node] == 1:
			view.plant_view.flower_open[tip.node] = 0.0
			tip.state = "stopped"
	await get_tree().create_timer(2.2).timeout
	if mode != "play" or session.def.id != L.id: return
	var o := _new_overlay(0.35)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-330, -170)
	box.custom_minimum_size = Vector2(660, 300)
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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	if level_index + 1 < Levels.all().size():
		row.add_child(_button("Next garden", func(): show_level_intro(level_index + 1), 20))
	else:
		row.add_child(_button("You've woken every garden ✦", show_map, 20))
	row.add_child(_button("Stay a while", func():
		_close_overlay()), 18)
	row.add_child(_button("Map", show_map, 18))

func _on_stuck() -> void:
	sfx.play("back", 0.8, -6)
	var why := "Your plant has stopped growing."
	if reasons.has("slick"): why = "Its shoots slipped on glassy rock. Something that clings could climb it."
	elif reasons.has("dark"): why = "It stalled in the dark. A plant that glows brings its own light."
	elif not session.world.crystals.is_empty() and _crystal_alive():
		if int(current_seed.thorns) > 0: why = "Lead a thorny shoot straight into the crystal to shatter it. Try a lure just below it."
		else: why = "Crystal blocks the way. Something thorny might break through."
	elif session.plant.energy <= 0.0: why = "It ran out of sap. Prune wasteful shoots, or find a plant that drinks."
	elif reasons.has("droop"): why = "It drooped reaching into open air. Stems need rock to lean on — guide it with a lure."
	var wild_left := false
	for w in session.world.wilds:
		if not w.pollinated: wild_left = true
	if wild_left: why += "\nThere's a wild plant here you haven't touched yet."
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.position = Vector2(-430, -230)
	p.custom_minimum_size = Vector2(860, 120)
	ui_root.add_child(p)
	stuck_panel = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var l := _label(why, 18, INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(800, 0)
	v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	row.add_child(_button("Try again", func(): _start_level(level_index, current_seed), 17))
	row.add_child(_button("Plant another seed", func(): show_vault(true), 17))
	if session.prunes_left > 0:
		row.add_child(_label("   or swipe to prune and wake new shoots", 15, DIM))

func _crystal_alive() -> bool:
	for c in session.world.crystals:
		if c.alive: return true
	return false
