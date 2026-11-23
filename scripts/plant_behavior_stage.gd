extends Control
## A safe little weather tray. Every response uses the specimen's expressed
## genome; trying rain, wind or night never edits DNA or spends an item.
const Portrait=preload("res://scripts/plant_portrait.gd")
const Abilities=preload("res://scripts/plant_adventure.gd")
const INK:=Color("355650")
var plant: Dictionary={}:
	set(value):
		plant=value
		if is_instance_valid(_portrait): _portrait.plant=plant
		queue_redraw()
var mode: String="rain":
	set(value):
		mode=value
		queue_redraw()
var animate: bool=true
var _portrait: Control
var _time: float=0.0
var _frame: int=-1

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	_portrait=Portrait.new()
	_portrait.plant=plant
	_portrait.animate=animate
	add_child(_portrait)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(_portrait): return
	_portrait.position=Vector2(size.x*0.27,8)
	_portrait.size=Vector2(size.x*0.46,maxf(1,size.y-33))
	queue_redraw()

func _process(delta: float) -> void:
	if not animate or not is_visible_in_tree(): return
	_time+=delta
	var frame: int=int(_time*24)
	if frame!=_frame:
		_frame=frame
		queue_redraw()

func _line(a: Vector2,b: Vector2,color: Color=INK,width: float=1.5) -> void:
	draw_line(a,b,color,width,true)

func _leaf(origin: Vector2,radius: float,angle: float,color: Color) -> void:
	var axis:=Vector2.from_angle(angle)*radius
	var cross:=axis.orthogonal()*0.35
	var points:=PackedVector2Array([origin-axis,origin+cross,origin+axis,origin-cross])
	draw_colored_polygon(points,color)
	points.append(points[0])
	draw_polyline(points,INK,1.2,true)
	_line(origin-axis,origin+axis,INK,0.8)

func _canopy_leaf(center: Vector2,span: float) -> void:
	var points:=PackedVector2Array()
	for i in range(41):
		var t: float=float(i)/40
		var edge: float=sin(t*PI)
		var lobes: float=sin(t*TAU*5)*3 if str(Abilities.gene(plant,"shape"))=="Split" else sin(t*TAU*7)*1.2
		points.append(center+Vector2((t-0.5)*span,-edge*(span*0.19)+lobes))
	for i in range(40,-1,-1):
		var t: float=float(i)/40
		points.append(center+Vector2((t-0.5)*span,sin(t*PI)*span*0.035))
	var pigment:=Color(str(Abilities.gene(plant,"color","a1bd7e"))).lerp(Color("a3c78b"),0.55)
	draw_colored_polygon(points,pigment)
	points.append(points[0])
	draw_polyline(points,INK,1.5,true)
	_line(center-Vector2(span*0.49,0),center+Vector2(span*0.49,0),Color("62804f"),1)
	for i in range(1,8):
		var t: float=float(i)/8
		var root:=center+Vector2((t-0.5)*span,0)
		_line(root,root+Vector2(-span*0.06,-sin(t*PI)*span*0.15),Color("66834f"),0.8)

