extends Node2D
## Small, non-interactive world annotations. They describe real session objects
## and light pull; they never choose a solution or change the simulation.

const GOLD := Color("ffdc83")
const CYAN := Color("91eee0")
const LEAF := Color("c2edaf")
const VIOLET := Color("d0a5ee")
const PAPER := Color("f0f2e7")
var session
var safe_rect := Rect2(24, 180, 1552, 695)
var font: Font
var time := 0.0
var focused_kind := ""
var focused_index := 0
var focused_until := 0.0
var focused_position := Vector2.ZERO
var focused_text := ""
var feedback_position := Vector2.ZERO
var feedback_message := ""
var feedback_valid := false
var feedback_until := 0.0
var preview_position := Vector2.ZERO
var preview_valid := true
var preview_reason := ""
var preview_visible := false
var hover_lure := -1
var pointer_world := Vector2.INF
var feedback_title := ""
var _occupied: Array[Rect2] = []
var _last_goals: Dictionary = {}
var _recent_goals: Dictionary = {}
var _last_wilds: Dictionary = {}
var _recent_wilds: Dictionary = {}

func setup(s) -> void:
	session = s
	font = ThemeDB.fallback_font
	visible = str(s.def.get("id", "")) != "demo"
	time = 0.0
	clear_focus()
	preview_visible = false
	feedback_until = 0.0
	pointer_world = Vector2.INF
	_last_goals.clear()
	_recent_goals.clear()
	_last_wilds.clear()
	_recent_wilds.clear()
	set_meta("world_annotations", true)
	queue_redraw()

func focus_target(kind: String, index := 0, duration := 6.0) -> void:
	focused_kind = {"sunwell":"goal", "key":"switch", "wisp":"decoy"}.get(kind, kind)
	focused_index = index
	focused_text = ""
	focused_until = time + maxf(0.1, duration)
	queue_redraw()

func focus_position(point: Vector2, text := "", duration := 5.0) -> void:
	focused_kind = "position"
	focused_position = point
	focused_text = text
	focused_until = time + maxf(0.1, duration)
	queue_redraw()

func clear_focus() -> void:
	focused_kind = ""
	focused_until = 0.0
	queue_redraw()

func show_lure_feedback(point: Vector2, message: String, valid := false, duration := 2.5) -> void:
	show_action_feedback(point, message, valid, duration, "Lure placed" if valid else "Can't place a lure")

func show_action_feedback(point: Vector2, message: String, valid := false, duration := 2.5, title := "") -> void:
	feedback_position = point
	feedback_message = message
	feedback_valid = valid
	feedback_title = title if not title.is_empty() else ("Done" if valid else "Try another spot")
	feedback_until = time + maxf(0.1, duration)
	queue_redraw()

func set_pointer_world(point: Vector2) -> void:
	pointer_world = point
	queue_redraw()

func set_lure_preview(point: Vector2, valid := true, reason := "") -> void:
	preview_position = point
	preview_valid = valid
	preview_reason = reason
	preview_visible = true
	queue_redraw()

func clear_lure_preview() -> void:
	preview_visible = false
	queue_redraw()

func _wild_position(index: int) -> Vector2:
	var wild: Dictionary = session.world.wilds[index]
	var point: Vector2 = wild.pos + Vector2(0, -55)
	for node: Vector2 in wild.get("nodes", PackedVector2Array()):
		if node.y < point.y: point = node
	return point

