extends RefCounted
## Deterministic ink-and-gouache scenery, rasterized once into the field's
## bounded HD chunks. Geometry and texture use world coordinates across seams.
var image: Image
var origin := Vector2.ZERO
var resolution: float = 6.0
const INK := Color("304943")

func canvas(target: Image,world_origin: Vector2,scale_factor: float) -> void:
	image=target; origin=world_origin; resolution=scale_factor

func rect(area: Rect2,color: Color) -> void:
	var pixels := Rect2i(Vector2i(((area.position-origin)*resolution).round()),Vector2i((area.size*resolution).ceil()))
	pixels=pixels.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	if pixels.has_area(): image.fill_rect(pixels,color)

func line(a: Vector2,b: Vector2,color: Color=INK,width: float=0.38) -> void:
	var first: Vector2=(a-origin)*resolution
	var last: Vector2=(b-origin)*resolution
	var thick: int=maxi(1,roundi(width*resolution))
	var edge := Vector2(image.get_size())+Vector2.ONE*thick
	if maxf(first.x,last.x)<-thick or minf(first.x,last.x)>edge.x or maxf(first.y,last.y)<-thick or minf(first.y,last.y)>edge.y:return
	# Clip long branches/veins at chunk gutters before walking raster pixels.
	# Neighbor chunks draw the same world line, preserving seamless contours.
	var delta: Vector2=last-first
	var begin: float=0.0
	var finish: float=1.0
	var denominators: Array[float]=[-delta.x,delta.x,-delta.y,delta.y]
	var numerators: Array[float]=[first.x+thick,edge.x-first.x,first.y+thick,edge.y-first.y]
	for i in range(4):
		var denominator: float=denominators[i]
		var numerator: float=numerators[i]
		if is_zero_approx(denominator):
			if numerator<0:return
		elif denominator<0:begin=maxf(begin,numerator/denominator)
		else:finish=minf(finish,numerator/denominator)
		if begin>finish:return
	last=first+delta*finish
	first+=delta*begin
	var start := Vector2i(first.round())
	var end := Vector2i(last.round())
	var dx: int=absi(end.x-start.x)
	var dy: int=-absi(end.y-start.y)
	var sx: int=1 if start.x<end.x else -1
	var sy: int=1 if start.y<end.y else -1
	var error: int=dx+dy
	var p: Vector2i=start
	var bounds := Rect2i(Vector2i.ZERO,image.get_size())
	while true:
		var pixel := Rect2i(p-Vector2i(thick/2,thick/2),Vector2i(thick,thick)).intersection(bounds)
		if pixel.has_area():image.fill_rect(pixel,color)
		if p==end:break
		var twice: int=error*2
		if twice>=dy:error+=dy;p.x+=sx
		if twice<=dx:error+=dx;p.y+=sy

func polygon(vertices: PackedVector2Array,fill: Color,stroke: Color=INK,width: float=0.38) -> void:
	if vertices.size()<3:return
	var points := PackedVector2Array()
	var top: float=INF
	var bottom: float=-INF
	for p in vertices:
		var q: Vector2=(p-origin)*resolution
		points.append(q);top=minf(top,q.y);bottom=maxf(bottom,q.y)
	for y in range(maxi(0,floori(top)),mini(image.get_height()-1,ceili(bottom))+1):
		var intersections: Array[float]=[]
		var scan: float=y+0.5
		for i in range(points.size()):
			var a: Vector2=points[i]
			var b: Vector2=points[(i+1)%points.size()]
			if (a.y<=scan and b.y>scan) or (b.y<=scan and a.y>scan): intersections.append(a.x+(scan-a.y)*(b.x-a.x)/(b.y-a.y))
		intersections.sort()
		for j in range(0,intersections.size()-1,2):
			var x: int=maxi(0,floori(intersections[j]))
			var end: int=mini(image.get_width(),ceili(intersections[j+1]))
			if end>x:image.fill_rect(Rect2i(x,y,end-x,1),fill)
	if stroke.a>0:
		for i in range(vertices.size()):line(vertices[i],vertices[(i+1)%vertices.size()],stroke,width)

