extends Control
## Atmospheric habitat. All contours and spores are reproducible, original drawings.
var time: float = 0.0
var motes: Array = []
var stalks: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 8149
	for i in range(65):
		motes.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.3, 1.0)))
	for i in range(40):
		stalks.append(Vector4(rng.randf(), rng.randf_range(0.1, 0.5), rng.randf_range(0.01, 0.04), rng.randf()))

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if size.x < 1 or size.y < 1: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1717"))
	# The far ecology stays barely visible behind the tended bed.
	for i in range(12):
		var center := Vector2(size.x * (0.1 + float(i % 4) * 0.3), size.y * float(i) / 12.0)
		draw_circle(center, size.x * 0.25, Color(0.08, 0.16, 0.14, 0.055))
	# Thin hanging collectors drink the mist above the tended beds. The light is
	# tissue pigment, muted enough to stay behind the resource bar and typography.
	for i in range(5):
		var x: float = size.x * (0.56 + float(i) * 0.076)
		var height: float = 40 + fposmod(float(i) * 47.3, 98.0)
		var points := PackedVector2Array()
		for j in range(23):
			var t: float = float(j) / 22.0
			points.append(Vector2(x + sin(t * 4 + float(i) + time * 0.09) * 15 * t, t * height))
		draw_polyline(points, Color(0.22, 0.33, 0.27, 0.15), 0.9, true)
		var tip: Vector2 = points[-1]
		_habitat_leaf(tip - Vector2(0, 11), tip + Vector2(3, 16), 5.5, Color(0.38, 0.46, 0.34, 0.11), float(i))
	for s: Vector4 in stalks:
		var x: float = s.x * size.x
		var base := Vector2(x, size.y)
		var top := Vector2(x + sin(time * 0.12 + s.w * 6.0) * 10.0, size.y * (1.0 - s.y))
		var points := PackedVector2Array()
		for j in range(15):
			var f := float(j) / 14.0
			points.append(base.lerp(top, f) + Vector2(sin(f * 3.0 + s.w * 6.0) * 25.0 * f, 0))
		draw_polyline(points, Color(0.15, 0.24, 0.20, 0.24), 1.5, true)
		for j in range(3):
			var f: float = 0.25 + j * 0.2
			var p: Vector2 = base.lerp(top, f)
			var side: float = -1.0 if j % 2 == 0 else 1.0
			var tip: Vector2 = p + Vector2(side * size.x * s.z, -40 - s.w * 22)
			_habitat_leaf(p, tip, 8 + s.w * 7, Color(0.12, 0.22, 0.19, 0.23), s.w * 8)
		# A narrow membrane stores the rainwater at the end of a few mature stalks.
		if s.w > 0.72:
			var top_point: Vector2 = points[-1]
			_habitat_leaf(top_point - Vector2(0, 7), top_point + Vector2(8, 23), 7, Color(0.26, 0.36, 0.29, 0.14), s.w * 12)
	# The outer root mat has no regular grid: fibers cross, split and disappear.
	for i in range(7):
		var points := PackedVector2Array()
		var base_y: float = size.y * (0.75 + float(i) * 0.035)
		for j in range(45):
			var t: float = float(j) / 44.0
			points.append(Vector2(t * size.x, base_y + sin(t * 7 + float(i) * 2.3) * 22 + sin(t * 21 + float(i)) * 4))
		draw_polyline(points, Color(0.20, 0.29, 0.21, 0.10), 0.8, true)
	for m: Vector3 in motes:
		var p := Vector2(fposmod(m.x * size.x + sin(time * 0.08 + m.y * 7.0) * 22.0, size.x), fposmod(m.y * size.y - time * m.z * 2.0, size.y))
		draw_circle(p, m.z * 1.5, Color(0.65, 0.74, 0.57, 0.15 * m.z))
	# Rain-hatched edge; the garden sits within a larger wet world.
	for i in range(70):
		var x := fposmod(i * 73.7, size.x)
		var y := fposmod(i * 119.3 + time * 8.0, size.y)
		draw_line(Vector2(x, y), Vector2(x - 2, y + 12), Color(0.4, 0.6, 0.55, 0.018), 1.0)

func _habitat_leaf(base: Vector2, tip: Vector2, width: float, color: Color, phase: float) -> void:
	var axis: Vector2 = tip - base
	var normal := Vector2(-axis.y, axis.x).normalized()
	var contour := PackedVector2Array()
	for i in range(23):
		var t: float = float(i) / 22.0
		var membrane: float = sin(t * PI) * width * (1 + sin(t * 19 + phase) * 0.035)
		contour.append(base.lerp(tip, t) + normal * (membrane + sin(t * PI) * 5))
	for i in range(22, -1, -1):
		var t: float = float(i) / 22.0
		contour.append(base.lerp(tip, t) - normal * sin(t * PI) * width * 0.65)
	draw_colored_polygon(contour, color)
	var vein := PackedVector2Array()
	for i in range(15):
		var t: float = float(i) / 14.0
		vein.append(base.lerp(tip, t) + normal * sin(t * PI) * 2)
	draw_polyline(vein, Color(0.35, 0.44, 0.33, color.a * 0.50), 0.65, true)
	for i in range(3, 12, 3):
		var t: float = float(i) / 14.0
		var point: Vector2 = vein[i]
		for side in [-1.0, 1.0]:
			draw_line(point, point + normal * sin(t * PI) * width * side * 0.65 - axis.normalized() * 3, Color(0.32, 0.40, 0.30, color.a * 0.3), 0.5, true)