func describe_target(kind: String, index := 0) -> Dictionary:
	if session == null: return {}
	match kind:
		"goal":
			if index < 0 or index >= session.world.goals.size(): return {}
			var goal: Dictionary = session.world.goals[index]
			var detail := "Grow a shoot into the ring"
			if goal.reached: detail = "Reached — this sunwell is awake"
			elif session.world.sleeping(goal): detail = "Reach goal %d first" % (int(goal.after) + 1)
			return {"kind":kind, "index":index, "position":goal.pos, "title":"GOAL %d" % (index + 1), "detail":detail, "color":GOLD}
		"wild":
			if index < 0 or index >= session.world.wilds.size(): return {}
			var wild: Dictionary = session.world.wilds[index]
			var gifts: Array[String] = []
			for entry: Array in [["thorns","Thorns"],["glow","Glow"],["tendrils","Tendrils"],["roots","Roots"],["buoyant","Buoyancy"],["waxy","Wax"]]:
				if int(wild.genome.get(str(entry[0]), 0)) > 0: gifts.append(str(entry[1]))
			var name: String = str(wild.genome.get("name", "Wild plant"))
			var title: String = "Wild gift · " + " + ".join(gifts) if not gifts.is_empty() else name
			var detail := "Touch with a shoot → hybrid seeds"
			if wild.pollinated: detail = "Pollinated — new hybrid seeds"
			return {"kind":kind, "index":index, "position":_wild_position(index), "title":title, "detail":detail, "color":LEAF}
		"lure":
			if index < 0 or index >= session.world.lures.size(): return {}
			return {"kind":kind, "index":index, "position":session.world.lures[index], "title":"LIGHT LURE", "detail":"Drag to pull shoots this way", "color":CYAN}
		"switch":
			if index < 0 or index >= session.world.switches.size(): return {}
			var key: Dictionary = session.world.switches[index]
			return {"kind":kind, "index":index, "position":key.pos, "title":"BLOOM KEY", "detail":"Gate opened" if key.on else "Touch with a shoot → opens the gate", "color":GOLD}
		"decoy":
			if index < 0 or index >= session.world.decoys.size(): return {}
			return {"kind":kind, "index":index, "position":session.world.decoys[index].pos, "title":"WANDERING WISP", "detail":"Pulls shoots; not a sunwell", "color":VIOLET}
		"seed":
			return {"kind":kind, "index":0, "position":session.world.seed_pos, "title":"YOUR PLANT", "detail":"Shoots grow upward toward light", "color":LEAF}
	return {}

func _process(delta: float) -> void:
	time += delta
	if session == null: return
	for index: int in range(session.world.goals.size()):
		var reached: bool = session.world.goals[index].reached
		if reached and not _last_goals.get(index, false): _recent_goals[index] = time + 3.5
		_last_goals[index] = reached
	for index: int in range(session.world.wilds.size()):
		var touched: bool = session.world.wilds[index].pollinated
		if touched and not _last_wilds.get(index, false): _recent_wilds[index] = time + 3.5
		_last_wilds[index] = touched
	queue_redraw()

func _draw() -> void:
	if session == null or font == null: return
	_occupied.clear()
	_draw_object_marks()
	var featured: Array[String] = []
	if focused_until > time:
		if focused_kind == "position":
			_halo(focused_position, PAPER)
			if not focused_text.is_empty(): _label(focused_position, focused_text, "", PAPER)
		else:
			var selected: Dictionary = describe_target(focused_kind, focused_index)
			if not selected.is_empty():
				_annotate(selected, true)
				featured.append(focused_kind + str(focused_index))
	var hovered: Dictionary = _hovered()
	if not hovered.is_empty() and not featured.has(str(hovered.kind) + str(hovered.index)):
		_annotate(hovered, false)
		featured.append(str(hovered.kind) + str(hovered.index))
	# Brief introductions identify the first objective/gift, then leave the art
	# open. Hover and the HUD's Show me button can always bring a label back.
	var intro: float = 22.0 if str(session.def.get("id", "")) in ["first_light", "twin_wells", "crystal_throat"] else 8.0
	if time < intro and featured.size() < 2:
		for index: int in range(session.world.goals.size()):
			if session.world.goals[index].reached or session.world.sleeping(session.world.goals[index]): continue
			if not featured.has("goal" + str(index)):
				_annotate(describe_target("goal", index), false)
				featured.append("goal" + str(index))
			break
	if time < intro and featured.size() < 2:
		for index: int in range(session.world.wilds.size()):
			if session.world.wilds[index].pollinated: continue
			if not featured.has("wild" + str(index)): _annotate(describe_target("wild", index), false)
			break
	for index: int in _recent_goals:
		if time < float(_recent_goals[index]) and not featured.has("goal" + str(index)):
			_annotate(describe_target("goal", index), false)
	for index: int in _recent_wilds:
		if time < float(_recent_wilds[index]) and not featured.has("wild" + str(index)):
			_annotate(describe_target("wild", index), false)
	if preview_visible:
		var color: Color = CYAN if preview_valid else Color("edac9e")
		_diamond(preview_position, 11, color, true)
		if preview_valid: _pull_arrows(preview_position)
		elif not preview_reason.is_empty(): _label(preview_position, "Can't place a lure here", preview_reason, color)
	if feedback_until > time:
		var color: Color = CYAN if feedback_valid else Color("edac9e")
		var point: Vector2 = feedback_position
		draw_arc(point, 19 + sin(time * 8) * 2, 0, TAU, 30, Color(color, 0.7), 2, true)
		if not feedback_valid:
			draw_line(point + Vector2(-6, -6), point + Vector2(6, 6), color, 2, true)
			draw_line(point + Vector2(6, -6), point + Vector2(-6, 6), color, 2, true)
		_label(point, feedback_title, feedback_message, color)