func ellipse(center: Vector2,radius: Vector2,fill: Color,stroke: Color=INK) -> void:
	var points := PackedVector2Array()
	for i in range(28):
		var angle: float=TAU*i/28.0
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
	polygon(points,fill,stroke,0.38)

func leaf(root: Vector2,tip: Vector2,width: float,fill: Color,serrated: bool=false) -> void:
	var forward: Vector2=tip-root
	var side: Vector2=forward.orthogonal().normalized()
	var bend: float=forward.length()*0.095*(1 if tip.x>=root.x else -1)
	var outline := PackedVector2Array([root])
	for i in range(1,15):
		var t: float=i/15.0
		var edge: float=pow(sin(t*PI),0.8)*width*(0.85 if serrated and i%2==0 else 1.0)
		outline.append(root+forward*t+side*(sin(t*PI)*bend+edge))
	outline.append(tip)
	for i in range(14,0,-1):
		var t: float=i/15.0
		var edge: float=pow(sin(t*PI),0.8)*width*(0.85 if serrated and i%2==0 else 1.0)
		outline.append(root+forward*t+side*(sin(t*PI)*bend-edge))
	polygon(outline,fill,INK,0.33)
	var previous: Vector2=root
	for i in range(1,13):
		var t: float=i/12.0
		var middle: Vector2=root+forward*t+side*sin(t*PI)*bend
		line(previous,middle,INK,0.22)
		previous=middle
	for i in range(2,13,2):
		var t: float=i/15.0
		var middle: Vector2=root+forward*t+side*sin(t*PI)*bend
		for sign_value in [-1,1]:line(middle,middle+forward*0.10+side*sign_value*pow(sin(t*PI),0.8)*width*0.76,INK.lightened(0.08),0.17)

func rock(center: Vector2,scale_factor: float,base: Color,seed_value: int=0) -> void:
	var p: Vector2=center
	var s: float=scale_factor
	var shape := PackedVector2Array([p+Vector2(-12,2)*s,p+Vector2(-11,-7)*s,p+Vector2(-5,-15)*s,p+Vector2(5,-16)*s,p+Vector2(12,-8)*s,p+Vector2(13,2)*s,p+Vector2(6,6)*s,p+Vector2(-4,6)*s])
	polygon(shape,base)
	polygon(PackedVector2Array([p+Vector2(5,-16)*s,p+Vector2(12,-8)*s,p+Vector2(13,2)*s,p+Vector2(6,6)*s,p+Vector2(4,-4)*s]),base.darkened(0.27))
	line(p+Vector2(-11,-7)*s,p+Vector2(-2,-5)*s)
	line(p+Vector2(-2,-5)*s,p+Vector2(4,-4)*s)
	line(p+Vector2(-2,-5)*s,p+Vector2(-4,6)*s)
	line(p+Vector2(-2,-5)*s,p+Vector2(-5,-15)*s)
	line(p+Vector2(4,-4)*s,p+Vector2(8,-7)*s)
	for i in range(5):
		var point: Vector2=p+Vector2(-8+posmod(seed_value+i*7,17),-6+posmod(seed_value+i*3,10))*s
		line(point,point+Vector2(0.6,-0.25)*s,INK.lightened(0.2),0.14)

func foliage_cloud(center: Vector2,radius: Vector2,fill: Color,seed_value: int) -> void:
	var outline := PackedVector2Array()
	for i in range(38):
		var a: float=TAU*i/38.0
		var r: float=1.0+sin(i*2.17+seed_value%29)*0.10+cos(i*0.81+seed_value%17)*0.07
		outline.append(center+Vector2(cos(a)*radius.x,sin(a)*radius.y)*r)
	polygon(outline,fill,INK,0.35)
	for mark in range(8):
		var a: float=mark*2.399+seed_value%13
		var q: Vector2=center+Vector2(cos(a)*radius.x*0.67,sin(a)*radius.y*0.60)
		line(q,q+Vector2(0.8,-0.45),fill.darkened(0.30),0.17)
		if mark%2==0:line(q+Vector2(-0.35,0.4),q+Vector2(-0.5,-0.3),fill.darkened(0.24),0.17)

