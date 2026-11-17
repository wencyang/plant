extends Control
class_name PlantPortrait
## Original handheld-style botanical sprites. Each visible mark is generated on
## an 80 × 96 pixel canvas from the same genes used by breeding and saved pedigrees.
const WIDTH: int = 80
const HEIGHT: int = 96
const INK := Color("193632")
static var _texture_cache: Dictionary = {}
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
var _frame: int = -1
var _rng := RandomNumberGenerator.new()
var _image: Image
var _pigment := Color("9bbd81")
var _accent := Color("ecc47d")
var _foliage := Color("619779")
var _pattern: String = "Solid"
var _shape: String = "Pointed"
var _deformed: bool = false
var _glow: bool = false
var _pose: int = 0
var _core_level: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	set_process(animate)

func _process(delta: float) -> void:
	_time += delta
	activity = move_toward(activity,0.0,delta*0.55)
	# Four held poses, rather than fractional rotation, preserve the pixel grid.
	var new_frame: int = int(_time*2.5) % 4
	if animate and new_frame != _frame:
		_frame = new_frame
		queue_redraw()

func _gene(slot: String, fallback: Variant) -> Variant:
	var data: Variant = plant.get("genes",{}).get(slot,fallback)
	return data.get("dominant",fallback) if data is Dictionary else data

func _draw() -> void:
	if plant.is_empty() or size.x < 1 or size.y < 1: return
	var frame: int = (_frame + posmod(int(plant.get("seed",1)),4)) % 4 if animate and alive else 0
	var charge: int = int(energy/34.0) + int(activity*3.0)
	var key: String = "hd2:%d:%s:%s:%d:%d" % [hash(JSON.stringify([plant.get("seed",1),plant.get("type","Leaf"),plant.get("genes",{}),plant.get("graft_history",[]),plant.get("inherited_graft_color",""),plant.get("deformed",false),plant.get("mature",true)])),alive,silhouette,frame,charge]
	var texture: Texture2D
	if _texture_cache.has(key): texture = _texture_cache[key]
	else:
		_pose = [0,1,0,-1][frame]
		_core_level = charge
		texture = ImageTexture.create_from_image(_make_sprite())
		if _texture_cache.size() > 768: _texture_cache.clear()
		_texture_cache[key] = texture
	var factor: float = minf(size.x/float(WIDTH),size.y/float(HEIGHT))
	# Nearest filtering keeps every edge hard even when a responsive cell falls
	# between whole multiples. Sprite bounds themselves always land on pixels.
	var dimensions := Vector2(roundf(WIDTH*factor),roundf(HEIGHT*factor))
	var offset := Vector2(roundf((size.x-dimensions.x)*0.5),roundf((size.y-dimensions.y)*0.5))
	draw_texture_rect(texture,Rect2(offset,dimensions),false,Color(1,1,1,clampf(reveal,0,1)))

func _make_sprite() -> Image:
	_image = Image.create(WIDTH,HEIGHT,false,Image.FORMAT_RGBA8)
	_image.fill(Color.TRANSPARENT)
	_rng.seed = int(plant.get("seed",92))
	_pigment = Color(str(_gene("color","9bbd81"))).lightened(0.10)
	_accent = Color(str(_gene("accent","edc27d"))).lightened(0.08)
	_foliage = Color("4b9270").lerp(_pigment,0.27)
	_pattern = str(_gene("pattern","Solid"))
	_shape = str(_gene("shape","Pointed"))
	_deformed = bool(plant.get("deformed",false))
	for record in plant.get("mutation_history",[]):
		if record is Dictionary and str(record.get("outcome","")).to_lower() == "deformity": _deformed = true
	_glow = str(_gene("glow","None")) != "None"
	# A small stepped soil shadow anchors the roots instead of a floating sticker.
	_ellipse(Vector2i(20,44),Vector2i(12,2),Color("254c3e"),false)
	_rect(12,44,16,1,Color("375b44"))
	_roots()
	match str(plant.get("type","Leaf")):
		"Bloom": _bloom()
		"Vine": _vine()
		"Root": _root()
		"Spore": _spore()
		"Toxin": _toxin()
		"Parasite": _parasite()
		"Carnivorous": _carnivorous()
		_: _leaf_rosette()
	var grafts: Array = plant.get("graft_history",[])
	for i in range(mini(2,grafts.size())):
		var data: Dictionary = grafts[i]
		var c := Color(str(data.get("donor_color",data.get("color",_accent.to_html()))))
		if data.get("trait","") == "feature": c = Color(str(data.get("value",c.to_html())))
		_graft(c,-1 if i > 0 else 1)
	if grafts.is_empty() and plant.has("inherited_graft_color"):
		_graft(Color(str(plant.inherited_graft_color)),1)
	return _apply_form()

