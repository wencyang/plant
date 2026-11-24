extends Node2D
## Golden-hour garden backdrop: gradient sky, sun, layered hills, fireflies,
## a dirt battle strip and soil plots.

var size := Vector2(1280, 800)
var ground_y := 440.0
var t := 0.0
var night := 0.0          # 0 = golden hour (shop), 1 = dusk (battle)
var night_target := 0.0
var flies: Array = []
var plots: Array = []     # Array of {pos: Vector2, glow: float, enemy: bool}
var show_enemy_side := false
var shop_shelf := false
var bin_rect := Rect2()
var bin_hot := false

func _ready() -> void:
	for i in 26:
		flies.append({"p": Vector2(randf(), randf_range(0.15, 0.7)), "ph": randf() * TAU, "sp": randf_range(0.2, 0.6)})

func _process(delta: float) -> void:
	t += delta
	night = move_toward(night, night_target, delta * 0.8)
	queue_redraw()

func _grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))

func _hill(base_y: float, amp: float, freq: float, offset: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, size.y))
	var n := 48
	for i in range(n + 1):
		var x := size.x * i / n
		var y := base_y - amp * (0.6 * sin(x * freq + offset) + 0.4 * sin(x * freq * 2.3 + offset * 1.7))
		pts.append(Vector2(x, y))
	pts.append(Vector2(size.x, size.y))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	var sky_top := Color("ffcf8a").lerp(Color("2c2a5c"), 0.75).lerp(Color("1a1840"), night)
	var sky_mid := Color("ff9f7a").lerp(Color("6b4a8a"), night)
	var sky_low := Color("ffe0a0").lerp(Color("e0807a"), night)
	_grad_rect(Rect2(0, 0, size.x, ground_y * 0.55), sky_top, sky_mid)
	_grad_rect(Rect2(0, ground_y * 0.55 - 1, size.x, ground_y * 0.5), sky_mid, sky_low)
	# sun
	var sun_pos := Vector2(size.x * 0.5, ground_y * 0.72 + night * 60)
	for i in 5:
		draw_circle(sun_pos, 70 + i * 34, Color(1.0, 0.92, 0.6, 0.10 - i * 0.015))
	draw_circle(sun_pos, 62, Color("fff1b8").lerp(Color("ffb27a"), night))
	# clouds
	for i in 4:
		var cx := fmod(i * 397.0 + t * (6 + i * 2), size.x + 300) - 150
		var cy := 70.0 + i * 38
		var cc := Color(1, 1, 1, 0.55 - night * 0.3)
		for k in 4:
			draw_circle(Vector2(cx + k * 34, cy + sin(k * 1.9) * 8), 26 + (k % 2) * 10, cc)
	# hills, far to near
	_hill(ground_y * 0.82, 26, 0.006, 1.0 + t * 0.01, Color("8fb7a0").lerp(Color("4c5d86"), night))
	_hill(ground_y * 0.90, 22, 0.009, 4.0, Color("6fa883").lerp(Color("3d5873"), night))
	# trees silhouettes
	for i in 9:
		var x := fmod(i * 173.0 + 40.0, size.x)
		var y := ground_y * 0.92 - 6
		var tc := Color("4d8a63").lerp(Color("2d4560"), night)
		draw_rect(Rect2(x - 4, y - 30, 8, 34), tc.darkened(0.2))
		draw_circle(Vector2(x, y - 44), 26 + (i % 3) * 6, tc)
		draw_circle(Vector2(x - 16, y - 32), 18, tc)
		draw_circle(Vector2(x + 16, y - 34), 19, tc)
	_hill(ground_y * 0.98, 14, 0.012, 2.0, Color("5e9b5c").lerp(Color("2f5a4c"), night))
	# main lawn
	_grad_rect(Rect2(0, ground_y - 30, size.x, size.y - ground_y + 30), Color("78b955").lerp(Color("3e7a50"), night), Color("4f8f3e").lerp(Color("24503a"), night))
	# battle strip
	var strip := Rect2(0, ground_y - 18, size.x, 44)
	draw_rect(strip, Color("b98a5a").lerp(Color("6e5240"), night))
	draw_rect(Rect2(strip.position.x, strip.position.y, strip.size.x, 6), Color("d6a874").lerp(Color("82614a"), night))
	# grass tufts along front edge
	var gcol := Color("3f7d36").lerp(Color("1d3d2c"), night)
	for i in int(size.x / 22):
		var x := i * 22.0 + 8
		var y := ground_y + 30
		var w := sin(t * 2.0 + i) * 2
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y), Vector2(x + w, y - 14 - (i % 3) * 4), Vector2(x + 5, y)]), gcol)
	# centre line divider (fence)
	var fx := size.x * 0.5
	for k in 3:
		var post := Rect2(fx - 5, ground_y - 46 + k * 0, 10, 50)
		draw_rect(post, Color("8a5a35").lerp(Color("4a3428"), night))
	draw_rect(Rect2(fx - 5, ground_y - 50, 10, 6), Color("1b2420"))
	# plots
	for plot in plots:
		_plot(plot)
	if shop_shelf: _shelf()
	# fireflies
	for f in flies:
		var p := Vector2(fmod(f.p.x * size.x + sin(t * f.sp + f.ph) * 40 + t * 8 * f.sp, size.x), f.p.y * ground_y + cos(t * f.sp * 1.3 + f.ph) * 20)
		var a := (0.35 + 0.65 * night) * (0.5 + 0.5 * sin(t * 3.0 + f.ph))
		draw_circle(p, 6, Color(1.0, 0.95, 0.5, a * 0.25))
		draw_circle(p, 2.2, Color(1.0, 0.98, 0.7, a))

