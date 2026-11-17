extends Control
class_name PlantPortrait
## A living botanical plate. All anatomy and tissue markings are regenerated from
## the stored individual, so a portrait and its plant on the bed remain identical.

var plant: Dictionary = {}:
	set(value):
		plant = value
		queue_redraw()
var alive: bool = true
var energy: float = 0.0
var activity: float = 0.0
var silhouette: bool = false
var animate: bool = true
var reveal: float = 1.0
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _pigment := Color("a7b78a")
var _accent := Color("d9a88e")
var _leaf_color := Color("527568")
var _ink := Color("142d29")
var _vein := Color("9cb59a")
var _pattern: String = "Solid"
var _shape: String = "Pointed"
var _phase: float = 0.0
var _glowing: bool = false
var _deformed: bool = false
var _texture: String = "Matte"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(animate)

func _process(delta: float) -> void:
	if not animate:
		return
	_time += delta
	activity = move_toward(activity, 0.0, delta * 0.5)
	queue_redraw()

func _gene(slot: String, fallback: Variant) -> Variant:
	var genes: Dictionary = plant.get("genes", {})
	var data: Variant = genes.get(slot, fallback)
	if data is Dictionary:
		return data.get("dominant", fallback)
	return data

func _tissue(c: Color, alpha: float = 1.0) -> Color:
	if silhouette:
		return Color(0.18, 0.26, 0.23, alpha)
	if not alive:
		c = c.lerp(Color("6f7060"), 0.86).darkened(0.18)
	c.a = alpha * clampf(reveal, 0.0, 1.0)
	return c

func _draw() -> void:
	if plant.is_empty() or size.x < 1.0 or size.y < 1.0:
		return
	_rng.seed = int(plant.get("seed", 92))
	_phase = float(posmod(int(plant.get("seed", 92)), 1000)) / 100.0
	_pigment = Color(str(_gene("color", "a8b896")))
	_accent = Color(str(_gene("accent", "d7af82")))
	_leaf_color = Color("3a6759").lerp(_pigment, 0.24)
	_vein = Color("a1b48e").lerp(_accent, 0.30)
	_pattern = str(_gene("pattern", "Solid"))
	_shape = str(_gene("shape", "Pointed"))
	_glowing = str(_gene("glow", "None")) != "None"
	_texture = str(_gene("texture", "Matte"))
	_deformed = false
	for event in plant.get("mutation_history", []):
		if event is Dictionary and ("deform" in str(event.get("outcome", "")).to_lower() or "deform" in str(event.get("result", "")).to_lower()):
			_deformed = true
	var s: float = minf(size.x / 205.0, size.y / 224.0)
	var growth: float = 1.0 if plant.get("mature", true) else 0.65
	var visual_size: String = str(_gene("size", "Standard"))
	if visual_size == "Small":
		growth *= 0.88
	elif visual_size == "Large":
		growth *= 1.04
	s *= growth
	var sway: float = sin(_time * 0.65 + _phase) * 0.018 if animate and alive else 0.0
	var wilt: float = 0.0 if alive else 0.24
	var pos := Vector2(size.x * 0.5, size.y * 0.88)
	var form_scale := Vector2.ONE
	match str(_gene("form", "Upright")):
		"Trailing": form_scale = Vector2(1.08, 0.82)
		"Rosette": form_scale = Vector2(1.10, 0.84)
		"Climbing": form_scale = Vector2(0.91, 1.04)
	draw_set_transform(pos, sway + wilt, Vector2(s, s) * form_scale)
	_root_crown()
	match str(plant.get("type", "Leaf")):
		"Bloom": _bloom()
		"Vine": _vine()
		"Root": _root()
		"Spore": _spore()
		"Toxin": _toxin()
		"Parasite": _parasite()
		"Carnivorous": _carnivorous()
		_: _leaf()
	var grafts: Array = plant.get("graft_history", [])
	if not grafts.is_empty():
		_graft_branch(grafts[0])
		if grafts.size() > 1:
			draw_set_transform(pos, sway + wilt, Vector2(-s,s) * form_scale)
			_graft_branch(grafts[1])
	elif plant.has("inherited_graft_color"):
		_graft_branch({"color":plant.inherited_graft_color})
	draw_set_transform(Vector2.ZERO)