func pine(p: Vector2,seed_value: int) -> void:
	# Tall open trunks and asymmetric, wind-shaped crowns echo a real pine
	# canopy. Branch clusters have distinct centers and a broken pen contour.
	var high: float=42+seed_value%21
	var lean: float=-3.0+seed_value%7
	ellipse(p+Vector2(8,3),Vector2(17,3.7),Color("8aa17a"),Color.TRANSPARENT)
	var trunk := PackedVector2Array([p+Vector2(-1.7,3),p+Vector2(-1.2,-high*0.52),p+Vector2(lean-0.7,-high),p+Vector2(lean+0.5,-high),p+Vector2(1.0,-high*0.52),p+Vector2(1.7,3)])
	polygon(trunk,Color("b39a72"),INK,0.34)
	line(p+Vector2(-0.2,1),p+Vector2(lean,-high+4),Color("e0c59a"),0.4)
	for root_side in [-1,1]:line(p+Vector2(root_side,0),p+Vector2(root_side*5.5,3.0),Color("67735a"),0.55)
	var clusters: Array[Vector3]=[
		Vector3(lean-9,-high+7,10.4),Vector3(lean+7,-high+4,12.0),
		Vector3(lean-1,-high+0.5,11.3)]
	if seed_value%3!=0:clusters.append(Vector3(-9 if seed_value%2 else 10,-high*0.65,6.2))
	for i in range(clusters.size()):
		var cluster: Vector3=clusters[i]
		var q: Vector2=p+Vector2(cluster.x,cluster.y)
		var branch_root: Vector2=p+Vector2(lean*0.5,cluster.y+5.5)
		line(branch_root,q+Vector2(-1,2.5),Color("4b5945"),0.8)
		line(branch_root+Vector2(-0.2,0),q+Vector2(-1,2),Color("b49c73"),0.35)
	for i in range(clusters.size()):
		var cluster: Vector3=clusters[i]
		var q: Vector2=p+Vector2(cluster.x,cluster.y)
		var pigment: Color=Color("7f9d6a") if i%2 else Color("9cb578")
		if i==5:pigment=Color("72916b")
		foliage_cloud(q,Vector2(cluster.z,4.6+(i%3)*0.9),pigment,seed_value+i*13)
		if i<3:foliage_cloud(q+Vector2(-2,-1.4),Vector2(cluster.z*0.63,2.4),pigment.lightened(0.09),seed_value+i*19)
	for bark in range(13):
		var y: float=-6-bark*2.5
		var x: float=lean*(-y/high)+(-0.6 if bark%2 else 0.4)
		line(p+Vector2(x,y),p+Vector2(x+0.2,y-1.2),Color("5f6049"),0.20)

func giant_fern(p: Vector2,seed_value: int) -> void:
	var scale_factor: float=0.88+(seed_value%9)*0.045
	ellipse(p+Vector2(5,3),Vector2(19,4.5)*scale_factor,Color("769980"),Color.TRANSPARENT)
	var fronds: Array[Vector3]=[
		Vector3(-22,-24,5.0),Vector3(-15,-43,6.1),Vector3(-3,-55,7.7),
		Vector3(11,-45,6.7),Vector3(23,-29,5.1),Vector3(7,-24,6.1)]
	for i in range(fronds.size()):
		var f: Vector3=fronds[i]
		var tip: Vector2=p+Vector2(f.x*(1+sin(seed_value%17+i)*0.12),f.y*(0.92+seed_value%13*0.015))*scale_factor
		var blade_root: Vector2=p+(tip-p)*0.18
		line(p,blade_root,Color("445f4c"),0.65)
		leaf(blade_root,tip,f.z*scale_factor,Color("8eae81") if i%2 else Color("b1c78e"),true)
		if i%2==0:
			var q: Vector2=blade_root.lerp(tip,0.62)
			ellipse(q+Vector2(1.0,-0.6),Vector2(0.5,0.75),Color("d4d3a3"),Color.TRANSPARENT)
	for index in range(2):
		var q: Vector2=p+Vector2(10+index*5,-4+index)
		line(q+Vector2(0,6),q+Vector2(0,-10),Color("647058"),0.45)
		ellipse(q+Vector2(0,-10),Vector2(2.7,3.0),Color("bd8e8a"))
		line(q+Vector2(0,-12),q+Vector2(0,-10),Color("896d66"),0.20)