func _draw() -> void:
	if size.x<2 or size.y<2: return
	var caps: Dictionary=Abilities.capabilities(plant)
	var canopy: bool=bool(caps.get("canopy",false)) and bool(plant.get("mature",true)) and not bool(plant.get("withered",false))
	var coil: bool=bool(caps.get("coil",false)) and bool(plant.get("mature",true)) and not bool(plant.get("withered",false))
	var glow: bool=bool(caps.get("glow",false)) and bool(plant.get("mature",true)) and not bool(plant.get("withered",false))
	var night: bool=mode=="night"
	var floor_y: float=size.y-24
	draw_style_box(_paper(Color("263f50") if night else Color("e4f0dc")),Rect2(Vector2.ZERO,size))
	# A few contour lines keep the tray in the same ink-and-paper world.
	for i in range(4):
		var y: float=floor_y+3+i*5
		_line(Vector2(8,y),Vector2(size.x-8,y),Color("8eb4a0") if night else Color("c4d4b1"),1)
	_ellipse(Vector2(size.x*0.51,floor_y-3),Vector2(size.x*0.22,9),Color(0.15,0.32,0.26,0.15))
	# A younger neighbor makes the shelter legible without numerical stats.
	var seedling:=Vector2(size.x*0.26,floor_y)
	_line(seedling,seedling-Vector2(0,23 if canopy else 13),Color("567e51"),2.5)
	_leaf(seedling-Vector2(0,14 if canopy else 7),9,-0.5,Color("99bd6a"))
	_leaf(seedling-Vector2(0,19 if canopy else 10),8,-2.6,Color("b7ce7a"))
	if mode=="rain":
		for i in range(30):
			var x: float=fposmod(i*47.7+_time*12,size.x-16)+8
			var y: float=fposmod(i*31.1+_time*126,maxf(1,floor_y))
			var shelter: bool=canopy and x>size.x*0.18 and x<size.x*0.69
			if shelter and y>floor_y*0.43:
				if i%4==0:
					var splash:=Vector2(x,floor_y*0.43)
					draw_arc(splash,3+fposmod(_time*9+i,6),PI,TAU,9,Color("80b9bd"),1,true)
				continue
			_line(Vector2(x,y),Vector2(x-2,y+8),Color("79b5bf"),1.5)
		if canopy:
			_line(Vector2(size.x*0.52,floor_y-4),Vector2(size.x*0.48,floor_y*0.43),Color("5e8559"),3)
			_canopy_leaf(Vector2(size.x*0.43,floor_y*0.43),size.x*0.52)
			_ellipse(Vector2(size.x*0.78,floor_y-2),Vector2(size.x*0.08,7),Color("8bc9be"))
			var drop:=Vector2(size.x*0.71,floor_y*0.5+fposmod(_time*72,maxf(1,floor_y*0.4)))
			draw_circle(drop,2.5,Color("74bec2"),true,-1,true)
	elif mode=="wind":
		var trellis_x: float=size.x*0.77
		_line(Vector2(trellis_x,floor_y),Vector2(trellis_x,28),Color("a47c51"),3)
		for i in range(4): _line(Vector2(trellis_x-14,40+i*27),Vector2(trellis_x+14,40+i*27),Color("a47c51"),2)
		if coil:
			var vine:=PackedVector2Array()
			for i in range(65):
				var f: float=float(i)/64
				vine.append(Vector2(lerpf(size.x*0.52,trellis_x,f)+sin(f*TAU*3)*9,lerpf(floor_y-8,36,f)))
			draw_polyline(vine,INK,4,true)
			draw_polyline(vine,Color("88b978"),2,true)
		elif canopy:
			_canopy_leaf(Vector2(size.x*0.71,floor_y*0.72),size.x*0.28)
		for i in range(8):
			var progress: float=fposmod(_time*0.18+float(i)/8,1)
			var x: float=lerpf(-10,size.x+10,progress)
			var y: float=45+i*11+sin(_time*2+i)*7
			if coil and x>trellis_x-10: x=trellis_x-6; y=48+i*9
			elif canopy and x>size.x*0.66: x=size.x*(0.66+float(i%3)*0.025); y=floor_y*0.7-3-float(i/3)*6
			draw_circle(Vector2(x,y),3,Color("e6b271"),true,-1,true)
			_line(Vector2(x,y),Vector2(x-4,y-7),Color("9b714e"),0.8)
		for i in range(4):
			var x: float=fposmod(_time*80+i*83,size.x)
			_line(Vector2(x,25+i*30),Vector2(x+28,22+i*30),Color("b0c6b2"),1)
	else:
		if glow:
			for i in range(7,0,-1):
				draw_circle(Vector2(size.x*0.5,floor_y*0.47),12+i*8,Color(0.87,0.94,0.49,0.018),true,-1,true)
		for i in range(7):
			var angle: float=_time*0.45+i*TAU/7
			var center:=Vector2(size.x*(0.5 if glow else 0.88),floor_y*(0.47 if glow else 0.27))
			var point:=center+Vector2(cos(angle)*(36+i*2),sin(angle*1.4)*23)
			var wing: float=2+absf(sin(_time*9+i))*3
			draw_circle(point+Vector2(-wing,0),wing,Color("e8dca7"),true,-1,true)
			draw_circle(point+Vector2(wing,0),wing,Color("f7e7bd"),true,-1,true)
			_line(point-Vector2(0,3),point+Vector2(0,3),INK,1)
		for i in range(14):
			var point:=Vector2(fposmod(i*71.3,size.x),fposmod(i*29.7,floor_y))
			draw_circle(point,1,Color(0.9,0.96,0.68,0.2+0.3*absf(sin(_time+i))),true,-1,true)

func _ellipse(center: Vector2,radius: Vector2,color: Color) -> void:
	var points:=PackedVector2Array()
	for i in range(40): points.append(center+Vector2(cos(float(i)*TAU/40),sin(float(i)*TAU/40))*radius)
	draw_colored_polygon(points,color)

func _paper(color: Color) -> StyleBoxFlat:
	var result:=StyleBoxFlat.new()
	result.bg_color=color
	result.border_color=Color("9ab193")
	result.set_border_width_all(1)
	result.set_corner_radius_all(8)
	return result
