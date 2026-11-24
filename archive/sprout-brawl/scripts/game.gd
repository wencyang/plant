extends Node2D
## Sprout Brawl — main controller.
## Title → (Shop ⇄ Battle) × rounds → Run end. Herbarium is persistent.

const Plant := preload("res://scripts/sim/plant.gd")
const Species := preload("res://scripts/sim/species.gd")
const Breeding := preload("res://scripts/sim/breeding.gd")
const RunState := preload("res://scripts/sim/run_state.gd")
const SaveData := preload("res://scripts/save_data.gd")
const PlantView := preload("res://scripts/view/plant_view.gd")
const PacketView := preload("res://scripts/view/packet_view.gd")
const Backdrop := preload("res://scripts/view/backdrop.gd")
const Fx := preload("res://scripts/view/fx.gd")
const Hud := preload("res://scripts/view/hud.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Battle := preload("res://scripts/sim/battle.gd")

const OUT := Color("1b2420")
const PLANT_SCALE := 1.3
const CREAM := Color("fff4d6")

var save: RefCounted
var run: RefCounted
var mode := "title"
var size := Vector2(1280, 800)
var ground_y := 440.0
var spacing := 118.0

# scene
var backdrop: Node2D
var world: Node2D
var plants_layer: Node2D
var packets_layer: Node2D
var fx: Node2D
var ui: CanvasLayer
var hud: Node2D
var sfx: Node
var info_card: PanelContainer
var info_text: RichTextLabel
var hint_label: Label
var rival_label: Label
var toast_label: Label
var reroll_button: Button
var fight_button: Button
var speed_button: Button
var skip_button: Button
var menu_button: Button
var sound_button: Button
var overlay: Control = null
var popup: Control = null
var bin_rect := Rect2()

var board_views: Array = [null, null, null, null, null]
var packet_views: Array = []
var battle_views: Dictionary = {}
var last_pos: Dictionary = {}
var title_views: Array = []

var drag: Dictionary = {}
var hover_target = null
var shake := 0.0
var speed := 1.0
var skipping := false
var crossed_this_run := false
var busy := false
var last_enemy: Array = []
var new_entries_this_run := 0
var font: Font

func _ready() -> void:
	randomize()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Nunito", "Varela Round", "Avenir Next", "Helvetica Neue", "Arial"])
	f.font_weight = 700
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	ThemeDB.fallback_font = f
	font = f
	save = SaveData.new()
	sfx = Sfx.new()
	add_child(sfx)
	sfx.muted = save.muted
	backdrop = Backdrop.new()
	add_child(backdrop)
	world = Node2D.new()
	add_child(world)
	plants_layer = Node2D.new()
	world.add_child(plants_layer)
	packets_layer = Node2D.new()
	world.add_child(packets_layer)
	fx = Fx.new()
	world.add_child(fx)
	fx.z_index = 10
	ui = CanvasLayer.new()
	add_child(ui)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	show_title()

# ======================================================================= UI

func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 24
	var normal := _box(Color("ffe9a8"))
	var hover := _box(Color("fff3c4"))
	var pressed := _box(Color("f2cf72"))
	pressed.content_margin_top = 12
	var disabled := _box(Color("cfc6ad"))
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", OUT)
	th.set_color("font_hover_color", "Button", OUT)
	th.set_color("font_pressed_color", "Button", OUT)
	th.set_color("font_disabled_color", "Button", Color("8a8470"))
	th.set_color("font_color", "Label", OUT)
	var panel := _box(CREAM, 18)
	panel.content_margin_left = 22
	panel.content_margin_right = 22
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_color("default_color", "RichTextLabel", OUT)
	th.set_font("normal_font", "RichTextLabel", font)
	th.set_font("bold_font", "RichTextLabel", font)
	th.set_font_size("normal_font_size", "RichTextLabel", 20)
	th.set_font_size("bold_font_size", "RichTextLabel", 22)
	return th

func _box(col: Color, radius := 16) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = col
	b.border_color = OUT
	b.set_border_width_all(4)
	b.set_corner_radius_all(radius)
	b.shadow_color = Color(0, 0, 0, 0.25)
	b.shadow_size = 0
	b.shadow_offset = Vector2(0, 5)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 8
	b.content_margin_bottom = 10
	b.expand_margin_bottom = 0
	return b

func _button(text: String, col: Color, cb: Callable, font_size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	var n := _box(col)
	n.shadow_size = 1
	var h := _box(col.lightened(0.15))
	h.shadow_size = 1
	var p := _box(col.darkened(0.12))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.pressed.connect(func():
		sfx.play("ui")
		cb.call())
	b.mouse_entered.connect(func(): if not b.disabled: _wiggle_control(b))
	b.focus_mode = Control.FOCUS_NONE
	return b

func _wiggle_control(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2(1.06, 1.06), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12)

func _label(text: String, size_px: int, col := OUT, outline := 0, outline_col := OUT) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size_px
	ls.font_color = col
	ls.outline_size = outline
	ls.outline_color = outline_col
	if outline > 0:
		ls.shadow_color = Color(0, 0, 0, 0.3)
		ls.shadow_offset = Vector2(0, 4)
		ls.shadow_size = 0
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_ui() -> void:
	hud = Hud.new()
	ui.add_child(hud)
	var root := Control.new()
	root.name = "UIRoot"
	root.theme = _theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	reroll_button = _button("Reroll  1", Color("9ad7ff"), _on_reroll, 24)
	root.add_child(reroll_button)
	fight_button = _button("FIGHT!", Color("ff8a5c"), _on_fight, 40)
	root.add_child(fight_button)
	speed_button = _button("Speed 1x", Color("c9f0a8"), _on_speed, 22)
	root.add_child(speed_button)
	skip_button = _button("Skip", Color("e8dcc0"), _on_skip, 22)
	root.add_child(skip_button)
	menu_button = _button("Menu", Color("e8dcc0"), _on_menu, 20)
	root.add_child(menu_button)
	sound_button = _button("Sound", Color("e8dcc0"), _on_sound, 20)
	root.add_child(sound_button)
	_update_sound_button()
	hint_label = _label("", 24, Color.WHITE, 10)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)
	toast_label = _label("", 28, Color("fff4d6"), 12)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)
	info_card = PanelContainer.new()
	info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_card.custom_minimum_size = Vector2(340, 0)
	info_text = RichTextLabel.new()
	info_text.bbcode_enabled = true
	info_text.fit_content = true
	info_text.scroll_active = false
	info_text.custom_minimum_size = Vector2(320, 0)
	info_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_card.add_child(info_text)
	info_card.visible = false
	root.add_child(info_card)
	rival_label = _label("", 26, Color.WHITE, 10)
	rival_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(rival_label)

func _ui_root() -> Control:
	return ui.get_node("UIRoot")