func fungus(p: Vector2,seed_value: int,moon: bool=false) -> void:
	ellipse(p+Vector2(4,2),Vector2(13,3),Color("689d9e") if moon else Color("7c9d87"),Color.TRANSPARENT)
	for index in range(3):
		var q: Vector2=p+Vector2(-9+index*8,-index%2*6)
		var high: float=13+posmod(seed_value+index*17,15)
		var width: float=7+index%2*3
		polygon(PackedVector2Array([q+Vector2(-1,2),q+Vector2(-1.5,-high+2),q+Vector2(1.5,-high+2),q+Vector2(1,2)]),Color("d0d8b9"))
		var cap := PackedVector2Array([q+Vector2(-width,-high+1),q+Vector2(-width+1,-high-4),q+Vector2(-width*0.4,-high-8),q+Vector2(width*0.3,-high-8.5),q+Vector2(width-1,-high-4),q+Vector2(width,-high+1),q+Vector2(width*0.45,-high+3),q+Vector2(-width*0.45,-high+3)])
		polygon(cap,Color("b1d3c7") if moon else Color("c69295"))
		for gill in range(-3,4):line(q+Vector2(gill*width/4.0,-high+0.5),q+Vector2(gill*width/7.0,-high+2.2),Color("776c75"),0.17)
		for spot in range(3):ellipse(q+Vector2(-3+spot*3,-high-4+spot%2),Vector2(0.7,0.5),Color("e4d8bf"),Color.TRANSPARENT)

func cliff(p: Vector2,seed_value: int,red: bool=false) -> void:
	var wide: float=0.88+(seed_value%7)*0.055
	var high: float=29+seed_value%17
	var base := Color("b57c68") if red else Color("c0ac80")
	var offsets: Array[Vector2]=[Vector2(-18,3),Vector2(-17,-high+9),Vector2(-11,-high+3),Vector2(-4,-high),Vector2(7,-high+2),Vector2(18,-high+8),Vector2(20,0),Vector2(11,7),Vector2(-3,8)]
	var rock_points := PackedVector2Array()
	for q in offsets:rock_points.append(p+Vector2(q.x*wide,q.y))
	ellipse(p+Vector2(6,4),Vector2(22*wide,4),Color("a47f67") if red else Color("a4a17b"),Color.TRANSPARENT)
	polygon(rock_points,base,INK,0.38)
	polygon(PackedVector2Array([p+Vector2(7*wide,-high+2),p+Vector2(18*wide,-high+8),p+Vector2(20*wide,0),p+Vector2(11*wide,7),p+Vector2(8*wide,-13)]),base.darkened(0.26),INK,0.35)
	var top := PackedVector2Array([p+Vector2(-17*wide,-high+9),p+Vector2(-11*wide,-high+3),p+Vector2(-4*wide,-high),p+Vector2(7*wide,-high+2),p+Vector2(18*wide,-high+8),p+Vector2(7*wide,-high+12),p+Vector2(-7*wide,-high+10)])
	polygon(top,Color("d6ac7d") if red else Color("d3c292"),INK,0.32)
	for row in range(8):
		var yy: float=-high+13+row*(high-8)/8.0
		var last: Vector2=p+Vector2(-16*wide,yy+0.2)
		for segment in range(1,7):
			var x: float=(-16+segment*4.1)*wide
			var next: Vector2=p+Vector2(x,yy+sin(segment*1.1+row*0.71+seed_value%7)*0.65)
			line(last,next,Color("765a50") if red else Color("81765c"),0.17)
			last=next
		line(last,last+Vector2(9*wide,-3.0),Color("69594e") if red else Color("6f7159"),0.18)
	line(p+Vector2(-3*wide,-high+10),p+Vector2(-1*wide,-15),INK,0.22)
	line(p+Vector2(-1*wide,-15),p+Vector2(-5*wide,7),INK,0.22)
	line(p+Vector2(-1*wide,-15),p+Vector2(-8*wide,-10),INK,0.20)
	for tuft in range(4):
		var q: Vector2=p+Vector2((-12+tuft*7)*wide,-high+6+sin(tuft*2)*2.2)
		for blade in range(6):line(q,q+Vector2((blade-2.5)*0.6,-2.4-absf(blade-2.5)*0.35),Color("e9c47d") if red else Color("a4b279"),0.38)
	rock(p+Vector2(-14*wide,7),0.24,base.lightened(0.08),seed_value)
	rock(p+Vector2(14*wide,6),0.22,base,seed_value+17)
	if red and seed_value%3==0:
		leaf(p+Vector2(-9*wide,-high+7),p+Vector2(-10*wide,-high-12),1.7,Color("92b99a"))

