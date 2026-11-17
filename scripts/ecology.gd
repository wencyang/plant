extends Control
## Quiet pixel habitat behind the tended garden. Everything snaps to a four-pixel
## environmental grid, with square drifting pollen and stepped fern silhouettes.
var time: float = 0.0
var motes: Array = []
var stalks: Array = []
var _last_tick: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 8149
	for i in range(40): motes.append(Vector3(rng.randf(),rng.randf(),rng.randf_range(0.3,1.0)))
	for i in range(32): stalks.append(Vector4(rng.randf(),rng.randf_range(0.08,0.35),rng.randf_range(0.6,1.2),rng.randf()))

func _process(delta: float) -> void:
	time += delta
	var tick: int = int(time*3.0)
	if tick != _last_tick:
		_last_tick = tick
		queue_redraw()

func _pixel_rect(x: float,y: float,w: float,h: float,c: Color) -> void:
	draw_rect(Rect2(Vector2(floorf(x/4)*4,floorf(y/4)*4),Vector2(maxf(4,floorf(w/4)*4),maxf(4,floorf(h/4)*4))),c)

func _draw() -> void:
	if size.x < 1 or size.y < 1: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("10252b"))
	# Very broad shadow bands, without blurred circles or vector gradients.
	_pixel_rect(0,size.y*0.64,size.x,size.y*0.36,Color("122b2b"))
	_pixel_rect(0,size.y*0.84,size.x,size.y*0.16,Color("17332e"))
	for i in range(90):
		var x: float = fposmod(float(i)*137.0+17,size.x)
		var y: float = fposmod(float(i)*83.0+41,size.y)
		if i%3 == 0: _pixel_rect(x,y,4,4,Color("193332"))
		else: _pixel_rect(x,y,8,4,Color("142c2e"))
	# Hanging searching filaments frame the top rather than competing with text.
	for i in range(7):
		var x: float = size.x*(0.48+float(i)*0.073)
		var height: float = 28+float((i*37)%90)
		for j in range(int(height/8.0)):
			var step_x: float = x+floorf(sin(float(j)*0.5+float(i))*2.0)*4
			_pixel_rect(step_x,j*8,4,8,Color("1b3834"))
			if j%3==1: _pixel_rect(step_x-4,j*8,4,4,Color("274638"))
		_cluster(Vector2(x,height),12,20,Color("24453a"),i)
	# Ferns and water-storing leaf fans grow around the lower screen edges.
	for s: Vector4 in stalks:
		var base := Vector2(floorf(s.x*size.x/4)*4,size.y)
		var height: float = floorf(size.y*s.y/4)*4
		var sway: float = 4.0 if sin(time*0.15+s.w*8)>0.8 else 0.0
		for j in range(int(height/8.0)):
			var y: float = base.y-float(j)*8
			var x: float = base.x+floorf(sin(float(j)*0.15+s.w*5)*3)*4+sway
			_pixel_rect(x,y,4,8,Color("234539"))
			if j%4==0 and j>0:
				var side: int = -1 if j%8==0 else 1
				var leaf_origin := Vector2(x+side*12,y-8)
				_cluster(leaf_origin,16+floorf(s.z*8),28+floorf(s.z*12),Color("204137"),j)
				_pixel_rect(x+side*4,y,12,4,Color("2c4e3d"))
	# Segmented roots disappear beneath one another, like a low-resolution map.
	for i in range(8):
		var start_y: float = size.y*(0.82+float(i)*0.024)
		for j in range(int(size.x/20.0)+1):
			var x: float = j*20
			var y: float = start_y+floorf(sin(j*0.55+i*1.8)*2)*4
			_pixel_rect(x,y,20,4,Color("254332") if i%2==0 else Color("1c3a30"))
			if j%5==0: _pixel_rect(x+4,y+4,4,8,Color("31513a"))
	for m: Vector3 in motes:
		var x: float = fposmod(m.x*size.x+floorf(sin(time*0.08+m.y*7)*5)*4,size.x)
		var y: float = fposmod(m.y*size.y-floorf(time*m.z)*4,size.y)
		draw_rect(Rect2(Vector2(floorf(x/2)*2,floorf(y/2)*2),Vector2(2,2)),Color(0.65,0.74,0.47,0.18+m.z*0.10))

func _cluster(origin: Vector2,width: float,height: float,color: Color,seed_value: int) -> void:
	for j in range(maxi(1,int(height/4))):
		var t: float = float(j)/maxf(1,height/4-1)
		var span: float = maxf(4,floorf(sin(t*PI)*width/4)*4)
		var offset: float = -4.0 if (j+seed_value)%4==0 else 0.0
		_pixel_rect(origin.x-span/2+offset,origin.y-height+j*4,span,4,color)
		if j%3==0: _pixel_rect(origin.x+offset,origin.y-height+j*4,4,4,color.lightened(0.045))
