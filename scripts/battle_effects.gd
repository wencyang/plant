extends Control
## Pixel-native growth: stepped fibers, square spores and dithered soil pigment.
## Events refer to controls rather than fixed board coordinates, so an opponent's
## bed can slide into the home garden without detaching its effects.

var cell_lookup: Dictionary = {}
var _effects: Array[Dictionary] = []
var _serial: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func add_events(events: Array) -> void:
	for event in events:
		if not event is Dictionary:
			continue
		_serial += 1
		var effect: Dictionary = event.duplicate(true)
		effect["age"] = 0.0
		effect["seed"] = _serial * 137 + str(event.get("source", "")).hash() % 1000
		effect["duration"] = 1.9 if str(event.get("kind", "")) in ["spore", "toxin", "shade"] else 1.65
		effect["origin"] = _cell_point(str(event.get("source", "")), 0.42)
		effect["destination"] = _cell_point(str(event.get("target", "")), 0.42)
		_effects.append(effect)
	while _effects.size() > 60:
		_effects.pop_front()
	queue_redraw()

func clear_effects() -> void:
	_effects.clear()
	queue_redraw()

func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index]["age"] = float(_effects[index]["age"]) + delta
		if float(_effects[index]["age"]) >= float(_effects[index]["duration"]):
			_effects.remove_at(index)
	queue_redraw()