func _path(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	if points.size() >= 2:
		draw_polyline(points, _tissue(color), width, true)

func _curve(a: Vector2, control: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in range(21):
		var t: float = float(i) / 20.0
		pts.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	_path(pts, color, width)

func _stem(a: Vector2, b: Vector2, bend: float = 0.0, thickness: float = 3.0) -> void:
	var control: Vector2 = (a + b) * 0.5 + Vector2(bend, 0)
	_curve(a, control, b, _ink, thickness + 1.8)
	_curve(a, control, b, _leaf_color.lightened(0.05), thickness)
	_curve(a + Vector2(-0.6, 0), control + Vector2(-0.6, 0), b, _vein.darkened(0.28), 0.65)

func _ellipse(center: Vector2, radius: Vector2, color: Color, outline: bool = true, phase: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in range(49):
		var a: float = float(i) / 48.0 * TAU
		var rough: float = 1.0 + 0.026 * sin(a * 5.0 + phase) + 0.014 * sin(a * 9.0 + phase)
		pts.append(center + Vector2(cos(a), sin(a)) * radius * rough)
	draw_colored_polygon(pts, _tissue(color))
	if outline:
		_path(pts, _ink.lightened(0.055), 1.0)

func _root_crown() -> void:
	# The lower fibers enter the earth instead of floating above it.
	for i in range(9):
		var a := Vector2(float(i - 4) * 1.9, -5)
		var tip := Vector2(float(i - 4) * 7.8, 9.0 + _rng.randf_range(-4, 4))
		var control := Vector2(tip.x * 0.3, 7)
		_curve(a, control, tip, Color("4e6856"), 2.0 - absf(float(i - 4)) * 0.18)
		_curve(a + Vector2(0, 1), control + Vector2(0, 1), tip + Vector2(0, 1), Color("263e34"), 0.7)
		if i % 2 == 0:
			_curve(tip * 0.7, tip + Vector2(0, -2), tip + Vector2(6, 5), Color("56745d"), 0.65)
	_ellipse(Vector2(0, -2), Vector2(13, 6), Color("3e5949"), true, _phase)

func _organ(start: Vector2, tip: Vector2, width: float, color: Color, bend: float = 0.0, texture: bool = true) -> void:
	# A leaf/petal is a bowed membrane around a structural vein. Markings are
	# located in that membrane's coordinates, never pasted over its silhouette.
	if _deformed and tip.x < -10:
		tip = start.lerp(tip, 0.76) + Vector2(4, 3)
		width *= 0.82
	var axis: Vector2 = tip - start
	var normal := Vector2(-axis.y, axis.x).normalized()
	var pts := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var form_power: float = 0.72 if _shape == "Round" else 0.95
	for i in range(25):
		var t: float = float(i) / 24.0
		var center: Vector2 = start.lerp(tip, t) + normal * sin(t * PI) * bend
		var envelope: float = pow(sin(t * PI), form_power) * width
		var rim: float = 1.0 + sin(t * 34.0 + _phase) * (0.12 if _shape == "Frilled" else 0.025)
		if _shape == "Split" and t > 0.7:
			rim *= 0.83 + 0.20 * sin(t * 45.0)
		left.append(center + normal * envelope * rim)
		right.append(center - normal * envelope * (0.92 + sin(t * 13.0) * 0.04))
	pts.append_array(left)
	for i in range(right.size() - 1, -1, -1):
		pts.append(right[i])
	draw_colored_polygon(pts, _tissue(color))
	var shadow := PackedVector2Array()
	for i in range(25):
		var t: float = float(i) / 24.0
		shadow.append(start.lerp(tip, t) + normal * sin(t * PI) * bend)
	for i in range(right.size() - 1, -1, -1):
		shadow.append(right[i])
	draw_colored_polygon(shadow, _tissue(color.darkened(0.20)))
	pts.append(pts[0])
	_path(pts, _ink.lightened(0.03), 1.0)
	if not texture:
		return
	var vein_color: Color = _vein.lerp(color, 0.40)
	if _glowing:
		vein_color = vein_color.lerp(_accent.lightened(0.2), 0.5 + sin(_time * 0.8 + _phase) * 0.12)
	_curve(start, (start + tip) * 0.5 + normal * bend * 1.3, tip, vein_color, 0.9)
	var pattern_color: Color = color.lerp(_accent, 0.65)
	for j in range(1, 10):
		var t: float = float(j) / 11.0
		var middle: Vector2 = start.lerp(tip, t) + normal * sin(t * PI) * bend
		var span: float = sin(t * PI) * width * 0.82
		for side in [-1.0, 1.0]:
			var edge: Vector2 = middle + normal * span * side - axis.normalized() * 4
			_curve(middle, middle + normal * span * side * 0.45, edge, color.lightened(0.14), 0.5)
		if _pattern == "Striped" or _pattern == "Bicolor Ring":
			if _pattern == "Striped" or j in [6, 7]:
				_curve(middle - normal * span, middle - axis.normalized() * 4, middle + normal * span, pattern_color, 2.0 if _pattern == "Bicolor Ring" else 1.25)
		elif _pattern == "Spotted" and j % 2 == 0:
			for side in [-0.5, 0.5]:
				_ellipse(middle + normal * span * side, Vector2(width * 0.10 + 0.7, width * 0.15 + 0.8), pattern_color, false)
		elif _pattern == "Starburst":
			_curve(start.lerp(tip, 0.28), middle + normal * span * 0.3, middle + normal * span * 0.8, pattern_color, 0.8)
		elif _pattern == "Gradient":
			_path(PackedVector2Array([middle - normal * span, middle + normal * span]), color.lerp(_accent, t * 0.6), 0.8)
		# Fine edge hatching and irregular moisture stipple.
		var side: float = -1.0 if j % 2 == 0 else 1.0
		_path(PackedVector2Array([middle + normal * span * side * 0.76, middle + normal * span * side * 0.96 - axis.normalized() * 2]), _ink.lightened(0.08), 0.45)
	for j in range(7):
		var t: float = _rng.randf_range(0.2, 0.85)
		var point: Vector2 = start.lerp(tip, t) + normal * sin(t * PI) * (bend + _rng.randf_range(-width * 0.65, width * 0.65))
		draw_circle(point, _rng.randf_range(0.30, 0.65), _tissue(color.lightened(0.2), 0.5))
	if _texture in ["Wet", "Waxy", "wet", "waxy", "Translucent", "translucent"]:
		var sheen_start: Vector2 = start.lerp(tip, 0.42) + normal * width * 0.36
		var sheen_end: Vector2 = start.lerp(tip, 0.75) + normal * width * 0.31
		_curve(sheen_start, (sheen_start + sheen_end) * 0.5 + normal * 1.4, sheen_end, color.lerp(_accent, 0.28).lightened(0.18), 1.3)
		if _texture.to_lower() == "translucent":
			_curve(start.lerp(tip, 0.25), start.lerp(tip, 0.5) - normal * width * 0.6, start.lerp(tip, 0.8), _accent.darkened(0.1), 0.55)

func _leaf() -> void:
	var tips: Array[Vector2] = [Vector2(-69,-67), Vector2(-61,-113), Vector2(-34,-151), Vector2(6,-166), Vector2(41,-142), Vector2(70,-99), Vector2(73,-58)]
	for i in range(tips.size()):
		var tip: Vector2 = tips[i] + Vector2(_rng.randf_range(-7, 7), _rng.randf_range(-5, 5))
		var base := Vector2(float(i - 3) * 2, -12)
		_stem(base, tip * 0.63, float(i - 3) * 3, 1.6)
		_organ(base + tip * 0.10, tip, 15.0 + float(i % 3) * 2, _leaf_color.lerp(_pigment, 0.34 + float(i % 2) * 0.15), float(3 - i) * 3)
	for side in [-1.0, 1.0]:
		_organ(Vector2(0,-6),Vector2(52 * side,-31),13,_leaf_color.darkened(0.08),side * 5)
	_seed_filament(Vector2(2, -88), Vector2(20, -163), 0.8)

func _bloom() -> void:
	_stem(Vector2(0, -3), Vector2(-4, -113), 13, 5.0)
	_organ(Vector2(2,-42),Vector2(-57,-90),17,_leaf_color,-12)
	_organ(Vector2(4,-62),Vector2(62,-124),17,_leaf_color.lightened(0.08),11)
	_stem(Vector2(3,-56),Vector2(48,-105),4,2)
	var petals: int = clampi(int(_gene("petals", 7)), 4, 12)
	var core := Vector2(-4,-119)
	var opening: float = 1.0 + sin(_time * 0.7 + _phase) * 0.025 + activity * 0.12
	for i in range(petals):
		var angle: float = float(i) / float(petals) * TAU - PI * 0.5
		var direction := Vector2(cos(angle), sin(angle) * 0.80)
		var reach: float = (48.0 + _rng.randf_range(-7, 7)) * opening
		var tip: Vector2 = core + direction * reach
		var color: Color = _pigment.darkened(0.15 if i % 2 == 0 else 0.0)
		_organ(core - direction * 5, tip, 12.0 + _rng.randf_range(-2, 3), color, sin(angle) * 5)
	for i in range(5):
		var a: float = float(i) / 5.0 * TAU
		_organ(core, core + Vector2(cos(a), sin(a) * 0.7) * 25, 7.0, _pigment.lerp(_accent,0.45),2)
	_ellipse(core, Vector2(10,8), _accent.darkened(0.1))
	for i in range(13):
		var a: float = float(i) * 2.4
		var p: Vector2 = core + Vector2(cos(a),sin(a)*0.7) * sqrt(float(i)) * 2
		draw_circle(p,0.9,_tissue(_accent.lightened(0.25)))
	_core(core,6)
	# A smaller nodding blossom reads as a branching organism, not a flower icon.
	_ellipse(Vector2(49,-105),Vector2(11,15),_pigment.darkened(0.13))
	for i in range(5):
		_curve(Vector2(42 + i * 3,-116),Vector2(39 + i * 4,-103),Vector2(46 + i,-91),_accent.darkened(0.1),0.6)
	_ellipse(Vector2(49,-92),Vector2(5,2),_accent,false)

func _vine() -> void:
	for i in range(4):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var tip := Vector2(side * (40 + float(i)*10),-115-float(i)*13)
		var points := PackedVector2Array()
		for j in range(45):
			var t: float = float(j) / 44.0
			points.append(Vector2(sin(t * 3.0 + float(i) * 0.5) * side * 35.0 * t + tip.x * t * 0.6,tip.y * t))
		_path(points,_ink,4.6-float(i)*0.4)
		_path(points,_leaf_color.lightened(float(i)*0.04),2.8-float(i)*0.3)
		for j in range(2,7):
			var t: float = float(j)/8.0
			var p: Vector2 = points[int(t*44)]
			var leaf_side: float = -1.0 if j%2==0 else 1.0
			_organ(p,p+Vector2(leaf_side*(22-t*7),-25),6.5,_leaf_color.lerp(_pigment,0.22),leaf_side*4)
		var end: Vector2 = points[-1]
		var curl := PackedVector2Array()
		for j in range(27):
			var a: float = float(j)/26.0 * PI * 1.7
			curl.append(end+Vector2(sin(a),cos(a)-1)*Vector2(10-j*0.22,9))
		_path(curl,_pigment.lerp(_leaf_color,0.4),1.5)
		_core(curl[-1],1.5)

func _root() -> void:
	for i in range(6):
		var angle: float = float(i)/6.0*TAU
		var tip := Vector2(cos(angle)*58,-67+sin(angle)*28)
		_organ(Vector2(0,-37),tip,14,_leaf_color.lerp(_pigment,0.25),sin(angle)*5)
	var bulb := PackedVector2Array()
	for i in range(61):
		var angle: float = float(i)/60.0*TAU
		var edge: float = 1+sin(angle*7+_phase)*0.09
		bulb.append(Vector2(cos(angle)*31*edge,-30+sin(angle)*30*edge))
	draw_colored_polygon(bulb,_tissue(_pigment.lerp(Color("78816a"),0.4)))
	_path(bulb,_ink,1.4)
	for i in range(7):
		_curve(Vector2(-23+i*7,-46),Vector2(-30+i*10,-16),Vector2(-15+i*5,-3),_leaf_color.darkened(0.1),1.2)
	for i in range(3):
		var x: float = float(i-1)*15
		_seed_filament(Vector2(x,-44),Vector2(x*1.4,-122-_rng.randf_range(0,21)),2.2)

func _cap(center: Vector2, width: float, height: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(33):
		var t: float = float(i)/32.0
		pts.append(center+Vector2((t-0.5)*width*2,-sin(t*PI)*height*(1+sin(t*18)*0.03)))
	for i in range(17):
		var t: float = float(i)/16.0
		pts.append(center+Vector2((0.5-t)*width*2,6+sin(t*PI)*5))
	draw_colored_polygon(pts,_tissue(color))
	pts.append(pts[0])
	_path(pts,_ink,1.0)
	for i in range(17):
		var t: float = float(i)/16.0
		var x: float = (t-0.5)*width*1.9
		_curve(center+Vector2(x,5),center+Vector2(x*0.6,10),center+Vector2(x*0.20,11),_accent.darkened(0.12),0.7)
	for i in range(31):
		var t: float = _rng.randf_range(0.08,0.92)
		var h: float = sin(t*PI)*height
		var point: Vector2 = center+Vector2((t-0.5)*width*2,-_rng.randf_range(0.18,0.82)*h)
		var r: float = _rng.randf_range(0.6,2.1) if _pattern == "Spotted" else _rng.randf_range(0.35,0.8)
		draw_circle(point,r,_tissue(_accent,0.7))
	if _pattern == "Striped" or _pattern == "Starburst":
		for i in range(7):
			var t: float = float(i+1)/8
			_curve(center+Vector2(0,-height*0.8),center+Vector2((t-0.5)*width,-height*0.6),center+Vector2((t-0.5)*width*1.8,0),_accent.darkened(0.1),1.1)

func _spore() -> void:
	var caps: Array[Vector2] = [Vector2(-39,-86),Vector2(34,-110),Vector2(-5,-149)]
	for i in range(3):
		var p: Vector2 = caps[i]
		_stem(Vector2(float(i-1)*6,-4),p+Vector2(0,6),float(i-1)*12,5.0-float(i)*0.6)
		_cap(p,31+float(i)*6,23+float(i)*5,_pigment.darkened(0.11 if i==0 else 0.0))
		_core(p+Vector2(0,6),4)
	# Spores are born under gills and drift slowly downward.
	for i in range(16):
		var p: Vector2 = caps[i%3]
		var phase: float = fmod(_time*3.0+float(i)*6.3,48.0)
		p += Vector2(sin(float(i)*4.2+_time*0.2)*24,phase+11)
		draw_circle(p,0.5+float(i%3)*0.3,_tissue(_accent,0.48*(1-phase/56)))
	_organ(Vector2(0,-5),Vector2(-37,-32),11,_leaf_color,4)
	_organ(Vector2(0,-5),Vector2(42,-29),11,_leaf_color,-4)

func _pitcher(base: Vector2, height: float, width: float, color: Color, lean: float = 0.0) -> void:
	var mouth: Vector2 = base+Vector2(lean,-height)
	var pts := PackedVector2Array()
	for i in range(29):
		var t: float = float(i)/28
		var w: float = width*(0.36+sin(t*PI)*0.60+t*0.25)
		pts.append(base.lerp(mouth,t)+Vector2(-w,0))
	for i in range(28,-1,-1):
		var t: float = float(i)/28
		var w: float = width*(0.36+sin(t*PI)*0.60+t*0.25)
		pts.append(base.lerp(mouth,t)+Vector2(w,0))
	draw_colored_polygon(pts,_tissue(color))
	pts.append(pts[0])
	_path(pts,_ink,1.1)
	for i in range(5):
		var x: float = (float(i)-2)*width*0.25
		_curve(base+Vector2(x*0.4,0),(base+mouth)*0.5+Vector2(x*1.8,0),mouth+Vector2(x,0),color.lightened(0.17),0.7)
	for i in range(18):
		var t: float = _rng.randf_range(0.2,0.9)
		var p: Vector2 = base.lerp(mouth,t)+Vector2(_rng.randf_range(-width*0.5,width*0.5),0)
		if _pattern=="Spotted":
			_ellipse(p,Vector2(1.8,2.6),_accent.darkened(0.1),false)
		elif i%3==0:
			_curve(p+Vector2(-width*0.35,-2),p+Vector2(0,2),p+Vector2(width*0.35,-2),_accent.darkened(0.2),0.8)
	_ellipse(mouth,Vector2(width*0.69,6.5),_accent.darkened(0.1))
	_ellipse(mouth+Vector2(0,0.2),Vector2(width*0.48,3.8),_ink,false)
	_curve(mouth+Vector2(-width*0.5,-4),mouth+Vector2(-width*0.8,-height*0.3),mouth+Vector2(width*0.4,-height*0.15),color.lightened(0.09),4)
	_core(mouth+Vector2(-width*0.4,1),2)

func _toxin() -> void:
	for i in range(4):
		var side: float = -1.0 if i%2==0 else 1.0
		_organ(Vector2(0,-8),Vector2(side*(43+i*7),-43-i*8),11,_leaf_color.lerp(_pigment,0.25),side*9)
	_pitcher(Vector2(-24,-24),87,19,_pigment.darkened(0.16),-13)
	_pitcher(Vector2(22,-20),116,23,_pigment,10)
	_pitcher(Vector2(0,-9),65,15,_pigment.lerp(_accent,0.15),0)

func _parasite() -> void:
	for i in range(5):
		var x: float = float(i-2)*18
		var tip := Vector2(x*1.5,-88-_rng.randf_range(0,53))
		var pale: Color = _pigment.lerp(Color("becbb1"),0.50)
		_curve(Vector2(float(i-2)*3,-7),Vector2(x*1.6,-32),tip,_ink,4)
		_curve(Vector2(float(i-2)*3,-7),Vector2(x*1.6,-32),tip,pale,2.2)
		_curve(tip,tip+Vector2(22,-21),tip+Vector2(20,9),pale,1.8)
		_ellipse(tip+Vector2(20,11),Vector2(4.5,9),_pigment)
		for j in range(4):
			var start: Vector2 = Vector2(x*0.9,-30-j*12)
			_curve(start,start+Vector2(16,-6),start+Vector2(18,8),pale.darkened(0.15),0.7)
		_core(tip+Vector2(20,13),1.8)

func _carnivorous() -> void:
	_organ(Vector2(0,-5),Vector2(-65,-65),18,_leaf_color,12)
	_organ(Vector2(0,-5),Vector2(59,-62),16,_leaf_color,-8)
	_pitcher(Vector2(-30,-20),86,18,_pigment.darkened(0.2),-8)
	_stem(Vector2(0,-4),Vector2(15,-112),-5,6)
	var core := Vector2(15,-116)
	var closing: float = 0.70 + sin(_time*0.35+_phase)*0.05 - activity*0.3
	for side in [-1.0,1.0]:
		var tip: Vector2 = core+Vector2(side*47*closing,-42)
		_organ(core,tip,23,_pigment,side*12)
		_organ(core+Vector2(side*3,-4),tip+Vector2(-side*6,6),14,_accent.darkened(0.2),side*9)
		for j in range(8):
			var t: float = float(j+1)/10
			var point: Vector2 = core.lerp(tip,t)+Vector2(-side*sin(t*PI)*17,-sin(t*PI)*5)
			_curve(point,point+Vector2(-side*8,-4),point+Vector2(-side*9,-12),_vein.lightened(0.15),0.8)
	_core(core,5)

func _seed_filament(base: Vector2, tip: Vector2, radius: float) -> void:
	_stem(base,tip,8,0.85)
	_ellipse(tip,Vector2(radius*1.3,radius*2.4),_accent,false)
	_core(tip,radius*0.8)

func _core(center: Vector2, radius: float) -> void:
	if silhouette:
		return
	var brightness: float = 0.15+energy*0.003+activity*0.6
	if _glowing:
		brightness += 0.28+sin(_time*0.8+_phase)*0.10
	if _glowing or activity > 0.05:
		for i in range(3,0,-1):
			draw_circle(center,radius*(1.0+float(i)*0.7),_tissue(_accent,brightness*0.04))
	_ellipse(center,Vector2(radius,radius*0.7),_accent.lightened(minf(brightness,0.3)),false)

func _graft_branch(data: Variant) -> void:
	var graft_color: Color = _accent
	if data is Dictionary:
		graft_color = Color(str(data.get("value",_accent.to_html()))) if data.get("trait","") == "feature" else Color(str(data.get("color",data.get("donor_color",_accent.to_html()))))
	_stem(Vector2(1,-54),Vector2(60,-82),-8,2.5)
	for i in range(4):
		var offset: float = float(i)*2.3
		_path(PackedVector2Array([Vector2(9+offset,-58),Vector2(11+offset,-63)]),_accent.darkened(0.1),0.8)
	_organ(Vector2(54,-80),Vector2(76,-102),9,graft_color,5)
	_organ(Vector2(54,-80),Vector2(76,-69),8,graft_color,-3)
	_core(Vector2(57,-81),3)