func ruins(p: Vector2,seed_value: int) -> void:
	rock(p+Vector2(0,1),1.05,Color("b9c7b8"),seed_value)
	polygon(PackedVector2Array([p+Vector2(-10,-10),p+Vector2(-10,-29),p+Vector2(-1,-33),p+Vector2(9,-29),p+Vector2(9,-11),p+Vector2(0,-7)]),Color("dbe1c8"))
	polygon(PackedVector2Array([p+Vector2(0,-29),p+Vector2(9,-29),p+Vector2(9,-11),p+Vector2(0,-7)]),Color("8faeaa"))
	for row in range(4):
		line(p+Vector2(-10,-25+row*4),p+Vector2(0,-21+row*4),Color("6b8880"),0.18)
		line(p+Vector2(0,-21+row*4),p+Vector2(9,-25+row*4),Color("5b7b78"),0.18)
		var xx: float=-7+row%2*4
		line(p+Vector2(xx,-24+row*4),p+Vector2(xx,-20+row*4),Color("6b8880"),0.18)
	for i in range(3):leaf(p+Vector2(-8+i*6,-28),p+Vector2(-12+i*9,-36-i%2*4),2.1,Color("9caf7d"))

func shelter(p: Vector2,biome: String,large: bool=false) -> void:
	var s: float=1.45 if large else 0.78
	var roof := Color("a4b9aa")
	if biome=="Amber Hollow":roof=Color("ba8f6f")
	elif biome=="Ember Ridge":roof=Color("c5846c")
	elif biome=="Moonfen":roof=Color("9caeb6")
	var shape: Array[Vector2]=[Vector2(-25,-7),Vector2(9,-13),Vector2(26,-4),Vector2(26,13),Vector2(-7,20),Vector2(-25,10)]
	var walls := PackedVector2Array()
	for vertex in shape:walls.append(p+vertex*s)
	polygon(walls,Color("e6e2c8"))
	polygon(PackedVector2Array([p+Vector2(-7,0)*s,p+Vector2(26,-4)*s,p+Vector2(26,13)*s,p+Vector2(-7,20)*s]),Color("c4d1bf"))
	var roof_points := PackedVector2Array([p+Vector2(-28,-13)*s,p+Vector2(8,-20)*s,p+Vector2(29,-8)*s,p+Vector2(-7,0)*s])
	polygon(roof_points,roof)
	for seam in range(6):
		var a: Vector2=p+Vector2(-23+seam*5.9,-14-seam*1.15)*s
		line(a,a+Vector2(21,12)*s,Color("566e67"),0.30)
	if large:
		line(p+Vector2(-17,-13)*s,p+Vector2(19,-20)*s,Color("e9edd7"),0.55)
		line(p+Vector2(-7,-6)*s,p+Vector2(29,-13)*s,Color("e9edd7"),0.55)
	for pane in range(4):
		var q: Vector2=p+Vector2(-3+pane*6,4-pane*1.4)*s
		polygon(PackedVector2Array([q,q+Vector2(4.5,-1)*s,q+Vector2(4.5,6)*s,q+Vector2(0,7)*s]),Color("8dafa5"))
		line(q+Vector2(0.8,1)*s,q+Vector2(2.7,3.5)*s,Color("dce6ca"),0.3)
	polygon(PackedVector2Array([p+Vector2(-19,-3)*s,p+Vector2(-11,1)*s,p+Vector2(-11,16)*s,p+Vector2(-19,12)*s]),Color("8b9f88"))
	line(p+Vector2(-17,4)*s,p+Vector2(-17,11)*s,Color("d2d5af"),0.4)
	for row in range(3):
		var q: Vector2=p+Vector2(-24,17+row*1.8)*s
		line(q,q+Vector2(18,8)*s,Color("8a8c73"),0.4)
	for pot in range(2):
		var q: Vector2=p+Vector2(21+pot*6,16-pot*2)*s
		ellipse(q,Vector2(2.7,1.5)*s,Color("b68f69"))
		leaf(q,q+Vector2(-1,-6)*s,1.6*s,Color("96b381"))