func _color(c: Color) -> Color:
	if silhouette: return Color("385949")
	if not alive: return c.lerp(Color("7b8062"),0.84).darkened(0.22)
	return c

func _native_pixel(x: int,y: int,c: Color) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT: _image.set_pixel(x,y,_color(c))

func _px(x: int,y: int,c: Color) -> void:
	# Anatomical coordinates retain their original proportions. Broad tissue
	# clusters span two pixels; all contours, veins and ribs use the finer grid.
	for yy in range(y*2,y*2+2):
		for xx in range(x*2,x*2+2): _native_pixel(xx,yy,c)

func _native_rect(x: int,y: int,w: int,h: int,c: Color) -> void:
	for yy in range(y,y+h):
		for xx in range(x,x+w): _native_pixel(xx,yy,c)

func _rect(x: int,y: int,w: int,h: int,c: Color) -> void:
	_native_rect(x*2,y*2,w*2,h*2,c)

func _native_line(a: Vector2i,b: Vector2i,c: Color,width: int = 1) -> void:
	var dx: int = absi(b.x-a.x)
	var dy: int = -absi(b.y-a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var error: int = dx+dy
	var p := a
	while true:
		_native_rect(p.x-width/2,p.y-width/2,width,width,c)
		if p == b: break
		var twice: int = error*2
		if twice >= dy: error += dy; p.x += sx
		if twice <= dx: error += dx; p.y += sy

func _line(a: Vector2i,b: Vector2i,c: Color,width: int = 1) -> void:
	_native_line(a*2,b*2,c,width*2)

func _stem(a: Vector2i,b: Vector2i,width: int = 1,pale: bool = false) -> void:
	_native_line(a*2+Vector2i(1,0),b*2+Vector2i(1,0),INK,width*2+2)
	var c: Color = _accent.lerp(Color("c8d9ad"),0.5) if pale else _foliage
	_native_line(a*2,b*2,c,width*2)
	_native_line(a*2+Vector2i(-1,0),b*2+Vector2i(-1,0),c.lightened(0.22),1)
	# Pinpoint lenticels make a stem feel fibrous without widening its silhouette.
	for j in range(2,8,2):
		var p := Vector2i(Vector2(a*2).lerp(Vector2(b*2),float(j)/9.0))
		_native_pixel(p.x+1,p.y,c.darkened(0.2))

func _ellipse(center: Vector2i,radius: Vector2i,c: Color,outline: bool = true,markings: bool = false) -> void:
	var middle := center*2
	var r := radius*2
	for y in range(middle.y-r.y,middle.y+r.y+1):
		for x in range(middle.x-r.x,middle.x+r.x+1):
			var dx: float = float(x-middle.x)/maxf(1,r.x)
			var dy: float = float(y-middle.y)/maxf(1,r.y)
			var distance: float = dx*dx+dy*dy
			if distance > 1: continue
			var color: Color = c
			var tone: float = dx*0.60+dy*0.35
			if tone > 0.48: color = c.darkened(0.28)
			elif tone > 0.18: color = c.darkened(0.15)
			elif tone < -0.40: color = c.lightened(0.23)
			elif tone < -0.15: color = c.lightened(0.12)
			if markings: color = _marked(color,Vector2i(x,y),float(y-middle.y+r.y)/maxf(1,r.y*2),dx)
			var edge: bool = pow((absf(x-middle.x)+1.0)/maxf(1,r.x),2)+dy*dy > 1.0 or dx*dx+pow((absf(y-middle.y)+1.0)/maxf(1,r.y),2) > 1.0
			if outline and edge: color = c.darkened(0.48) if dx < -0.1 else INK
			_native_pixel(x,y,color)
	if outline:
		# A tiny cuticle highlight is a real extra pixel, rather than a blurred rim.
		_native_pixel(middle.x-maxi(1,r.x/3),middle.y-maxi(1,r.y*2/3),c.lightened(0.3))

func _marked(base: Color,p: Vector2i,t: float,side: float) -> Color:
	match _pattern:
		"Striped":
			var band: int = posmod(p.y+p.x/3,10)
			if band < 3: return base.lerp(_accent,0.82)
			if band == 3: return base.lerp(_accent.darkened(0.16),0.55)
		"Spotted":
			var spot := Vector2i(posmod(p.x,12)-4,posmod(p.y,12)-5)
			if spot.length_squared() <= 5: return _accent
			if spot.length_squared() <= 9: return base.lerp(_accent,0.45)
		"Gradient":
			return base.lerp(_accent,floorf(t*8.0)/8.0*0.70)
		"Starburst":
			if absf(side) < 0.09 or posmod(p.x+p.y,14) == 0: return _accent
			if absf(side) < 0.18: return base.lerp(_accent,0.35)
		"Bicolor Ring":
			if t > 0.43 and t < 0.60: return _accent
			if t > 0.39 and t < 0.64: return base.lerp(_accent,0.45)
	return base

func _leaf(base: Vector2i,tip_value: Vector2i,width: float,color: Color,patterned: bool = true) -> void:
	var tip: Vector2i = tip_value
	if _deformed and tip.x < 20: tip = Vector2i(Vector2(base).lerp(Vector2(tip),0.72)); width *= 0.75
	# Rasterize the membrane at native 80×96 resolution. In particular these
	# bounds and edge tests are not enlarged 40×48 pixels.
	var base_hd := Vector2(base)*2.0
	var tip_hd := Vector2(tip)*2.0
	var axis: Vector2 = tip_hd-base_hd
	var length: float = axis.length()
	if length < 1: return
	var direction: Vector2 = axis/length
	var normal := Vector2(-direction.y,direction.x)
	var pixels: Dictionary = {}
	var native_width: float = width*2.0
	var bounds := Rect2(base_hd.min(tip_hd)-Vector2.ONE*(native_width+2),Vector2(absf(axis.x),absf(axis.y))+Vector2.ONE*(native_width*2+4))
	for y in range(int(bounds.position.y),int(bounds.end.y)+1):
		for x in range(int(bounds.position.x),int(bounds.end.x)+1):
			var delta := Vector2(x,y)-base_hd
			var t: float = delta.dot(direction)/length
			if t < 0 or t > 1: continue
			var half: float = pow(maxf(0,sin(t*PI)),0.45 if _shape == "Round" else 0.85)*native_width
			if _shape == "Frilled": half *= 0.9+0.14*sin(t*35.0)
			if _shape == "Split" and t > 0.72 and absf(delta.dot(normal)) < (t-0.72)*native_width*1.8: continue
			var lateral: float = delta.dot(normal)
			if absf(lateral) <= half:
				var ratio: float = lateral/maxf(1,half)
				var c := color
				if ratio > 0.55: c = color.darkened(0.25)
				elif ratio > 0.12: c = color.darkened(0.12)
				elif ratio < -0.55: c = color.lightened(0.22)
				elif ratio < -0.20: c = color.lightened(0.10)
				if patterned: c = _marked(c,Vector2i(x,y),t,ratio)
				# Restrained fine grain is pigment inside tissue, not uniform noise.
				if posmod(x*13+y*7+int(plant.get("seed",0)),37)==0: c = c.darkened(0.045)
				pixels[Vector2i(x,y)] = c
	for p: Vector2i in pixels:
		var edge: bool = false
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not pixels.has(p+offset): edge = true; break
		_native_pixel(p.x,p.y,(color.darkened(0.43) if Vector2(p).dot(normal) < base_hd.dot(normal) else INK) if edge else pixels[p])
	var vein_color: Color = color.lerp(_accent,0.45) if patterned else color.lightened(0.25)
	_native_line(Vector2i(base_hd),Vector2i(tip_hd),vein_color,1)
	# Fine secondary ribs are half the old pixel width and terminate inside the rim.
	for j in range(2,9):
		var t: float = float(j)/10.0
		var middle: Vector2 = base_hd.lerp(tip_hd,t)
		var spread: float = sin(t*PI)*native_width*0.76
		for side in [-1,1]:
			var end: Vector2 = middle+normal*spread*side-direction*3.0
			_native_line(Vector2i(middle),Vector2i(end),color.lightened(0.13),1)
	var texture: String = str(_gene("texture","Matte"))
	if texture in ["Waxy","Wet","Translucent"]:
		var cuticle_start: Vector2 = base_hd.lerp(tip_hd,0.40)-normal*native_width*0.40
		var cuticle_end: Vector2 = base_hd.lerp(tip_hd,0.69)-normal*native_width*0.34
		_native_line(Vector2i(cuticle_start),Vector2i(cuticle_end),color.lerp(_accent,0.25).lightened(0.29),1)
		if texture == "Translucent":
			_native_line(Vector2i(base_hd.lerp(tip_hd,0.28)+normal*2),Vector2i(base_hd.lerp(tip_hd,0.80)+normal*2),_accent.lerp(color,0.55),1)

func _roots() -> void:
	for i in range(5):
		var end := Vector2i(10+i*5,45+int(i%2))
		_line(Vector2i(20,40),end,Color("6f8963"))
		_px(end.x-1,end.y+1,Color("425f47"))
	_rect(17,40,7,3,Color("517951"))

func _leaf_rosette() -> void:
	var tips: Array = [Vector2i(6,30),Vector2i(5,21),Vector2i(12,10),Vector2i(21,5),Vector2i(30,12),Vector2i(35,23),Vector2i(34,32)]
	for i in range(tips.size()):
		var tip: Vector2i = tips[i]+Vector2i(_pose*(i%2),int(_rng.randi_range(-1,1)))
		_leaf(Vector2i(19+i%3,41),tip,3.3+float(i%3)*0.6,_foliage.lerp(_pigment,0.30+float(i%2)*0.14))
	_leaf(Vector2i(20,42),Vector2i(8,37),3.5,_foliage.darkened(0.05))
	_leaf(Vector2i(20,42),Vector2i(33,37),3.2,_foliage)

func _bloom() -> void:
	var core := Vector2i(20+_pose,16)
	_stem(Vector2i(20,42),core,2)
	_leaf(Vector2i(20,36),Vector2i(7,29),3.7,_foliage)
	_leaf(Vector2i(20,29),Vector2i(34,22),3.6,_foliage)
	var petals: int = clampi(int(_gene("petals",6)),4,10)
	for i in range(petals):
		var angle: float = TAU*float(i)/petals-PI*0.5
		var tip := core+Vector2i(roundi(cos(angle)*11),roundi(sin(angle)*10))
		_leaf(core,tip,3.5 if petals < 7 else 2.8,_pigment.darkened(float(i%2)*0.08))
	_ellipse(core,Vector2i(4,4),_accent)
	_rect(core.x-1,core.y-2,2,2,_accent.lightened(0.24))
	_core(core,2)
	_stem(Vector2i(20,31),Vector2i(32,16),1)
	_ellipse(Vector2i(32,15),Vector2i(3,5),_pigment,true,true)
	_rect(30,20,4,1,_foliage.lightened(0.10))

func _vine() -> void:
	for i in range(3):
		var side: int = -1 if i%2 == 0 else 1
		var root_point := Vector2i(18+i*2,42)
		var bend := Vector2i(20+side*(7+i),25)
		var end := Vector2i(20+side*(8-i*2)+_pose,7+i*3)
		_stem(root_point,bend,2)
		_stem(bend,end,1)
		_stem(end,end+Vector2i(side*4,-2))
		_stem(end+Vector2i(side*4,-2),end+Vector2i(side*6,1))
		_stem(end+Vector2i(side*6,1),end+Vector2i(side*4,4))
		for j in range(3):
			var base := Vector2i(Vector2(bend).lerp(Vector2(end),float(j+1)/4.0))
			_leaf(base,base+Vector2i((-1 if j%2==0 else 1)*7,-6),2.4,_foliage.lerp(_pigment,0.35))
	_leaf(Vector2i(20,41),Vector2i(7,36),3.2,_foliage)
	_leaf(Vector2i(20,41),Vector2i(34,35),3.0,_foliage)

func _root() -> void:
	for tip in [Vector2i(6,25),Vector2i(11,17),Vector2i(20,11),Vector2i(29,17),Vector2i(35,26)]:
		_leaf(Vector2i(20,34),tip+Vector2i(_pose,0),3.4,_foliage)
	_ellipse(Vector2i(20,35),Vector2i(9,8),_pigment.lerp(Color("b2a56b"),0.25),true,true)
	for x in [15,20,25]:
		_line(Vector2i(x,30),Vector2i(x+int((x-20)/3),40),_pigment.darkened(0.34))
		_px(x-1,32,_accent.darkened(0.08))
	_stem(Vector2i(20,29),Vector2i(22+_pose,7),1)
	_ellipse(Vector2i(22+_pose,6),Vector2i(2,4),_accent)

func _cap(center: Vector2i,width: int,height: int,color: Color) -> void:
	var middle := center*2
	var w: int = width*2
	var h: int = height*2
	for y in range(-h,5):
		for x in range(-w,w+1):
			var norm: float = pow(float(x)/maxf(1,w),2)+pow(float(y)/maxf(1,h),2)
			if y <= 0 and norm > 1.0: continue
			if y > 0 and abs(x) > w-3: continue
			var c: Color = color
			if y > -2: c = color.darkened(0.26)
			elif x > w/3: c = color.darkened(0.14)
			elif x < -w/3 and y < -h/3: c = color.lightened(0.19)
			elif y < -h*2/3: c = color.lightened(0.09)
			c = _marked(c,middle+Vector2i(x,y),float(y+h)/float(h+4),float(x)/w)
			var edge: bool = (norm > 0.88 and y < -1) or y==4 or abs(x)==w
			_native_pixel(middle.x+x,middle.y+y,INK if edge else c)
	# Delicate gill ribs hang under the cap, each a single native pixel wide.
	for x in range(-w+4,w-3,4):
		_native_line(middle+Vector2i(x,0),middle+Vector2i(roundi(x*0.80),3),_accent.darkened(0.12),1)
	for i in range(5):
		var p := middle+Vector2i(-w/2+i*3,-h/2-int(i%2))
		_native_pixel(p.x,p.y,color.lightened(0.26))

func _spore() -> void:
	var caps: Array = [Vector2i(10,27),Vector2i(29,23),Vector2i(20+_pose,12)]
	for i in range(3):
		var p: Vector2i = caps[i]
		_stem(Vector2i(18+i*2,42),p+Vector2i(0,2),2,true)
		_cap(p,7 if i<2 else 10,5 if i<2 else 7,_pigment)
		_core(p+Vector2i(0,2),1)
	if _glow:
		for i in range(5):
			_px(5+int(_rng.randi_range(0,29)),27+posmod(i*5+_pose,13),_accent)

func _pitcher(base: Vector2i,height: int,width: int,color: Color,lean: int = 0) -> void:
	var mouth := base+Vector2i(lean,-height)
	var base_hd := base*2
	var mouth_hd := mouth*2
	for y in range(height*2):
		var t: float = float(y)/(height*2)
		var half: int = maxi(3,roundi(width*2.0*(0.45+sin(t*PI)*0.55)))
		var center_x: int = roundi(lerpf(float(base_hd.x),float(mouth_hd.x),t))
		for x in range(-half,half+1):
			var c := color
			if x > half/2: c = color.darkened(0.27)
			elif x > 0: c = color.darkened(0.12)
			elif x < -half/2: c = color.lightened(0.16)
			c = _marked(c,Vector2i(center_x+x,base_hd.y-y),t,float(x)/maxf(1,half))
			if abs(x)==half: c = INK
			elif posmod(x+half/2,5)==0 and t>0.18 and t<0.86: c = c.lightened(0.07)
			_native_pixel(center_x+x,base_hd.y-y,c)
	_ellipse(mouth,Vector2i(width,3),_accent)
	_ellipse(mouth+Vector2i(0,-1),Vector2i(maxi(1,width-2),1),INK,false)
	_leaf(mouth+Vector2i(-width,0),mouth+Vector2i(0,-6),2.3,color)
	_native_line(mouth_hd+Vector2i(-width+1,-1),mouth_hd+Vector2i(width-2,-1),_accent.lightened(0.24),1)
	_core(mouth+Vector2i(-width+1,0),1)

func _toxin() -> void:
	_leaf(Vector2i(20,42),Vector2i(4,33),4.0,_foliage)
	_leaf(Vector2i(20,42),Vector2i(36,32),4.0,_foliage)
	_pitcher(Vector2i(12,38),19,5,_pigment.darkened(0.10),-2+_pose)
	_pitcher(Vector2i(27,39),28,6,_pigment,1+_pose)
	_pitcher(Vector2i(20,42),14,4,_pigment.lerp(_accent,0.12))

func _parasite() -> void:
	for i in range(5):
		var start := Vector2i(18+i,42)
		var bend := Vector2i(7+i*6,29)
		var end := Vector2i(5+i*7+_pose,12+int(_rng.randi_range(0,7)))
		_stem(start,bend,1,true)
		_stem(bend,end,1,true)
		_stem(end,end+Vector2i(3,-2),1,true)
		_ellipse(end+Vector2i(4,1),Vector2i(2,4),_pigment.lerp(Color("d6d8b8"),0.45))
		_line(bend,bend+Vector2i(4,3),_accent)
		_core(end+Vector2i(4,1),1)

func _carnivorous() -> void:
	_leaf(Vector2i(20,42),Vector2i(4,33),4.8,_foliage)
	_leaf(Vector2i(20,42),Vector2i(35,34),4.8,_foliage)
	_pitcher(Vector2i(10,40),15,4,_pigment.darkened(0.08),-2)
	var hinge := Vector2i(25+_pose,22)
	_stem(Vector2i(20,42),hinge,3)
	var opening: int = 9 if activity < 0.3 else 6
	for side in [-1,1]:
		var tip := hinge+Vector2i(side*opening,-14)
		_leaf(hinge,tip,5.0,_pigment)
		_leaf(hinge+Vector2i(side,0),tip+Vector2i(-side*2,2),2.4,_accent.darkened(0.12))
		for j in range(4):
			var p := Vector2i(Vector2(hinge).lerp(Vector2(tip),float(j+1)/5.0))
			_line(p,p+Vector2i(-side*3,-2),_accent.lightened(0.15))
	_core(hinge,2)

func _core(center: Vector2i,radius: int) -> void:
	if silhouette: return
	var c: Color = _accent.lightened(minf(0.40,float(_core_level)*0.06))
	if _glow and _pose != -1: c = c.lightened(0.12)
	_rect(center.x-radius/2,center.y-radius/2,maxi(1,radius),maxi(1,radius),c)
	if _glow:
		_px(center.x-2,center.y,c.darkened(0.2))
		_px(center.x+2,center.y,c.darkened(0.2))

func _graft(color: Color,side: int) -> void:
	var join := Vector2i(20,32)
	var end := Vector2i(20+side*12,24)
	_stem(join,end)
	_rect(20+side*3,29,2,3,_accent.darkened(0.1))
	_leaf(end,end+Vector2i(side*5,-5),3,color)
	_leaf(end,end+Vector2i(side*5,5),3,color)

func _apply_form() -> Image:
	var form: String = str(_gene("form","Upright"))
	var growth: float = 1.0 if plant.get("mature",true) else 0.65
	var scale_x: float = growth
	var scale_y: float = growth
	if str(_gene("size","Standard")) == "Small": scale_x *= 0.86; scale_y *= 0.86
	if str(_gene("size","Standard")) == "Large": scale_x *= 1.06; scale_y *= 1.04
	match form:
		"Rosette": scale_x *= 1.05; scale_y *= 0.86
		"Trailing": scale_x *= 1.02; scale_y *= 0.88
		"Climbing": scale_x *= 0.88; scale_y *= 1.04
	if is_equal_approx(scale_x,1.0) and is_equal_approx(scale_y,1.0): return _image
	var result := Image.create(WIDTH,HEIGHT,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var source_x: int = roundi((x-40.0)/scale_x+40.0)
			var source_y: int = roundi((y-88.0)/scale_y+88.0)
			if source_x>=0 and source_x<WIDTH and source_y>=0 and source_y<HEIGHT: result.set_pixel(x,y,_image.get_pixel(source_x,source_y))
	return result