func _draw_object_marks() -> void:
	for index: int in range(session.world.goals.size()):
		var goal: Dictionary = session.world.goals[index]
		var point: Vector2 = goal.pos + Vector2(25, -25)
		draw_circle(point, 12, Color("17292a"))
		draw_arc(point, 12, 0, TAU, 24, Color(GOLD, 0.9 if not session.world.sleeping(goal) else 0.35), 1.4, true)
		if goal.reached:
			draw_polyline(PackedVector2Array([point + Vector2(-5, 0), point + Vector2(-1, 4), point + Vector2(6, -5)]), GOLD, 2, true)
		else:
			draw_string(font, point + Vector2(-7, 5), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, 14, 14, Color(GOLD, 0.5 if session.world.sleeping(goal) else 1.0))
	for index: int in range(session.world.lures.size()):
		var point: Vector2 = session.world.lures[index]
		_diamond(point, 12, Color(CYAN, 0.8), false)
		if index == hover_lure or (focused_kind == "lure" and focused_index == index and focused_until > time): _pull_arrows(point)
	for index: int in range(session.world.switches.size()):
		var key: Dictionary = session.world.switches[index]
		if key.on: continue
		var point: Vector2 = key.pos + Vector2(23, -22)
		draw_rect(Rect2(point - Vector2(8, 6), Vector2(16, 12)), Color("26312d"))
		draw_rect(Rect2(point - Vector2(8, 6), Vector2(16, 12)), GOLD, false, 1.5)
		draw_arc(point + Vector2(0, -6), 5, PI, TAU, 12, GOLD, 1.5, true)
	for decoy: Dictionary in session.world.decoys:
		for index: int in range(3):
			var angle: float = index * TAU / 3 + time * 0.3
			draw_arc(decoy.pos, 17, angle, angle + 0.9, 10, Color(VIOLET, 0.65), 1.3, true)

func _hovered() -> Dictionary:
	if hover_lure >= 0: return describe_target("lure", hover_lure)
	var pointer: Vector2 = pointer_world
	if not safe_rect.has_point(pointer): return {}
	var nearest: Dictionary = {}
	var distance: float = 54.0
	for entry: Array in [["goal", session.world.goals.size()],["wild", session.world.wilds.size()],["switch", session.world.switches.size()],["decoy", session.world.decoys.size()]]:
		for index: int in range(int(entry[1])):
			var row: Dictionary = describe_target(str(entry[0]), index)
			var separation: float = pointer.distance_to(row.position)
			if separation < distance: distance = separation; nearest = row
	return nearest

