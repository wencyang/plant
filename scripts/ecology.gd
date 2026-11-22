extends Control
## An illustrated garden edge: fine ink, pale paper, gentle living motion.
const SceneArt = preload("res://scripts/habitat_scene.gd")
var time: float = 0.0
var motes: Array[Vector3] = []
var stalks: Array[Vector4] = []
var _last_tick: int = -1
var _landscape: Texture2D
const INK := Color("334a40")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_landscape=SceneArt.texture_for("Mosswood")
	var rng:=RandomNumberGenerator.new()
	rng.seed=8149
	for i in range(24): motes.append(Vector3(rng.randf(),rng.randf(),rng.randf_range(0.3,1.0)))
	for i in range(14): stalks.append(Vector4(rng.randf(),rng.randf_range(0.06,0.17),rng.randf_range(0.6,1.2),rng.randf()))

func _process(delta: float) -> void:
	time+=delta
	var tick: int=int(time*12.0)
	if tick!=_last_tick:
		_last_tick=tick
		queue_redraw()

func _draw() -> void:
	if size.x<1 or size.y<1: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("e3e7cc"))
	if _landscape!=null:
		var extent: Vector2=_landscape.get_size()
		var scale: float=maxf(size.x/extent.x,size.y/extent.y)
		var view: Vector2=extent*scale
		draw_texture_rect(_landscape,Rect2((size-view)*0.5,view),false)
		# Translucent paper gives the garden controls a calm, readable backdrop.
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.94,0.94,0.83,0.77))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0,size.y*0.55),Vector2(size.x*0.22,size.y*0.35),Vector2(size.x*0.61,size.y*0.64),Vector2(size.x,size.y*0.42),size,Vector2(0,size.y)]),Color("c5d2aa"))
	# Slightly irregular contours and leaf veins follow the source art direction.
	for i in range(stalks.size()):
		var s: Vector4=stalks[i]
		var base:=Vector2(s.x*size.x,size.y+14)
		var height: float=size.y*s.y
		var sway: float=sin(time*0.32+s.w*8)*3.0
		var tip:=base+Vector2(sway+sin(s.w*11)*25,-height)
		draw_line(base,tip,INK,1.6,true)
		for j in range(4):
			var t: float=0.20+float(j)*0.18
			var node: Vector2=base.lerp(tip,t)
			var side: float=-1.0 if (i+j)%2==0 else 1.0
			_leaf(node,node+Vector2(side*(16+j*3),-13-j*2),7.0+j,Color("8fa77b") if i%2==0 else Color("b5bf86"))
		if i%3==0:
			for petal in range(5):
				var angle: float=float(petal)*TAU/5.0
				var p: Vector2=tip+Vector2(cos(angle),sin(angle))*5.5
				draw_circle(p,4.5,Color("e4ad87"),true,-1,true)
				draw_arc(p,4.5,0,TAU,14,INK,0.8,true)
			draw_circle(tip,2.4,Color("bf934e"),true,-1,true)
	for m: Vector3 in motes:
		var pos:=Vector2(fposmod(m.x*size.x+sin(time*0.2+m.y*9)*10,size.x),fposmod(m.y*size.y-time*m.z*3,size.y))
		draw_circle(pos,1.3,Color(1.0,0.97,0.76,0.35+m.z*0.2),true,-1,true)
	for i in range(3):
		var p:=Vector2(fposmod(float(i)*size.x*0.37+time*(9+i*2),size.x+40)-20,size.y*(0.19+i*0.28)+sin(time*0.8+i*2.1)*16)
		var wing: float=3.0+sin(time*4+i)*2.0
		_leaf(p,p+Vector2(-wing*2,-3),3.0,Color("d79878"))
		_leaf(p,p+Vector2(wing*2,-3),3.0,Color("e5b88d"))

func _leaf(base: Vector2,tip: Vector2,width: float,color: Color) -> void:
	var axis: Vector2=tip-base
	var side: Vector2=axis.normalized().orthogonal()
	var points:=PackedVector2Array()
	for sign_value: float in [1.0,-1.0]:
		for i in range(9):
			var t: float=float(i)/8.0 if sign_value>0 else 1.0-float(i)/8.0
			var ripple: float=1.0+sin(t*PI*7)*0.09
			points.append(base+axis*t+side*(sin(t*PI)*width*ripple*sign_value))
	draw_colored_polygon(points,color)
	points.append(points[0])
	draw_polyline(points,INK,0.9,true)
	draw_line(base,tip,INK,0.65,true)
