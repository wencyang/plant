extends Node2D
## A read-only picture of the exact prune operation. The simulation supplies
## removed nodes, surviving shoot directions and sap; this view invents none.

const CUT := Color("f2b17d")
const REMOVED := Color("ed927f")
const NEW_GROWTH := Color("b7ed9e")
const PAPER := Color("edf1e5")
var session
var plant_view: Node2D
var annotation_layer: Node2D
var safe_rect := Rect2(24, 180, 1552, 695)
var preview: Dictionary = {}
var points: Array = []
var font: Font
var label_rect := Rect2()
var title := ""
var detail := ""
var instruction := ""
var t := 0.0

func setup(s, source: Node2D, labels: Node2D = null) -> void:
	session = s
	plant_view = source
	annotation_layer = labels
	font = ThemeDB.fallback_font
	set_meta("prune_preview_overlay", true)
	clear_preview()

func set_preview(path: Array) -> Dictionary:
	points.clear()
	for point in path:
		if point is Vector2 and is_finite(point.x) and is_finite(point.y): points.append(point)
	if points.is_empty():
		clear_preview()
		return {}
	visible = true
	preview = session.plant.preview_prune_path(points) if session != null and session.plant.has_method("preview_prune_path") else {}
	_update_text()
	queue_redraw()
	return preview.duplicate(true)

func clear_preview() -> void:
	visible = false
	preview = {}
	points.clear()
	label_rect = Rect2()
	title = ""
	detail = ""
	instruction = ""
	queue_redraw()

func _update_text() -> void:
	instruction = "Release to cut · right-click / Esc cancels"
	if session == null: return
	if int(session.prunes_left) <= 0:
		title = "No prunes left"
		detail = "Release will leave your plant unchanged"
		instruction = "Right-click / Esc cancels"
	elif not bool(preview.get("has_hits", false)):
		title = "Cross a living stem"
		detail = "No cut at this spot"
		instruction = "Keep drawing · right-click / Esc cancels"
	else:
		var shoots: int = int(preview.get("new_shoots", 0))
		title = "Cut → %d new shoots" % shoots if shoots != 1 else "Cut → 1 new shoot"
		if shoots == 0: title = "Cut preview · no new shoots"
		detail = "Returns ~%d sap · uses 1 prune" % roundi(float(preview.get("sap_refund", 0)))

func _process(delta: float) -> void:
	if not visible: return
	t += delta
	_update_text()
	queue_redraw()

func _render_node(index: int, fallback: Vector2) -> Vector2:
	if session == null or index < 0 or index >= session.plant.pos.size(): return fallback
	if is_instance_valid(plant_view): return plant_view.P(index)
	return session.plant.pos[index]

func _render_cut(cut: Dictionary) -> Vector2:
	var point: Vector2 = cut.get("position", Vector2.ZERO)
	var index: int = int(cut.get("node_id", -1))
	var parent: int = int(cut.get("parent_id", -1))
	if index < 0 or parent < 0 or session == null or index >= session.plant.pos.size(): return point
	var start: Vector2 = session.plant.pos[parent]
	var finish: Vector2 = session.plant.pos[index]
	var fraction: float = clampf(start.distance_to(point) / maxf(0.001, start.distance_to(finish)), 0, 1)
	return _render_node(parent, start).lerp(_render_node(index, finish), fraction)

func _render_anchor(point: Vector2) -> Vector2:
	for cut: Dictionary in preview.get("cuts", []):
		var anchor: Vector2 = cut.get("anchor", Vector2.INF)
		if anchor.distance_squared_to(point) < 0.01: return _render_node(int(cut.get("parent_id", -1)), point)
	return point

func _draw() -> void:
	if session == null or points.is_empty() or font == null: return
	var available: bool = int(session.prunes_left) > 0
	var hit: bool = available and bool(preview.get("has_hits", false))
	if hit:
		_draw_removed()
		for cut: Dictionary in preview.get("cuts", []): _scissors(_render_cut(cut))
		var origins: Array = preview.get("new_shoot_positions", [])
		var directions: Array = preview.get("new_shoot_directions", [])
		for index: int in range(mini(origins.size(), directions.size())):
			_arrow(_render_anchor(origins[index]), directions[index])
	var cursor: Vector2 = points.back()
	var color: Color = CUT if hit else Color("b9c9bc")
	if not available: color = REMOVED
	if not hit:
		draw_arc(cursor, 9 + sin(t * 4) * 1.2, 0, TAU, 24, Color(color, 0.65), 1.3, true)
	_label(cursor, color)