func _plot(plot: Dictionary) -> void:
	var c: Vector2 = plot.pos
	var glow: float = plot.get("glow", 0.0)
	var enemy: bool = plot.get("enemy", false)
	if enemy and not show_enemy_side: return
	if glow > 0.0:
		draw_colored_polygon(_ellipse(c + Vector2(0, 6), 62, 20), Color(1.0, 0.95, 0.55, 0.45 * glow))
	draw_colored_polygon(_ellipse(c + Vector2(0, 8), 52, 15), Color("1b2420"))
	draw_colored_polygon(_ellipse(c + Vector2(0, 6), 49, 12), Color("6b4428").lerp(Color("3c2a20"), night))
	draw_colored_polygon(_ellipse(c + Vector2(0, 3), 42, 8), Color("8a5a35").lerp(Color("4a3428"), night))
	for k in 4:
		draw_circle(c + Vector2(-24 + k * 16, 5 + (k % 2) * 3), 2.0, Color("4a2e1a"))

func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _shelf() -> void:
	var top := size.y - 214.0
	var out := Color("1b2420")
	draw_rect(Rect2(0, top - 4, size.x, size.y - top + 4), out)
	draw_rect(Rect2(0, top, size.x, size.y - top), Color("a8703f"))
	for i in 4:
		var y := top + 12 + i * 52
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("8f5c32"), 3)
	draw_rect(Rect2(0, top, size.x, 14), Color("c98d55"))
	draw_line(Vector2(0, top + 14), Vector2(size.x, top + 14), out, 3)
	# compost bin
	var r := bin_rect
	var col := Color("5aa05a") if not bin_hot else Color("8be07a")
	var body := PackedVector2Array([r.position + Vector2(8, 34), r.position + Vector2(r.size.x - 8, 34), r.end - Vector2(16, 0), Vector2(r.position.x + 16, r.end.y)])
	draw_colored_polygon(body, col)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, out, 4, true)
	var lid := Rect2(r.position + Vector2(0, 18 - (10 if bin_hot else 0)), Vector2(r.size.x, 18))
	draw_rect(lid, col.darkened(0.15))
	draw_rect(lid, out, false, 4)
	for i in 3:
		var x := r.position.x + 36 + i * 30
		draw_line(Vector2(x, r.position.y + 50), Vector2(x - 4, r.end.y - 14), col.darkened(0.25), 4)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size("SELL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var p := Vector2(r.position.x + r.size.x * 0.5 - w * 0.5, r.position.y + 100)
	draw_string_outline(font, p, "SELL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, out)
	draw_string(font, p, "SELL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