func _layout() -> void:
	size = get_viewport_rect().size
	ground_y = round(size.y * 0.6)
	spacing = clampf((size.x * 0.5 - 130.0) / 4.15, 100.0, 160.0)
	backdrop.size = size
	backdrop.ground_y = ground_y
	hud.width = size.x
	var plots: Array = []
	for i in RunState.SLOTS: plots.append({"pos": slot_pos(i), "glow": 0.0, "enemy": false})
	for i in RunState.SLOTS: plots.append({"pos": enemy_pos(i), "glow": 0.0, "enemy": true})
	backdrop.plots = plots
	fight_button.size = Vector2(210, 84)
	fight_button.position = Vector2(size.x - 236, size.y - 112)
	reroll_button.size = Vector2(170, 56)
	reroll_button.position = Vector2(size.x - 216, size.y - 190)
	speed_button.size = Vector2(150, 50)
	speed_button.position = Vector2(size.x - 330, size.y - 76)
	skip_button.size = Vector2(110, 50)
	skip_button.position = Vector2(size.x - 160, size.y - 76)
	menu_button.size = Vector2(96, 44)
	menu_button.position = Vector2(size.x - 128, 20)
	sound_button.size = Vector2(150, 44)
	sound_button.position = Vector2(size.x - 292, 20)
	rival_label.size = Vector2(size.x * 0.5, 40)
	rival_label.position = Vector2(size.x * 0.5 - 30, 88)
	hint_label.size = Vector2(size.x, 40)
	hint_label.position = Vector2(0, 92)
	toast_label.size = Vector2(size.x, 40)
	toast_label.position = Vector2(0, ground_y - 250)
	bin_rect = Rect2(28, size.y - 190, 140, 170)
	backdrop.bin_rect = bin_rect
	for i in RunState.SLOTS:
		if board_views[i] != null and not (drag.get("view") == board_views[i]):
			board_views[i].position = slot_pos(i)
	_layout_packets(false)

func slot_pos(i: int) -> Vector2:
	return Vector2(size.x * 0.5 - 72 - (RunState.SLOTS - 1 - i) * spacing, ground_y + 2)

func enemy_pos(k: int) -> Vector2:
	return Vector2(size.x * 0.5 + 72 + k * spacing, ground_y + 2)

func player_battle_pos(k: int) -> Vector2:
	return Vector2(size.x * 0.5 - 72 - k * spacing, ground_y + 2)

func packet_pos(i: int) -> Vector2:
	var start := 250.0
	var step := clampf((size.x - 520.0) / 6.0, 132.0, 160.0)
	return Vector2(start + i * step, size.y - 108)

func _process(delta: float) -> void:
	shake = max(0.0, shake - delta * 3.0)
	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 14.0
	if mode == "shop" and not drag.is_empty():
		_update_drag_glow()

# ======================================================================= title

