extends Node2D
## A seed packet (or garden item) on the shop shelf.

const PlantView := preload("res://scripts/view/plant_view.gd")
const Species := preload("res://scripts/sim/species.gd")
const OUT := Color("1b2420")
const W := 124.0
const H := 158.0

var entry: Dictionary = {}
var preview: Node2D = null
var affordable := true
var hovered := false
var lifted := false
var t := 0.0
var wobble := 0.0
var lift := 0.0

func setup(e: Dictionary) -> void:
	entry = e
	if e.kind == "seed":
		preview = PlantView.new()
		add_child(preview)
		preview.setup(e.plant, 1.0)
		preview.position = Vector2(0, 30)
		preview.scale = Vector2(0.6, 0.6)
		preview.badge_scale = 1.45
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	wobble = move_toward(wobble, 0.0, delta * 2.0)
	lift = move_toward(lift, 1.0 if (hovered or lifted) else 0.0, delta * 8.0)
	rotation = sin(t * 18.0) * wobble * 0.12
	if preview != null:
		preview.position = Vector2(0, 30 - lift * 10)
		preview.modulate = Color(1, 1, 1, 1) if affordable else Color(0.7, 0.7, 0.7, 1)
	queue_redraw()

func rect() -> Rect2:
	return Rect2(-W * 0.5, -H * 0.5 - 30, W, H + 34)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var y_off := -lift * 10.0
	var r := Rect2(-W * 0.5, -H * 0.5 - 30 + y_off, W, H)
	var base := Color("fff4d6")
	var band := Color("8bc76a")
	if entry.kind == "seed":
		band = Color.from_hsv(float(entry.plant.genes.flower_hue), 0.45, 0.95)
	else:
		band = Color("c6a2ff") if entry.item == "pollen" else Color("8fd1ff") if entry.item == "water" else Color("d9b27a")
	if not affordable:
		base = base.darkened(0.25)
		band = band.darkened(0.3)
	# shadow + card
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.25))
	draw_rect(r.grow(3), OUT)
	draw_rect(r, base)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 34)), band)
	draw_line(r.position + Vector2(0, 34), r.position + Vector2(r.size.x, 34), OUT, 3)
	# zigzag top edge
	for i in 8:
		var x := r.position.x + i * W / 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, r.position.y), Vector2(x + W / 16.0, r.position.y + 6), Vector2(x + W / 8.0, r.position.y)]), OUT)
	var title: String = entry.plant.name if entry.kind == "seed" else str(entry.get("label", "Item"))
	_text(font, title, Vector2(0, r.position.y + 26), 17, Color.WHITE, true)
	if entry.kind == "item":
		_item_icon(Vector2(0, r.position.y + 90))
	else:
		var ab: String = entry.plant.abilities.keys()[0]
		_text(font, Species.ABILITIES[ab].name, Vector2(0, r.position.y + 54), 15, Species.ABILITIES[ab].color.darkened(0.35), false)
	# price tag
	var tag := Vector2(r.end.x - 6, r.position.y - 4)
	_sun(tag, 17)
	_text(font, str(entry.cost), tag + Vector2(0, 7), 19, OUT, false)

func _sun(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0 + t * 0.6
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.78))
	draw_colored_polygon(pts, OUT)
	var inner := PackedVector2Array()
	for p in pts: inner.append(c + (p - c) * 0.84)
	draw_colored_polygon(inner, Color("ffd34d"))

func _text(font: Font, s: String, c: Vector2, size: int, col: Color, outline: bool) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if w > W - 10:
		size = int(size * (W - 10) / w)
		w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := c - Vector2(w * 0.5, 0)
	if outline: draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, OUT)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _item_icon(c: Vector2) -> void:
	match entry.item:
		"fertilizer":
			var bag := PackedVector2Array([c + Vector2(-30, -30), c + Vector2(30, -30), c + Vector2(36, 34), c + Vector2(-36, 34)])
			draw_colored_polygon(bag, Color("c99a5b"))
			draw_polyline(bag + PackedVector2Array([bag[0]]), OUT, 3, true)
			draw_rect(Rect2(c + Vector2(-30, -36), Vector2(60, 10)), Color("a87a45"))
			draw_circle(c + Vector2(0, 4), 13, Color("6fcf5a"))
			draw_string(ThemeDB.fallback_font, c + Vector2(-16, 12), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, OUT)
		"water":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -16), c + Vector2(22, -16), c + Vector2(26, 30), c + Vector2(-30, 30)]), Color("5fb6ff"))
			draw_line(c + Vector2(22, -4), c + Vector2(48, -26), OUT, 9)
			draw_line(c + Vector2(22, -4), c + Vector2(48, -26), Color("5fb6ff"), 5)
			draw_arc(c + Vector2(-2, -18), 16, PI, TAU, 12, OUT, 4)
			for i in 3:
				draw_circle(c + Vector2(52 + i * 3, -16 + i * 12 + fmod(t * 30.0, 12.0)), 3, Color("8fd1ff"))
			draw_string(ThemeDB.fallback_font, c + Vector2(-17, 14), "+3", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		"pollen":
			draw_rect(Rect2(c + Vector2(-24, -24), Vector2(48, 56)), Color(0.85, 0.78, 1.0, 0.8))
			draw_rect(Rect2(c + Vector2(-24, -24), Vector2(48, 56)), OUT, false, 3)
			draw_rect(Rect2(c + Vector2(-27, -34), Vector2(54, 12)), Color("8a5a35"))
			for i in 7:
				var a := t * 2.0 + i
				var p := c + Vector2(sin(a * 1.3) * 14, 6 + cos(a) * 14)
				draw_circle(p, 3.5, Color.from_hsv(fmod(i * 0.14 + t * 0.2, 1.0), 0.5, 1.0))
