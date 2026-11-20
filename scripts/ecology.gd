extends Control
## A sunny pixel garden: cloud puffs, leaf shadows and little passing butterflies.
## Snapped geometry keeps the hand-built habitat crisp at every window size.
var time: float = 0.0
var motes: Array = []
var stalks: Array = []
var _last_tick: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 8149
	for i in range(30): motes.append(Vector3(rng.randf(),rng.randf(),rng.randf_range(0.3,1.0)))
	for i in range(22): stalks.append(Vector4(rng.randf(),rng.randf_range(0.06,0.22),rng.randf_range(0.6,1.2),rng.randf()))

func _process(delta: float) -> void:
	time += delta
	var tick: int = int(time*6.0)
	if tick != _last_tick:
		_last_tick = tick
		queue_redraw()

func _pixel_rect(x: float,y: float,w: float,h: float,c: Color) -> void:
	draw_rect(Rect2(Vector2(floorf(x/4)*4,floorf(y/4)*4),Vector2(maxf(4,floorf(w/4)*4),maxf(4,floorf(h/4)*4))),c)

func _draw() -> void:
	if size.x < 1 or size.y < 1: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("bfe8cd"))
	_pixel_rect(0,0,size.x,size.y*0.23,Color("b9e5e5"))
	_pixel_rect(0,size.y*0.23,size.x,size.y*0.40,Color("c6ebce"))
	_pixel_rect(0,size.y*0.63,size.x,size.y*0.37,Color("add787"))
	_pixel_rect(0,size.y*0.88,size.x,size.y*0.12,Color("91c76c"))
	# A stepped sun and slow square-edged clouds make the garden feel outdoors.
	var sun := Vector2(size.x*0.91,maxf(40,size.y*0.085))
	_pixel_rect(sun.x-24,sun.y-32,48,64,Color("ffe99b"))
	_pixel_rect(sun.x-32,sun.y-24,64,48,Color("ffe99b"))
	_pixel_rect(sun.x-20,sun.y-24,40,48,Color("fff4b9"))
	for i in range(4):
		var cloud_x: float = fposmod(float(i)*size.x*0.29+time*1.6,size.x+220)-110
		var cloud_y: float = 28+float((i*47)%93)
		_pixel_rect(cloud_x,cloud_y,108,16,Color("eaf6db"))
		_pixel_rect(cloud_x+16,cloud_y-12,32,28,Color("f7fbe9"))
		_pixel_rect(cloud_x+44,cloud_y-20,40,36,Color("f7fbe9"))
		_pixel_rect(cloud_x+80,cloud_y-8,24,24,Color("f7fbe9"))
	# Tiny sunlight patches and grass remain quiet behind the cream game panels.
	for i in range(62):
		var x: float = fposmod(float(i)*137.0+17,size.x)
		var y: float = size.y*0.22+fposmod(float(i)*83.0+41,size.y*0.78)
		_pixel_rect(x,y,12 if i%3==0 else 4,4,Color("d9edaa") if i%2==0 else Color("a3cd81"))
	# Branches frame the upper corners with fresh leaves, not dark hanging vines.
	for i in range(5):
		var x: float = size.x*(0.69+float(i)*0.073)
		var height: float = 16+float((i*37)%68)
		for j in range(int(height/8.0)):
			var step_x: float = x+floorf(sin(float(j)*0.5+float(i))*2.0)*4
			_pixel_rect(step_x,j*8,4,8,Color("79ac64"))
		_cluster(Vector2(x,height),16,28,Color("8dc971"),i)
	# Ferns, daisies and coral buds grow along the lower edge.
	for i in range(stalks.size()):
		var s: Vector4 = stalks[i]
		var base := Vector2(floorf(s.x*size.x/4)*4,size.y)
		var height: float = floorf(size.y*s.y/4)*4
		var sway: float = 4.0 if sin(time*0.3+s.w*8)>0.8 else 0.0
		var crown := Vector2(base.x+sway,base.y-height)
		for j in range(int(height/8.0)):
			var y: float = base.y-float(j)*8
			var x: float = base.x+floorf(sin(float(j)*0.15+s.w*5)*3)*4+sway
			_pixel_rect(x,y,4,8,Color("619c53"))
			if j%4==0 and j>0:
				var side: int = -1 if j%8==0 else 1
				_cluster(Vector2(x+side*12,y-8),16+floorf(s.z*8),24+floorf(s.z*8),Color("78b85d"),j)
		if i%3==0:
			var petals := Color("fff4d4") if i%2==0 else Color("f3aa8d")
			_pixel_rect(crown.x-8,crown.y-4,20,8,petals)
			_pixel_rect(crown.x-4,crown.y-8,12,16,petals)
			_pixel_rect(crown.x,crown.y-4,4,8,Color("e8b557"))
	# Pollen glints and three butterflies add life without covering the controls.
	for m: Vector3 in motes:
		var x: float = fposmod(m.x*size.x+floorf(sin(time*0.12+m.y*7)*5)*4,size.x)
		var y: float = fposmod(m.y*size.y-floorf(time*m.z)*4,size.y)
		draw_rect(Rect2(Vector2(floorf(x/2)*2,floorf(y/2)*2),Vector2(2,2)),Color(1.0,0.99,0.70,0.35+m.z*0.18))
	for i in range(3):
		var x: float = fposmod(float(i)*size.x*0.37+time*(9+i*2),size.x+40)-20
		var y: float = size.y*(0.19+i*0.28)+sin(time*0.8+i*2.1)*16
		var wings: int = 4 if posmod(int(time*6)+i,4)<2 else 8
		var hue := Color("e99b76") if i%2==0 else Color("d4afed")
		_pixel_rect(x-wings,y-4,wings,8,hue)
		_pixel_rect(x+4,y-4,wings,8,hue)
		_pixel_rect(x,y,4,8,Color("52704b"))

func _cluster(origin: Vector2,width: float,height: float,color: Color,seed_value: int) -> void:
	for j in range(maxi(1,int(height/4))):
		var t: float = float(j)/maxf(1,height/4-1)
		var span: float = maxf(4,floorf(sin(t*PI)*width/4)*4)
		var offset: float = -4.0 if (j+seed_value)%4==0 else 0.0
		_pixel_rect(origin.x-span/2+offset,origin.y-height+j*4,span,4,color)
		if j%3==0: _pixel_rect(origin.x+offset,origin.y-height+j*4,4,4,color.lightened(0.16))