func show_title() -> void:
	mode = "title"
	_clear_run_views()
	backdrop.night_target = 0.0
	backdrop.show_enemy_side = false
	hud.visible = false
	_set_shop_ui(false)
	_set_battle_ui(false)
	menu_button.visible = false
	sound_button.visible = true
	hint_label.text = ""
	sfx.music("shop")
	# parade of plants
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var picks: Array = Species.ORDER.duplicate()
	picks.shuffle()
	for i in 10:
		var p = Plant.create(picks[i % picks.size()], rng)
		if i % 3 == 0: p = Breeding.cross(p, Plant.create(picks[(i + 3) % 8], rng), rng, i == 6)
		var v := PlantView.new()
		plants_layer.add_child(v)
		v.setup(p, 1.0 if i < 5 else -1.0)
		v.show_badges = false
		v.scale = Vector2(PLANT_SCALE, PLANT_SCALE)
		v.position = slot_pos(i) if i < 5 else enemy_pos(i - 5)
		v.spawn_pop()
		title_views.append(v)
	backdrop.show_enemy_side = true
	var o := _new_overlay(false)
	var title := _label("SPROUT BRAWL", 112, Color("ffe066"), 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(size.x, 140)
	title.position = Vector2(0, size.y * 0.09)
	o.add_child(title)
	_bob(title)
	var sub := _label("Breed weird plants.  Win garden brawls.", 32, Color.WHITE, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(size.x, 44)
	sub.position = Vector2(0, size.y * 0.09 + 140)
	o.add_child(sub)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.size = Vector2(size.x, 160)
	box.position = Vector2(0, ground_y + 70)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var play := _button("   Play   ", Color("ff8a5c"), _start_run, 44)
	row.add_child(play)
	row.add_child(_button("Herbarium  %d/36" % save.herbarium.size(), Color("c9f0a8"), show_herbarium, 26))
	row.add_child(_button("How to play", Color("9ad7ff"), show_how_to, 26))
	var rec := "Best: %d trophies   ·   Garden Cups won: %d   ·   Runs: %d" % [save.best_trophies, save.cups, save.runs]
	var rl := _label(rec, 22, Color.WHITE, 8)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rl)

func _bob(c: Control) -> void:
	c.pivot_offset = Vector2(size.x * 0.5, 70)
	var tw: Tween = c.create_tween().set_loops()
	tw.tween_property(c, "rotation", 0.025, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "rotation", -0.025, 1.2).set_trans(Tween.TRANS_SINE)

func _new_overlay(dim := true) -> Control:
	_close_overlay()
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP if dim else Control.MOUSE_FILTER_IGNORE
	if dim:
		var shade := ColorRect.new()
		shade.color = Color(0.06, 0.08, 0.12, 0.62)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		o.add_child(shade)
	_ui_root().add_child(o)
	overlay = o
	o.modulate.a = 0.0
	o.create_tween().tween_property(o, "modulate:a", 1.0, 0.18)
	return o

func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

func _center_panel(o: Control, min_size: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	panel.pivot_offset = min_size * 0.5
	panel.scale = Vector2(0.85, 0.85)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return box

func show_how_to() -> void:
	var back_to_title := mode == "title"
	var o := _new_overlay()
	var box := _center_panel(o, Vector2(760, 0))
	var h := _label("How to play", 44)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(700, 0)
	rt.text = "[b]1. Plant.[/b] Tap a seed packet to plant it (3 sun). You get 10 sun every round.\n\n" + \
		"[b]2. Cross-pollinate![/b] Drag one plant onto another. They merge into a [color=#c05a00]stronger hybrid[/color] that keeps [b]both[/b] parents' abilities and looks. Same abilities stack and get stronger. Deeper generations hit harder.\n\n" + \
		"[b]3. Glowing mutants.[/b] Every cross has a small chance of a glowing mutant (+2/+2, stronger abilities). Magic Pollen guarantees one.\n\n" + \
		"[b]4. Brawl.[/b] Your [b]rightmost[/b] plant fights first. Front plants clash until one wilts. Win 10 brawls before your 5 hearts run out!\n\n" + \
		"[b]5. Collect.[/b] Every new family pairing goes into your Herbarium — can you find all 36?"
	box.add_child(rt)
	var ok := _button("Got it!", Color("c9f0a8"), func():
		_close_overlay()
		if back_to_title: show_title(), 26)
	box.add_child(ok)

# ======================================================================= run flow

func _clear_run_views() -> void:
	for v in title_views:
		if is_instance_valid(v): v.queue_free()
	title_views.clear()
	for i in board_views.size():
		if board_views[i] != null and is_instance_valid(board_views[i]): board_views[i].queue_free()
		board_views[i] = null
	for v in battle_views.values():
		if is_instance_valid(v): v.queue_free()
	battle_views.clear()
	for p in packet_views:
		if is_instance_valid(p): p.queue_free()
	packet_views.clear()

func _start_run() -> void:
	_close_overlay()
	_clear_run_views()
	run = RunState.new()
	crossed_this_run = false
	new_entries_this_run = 0
	save.runs += 1
	save.save()
	hud.visible = true
	menu_button.visible = true
	_enter_shop(true)

func _enter_shop(first := false) -> void:
	mode = "shop"
	busy = false
	backdrop.night_target = 0.0
	backdrop.show_enemy_side = false
	_set_battle_ui(false)
	_set_shop_ui(true)
	sfx.music("shop")
	_sync_hud()
	_rebuild_board_views()
	_rebuild_packets(true)
	_banner("Round %d" % run.round_number, Color("ffe066"))
	if run.round_number == 3: _toast("New seeds unlocked: Whiplash & Nightcap!", 3.0)
	elif run.round_number == 5: _toast("Rare seeds unlocked: Snapjaw & Mistlewisp!", 3.0)
	elif run.round_number == 2: _toast("Garden items appear in the shop — drag them onto a plant.", 3.0)
	_update_hint()

func _set_shop_ui(on: bool) -> void:
	reroll_button.visible = on
	fight_button.visible = on
	hud.show_sun = on
	packets_layer.visible = on
	backdrop.shop_shelf = on
	if on:
		fight_button.pivot_offset = fight_button.size * 0.5

func _set_battle_ui(on: bool) -> void:
	rival_label.visible = on
	speed_button.visible = on
	skip_button.visible = on

func _sync_hud() -> void:
	hud.hearts = run.hearts
	hud.trophies = run.trophies
	hud.round_number = run.round_number
	hud.sun = run.sun
	hud.max_trophies = RunState.TROPHIES_TO_WIN
	reroll_button.disabled = run.sun < RunState.REROLL_COST
	for p in packet_views:
		var idx := packet_views.find(p)
		p.affordable = run.can_afford(idx)

func _rebuild_board_views() -> void:
	for i in RunState.SLOTS:
		if board_views[i] != null and is_instance_valid(board_views[i]): board_views[i].queue_free()
		board_views[i] = null
		var p = run.board[i]
		if p != null:
			var v := _make_view(p, 1.0)
			v.position = slot_pos(i)
			v.spawn_pop()
			board_views[i] = v

func _make_view(p, face: float) -> Node2D:
	var v := PlantView.new()
	plants_layer.add_child(v)
	v.setup(p, face)
	v.scale = Vector2(PLANT_SCALE, PLANT_SCALE)
	return v

func _rebuild_packets(animate: bool) -> void:
	for p in packet_views:
		if is_instance_valid(p): p.queue_free()
	packet_views.clear()
	for i in run.shop.size():
		var e: Dictionary = run.shop[i]
		if e.kind == "item": e["label"] = RunState.ITEMS[e.item].name
		var pv := PacketView.new()
		packets_layer.add_child(pv)
		pv.setup(e)
		pv.position = packet_pos(i)
		if animate:
			pv.position.y += 260
			var tw: Tween = pv.create_tween()
			tw.tween_interval(i * 0.06)
			tw.tween_property(pv, "position:y", packet_pos(i).y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		packet_views.append(pv)
	_sync_hud()

func _layout_packets(animate: bool) -> void:
	for i in packet_views.size():
		var pv = packet_views[i]
		if drag.get("view") == pv: continue
		if animate:
			pv.create_tween().tween_property(pv, "position", packet_pos(i), 0.2).set_trans(Tween.TRANS_QUAD)
		else:
			pv.position = packet_pos(i)

func _update_hint() -> void:
	if mode != "shop" or run == null:
		hint_label.text = ""
		return
	var txt := ""
	if run.round_number <= 4:
		if run.plant_count() == 0:
			txt = "Tap a seed packet to plant it!"
		elif not crossed_this_run and run.plant_count() >= 2:
			txt = "Drag one plant onto another to cross-pollinate them into a hybrid!"
		elif run.sun >= RunState.SEED_COST:
			txt = "Spend your sun, then hit FIGHT. Your rightmost plant fights first."
		else:
			txt = "Ready? Hit FIGHT!"
	hint_label.text = txt

# ======================================================================= shop input

func _unhandled_input(event: InputEvent) -> void:
	if mode != "shop" or busy or overlay != null or popup != null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		if event.pressed: _press(pos)
		else: _release(pos)
	elif event is InputEventMouseMotion:
		var pos := get_global_mouse_position()
		if not drag.is_empty():
			var v: Node2D = drag.view
			v.position = pos + drag.offset
			if pos.distance_to(drag.start) > 10.0: drag.moved = true
			info_card.visible = false
		else:
			_hover(pos)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER: _on_fight()
		elif event.keycode == KEY_R: _on_reroll()

func _plant_at(pos: Vector2) -> int:
	for i in RunState.SLOTS:
		var v = board_views[i]
		if v != null and v.hit_test(v.to_local(pos)): return i
	return -1

func _packet_at(pos: Vector2) -> int:
	for i in range(packet_views.size() - 1, -1, -1):
		var pv = packet_views[i]
		if pv.rect().has_point(pv.to_local(pos)): return i
	return -1

func _slot_near(pos: Vector2) -> int:
	if pos.y < ground_y - 220 or pos.y > ground_y + 90: return -1
	var best := -1
	var best_d := spacing * 0.6
	for i in RunState.SLOTS:
		var d: float = abs(slot_pos(i).x - pos.x)
		if d < best_d:
			best_d = d
			best = i
	return best

func _press(pos: Vector2) -> void:
	var pi := _packet_at(pos)
	if pi >= 0:
		var pv = packet_views[pi]
		drag = {"kind": "packet", "index": pi, "view": pv, "offset": pv.position - pos, "start": pos, "moved": false}
		pv.lifted = true
		pv.z_index = 5
		sfx.play("swish", 1.3, -6)
		return
	var si := _plant_at(pos)
	if si >= 0:
		var v = board_views[si]
		drag = {"kind": "plant", "slot": si, "view": v, "offset": v.position - pos, "start": pos, "moved": false}
		v.lifted = true
		v.z_index = 5
		v.bounce(0.25)
		sfx.play("swish", 1.1, -6)

func _release(pos: Vector2) -> void:
	if drag.is_empty(): return
	var d := drag
	drag = {}
	_clear_glow()
	var v: Node2D = d.view
	v.z_index = 0
	if d.kind == "packet":
		v.lifted = false
		var index: int = d.index
		var e: Dictionary = run.shop[index]
		if not d.moved:
			if e.kind == "seed": _buy_to(index, run.first_empty())
			else:
				_toast("Drag %s onto one of your plants." % RunState.ITEMS[e.item].name)
				v.wobble = 1.0
			_layout_packets(true)
			return
		var slot := _slot_near(pos)
		if slot < 0:
			_layout_packets(true)
			return
		if e.kind == "seed":
			if run.board[slot] == null: _buy_to(index, slot)
			else: _ask_cross_packet(index, slot)
		else:
			_use_item(index, slot)
		_layout_packets(true)
	else:
		v.lifted = false
		var from: int = d.slot
		if not d.moved:
			v.bounce(0.4)
			sfx.play("pop", 1.3, -4)
			_show_info_for_plant(run.board[from], v.global_position + Vector2(0, -140))
			_return_view(from)
			return
		if bin_rect.grow(20).has_point(pos):
			_sell(from)
			return
		var to := _slot_near(pos)
		if to < 0 or to == from:
			_return_view(from)
			return
		if run.board[to] == null:
			run.move(from, to)
			board_views[to] = board_views[from]
			board_views[from] = null
			_return_view(to)
			sfx.play("swish")
		else:
			_return_view(from)
			_ask_cross(from, to)

func _return_view(slot: int) -> void:
	var v = board_views[slot]
	if v == null: return
	var tw: Tween = v.create_tween()
	tw.tween_property(v, "position", slot_pos(slot), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): v.bounce(0.3))

func _update_drag_glow() -> void:
	var pos := get_global_mouse_position()
	var slot := _slot_near(pos)
	for i in RunState.SLOTS:
		backdrop.plots[i].glow = 1.0 if i == slot else 0.0
	backdrop.bin_hot = drag.kind == "plant" and bin_rect.grow(20).has_point(pos)
	for i in RunState.SLOTS:
		var bv = board_views[i]
		if bv != null and bv != drag.view:
			bv.lifted = i == slot and run.board[i] != null

func _clear_glow() -> void:
	backdrop.bin_hot = false
	for i in RunState.SLOTS:
		backdrop.plots[i].glow = 0.0
		if board_views[i] != null: board_views[i].lifted = false

func _hover(pos: Vector2) -> void:
	var pi := _packet_at(pos)
	for i in packet_views.size(): packet_views[i].hovered = i == pi
	if pi >= 0:
		var e: Dictionary = run.shop[pi]
		if e.kind == "seed": _show_info_for_plant(e.plant, packet_views[pi].global_position + Vector2(0, -150), true)
		else: _show_info_item(e.item, packet_views[pi].global_position + Vector2(0, -150))
		return
	var si := _plant_at(pos)
	if si >= 0:
		_show_info_for_plant(run.board[si], board_views[si].global_position + Vector2(0, -140))
		return
	info_card.visible = false

func _plant_bbcode(p, shop := false) -> String:
	var s := "[font_size=26][b]%s[/b][/font_size]" % p.name
	if p.mutant: s += "  [color=#b04ad0]✦ glowing mutant[/color]"
	s += "\n[color=#6a6a5a]"
	if p.gen > 1: s += "Generation %d · " % p.gen
	var fams: Array = []
	for l in p.lineage: fams.append(Species.DATA[l].name)
	s += " × ".join(fams) + "[/color]\n"
	s += "[color=#d0601a][b]%d attack[/b][/color]   [color=#2f9a48][b]%d health[/b][/color]\n" % [p.atk, p.hp]
	for ab in p.abilities:
		var col: Color = Species.ABILITIES[ab].color.darkened(0.3)
		s += "[color=#%s][b]%s %d[/b][/color]  %s\n" % [col.to_html(false), Species.ABILITIES[ab].name, p.power(ab), Species.describe(ab, p.power(ab))]
	if p.pollen: s += "[color=#a07a00]Dusted with Magic Pollen: next cross is a glowing mutant![/color]\n"
	if shop: s += "[color=#6a6a5a]Tap to plant · drop on a plant to cross[/color]"
	else: s += "[color=#6a6a5a]Drag onto a plant to cross · to the bin to sell (+%d)[/color]" % p.sell_value()
	return s

func _show_info_for_plant(p, anchor: Vector2, shop := false) -> void:
	if p == null: return
	info_text.text = _plant_bbcode(p, shop)
	_place_card(anchor)

func _show_info_item(item: String, anchor: Vector2) -> void:
	var d: Dictionary = RunState.ITEMS[item]
	info_text.text = "[font_size=26][b]%s[/b][/font_size]\n%s\n[color=#6a6a5a]Drag onto one of your plants · %d sun[/color]" % [d.name, d.desc, d.cost]
	_place_card(anchor)

func _place_card(anchor: Vector2) -> void:
	info_card.visible = true
	info_card.reset_size()
	var s := info_card.get_combined_minimum_size()
	var p := anchor - Vector2(s.x * 0.5, s.y)
	p.x = clampf(p.x, 12, size.x - s.x - 12)
	p.y = clampf(p.y, 84, size.y - s.y - 12)
	info_card.position = p

# ======================================================================= shop actions

func _buy_to(index: int, slot: int) -> void:
	if slot < 0:
		_toast("Your garden is full! Cross two plants to make room.")
		packet_views[index].wobble = 1.0
		sfx.play("back")
		return
	if not run.can_afford(index):
		_toast("Not enough sun!")
		packet_views[index].wobble = 1.0
		hud.sun_bump = 1.0
		sfx.play("back")
		return
	var pv = packet_views[index]
	var p = run.buy_seed(index, slot)
	if p == null: return
	packet_views.remove_at(index)
	pv.queue_free()
	var v := _make_view(p, 1.0)
	v.position = slot_pos(slot)
	v.spawn_pop()
	board_views[slot] = v
	fx.burst(slot_pos(slot) + Vector2(0, -10), Color("a0703f"), 16, 220, "dot", 700, 5)
	fx.burst(slot_pos(slot) + Vector2(0, -40), v.leaf_col(), 10, 200, "petal", 300, 7)
	sfx.play("buy")
	hud.sun_bump = 1.0
	_sync_hud()
	_layout_packets(true)
	_update_hint()

func _use_item(index: int, slot: int) -> void:
	if run.board[slot] == null:
		_toast("Drop it on a plant!")
		return
	if not run.can_afford(index):
		_toast("Not enough sun!")
		sfx.play("back")
		return
	var item: String = run.shop[index].item
	if not run.use_item(index, slot):
		_toast("That plant is already dusted with pollen.")
		return
	var pv = packet_views[index]
	packet_views.remove_at(index)
	pv.queue_free()
	var v = board_views[slot]
	v.sync_stats()
	v.bounce(0.6)
	v.badge_bump_atk = 1.0
	v.badge_bump_hp = 1.0
	var head: Vector2 = v.global_position + v.head_offset()
	match item:
		"fertilizer":
			fx.number(head, "+1/+1", Color("8dff7a"))
			fx.burst(head, Color("8dff7a"), 14, 200, "star", 100, 7)
		"water":
			fx.number(head, "+3 health", Color("8fd1ff"))
			fx.burst(head + Vector2(0, -40), Color("8fd1ff"), 18, 160, "dot", 600, 5)
		"pollen":
			fx.label(head + Vector2(0, -50), "Pollinated!", Color("ffe066"), 26)
			fx.burst(head, Color("ffe066"), 24, 240, "star", 60, 7)
	sfx.play("bloom", 1.2)
	hud.sun_bump = 1.0
	_sync_hud()
	_update_hint()

func _sell(slot: int) -> void:
	var v = board_views[slot]
	var p = run.board[slot]
	var value: int = run.sell(slot)
	board_views[slot] = null
	fx.burst(v.global_position + Vector2(0, -40), Color("a0703f"), 18, 240, "dot", 500, 6)
	fx.number(v.global_position + Vector2(0, -90), "+%d sun" % value, Color("ffd34d"))
	var tw: Tween = v.create_tween()
	tw.tween_property(v, "scale", Vector2(0.1, 0.1), 0.2)
	tw.tween_callback(v.queue_free)
	sfx.play("pop", 0.8)
	_toast("Composted %s for %d sun." % [p.name, value], 1.6)
	_sync_hud()
	_update_hint()

func _on_reroll() -> void:
	if mode != "shop" or busy: return
	if not run.reroll():
		_toast("Not enough sun!")
		return
	hud.sun_bump = 1.0
	_rebuild_packets(true)
	sfx.play("swish", 0.8)

# ======================================================================= crossing

func _cross_preview(a, b) -> String:
	var atk: int = max(a.atk, b.atk) + int(ceil(min(a.atk, b.atk) / 2.0))
	var hp: int = max(a.hp, b.hp) + int(ceil(min(a.hp, b.hp) / 2.0)) + 1
	var merged: Dictionary = {}
	for parent in [a, b]:
		for ab in parent.abilities:
			if merged.has(ab): merged[ab] = "up"
			else: merged[ab] = "new"
	var parts: Array = []
	for ab in merged:
		var col: Color = Species.ABILITIES[ab].color.darkened(0.3)
		parts.append("[color=#%s][b]%s%s[/b][/color]" % [col.to_html(false), Species.ABILITIES[ab].name, " ▲" if merged[ab] == "up" else ""])
	var s := "[center][font_size=30][b]%s × %s[/b][/font_size]\n" % [a.name, b.name]
	s += "Generation %d hybrid  ·  about [color=#d0601a][b]%d[/b][/color]/[color=#2f9a48][b]%d[/b][/color]\n" % [max(a.gen, b.gen) + 1, atk, hp]
	s += "Abilities: " + ", ".join(parts)
	if merged.size() > 3: s += "\n[color=#a05000](only 3 abilities fit — the strongest survive)[/color]"
	if a.pollen or b.pollen: s += "\n[color=#b04ad0][b]✦ Magic Pollen: guaranteed glowing mutant! ✦[/b][/color]"
	else: s += "\n[color=#6a6a5a]%d%% chance of a glowing mutant[/color]" % int(Breeding.mutation_chance(a, b) * 100.0)
	var key := Species.pair_key(a.head(), b.head())
	if not save.herbarium.has(key): s += "\n[color=#2f9a48][b]New Herbarium entry![/b][/color]"
	return s + "[/center]"

func _cross_popup(text: String, on_cross: Callable, on_swap: Callable) -> void:
	var o := _new_overlay()
	popup = o
	var box := _center_panel(o, Vector2(620, 0))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(580, 0)
	rt.text = text
	box.add_child(rt)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	row.add_child(_button("Cross-pollinate!", Color("ff9ec4"), func():
		_close_popup()
		on_cross.call(), 28))
	if on_swap.is_valid():
		row.add_child(_button("Swap places", Color("9ad7ff"), func():
			_close_popup()
			on_swap.call(), 22))
	row.add_child(_button("Cancel", Color("e8dcc0"), _close_popup, 22))

func _close_popup() -> void:
	popup = null
	_close_overlay()

func _ask_cross(from: int, to: int) -> void:
	var a = run.board[from]
	var b = run.board[to]
	_cross_popup(_cross_preview(a, b), func(): _do_cross(from, to), func(): _do_swap(from, to))

func _ask_cross_packet(index: int, slot: int) -> void:
	if not run.can_afford(index):
		_toast("Not enough sun!")
		sfx.play("back")
		return
	var a = run.shop[index].plant
	var b = run.board[slot]
	var text := _cross_preview(a, b).replace("[/center]", "\n[color=#6a6a5a]Buys the packet (3 sun) and crosses it straight in.[/color][/center]")
	_cross_popup(text, func():
		var tmp := -1
		for i in RunState.SLOTS:
			if run.board[i] == null: tmp = i
		if tmp < 0:
			# Garden is full: cross directly without a temporary plot.
			var pv = packet_views[index]
			var p = run.shop[index].plant
			run.sun -= int(run.shop[index].cost)
			run.shop.remove_at(index)
			packet_views.remove_at(index)
			pv.queue_free()
			var child = Breeding.cross(run.board[slot], p, run.rng)
			var ghost := _make_view(p, 1.0)
			ghost.position = pv.global_position
			run.board[slot] = child
			_animate_cross(ghost, board_views[slot], slot, child)
			_sync_hud()
			_layout_packets(true)
		else:
			_buy_to(index, tmp)
			_do_cross(tmp, slot), Callable())

func _do_swap(from: int, to: int) -> void:
	run.move(from, to)
	var tmp = board_views[to]
	board_views[to] = board_views[from]
	board_views[from] = tmp
	_return_view(from)
	_return_view(to)
	sfx.play("swish")

func _do_cross(from: int, to: int) -> void:
	var va = board_views[from]
	var vb = board_views[to]
	var child = run.cross(from, to)
	if child == null: return
	board_views[from] = null
	_animate_cross(va, vb, to, child)

func _animate_cross(va: Node2D, vb: Node2D, slot: int, child) -> void:
	busy = true
	crossed_this_run = true
	info_card.visible = false
	var target := slot_pos(slot)
	sfx.play("cross")
	var tw := create_tween()
	tw.tween_property(va, "position", target + Vector2(-40, -30), 0.28).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(vb, "position", target + Vector2(40, -30), 0.28).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		fx.burst(target + Vector2(0, -80), Color("ff7aa8"), 12, 220, "heart", 150, 12)
		fx.burst(target + Vector2(0, -80), Color("ffe066"), 26, 280, "star", 100, 6))
	tw.tween_property(va, "position", target + Vector2(0, -40), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(vb, "position", target + Vector2(0, -40), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(va, "scale", Vector2(0.2, 0.2), 0.22)
	tw.parallel().tween_property(vb, "scale", Vector2(0.2, 0.2), 0.22)
	tw.tween_callback(func():
		va.queue_free()
		vb.queue_free()
		shake = 0.5
		fx.ring(target + Vector2(0, -60), Color("ffffff"), 140, 0.5)
		fx.burst(target + Vector2(0, -60), Color("fff4d6"), 30, 380, "petal", 200, 9)
		if child.mutant: fx.burst(target + Vector2(0, -60), Color("c58bff"), 30, 420, "star", 50, 9)
		var v := _make_view(child, 1.0)
		v.position = target
		v.spawn_pop()
		v.bounce(0.8)
		board_views[slot] = v
		var key: String = Breeding.herbarium_key(child)
		var is_new: bool = save.discover(key, child.mutant)
		if is_new: new_entries_this_run += 1
		_sync_hud()
		_update_hint()
		_reveal(child, is_new))

func _reveal(child, is_new: bool) -> void:
	sfx.play("mutant" if child.mutant else "bloom")
	var o := _new_overlay()
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(center)
	var heading := _label("GLOWING MUTANT!" if child.mutant else ("NEW HYBRID!" if is_new else "HYBRID!"), 64, Color("e9b6ff") if child.mutant else Color("ffe066"), 18)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.size = Vector2(size.x, 80)
	heading.position = Vector2(0, size.y * 0.08)
	center.add_child(heading)
	heading.pivot_offset = Vector2(size.x * 0.5, 40)
	heading.scale = Vector2(0.3, 0.3)
	heading.create_tween().tween_property(heading, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var view := PlantView.new()
	center.add_child(view)
	view.setup(child, 1.0)
	view.position = Vector2(size.x * 0.32, size.y * 0.62)
	view.scale = Vector2(2.3, 2.3)
	view.badge_scale = 0.8
	view.spawn_pop()
	var rays := Fx.new()
	center.add_child(rays)
	center.move_child(rays, 0)
	rays.burst(view.position + Vector2(0, -140), Color("ffe066"), 40, 520, "star", 40, 9)
	if child.mutant: rays.confetti(Rect2(0, 0, size.x, 10), 90)
	var panel := PanelContainer.new()
	panel.position = Vector2(size.x * 0.48, size.y * 0.24)
	panel.custom_minimum_size = Vector2(min(560.0, size.x * 0.46), 0)
	center.add_child(panel)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(min(520.0, size.x * 0.42), 0)
	var text := _plant_bbcode(child).split("\n")
	text.remove_at(text.size() - 1)
	var body := "\n".join(text)
	if is_new: body += "\n[color=#2f9a48][b]New Herbarium entry! %d/36 discovered[/b][/color]" % save.herbarium.size()
	body += "\n\n[color=#6a6a5a]Click anywhere to continue[/color]"
	rt.text = body
	panel.add_child(rt)
	var closer := Button.new()
	closer.flat = true
	closer.set_anchors_preset(Control.PRESET_FULL_RECT)
	closer.focus_mode = Control.FOCUS_NONE
	closer.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	closer.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	closer.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	o.add_child(closer)
	closer.pressed.connect(func():
		sfx.play("ui")
		_close_overlay()
		busy = false)

# ======================================================================= battle

func _on_fight() -> void:
	if mode != "shop" or busy or overlay != null: return
	if run.plant_count() == 0:
		_toast("Plant something first!")
		sfx.play("back")
		return
	busy = true
	info_card.visible = false
	mode = "battle"
	_set_shop_ui(false)
	_set_battle_ui(true)
	hint_label.text = ""
	speed = 1.0 if speed < 1.0 else speed
	skipping = false
	_update_speed_button()
	backdrop.night_target = 1.0
	backdrop.show_enemy_side = true
	sfx.music("battle")
	var player_front: Array = run.front_first()
	var rival: String = run.rival_name()
	rival_label.text = "vs " + rival
	run.fight()
	var enemy_board: Array = run.rival_board()
	var enemy_front: Array = []
	for i in range(enemy_board.size() - 1, -1, -1): enemy_front.append(enemy_board[i])
	# Re-run with the very same objects so uids line up with the views.
	var replay = Battle.new()
	replay.run(player_front, enemy_front, run.run_seed + run.round_number * 13)
	_play_battle(replay, player_front, enemy_front, rival)

func _play_battle(battle, player_front: Array, enemy_front: Array, rival: String) -> void:
	for i in RunState.SLOTS:
		if board_views[i] != null: board_views[i].visible = false
	battle_views.clear()
	last_pos.clear()
	for k in player_front.size():
		var v := _make_view(player_front[k], 1.0)
		v.position = _board_pos_of(player_front[k])
		v.angry = true
		battle_views[player_front[k].uid] = v
		v.create_tween().tween_property(v, "position", player_battle_pos(k), 0.4).set_trans(Tween.TRANS_QUAD)
	await _wait(0.3)
	_banner("VS  " + rival, Color("ffb0b0"))
	sfx.play("start")
	for k in enemy_front.size():
		var v := _make_view(enemy_front[k], -1.0)
		v.position = enemy_pos(k)
		v.angry = true
		v.spawn_pop()
		battle_views[enemy_front[k].uid] = v
		fx.burst(enemy_pos(k) + Vector2(0, -10), Color("a0703f"), 10, 200, "dot", 700, 5)
		sfx.play("pop", 1.0 + k * 0.1, -6)
		await _wait(0.14)
	await _wait(0.9)
	for e in battle.events:
		await _play_event(e)
	await _wait(0.4)
	_battle_over(battle.winner)

func _board_pos_of(p) -> Vector2:
	for i in RunState.SLOTS:
		if run.board[i] == p: return slot_pos(i)
	return slot_pos(RunState.SLOTS - 1)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / (speed if not skipping else 25.0)).timeout

func _view(uid: int):
	var v = battle_views.get(uid)
	if v != null and is_instance_valid(v): return v
	return null

func _vpos(uid: int) -> Vector2:
	var v = _view(uid)
	if v != null:
		last_pos[uid] = v.position
		return v.position
	return last_pos.get(uid, Vector2(size.x * 0.5, ground_y))

func _side_pos(side: int, k: int) -> Vector2:
	return player_battle_pos(k) if side == 0 else enemy_pos(k)

func _relayout(side: int, order: Array) -> void:
	for k in order.size():
		var v = _view(order[k])
		if v != null:
			v.create_tween().tween_property(v, "position", _side_pos(side, k), 0.25 / speed).set_trans(Tween.TRANS_QUAD)

func _play_event(e: Dictionary) -> void:
	match e.t:
		"begin":
			await _wait(0.1)
		"ability":
			var src: Vector2 = _vpos(e.src)
			var v = _view(e.src)
			var col: Color = Species.ABILITIES[e.ab].color
			var head := src + Vector2(0, -70)
			if v != null:
				v.bounce(0.5)
				head = src + v.head_offset()
			fx.label(head + Vector2(randf_range(-20, 20), -105), Species.ABILITIES[e.ab].name + "!", col, 24)
			fx.ring(head, col, 80, 0.4)
			match e.ab:
				"sunburst":
					sfx.play("bloom", 1.4, -4)
					fx.ring(head, Color("ffe066"), 220, 0.6)
					fx.burst(head, Color("ffe066"), 22, 360, "star", 0, 7)
				"leech":
					sfx.play("zap", 1.2)
					fx.beam(_vpos(e.targets[0]) + Vector2(0, -60), head, Color("7fe0ff"), 7, 0.4)
				"lash":
					sfx.play("swish", 0.7)
					fx.beam(head, _vpos(e.targets[0]) + Vector2(0, -60), Color("47c98a"), 10, 0.4)
					shake = max(shake, 0.25)
				"thorns":
					fx.burst(head, Color("f1e2c0"), 10, 260, "star", 200, 5)
				"devour":
					if v != null: v.chomp = 1.0
					sfx.play("hit", 0.6)
					fx.burst(head, Color("ff5a4a"), 14, 240, "heart", 100, 9)
				"burst":
					sfx.play("pop", 0.6)
					fx.burst(src + Vector2(0, -40), Color("ff8ab3"), 30, 320, "dot", -40, 9)
					fx.beam(src + Vector2(0, -40), _vpos(e.targets[0]) + Vector2(0, -60), Color("ff8ab3"), 12, 0.35, false)
				"reseed":
					fx.burst(src + Vector2(0, -20), Color("7bd65a"), 18, 200, "petal", 300, 7)
			await _wait(0.42 if e.ab != "thorns" else 0.18)
		"buff":
			var v = _view(e.uid)
			if v != null:
				v.display_atk = e.atk
				v.display_hp = e.hp
				if e.datk != 0: v.badge_bump_atk = 1.0
				if e.dhp != 0: v.badge_bump_hp = 1.0
				var txt := ""
				if e.datk != 0: txt += ("+%d" % e.datk if e.datk > 0 else "%d" % e.datk) + " atk "
				if e.dhp != 0: txt += "+%d hp" % e.dhp
				fx.number(v.position + Vector2(0, -20), txt.strip_edges(), Color("8dff7a") if e.datk >= 0 else Color("ff8a8a"), 24)
			await _wait(0.12)
		"clash":
			var a = _view(e.a)
			var b = _view(e.b)
			if a == null or b == null: return
			var tw := create_tween().set_parallel(true)
			tw.tween_property(a, "lunge", -16.0, 0.12 / speed)
			tw.tween_property(b, "lunge", -16.0, 0.12 / speed)
			await tw.finished
			if not is_instance_valid(a) or not is_instance_valid(b): return
			var tw2 := create_tween().set_parallel(true)
			tw2.tween_property(a, "lunge", 54.0, 0.09 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw2.tween_property(b, "lunge", 54.0, 0.09 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await tw2.finished
			if not is_instance_valid(a) or not is_instance_valid(b): return
			if a.plant.head() == "snap": a.chomp = 1.0
			if b.plant.head() == "snap": b.chomp = 1.0
			var mid: Vector2 = (a.position + b.position) * 0.5 + Vector2(0, -60)
			fx.burst(mid, Color("fff4b0"), 16, 360, "star", 300, 6)
			fx.ring(mid, Color.WHITE, 70, 0.25)
			shake = max(shake, 0.35)
			sfx.play("hit", 1.0)
			var tw3 := create_tween().set_parallel(true)
			tw3.tween_property(a, "lunge", 0.0, 0.25 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw3.tween_property(b, "lunge", 0.0, 0.25 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"dmg":
			var v = _view(e.uid)
			if v != null:
				v.display_hp = e.hp
				v.flash = 1.0
				v.hurt = 1.0
				v.badge_bump_hp = 1.0
				var col := Color("ff5a5a") if e.kind != "poison" else Color("c58bff")
				fx.number(v.position + v.head_offset() + Vector2(0, -30), "-%d" % e.amt, col, 34 if e.amt >= 5 else 28)
				fx.burst(v.position + v.head_offset(), v.leaf_col(), 6, 200, "petal", 400, 6)
				if e.amt >= 6: shake = max(shake, 0.6)
			await _wait(0.16 if e.kind != "hit" else 0.08)
		"poisoned":
			var v = _view(e.uid)
			if v != null:
				v.display_poison = e.poison
				fx.burst(v.position + v.head_offset(), Color("a35cff"), 10, 120, "dot", -120, 6)
		"poison_tick":
			await _wait(0.2)
		"faint":
			var v = _view(e.uid)
			if v != null:
				last_pos[e.uid] = v.position
				battle_views.erase(e.uid)
				sfx.play("lose", 1.6, -8)
				fx.burst(v.position + v.head_offset(), v.flower_col(), 22, 300, "petal", 350, 8)
				fx.burst(v.position + v.head_offset(), v.leaf_col(), 12, 260, "petal", 350, 7)
				var tw: Tween = v.create_tween()
				tw.tween_property(v, "wilt", 1.0, 0.35 / speed)
				tw.tween_property(v, "modulate:a", 0.0, 0.25 / speed)
				tw.tween_callback(v.queue_free)
			await _wait(0.3)
			_relayout(e.side, e.order)
			await _wait(0.2)
		"summon":
			var p = e.plant
			var v := _make_view(p, 1.0 if e.side == 0 else -1.0)
			v.angry = true
			var k: int = e.order.find(p.uid)
			v.position = _side_pos(e.side, k)
			v.spawn_pop()
			battle_views[p.uid] = v
			fx.burst(v.position, Color("a0703f"), 14, 220, "dot", 700, 5)
			sfx.play("pop", 1.4)
			_relayout(e.side, e.order)
			await _wait(0.35)
		"end":
			pass

func _battle_over(winner: int) -> void:
	_set_battle_ui(false)
	skipping = false
	var text := "DRAW"
	var col := Color("e8dcc0")
	if winner == 0:
		text = "VICTORY!"
		col = Color("ffe066")
		sfx.play("win")
		fx.confetti(Rect2(0, 0, size.x, 10), 120)
		for v in battle_views.values():
			if is_instance_valid(v) and v.facing > 0:
				_victory_hop(v)
		hud.trophy_bump = 1.0
	elif winner == 1:
		text = "DEFEAT"
		col = Color("ff8a8a")
		sfx.play("lose")
		hud.heart_shake = 1.0
		shake = 0.8
	hud.hearts = run.hearts
	hud.trophies = run.trophies
	var o := _new_overlay(false)
	var l := _label(text, 120, col, 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(size.x, 150)
	l.position = Vector2(0, size.y * 0.13)
	l.pivot_offset = Vector2(size.x * 0.5, 75)
	l.scale = Vector2(0.2, 0.2)
	o.add_child(l)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var sub_text := ""
	if winner == 0: sub_text = "+1 trophy  (%d/%d)" % [run.trophies, RunState.TROPHIES_TO_WIN]
	elif winner == 1: sub_text = "-1 heart  (%d left)" % run.hearts
	else: sub_text = "Nobody wins this one."
	var sub := _label(sub_text, 30, Color.WHITE, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(size.x, 40)
	sub.position = Vector2(0, size.y * 0.13 + 150)
	o.add_child(sub)
	await get_tree().create_timer(0.7).timeout
	if not is_instance_valid(o): return
	var cont := _button("Continue", Color("c9f0a8"), _after_battle, 30)
	cont.size = Vector2(220, 64)
	cont.position = Vector2(size.x * 0.5 - 110, size.y - 120)
	o.add_child(cont)
	o.mouse_filter = Control.MOUSE_FILTER_STOP

func _victory_hop(v: Node2D) -> void:
	var tw: Tween = v.create_tween().set_loops(3)
	tw.tween_property(v, "position:y", v.position.y - 30, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "position:y", v.position.y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _after_battle() -> void:
	_close_overlay()
	for v in battle_views.values():
		if is_instance_valid(v): v.queue_free()
	battle_views.clear()
	if run.is_over():
		show_run_end()
		return
	run.next_round()
	_enter_shop()

func _on_speed() -> void:
	speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else 1.0)
	_update_speed_button()

func _update_speed_button() -> void:
	speed_button.text = "Speed %dx" % int(speed)

func _on_skip() -> void:
	skipping = true

# ======================================================================= run end

func show_run_end() -> void:
	mode = "end"
	var won: bool = run.won()
	save.best_trophies = max(save.best_trophies, run.trophies)
	if won: save.cups += 1
	save.save()
	var o := _new_overlay()
	if won:
		sfx.play("win")
		fx.confetti(Rect2(0, 0, size.x, 10), 200)
	var box := _center_panel(o, Vector2(720, 0))
	var h := _label("GARDEN CUP CHAMPION!" if won else "Your garden wilted...", 50, Color("c47a00") if won else OUT)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	var best = null
	for p in run.board:
		if p != null and (best == null or p.strength() > best.strength()): best = p
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(680, 250)
	box.add_child(stage)
	if best != null:
		var v := PlantView.new()
		stage.add_child(v)
		v.setup(best, 1.0)
		v.scale = Vector2(1.7, 1.7)
		v.position = Vector2(170, 210)
		v.badge_scale = 0.8
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.position = Vector2(320, 30)
		rt.custom_minimum_size = Vector2(350, 0)
		rt.text = "[b]Star plant[/b]\n[font_size=28][b]%s[/b][/font_size]\nGeneration %d · %d/%d" % [best.name, best.gen, best.atk, best.hp]
		stage.add_child(rt)
	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.fit_content = true
	stats.custom_minimum_size = Vector2(680, 0)
	stats.text = "[center]Trophies [b]%d/%d[/b]  ·  Rounds [b]%d[/b]  ·  New Herbarium entries [b]%d[/b]  (%d/36)[/center]" % [run.trophies, RunState.TROPHIES_TO_WIN, run.round_number, new_entries_this_run, save.herbarium.size()]
	box.add_child(stats)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(_button("Play again", Color("ff8a5c"), _start_run, 30))
	row.add_child(_button("Title", Color("e8dcc0"), func():
		_close_overlay()
		show_title(), 24))

# ======================================================================= herbarium

func show_herbarium() -> void:
	var from_title := mode == "title"
	var o := _new_overlay()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = 24
	panel.offset_bottom = -24
	o.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label("Herbarium   %d/36" % save.herbarium.size(), 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Close", Color("e8dcc0"), func():
		_close_overlay()
		if from_title: show_title(), 22))
	var sub := _label("Cross two families to discover their hybrid. ✦ marks a glowing mutant you've bred.", 20, Color("6a6a5a"))
	box.add_child(sub)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	box.add_child(area)
	var keys: Array = Species.herbarium_keys()
	var cols := 9
	var cell := Vector2((size.x - 110) / cols, (size.y - 190) / 4.0)
	for i in keys.size():
		var key: String = keys[i]
		var parts: PackedStringArray = key.split("+")
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		var a = Plant.create(parts[0], rng)
		var b = Plant.create(parts[1], rng)
		var known: bool = save.herbarium.has(key)
		var mut: bool = known and bool(save.herbarium[key].mutant)
		var c = Breeding.cross(a, b, rng, mut)
		c.mutant = mut
		if parts[0] == parts[1]: c.name = a.name + " II"
		var pos := Vector2((i % cols + 0.5) * cell.x, (int(i / cols) + 1.0) * cell.y - 26)
		var v := PlantView.new()
		area.add_child(v)
		v.setup(c, 1.0)
		v.show_badges = false
		var s: float = clampf(cell.y / 170.0, 0.5, 0.95)
		v.scale = Vector2(s, s)
		v.position = pos
		if not known:
			v.modulate = Color(0, 0, 0, 0.3)
		var name_l := _label(c.name if known else "???", 16, OUT if known else Color("8a8470"))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.size = Vector2(cell.x, 20)
		name_l.position = Vector2(pos.x - cell.x * 0.5, pos.y + 4)
		area.add_child(name_l)
		var fam := _label("%s × %s" % [Species.DATA[parts[0]].name, Species.DATA[parts[1]].name], 12, Color("8a8470"))
		fam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fam.size = Vector2(cell.x, 16)
		fam.position = Vector2(pos.x - cell.x * 0.5, pos.y + 22)
		area.add_child(fam)
		if mut:
			var star := _label("✦", 22, Color("b04ad0"))
			star.position = pos + Vector2(cell.x * 0.3, -cell.y * 0.7)
			area.add_child(star)

# ======================================================================= misc

func _banner(text: String, col: Color) -> void:
	var l := _label(text, 72, col, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(size.x, 100)
	l.position = Vector2(0, size.y * 0.2)
	l.pivot_offset = Vector2(size.x * 0.5, 50)
	l.scale = Vector2(0.3, 0.3)
	_ui_root().add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)

func _toast(text: String, duration := 2.0) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var tw := toast_label.create_tween()
	tw.tween_interval(duration)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.4)

func _on_menu() -> void:
	if mode == "battle": return
	var o := _new_overlay()
	popup = o
	var box := _center_panel(o, Vector2(420, 0))
	var h := _label("Paused", 40)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	box.add_child(_button("Resume", Color("c9f0a8"), _close_popup, 26))
	box.add_child(_button("How to play", Color("9ad7ff"), func():
		popup = null
		show_how_to(), 24))
	box.add_child(_button("Herbarium", Color("e8dcc0"), func():
		popup = null
		show_herbarium(), 24))
	box.add_child(_button("Abandon run", Color("ff9e9e"), func():
		popup = null
		_close_overlay()
		show_title(), 24))

func _on_sound() -> void:
	save.muted = not save.muted
	save.save()
	sfx.set_muted(save.muted)
	if not save.muted: sfx.current_music = ""
	sfx.music("battle" if mode == "battle" else "shop")
	_update_sound_button()

func _update_sound_button() -> void:
	sound_button.text = "Sound: off" if save.muted else "Sound: on"