func scenery(biome: String,p: Vector2,seed_value: int) -> void:
	match biome:
		"Mosswood":
			if seed_value%3==0:giant_fern(p,seed_value)
			else:pine(p,seed_value)
		"Amber Hollow":cliff(p,seed_value)
		"Ember Ridge":cliff(p,seed_value,true)
		"Glassfall Coast":
			rock(p,1.25,Color("d6d9bc"),seed_value)
			if seed_value%2==0:leaf(p+Vector2(-9,-5),p+Vector2(-12,-22),2.1,Color("a6b995"))
		"Sporefen":fungus(p,seed_value)
		"Moonfen":fungus(p,seed_value,true)
		"Sunken Glade":ruins(p,seed_value)
		"Ancient Grove":
			giant_fern(p,seed_value)
			if seed_value%3==0:fungus(p+Vector2(7,4),seed_value)

func patch(p: Vector2,terrain: String) -> void:
	# Ground-level cues never hide the collectable organism or change collision.
	if terrain in ["tide_pool","stone_cistern","spore_marsh"]:
		ellipse(p+Vector2(0,1),Vector2(13,5),Color("aac9b5"),Color("748f83"))
		ellipse(p+Vector2(0,1),Vector2(11.3,3.3),Color("6ea8a5"),Color.TRANSPARENT)
		for i in range(3):line(p+Vector2(-8+i*7,1+i%2),p+Vector2(-4+i*7,1+i%2),Color("d3e6cc"),0.18)
	elif terrain in ["cliff_ledge","root_fissure"]:
		polygon(PackedVector2Array([p+Vector2(-13,1),p+Vector2(-9,-4),p+Vector2(10,-3),p+Vector2(14,2),p+Vector2(8,5),p+Vector2(-8,5)]),Color("d8ba8c"))
		line(p+Vector2(-10,2),p+Vector2(11,1),Color("8d7c60"),0.18)
	elif terrain in ["root_bank","giant_roots","host_trunks"]:
		for side in [-1,1]:
			line(p+Vector2(side*11,-2),p+Vector2(side*8,3),Color("b09b75"),1.5)
			line(p+Vector2(side*11,-2),p+Vector2(side*8,3),INK,0.20)
	else:
		ellipse(p+Vector2(0,1),Vector2(12,4.2),Color("c6ce9d"),Color("8b9d77"))
		for i in range(4):line(p+Vector2(-10+i*6,2),p+Vector2(-9+i*6,0),Color("708a5f"),0.20)