func _cell_point(id: String, height_ratio: float, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var cell: Variant = cell_lookup.get(id)
	if not is_instance_valid(cell) or not cell is Control:
		return fallback
	var global_point: Vector2 = cell.get_global_transform() * Vector2(cell.size.x * 0.5, cell.size.y * height_ratio)
	# Battle packets put their sprite to the left of the name. Growth starts in
	# that body, rather than the rectangular cell's now-empty middle.
	var portrait: Variant = cell.get("portrait")
	if is_instance_valid(portrait) and portrait is Control:
		global_point = portrait.get_global_transform()*Vector2(portrait.size.x*0.5,portrait.size.y*height_ratio)
	return get_global_transform().affine_inverse() * global_point

func _draw() -> void:
	for effect: Dictionary in _effects:
		var t: float = clampf(float(effect.age) / float(effect.duration), 0.0, 1.0)
		var opacity: float = minf(1.0, t * 8.0) * pow(1.0 - t, 0.65)
		var origin: Vector2 = _cell_point(str(effect.get("source", "")), 0.42, effect.origin)
		var target: Vector2 = _cell_point(str(effect.get("target", "")), 0.42, effect.destination)
		var soil: Vector2 = _cell_point(str(effect.get("target", "")), 0.79, target + Vector2(0, 24))
		var seed_value: float = float(effect.seed)
		match str(effect.get("kind", "root")):
			"entangle":
				_fiber(origin + Vector2(0, 22), soil, t, opacity, Color("86916a"), seed_value, 2.0)
				_entanglement(target, soil, t, opacity, seed_value)
			"parasite":
				_fiber(origin, target, t, opacity, Color("b0bca0"), seed_value, 1.4)
				_fiber(origin + Vector2(3, 0), target + Vector2(3, 0), t, opacity * 0.45, Color("c2c6a9"), seed_value + 2, 0.7)
				_sacs(target, t, opacity, Color("b8c6ae"), seed_value)
			"spore":
				_spores(origin, target, t, opacity, seed_value)
			"toxin":
				_seep(soil, t, opacity, seed_value)
			"bloom":
				_bloom(origin, t, opacity, seed_value)
				_spores(origin, target, t, opacity * 0.35, seed_value)
			"shade":
				_shade(target, t, opacity, seed_value)
			"wither":
				_wither(target, soil, t, opacity, seed_value)
			"devour":
				_devour(target, t, opacity)
			_:
				var healing: bool = float(effect.get("amount", 0)) < 0
				if origin.distance_to(target) > 12:
					_fiber(origin + Vector2(0, 22), soil, t, opacity * 0.8, Color("889974") if healing else Color("697f5d"), seed_value, 1.4)
				_root_network(soil, t, opacity, seed_value, healing)

func _stamp(point: Vector2, width: float, height: float, color: Color) -> void:
	var p := Vector2(floorf(point.x/2.0)*2.0,floorf(point.y/2.0)*2.0)
	var dimensions := Vector2(maxf(2,roundf(width/2.0)*2.0),maxf(2,roundf(height/2.0)*2.0))
	draw_rect(Rect2(p,dimensions),color)

func _pixel_path(points: PackedVector2Array,color: Color,width: float = 2.0) -> void:
	if points.size() < 2: return
	for i in range(points.size()-1):
		var count: int = maxi(1,ceili(points[i].distance_to(points[i+1])/2.5))
		for j in range(count+1):
			var p: Vector2 = points[i].lerp(points[i+1],float(j)/count)
			_stamp(p,width,width,color)

func _pixel_leaf(base: Vector2,tip: Vector2,width: float,color: Color) -> void:
	var axis: Vector2 = tip-base
	var length: float = axis.length()
	if length < 1: return
	var direction: Vector2 = axis/length
	var normal := Vector2(-direction.y,direction.x)
	var minimum: Vector2 = base.min(tip)-Vector2.ONE*width
	var maximum: Vector2 = base.max(tip)+Vector2.ONE*width
	for y in range(int(floorf(minimum.y/2.0)),int(ceilf(maximum.y/2.0))+1):
		for x in range(int(floorf(minimum.x/2.0)),int(ceilf(maximum.x/2.0))+1):
			var p := Vector2(x*2,y*2)
			var relative: Vector2 = p-base
			var t: float = relative.dot(direction)/length
			if t < 0 or t > 1: continue
			var half: float = sin(t*PI)*width
			var side: float = relative.dot(normal)
			if absf(side) <= half:
				var c: Color = color.darkened(0.22) if side > 0 else color
				c.a = color.a
				_stamp(p,2,2,c)
	_pixel_path(PackedVector2Array([base,tip]),Color(color.lightened(0.15),color.a*0.85),2)

func _fiber(origin: Vector2, target: Vector2, t: float, alpha: float, color: Color, phase: float, width: float) -> void:
	var distance: float = origin.distance_to(target)
	if distance < 1: return
	var normal: Vector2 = Vector2(-(target-origin).y,(target-origin).x).normalized()
	var growth: float = minf(1.0,t*3.8)
	var points := PackedVector2Array()
	for i in range(43):
		var s: float = float(i)/42.0*growth
		var arch: float = sin(s*PI)*minf(42.0,distance*0.14)
		var curl: float = sin(s*17.0+phase)*5.0*sin(s*PI)
		points.append(origin.lerp(target,s)+normal*(arch+curl))
	_pixel_path(points,Color(0.08,0.16,0.14,alpha*0.85),6)
	color.a = alpha*0.90
	_pixel_path(points,color,3)
	# Thin branches emerge from the older tissue while the growing tip remains attached.
	for i in range(5,points.size()-3,7):
		var side: float = -1.0 if i%2==0 else 1.0
		var start: Vector2 = points[i]
		var end: Vector2 = start+normal*side*(7.0+sin(phase+float(i))*3)+(target-origin).normalized()*3
		_pixel_path(PackedVector2Array([start,start.lerp(end,0.5)+normal*3,end]),Color(color,alpha*0.60),3)

func _entanglement(target: Vector2,soil: Vector2,t: float,alpha: float,phase: float) -> void:
	var growth: float = minf(1.0,t*3.0)
	for i in range(3):
		var points := PackedVector2Array()
		for j in range(30):
			var s: float = float(j)/29.0*growth
			var p: Vector2 = soil.lerp(target+Vector2(0,-7),s)
			p.x += sin(s*TAU*1.4+phase+float(i)*2)*(12-s*5)
			points.append(p)
		_pixel_path(points,Color(0.47,0.60,0.32,alpha*0.8),3)

func _spores(origin: Vector2,target: Vector2,t: float,alpha: float,phase: float) -> void:
	for i in range(21):
		var offset: float = float(i)*2.399+phase
		var travel: float = clampf(t*1.2-float(i%5)*0.05,0.0,1.0)
		var point: Vector2 = origin.lerp(target,travel)
		var spread: float = 9.0+sin(t*PI)*20.0
		point += Vector2(cos(offset+t),sin(offset*1.2))*spread
		point += Vector2(sin(t*2+offset)*4,t*13-9)
		_stamp(point,3,3,Color(0.72,0.84,0.61,alpha*(0.38+float(i%3)*0.15)))
		if i%5==0: _stamp(point+Vector2(3,0),3,3,Color(0.40,0.61,0.42,alpha*0.20))

func _seep(center: Vector2,t: float,alpha: float,phase: float) -> void:
	var width: float = (18+floorf(t*5)*3)*1.2
	for y in range(-4,5):
		for x in range(-13,14):
			var point := Vector2(x*3,y*3)
			var radius: float = pow(point.x/maxf(1,width),2)+pow(point.y/maxf(1,width*0.35),2)
			if radius > 1 or posmod(x*17+y*7+int(phase),5)==0: continue
			var c := Color(0.25,0.30,0.12,alpha*0.32)
			if posmod(x*11+y*3,4)==0: c = Color(0.43,0.42,0.18,alpha*0.25)
			_stamp(center+point,3,3,c)
	for i in range(8):
		var a: float = float(i)*2.4+phase
		var p: Vector2 = center+Vector2(cos(a)*18,sin(a)*6-floorf(t*4)*3)
		_stamp(p,3,3,Color(0.62,0.62,0.28,alpha*0.5))

func _sacs(center: Vector2,t: float,alpha: float,color: Color,phase: float) -> void:
	for i in range(5):
		var a: float = float(i)/5*TAU+phase
		var p: Vector2 = center+Vector2(cos(a),sin(a))*(7+t*3)
		color.a = alpha*0.60
		_stamp(p,3,6,color)

func _root_network(center: Vector2,t: float,alpha: float,phase: float,healing: bool) -> void:
	var color := Color("b0c98a") if healing else Color("7f9e61")
	for i in range(7):
		var a: float = float(i)/7*TAU+phase
		var tip: Vector2 = center+Vector2(cos(a)*25,sin(a)*10)
		_fiber(center,tip,t,alpha*0.65,color,a,3)
	if healing: _sacs(center-Vector2(0,t*22),t,alpha*0.60,color,phase)

func _bloom(center: Vector2,t: float,alpha: float,phase: float) -> void:
	var opening: float = floorf(sin(minf(t*1.5,1.0)*PI*0.6)*6)/6.0
	for i in range(7):
		var angle: float = float(i)/7*TAU+phase*0.01
		var direction := Vector2(cos(angle),sin(angle)*0.8)
		var tip: Vector2 = center+direction*31*opening
		_pixel_leaf(center,tip,6*opening,Color(0.82,0.67,0.36,alpha*0.32))
	# A warm tissue core opens and closes with its sepals; no ring or flash explosion.
	_stamp(center-Vector2(3,3),6,6,Color(0.93,0.80,0.49,alpha*0.7))
	_stamp(center,3,3,Color(0.97,0.87,0.61,alpha*0.8))

func _shade(center: Vector2,t: float,alpha: float,phase: float) -> void:
	for i in range(5):
		var a: float = float(i)*2.4+phase
		var c: Vector2 = center+Vector2(cos(a)*12,sin(a)*7+floorf(t*3)*3)
		for row in range(5):
			var width: float = 15+float(2-absi(2-row))*9
			_stamp(c+Vector2(-width/2,row*3-6),width,3,Color(0.04,0.12,0.11,alpha*0.15))

func _wither(target: Vector2,soil: Vector2,t: float,alpha: float,phase: float) -> void:
	for i in range(8):
		var a: float = float(i)*2.4+phase
		var p: Vector2 = target.lerp(soil,floorf(t*5)/5.0*0.8)+Vector2(cos(a)*(8+t*6),sin(a)*11)
		_stamp(p,3,6,Color(0.48,0.48,0.32,alpha*0.4))
		_stamp(p+Vector2(3,3),3,3,Color(0.35,0.38,0.27,alpha*0.35))

func _devour(center: Vector2,t: float,alpha: float) -> void:
	var closing: float = 1-floorf(minf(t*2,1.0)*5)/5.0
	for side in [-1.0,1.0]:
		var base: Vector2 = center+Vector2(0,14)
		var tip: Vector2 = center+Vector2(side*(4+closing*18),-15)
		_pixel_leaf(base,tip,8,Color(0.49,0.53,0.29,alpha*0.55))
		for j in range(4):
			var p: Vector2 = base.lerp(tip,float(j+1)/5.0)
			_stamp(p+Vector2(-side*3,-3),3,3,Color(0.77,0.76,0.46,alpha*0.6))