func _draw_removed() -> void:
	for segment: Array in preview.get("removed_segments", []):
		if segment.size() < 3: continue
		var index: int = int(segment[2])
		if index < 0 or index >= session.plant.pos.size(): continue
		var parent: int = int(session.plant.parent[index])
		var start: Vector2 = _render_node(parent, segment[0])
		var finish: Vector2 = _render_node(index, segment[1])
		if start.distance_squared_to(finish) < 0.25: continue
		draw_line(start, finish, Color(REMOVED, 0.16), 9.0, true)
		draw_line(start, finish, Color(CUT, 0.78), 2.6, true)

func _scissors(point: Vector2) -> void:
	draw_circle(point, 12, Color(0.045, 0.07, 0.075, 0.72))
	draw_arc(point, 13, 0, TAU, 24, Color(CUT, 0.7), 1.0, true)
	draw_circle(point + Vector2(-5, 6), 3.0, Color(CUT, 0.9), false, 1.5, true)
	draw_circle(point + Vector2(5, 6), 3.0, Color(CUT, 0.9), false, 1.5, true)
	draw_line(point + Vector2(-4, 4), point + Vector2(7, -8), CUT, 1.7, true)
	draw_line(point + Vector2(4, 4), point + Vector2(-7, -8), CUT, 1.7, true)

func _arrow(point: Vector2, raw_direction: Vector2) -> void:
	var direction: Vector2 = raw_direction.normalized()
	if direction == Vector2.ZERO: return
	var start: Vector2 = point + direction * 7
	var end: Vector2 = point + direction * 31
	draw_circle(point, 2.7, NEW_GROWTH)
	draw_line(start, end, Color(NEW_GROWTH, 0.8), 1.7, true)
	draw_line(end, end - direction.rotated(0.55) * 7, NEW_GROWTH, 1.7, true)
	draw_line(end, end - direction.rotated(-0.55) * 7, NEW_GROWTH, 1.7, true)

func _label(cursor: Vector2, color: Color) -> void:
	var width: float = maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, maxf(font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, font.get_string_size(instruction, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)) + 28
	width = minf(width, safe_rect.size.x)
	var protected: Array[Vector2] = []
	for cut: Dictionary in preview.get("cuts", []):
		protected.append(_render_cut(cut))
		protected.append(_render_anchor(cut.get("anchor", Vector2.ZERO)))
	var best := INF
	# A swipe may finish on either side of a branch. Keep the caption away from
	# the actual scissors and new shoots, rather than always putting it to the
	# right of the pointer and covering the thing the player is inspecting.
	for offset: Vector2 in [Vector2(25, -110),Vector2(-width - 25, -110),Vector2(25, 36),Vector2(-width - 25, 36),Vector2(-width * 0.5, -175)]:
		var candidate := Rect2(cursor + offset, Vector2(width, 88))
		candidate.position.x = clampf(candidate.position.x, safe_rect.position.x, maxf(safe_rect.position.x, safe_rect.end.x - width))
		candidate.position.y = clampf(candidate.position.y, safe_rect.position.y, maxf(safe_rect.position.y, safe_rect.end.y - candidate.size.y))
		var penalty := 0.0
		if candidate.grow(12).has_point(cursor): penalty += 1.0
		for point: Vector2 in protected:
			if candidate.grow(40).has_point(point): penalty += 1.0
		if is_instance_valid(annotation_layer):
			for existing: Rect2 in annotation_layer._occupied:
				if candidate.grow(6).intersects(existing): penalty += 1.0
		if penalty < best:
			best = penalty
			label_rect = candidate
		if penalty == 0: break
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.055, 0.065, 0.91)
	box.border_color = Color(color, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	draw_style_box(box, label_rect)
	draw_string(font, label_rect.position + Vector2(13, 25), title, HORIZONTAL_ALIGNMENT_LEFT, width - 26, 18, color)
	draw_string(font, label_rect.position + Vector2(13, 48), detail, HORIZONTAL_ALIGNMENT_LEFT, width - 26, 14, PAPER)
	draw_string(font, label_rect.position + Vector2(13, 70), instruction, HORIZONTAL_ALIGNMENT_LEFT, width - 26, 13, Color(PAPER, 0.72))
