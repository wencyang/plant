extends Node2D
## Top bar: hearts, trophies, round and sun.

const OUT := Color("1b2420")

var hearts := 5
var max_hearts := 5
var trophies := 0
var max_trophies := 10
var round_number := 1
var sun := 10
var show_sun := true
var width := 1280.0
var t := 0.0
var heart_shake := 0.0
var sun_bump := 0.0
var trophy_bump := 0.0

func _process(delta: float) -> void:
	t += delta
	heart_shake = max(0.0, heart_shake - delta * 1.5)
	sun_bump = max(0.0, sun_bump - delta * 3.0)
	trophy_bump = max(0.0, trophy_bump - delta * 2.0)
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	# banner
	var bar := Rect2(12, 10, width - 24, 64)
	draw_rect(Rect2(bar.position + Vector2(0, 5), bar.size), Color(0, 0, 0, 0.2))
	draw_rect(bar.grow(3), OUT)
	draw_rect(bar, Color("fff4d6"))
	draw_rect(Rect2(bar.position + Vector2(0, bar.size.y - 10), Vector2(bar.size.x, 10)), Color("f0dcae"))
	# hearts
	for i in max_hearts:
		var c := Vector2(48 + i * 44, 42)
		if i == hearts and heart_shake > 0.0: c += Vector2(sin(t * 60) * 6 * heart_shake, 0)
		_heart(c, 17, Color("ff5d73") if i < hearts else Color("d9c9a8"))
	# trophies
	var tx := 48 + max_hearts * 44 + 30.0
	_cup(Vector2(tx, 42), 1.0 + trophy_bump * 0.4)
	_text(font, "%d/%d" % [trophies, max_trophies], Vector2(tx + 28, 53), 30, OUT)
	# round
	var rtxt := "Round %d" % round_number
	var rw := font.get_string_size(rtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_text(font, rtxt, Vector2(width * 0.5 - rw * 0.5, 53), 30, OUT)
	if show_sun:
		var sx := width * 0.5 + rw * 0.5 + 60
		_sun(Vector2(sx, 42), 22 * (1.0 + sun_bump * 0.4))
		_text(font, str(sun), Vector2(sx + 30, 54), 34, Color("c47a00"))

func _text(font: Font, s: String, p: Vector2, size: int, col: Color) -> void:
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _heart(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))) * r / 16.0)
	draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUT, 3, true)
	draw_circle(c + Vector2(-r * 0.4, -r * 0.35), r * 0.18, Color(1, 1, 1, 0.6))

func _cup(c: Vector2, s: float) -> void:
	var gold := Color("ffc93c")
	var cup := PackedVector2Array([c + Vector2(-14, -16) * s, c + Vector2(14, -16) * s, c + Vector2(10, 2) * s, c + Vector2(3, 6) * s, c + Vector2(3, 12) * s,
		c + Vector2(9, 16) * s, c + Vector2(-9, 16) * s, c + Vector2(-3, 12) * s, c + Vector2(-3, 6) * s, c + Vector2(-10, 2) * s])
	draw_arc(c + Vector2(-14, -8) * s, 7 * s, PI * 0.5, PI * 1.5, 10, OUT, 4, true)
	draw_arc(c + Vector2(14, -8) * s, 7 * s, -PI * 0.5, PI * 0.5, 10, OUT, 4, true)
	draw_colored_polygon(cup, gold)
	var closed := cup.duplicate()
	closed.append(cup[0])
	draw_polyline(closed, OUT, 3, true)

func _sun(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0 + t * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.74))
	draw_colored_polygon(pts, OUT)
	var inner := PackedVector2Array()
	for p in pts: inner.append(c + (p - c) * 0.84)
	draw_colored_polygon(inner, Color("ffd34d"))
	draw_circle(c, r * 0.45, Color("ffe98a"))