func _annotate(row: Dictionary, focus: bool) -> void:
	if row.is_empty(): return
	if focus: _halo(row.position, row.color)
	_label(row.position, str(row.title), str(row.detail), row.color)

func _halo(point: Vector2, color: Color) -> void:
	var radius: float = 38 + sin(time * 3) * 3
	for index: int in range(4):
		var angle: float = index * PI / 2 + 0.12
		draw_arc(point, radius, angle, angle + 0.5, 12, Color(color, 0.9), 2.4, true)

func _diamond(point: Vector2, radius: float, color: Color, center: bool) -> void:
	var shape := PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point + Vector2(-radius, 0), point + Vector2(0, -radius)])
	draw_polyline(shape, color, 1.5, true)
	if center: draw_circle(point, 2.5, color)

func _pull_arrows(light: Vector2) -> void:
	var tips: Array[Vector2] = []
	for tip: Dictionary in session.plant.tips:
		var index: int = int(tip.node)
		if session.plant.alive[index] != 1 or session.plant.kind[index] != 0: continue
		var point: Vector2 = session.plant.pos[index]
		if point.distance_to(light) < 50 or point.distance_to(light) > 1600: continue
		tips.append(point)
	tips.sort_custom(func(a: Vector2,b: Vector2): return a.distance_squared_to(light) < b.distance_squared_to(light))
	for point: Vector2 in tips.slice(0, 3):
		var direction: Vector2 = point.direction_to(light)
		var start: Vector2 = point + direction * 14
		var end: Vector2 = start + direction * 37
		draw_line(start, end, Color(CYAN, 0.45), 1.7, true)
		draw_line(end, end - direction.rotated(0.5) * 9, Color(CYAN, 0.7), 1.7, true)
		draw_line(end, end - direction.rotated(-0.5) * 9, Color(CYAN, 0.7), 1.7, true)

func _lines(text: String, width: float, size_px: int) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	for word: String in text.split(" ", false):
		var candidate: String = word if current.is_empty() else current + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width and not current.is_empty():
			result.append(current)
			current = word
		else: current = candidate
	if not current.is_empty(): result.append(current)
	return result

func _label(anchor: Vector2, title: String, detail: String, color: Color) -> void:
	var width: float = clampf(maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) + 28, 120, 310)
	var lines: Array[String] = _lines(detail, width - 24, 14)
	var height: float = 35 + mini(2, lines.size()) * 19
	var rect:=Rect2(anchor + Vector2(-width * 0.5, -height - 35), Vector2(width, height))
	for offset: Vector2 in [Vector2(-width * 0.5, -height - 35),Vector2(-width * 0.5, 42),Vector2(45, -height * 0.5),Vector2(-width - 45, -height * 0.5)]:
		rect.position = anchor + offset
		rect.position.x = clampf(rect.position.x, safe_rect.position.x, maxf(safe_rect.position.x, safe_rect.end.x - width))
		rect.position.y = clampf(rect.position.y, safe_rect.position.y, maxf(safe_rect.position.y, safe_rect.end.y - height))
		var clear: bool = not rect.grow(20).has_point(anchor)
		for other: Rect2 in _occupied:
			if other.grow(8).intersects(rect): clear = false; break
		if clear: break
	_occupied.append(rect)
	var edge: Vector2 = Vector2(clampf(anchor.x, rect.position.x + 12, rect.end.x - 12),clampf(anchor.y, rect.position.y + 8, rect.end.y - 8))
	draw_line(anchor, edge, Color(color, 0.45), 1.2, true)
	var box:=StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.055, 0.065, 0.88)
	box.border_color = Color(color, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	draw_style_box(box, rect)
	draw_string(font, rect.position + Vector2(12, 24), title, HORIZONTAL_ALIGNMENT_LEFT, width - 24, 17, color)
	for index: int in range(mini(2, lines.size())):
		draw_string(font, rect.position + Vector2(12, 45 + index * 19), lines[index], HORIZONTAL_ALIGNMENT_LEFT, width - 24, 14, PAPER)
