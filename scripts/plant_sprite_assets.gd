extends RefCounted
class_name PlantSpriteAssets
## Shared, tightly framed botanical originals. Raw PNG loading keeps first-run
## previews working before the editor has imported project assets.
const PATHS := {
	"Leaf":"res://assets/plants/leaf.png", "Bloom":"res://assets/plants/bloom.png",
	"Vine":"res://assets/plants/vine.png", "Root":"res://assets/plants/root.png",
	"Spore":"res://assets/plants/spore.png", "Toxin":"res://assets/plants/toxin.png",
	"Parasite":"res://assets/plants/parasite.png", "Carnivorous":"res://assets/plants/carnivorous.png"
}
static var _images: Dictionary = {}
static var _textures: Dictionary = {}
static var _frame_offsets: Dictionary = {}
static var _flower_images: Dictionary = {}
static var _flower_textures: Dictionary = {}
static var _flower_heads: Dictionary = {}
const COMPOSITE_SIZE := Vector2i(480,576)
const MAX_COMPOSITES: int = 64
const TYPE_ORDER := ["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"]
# Each region is an organ, with the parent plant's root system excluded. The
# small clipped join is concealed where its new stem enters the host canopy.
const ORGAN_REGIONS := {
	"Leaf":Rect2(0.04,0.34,0.69,0.42),
	"Bloom":Rect2(0.27,0.015,0.55,0.315),
	"Vine":Rect2(0.03,0.015,0.91,0.75),
	"Root":Rect2(0.20,0.37,0.68,0.61),
	"Spore":Rect2(0.01,0.015,0.98,0.40),
	"Toxin":Rect2(0.55,0.31,0.41,0.58),
	"Parasite":Rect2(0.025,0.23,0.56,0.36),
	"Carnivorous":Rect2(0.34,0.015,0.64,0.34)
}
static var _composites: Dictionary = {}

static func composition_for(specimen: Dictionary) -> Array[Dictionary]:
	var host: String = str(specimen.get("type","Leaf"))
	var result: Array[Dictionary] = []
	var mix: Dictionary = specimen.get("lineage_mix",{})
	# Secondary types also support plants saved before ancestry proportions were
	# introduced. Full old-pedigree reconstruction belongs to the model loader.
	if mix.is_empty() and not str(specimen.get("secondary_type","")).is_empty():
		mix = {host:0.5,str(specimen.secondary_type):0.5}
	var candidates: Array[String] = []
	for key: Variant in mix:
		if str(key)!=host and PATHS.has(str(key)) and float(mix[key])>=0.065: candidates.append(str(key))
	candidates.sort_custom(func(a: String,b: String):
		if not is_equal_approx(float(mix[a]),float(mix[b])): return float(mix[a])>float(mix[b])
		return TYPE_ORDER.find(a)<TYPE_ORDER.find(b))
	for i in range(mini(2,candidates.size())):
		result.append({"type":candidates[i],"weight":float(mix[candidates[i]]),"graft":false,"petals":_petals(specimen.get("genes",{}))})
	var records: Array = specimen.get("graft_history",[]).duplicate()
	records.append_array(specimen.get("inherited_graft_records",[]))
	var seen: Dictionary = {}
	var grafts: int = 0
	for record: Variant in records:
		if not record is Dictionary or not bool(record.get("success",true)): continue
		var donor_type: String = str(record.get("donor_type",""))
		if not PATHS.has(donor_type): continue
		var identity: String = "%s/%s/%s" % [record.get("donor",""),donor_type,record.get("donor_color","")]
		if seen.has(identity): continue
		seen[identity] = true
		var color: String = str(record.get("donor_color",record.get("color","c4d2a1")))
		result.append({"type":donor_type,"weight":0.42,"graft":true,"color":color,"petals":_petals(record.get("donor_genes",specimen.get("genes",{})))})
		grafts += 1
		if grafts>=2: break
	# At most three lateral organs leave a readable host crown and one rootstock.
	while result.size()>3: result.remove_at(1 if not bool(result[1].get("graft",false)) else 0)
	return result

static func texture_for_plant(specimen: Dictionary) -> Texture2D:
	var organs: Array[Dictionary] = composition_for(specimen)
	var host: String = str(specimen.get("type","Leaf"))
	if image_for(host)==null: return null
	var petals: int = _petals(specimen.get("genes",{}))
	if organs.is_empty(): return _flower_texture(petals) if host=="Bloom" else texture_for(host)
	var key: String = JSON.stringify([host,petals if host=="Bloom" else 0,posmod(int(specimen.get("seed",1)),17),organs])
	if _composites.has(key):
		var reused: Texture2D = _composites[key]
		_composites.erase(key)
		_composites[key] = reused
		return reused
	var image: Image = _compose(host,organs,int(specimen.get("seed",1)),petals)
	if image==null: return texture_for(host)
	image.fix_alpha_edges()
	image.generate_mipmaps()
	var result := ImageTexture.create_from_image(image)
	while _composites.size()>=MAX_COMPOSITES: _composites.erase(_composites.keys()[0])
	_composites[key] = result
	return result

static func _compose(host: String,organs: Array[Dictionary],seed_value: int,petals: int) -> Image:
	var original: Image = _flower_image(petals) if host=="Bloom" else image_for(host)
	if original==null: return null
	var image := Image.create(COMPOSITE_SIZE.x,COMPOSITE_SIZE.y,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var front_parts: Array[Dictionary] = []
	var phase: float = float(posmod(seed_value,17)-8)
	# New stems grow from the same root crown. The host is drawn over the joins,
	# so secondary organs never look like a second whole plant on the same card.
	for i in range(organs.size()):
		var organ: Dictionary = organs[i]
		var organ_type: String = str(organ.type)
		var source: Image = image_for(organ_type)
		if source==null: continue
		var region: Rect2 = ORGAN_REGIONS[organ_type]
		var bounds := Rect2i(Vector2i((region.position*Vector2(source.get_size())).floor()),Vector2i((region.size*Vector2(source.get_size())).ceil()))
		bounds = bounds.intersection(Rect2i(Vector2i.ZERO,source.get_size()))
		var fragment: Image = _flower_head(int(organ.get("petals",5))).duplicate() if organ_type=="Bloom" else source.get_region(bounds)
		if organ_type!="Bloom": _isolate_organ(fragment,organ_type)
		if bool(organ.get("graft",false)): _tint_organ(fragment,Color.from_string(str(organ.get("color","c4d2a1")),Color("c4d2a1")))
		var side: float = 1.0 if i%2==0 else -1.0
		var ancestry_scale: float = clampf(0.77+float(organ.weight)*0.46,0.80,1.04)
		if i==2: ancestry_scale *= 0.73
		var extent: Vector2
		var center: Vector2
		var join: Vector2
		var pale: bool = organ_type in ["Spore","Parasite","Root"]
		match organ_type:
			"Leaf":
				extent = Vector2(215,155)*ancestry_scale
				center = Vector2(240+side*128,355+i*10)
				join = center+Vector2(-side*45,36)
			"Bloom":
				extent = Vector2(185,153)*ancestry_scale
				center = Vector2(240+side*104,113+i*43)
				join = center+Vector2(0,extent.y*0.35)
			"Vine":
				extent = Vector2(155,286)*ancestry_scale
				center = Vector2(240+side*143,274+i*5)
				join = center+Vector2(-side*15,extent.y*0.45)
			"Root":
				extent = Vector2(155,190)*ancestry_scale
				center = Vector2(240+side*23,460)
				join = Vector2(240,414)
			"Spore":
				extent = Vector2(222,139)*ancestry_scale
				center = Vector2(240+side*111,151+i*51)
				join = center+Vector2(0,extent.y*0.35)
			"Toxin":
				extent = Vector2(120,221)*ancestry_scale
				center = Vector2(240+side*136,251+i*23)
				join = center+Vector2(-side*9,-extent.y*0.42)
			"Parasite":
				extent = Vector2(179,160)*ancestry_scale
				center = Vector2(240+side*127,204+i*38)
				join = center+Vector2(0,extent.y*0.24)
			_:
				extent = Vector2(205,154)*ancestry_scale
				center = Vector2(240+side*116,132+i*48)
				join = center+Vector2(-side*18,extent.y*0.35)
		center.x += phase*0.5
		join.x += phase*0.5
		if i==2:
			center.y += 54
			join.y += 54
		var stem_color := Color("698e51") if not pale else Color("adbc8d")
		if bool(organ.get("graft",false)): stem_color = stem_color.lerp(Color.from_string(str(organ.color),stem_color),0.30)
		_branch(image,Vector2(240,438),join,stem_color,8.0 if organ_type=="Spore" else 5.0,side)
		fragment.resize(maxi(1,roundi(extent.x)),maxi(1,roundi(extent.y)),Image.INTERPOLATE_LANCZOS)
		var position := Vector2i((center-extent*0.5).round())
		var part: Dictionary = {"image":fragment,"position":position}
		if organ_type=="Root": front_parts.append(part)
		else: image.blend_rect(fragment,Rect2i(Vector2i.ZERO,fragment.get_size()),position)
	var host_image: Image = original.duplicate()
	var host_scale: float = minf(336.0/host_image.get_width(),470.0/host_image.get_height())
	var host_size := Vector2i(Vector2(host_image.get_size())*host_scale)
	host_image.resize(host_size.x,host_size.y,Image.INTERPOLATE_LANCZOS)
	image.blend_rect(host_image,Rect2i(Vector2i.ZERO,host_size),Vector2i((COMPOSITE_SIZE.x-host_size.x)/2,556-host_size.y))
	for part: Dictionary in front_parts:
		var fragment: Image = part.image
		image.blend_rect(fragment,Rect2i(Vector2i.ZERO,fragment.get_size()),part.position)
	return image

static func _petals(genes: Dictionary) -> int:
	var value: Variant = genes.get("petals",5)
	if value is Dictionary: value = value.get("dominant",5)
	return clampi(int(value),3,12)

static func _flower_texture(petals: int) -> Texture2D:
	if petals==5: return texture_for("Bloom")
	if _flower_textures.has(petals): return _flower_textures[petals]
	var image: Image = _flower_image(petals).duplicate()
	image.fix_alpha_edges()
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_flower_textures[petals] = texture
	return texture

static func _flower_image(petals: int) -> Image:
	if petals==5: return image_for("Bloom")
	if _flower_images.has(petals): return _flower_images[petals]
	var image: Image = image_for("Bloom").duplicate()
	var offset: Vector2i = _frame_offsets.get("Bloom",Vector2i.ZERO)
	# The authored blossoms occupy these exact source-frame bounds. Replace only
	# their petals, leaving the three stems, buds and basal foliage untouched.
	var flowers := [Rect2i(111,20,186,146),Rect2i(22,129,133,151),Rect2i(225,205,140,130)]
	for bounds: Rect2i in flowers:
		bounds.position += offset
		var center: Vector2 = Vector2(bounds.get_center())
		var radius: Vector2 = Vector2(bounds.size)*0.53
		for y in range(maxi(0,bounds.position.y-4),mini(image.get_height(),bounds.end.y+4)):
			for x in range(maxi(0,bounds.position.x-4),mini(image.get_width(),bounds.end.x+4)):
				var color: Color = image.get_pixel(x,y)
				var distance: float = ((Vector2(x,y)-center)/radius).length()
				color.a *= smoothstep(0.87,1.02,distance)
				image.set_pixel(x,y,color)
		var head: Image = _flower_head(petals).duplicate()
		head.resize(bounds.size.x,bounds.size.y,Image.INTERPOLATE_LANCZOS)
		image.blend_rect(head,Rect2i(Vector2i.ZERO,head.get_size()),bounds.position)
	image.fix_alpha_edges()
	_flower_images[petals] = image
	return image

static func _flower_head(petals: int) -> Image:
	if _flower_heads.has(petals): return _flower_heads[petals]
	var source: Image = image_for("Bloom")
	var region: Rect2 = ORGAN_REGIONS.Bloom
	var bounds := Rect2i(Vector2i((region.position*Vector2(source.get_size())).floor()),Vector2i((region.size*Vector2(source.get_size())).ceil()))
	bounds = bounds.intersection(Rect2i(Vector2i.ZERO,source.get_size()))
	var original: Image = source.get_region(bounds)
	_isolate_organ(original,"Bloom")
	if petals==5:
		_flower_heads[petals] = original
		return original
	var result := Image.create(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	# Repeat an authored petal sector around the original stamen core. This is
	# actual N-petal anatomy, retaining its painted veins and stepped silhouette.
	var center := Vector2(original.get_width()*0.49,original.get_height()*0.49)
	var radius := Vector2(original.get_width()*0.50,original.get_height()*0.50)
	var sector: float = TAU/float(petals)
	for y in result.get_height():
		for x in result.get_width():
			var delta: Vector2 = (Vector2(x,y)-center)/radius
			var length: float = delta.length()
			var angle: float = atan2(delta.y,delta.x)+PI*0.5
			var within: float = wrapf(angle+sector*0.5,0.0,sector)-sector*0.5
			# The chosen authored petal points upper-left, rather than exactly up.
			# Align to its center so each sector contributes one complete petal.
			var source_angle: float = within*float(petals)/5.0-2.02
			var point: Vector2 = center+Vector2(cos(source_angle),sin(source_angle))*radius*length
			var sampled := Color.TRANSPARENT
			if point.x>=0 and point.y>=0 and point.x<original.get_width() and point.y<original.get_height(): sampled = original.get_pixel(roundi(point.x),roundi(point.y)) if roundi(point.x)<original.get_width() and roundi(point.y)<original.get_height() else Color.TRANSPARENT
			var core: Color = original.get_pixel(x,y)
			var blend: float = smoothstep(0.22,0.37,length)
			result.set_pixel(x,y,core.lerp(sampled,blend))
	result.fix_alpha_edges()
	_flower_heads[petals] = result
	return result

static func _isolate_organ(image: Image,organ_type: String) -> void:
	# A botanical organ is not a rectangular photograph. Remove neighboring
	# tissue where the atlas region intersects it, and feather only that cut join.
	# Original transparent outlines, fine cilia, veins and root hairs are retained.
	var feature_mask := PackedByteArray()
	var feature_only: bool = organ_type in ["Bloom","Parasite","Root"]
	var width: int = image.get_width()
	var height: int = image.get_height()
	if feature_only:
		feature_mask.resize(width*height)
		for y in height:
			for x in width:
				var color: Color = image.get_pixel(x,y)
				var warm: bool = color.r>color.g*0.96 or color.r+color.b>color.g*1.93
				if warm and color.a>0.1: feature_mask[y*width+x] = 1
	for y in height:
		for x in width:
			var color: Color = image.get_pixel(x,y)
			if color.a<=0: continue
			var uv := Vector2(float(x)/maxi(1,width-1),float(y)/maxi(1,height-1))
			var alpha: float = 1.0
			if organ_type=="Vine":
				alpha = smoothstep(0.0,0.04,uv.x)*smoothstep(0.0,0.04,1.0-uv.x)*(1.0-smoothstep(0.88,1.0,uv.y))
			elif organ_type=="Root":
				alpha = smoothstep(0.0,0.07,uv.y)
			elif organ_type=="Toxin":
				var half: float = 0.35 if uv.y<0.37 else (0.33-smoothstep(0.65,1.0,uv.y)*0.08)
				alpha = (1.0-smoothstep(half-0.035,half,absf(uv.x-0.53)))*smoothstep(0.0,0.06,uv.y)*(1.0-smoothstep(0.96,1.0,uv.y))
			else:
				var radius := Vector2(0.55,0.56)
				if organ_type=="Spore": radius = Vector2(0.57,0.58)
				if organ_type=="Parasite": radius = Vector2(0.56,0.61)
				if organ_type=="Carnivorous": radius = Vector2(0.59,0.58)
				var distance: float = ((uv-Vector2(0.5,0.5))/radius).length()
				alpha = 1.0-smoothstep(0.92,1.0,distance)
			if feature_only:
				var accepted: bool = feature_mask[y*width+x]>0
				if not accepted:
					for oy in range(maxi(0,y-2),mini(height,y+3)):
						for ox in range(maxi(0,x-2),mini(width,x+3)):
							if feature_mask[oy*width+ox]>0: accepted = true; break
						if accepted: break
				if not accepted: alpha = 0.0
			color.a *= alpha
			image.set_pixel(x,y,color)

static func _tint_organ(image: Image,target: Color) -> void:
	var light_target: float = maxf(0.18,target.r*0.24+target.g*0.59+target.b*0.17)
	for y in image.get_height():
		for x in image.get_width():
			var source: Color = image.get_pixel(x,y)
			if source.a<0.05: continue
			var light: float = source.r*0.24+source.g*0.59+source.b*0.17
			var mapped := Color(target.r/light_target*light,target.g/light_target*light,target.b/light_target*light,source.a)
			var strength: float = 0.75*smoothstep(0.12,0.30,light)*(1.0-smoothstep(0.76,0.97,light)*0.65)
			var result: Color = source.lerp(mapped,strength).clamp()
			result.a = source.a
			image.set_pixel(x,y,result)

static func _branch(image: Image,start: Vector2,finish: Vector2,color: Color,width: float,side: float) -> void:
	var previous: Vector2 = start
	for i in range(1,51):
		var t: float = float(i)/50.0
		var point: Vector2 = start.lerp(finish,t)+Vector2(side*sin(t*PI)*18,0)
		_line(image,previous,point,Color("203b2c"),width+3)
		_line(image,previous,point,color,width)
		_line(image,previous+Vector2(-1,0),point+Vector2(-1,0),color.lightened(0.20),1.5)
		previous = point

static func _line(image: Image,start: Vector2,finish: Vector2,color: Color,width: float) -> void:
	var count: int = maxi(1,ceili(start.distance_to(finish)))
	var size: int = maxi(1,roundi(width))
	for i in range(count+1):
		var point: Vector2 = start.lerp(finish,float(i)/count)
		var bounds := Rect2i(Vector2i(point)-Vector2i(size/2,size/2),Vector2i(size,size)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		if bounds.has_area(): image.fill_rect(bounds,color)

static func image_for(plant_type: String) -> Image:
	plant_type = plant_type if PATHS.has(plant_type) else "Leaf"
	if _images.has(plant_type): return _images[plant_type]
	var path: String = str(PATHS.get(plant_type,PATHS.Leaf))
	var source: Image
	if FileAccess.file_exists(path):
		source = Image.new()
		if source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return null
	elif ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D
		if imported != null: source = imported.get_image()
	if source == null or source.is_empty(): return null
	if source.is_compressed() and source.decompress()!=OK: return null
	if source.has_mipmaps(): source.clear_mipmaps()
	if source.get_format() != Image.FORMAT_RGBA8: source.convert(Image.FORMAT_RGBA8)
	# Ignore nearly transparent edge dust when establishing the specimen bounds.
	var pixels: PackedByteArray = source.get_data()
	var left: int = source.get_width()
	var right: int = -1
	var top: int = source.get_height()
	var bottom: int = -1
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if pixels[(y*source.get_width()+x)*4+3] < 16: continue
			left = mini(left,x)
			right = maxi(right,x)
			top = mini(top,y)
			bottom = maxi(bottom,y)
	if right < left or bottom < top: return null
	# Generators may leave one-bit alpha dust in empty cells. Remove only that
	# invisible matte, retaining antialiased tissue edges and fine root hairs.
	for i in range(3,pixels.size(),4):
		if pixels[i]<12: pixels[i] = 0
	source = Image.create_from_data(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8,pixels)
	var bounds := Rect2i(left,top,right-left+1,bottom-top+1)
	# A tiny alpha gutter lets shader-driven frond motion stay inside the texture.
	var gutter: int = maxi(4,roundi(maxi(bounds.size.x,bounds.size.y)*0.018))
	var framed := Image.create(bounds.size.x+gutter*2,bounds.size.y+gutter*2,false,Image.FORMAT_RGBA8)
	framed.fill(Color.TRANSPARENT)
	framed.blit_rect(source,bounds,Vector2i(gutter,gutter))
	framed.fix_alpha_edges()
	_frame_offsets[plant_type] = Vector2i(gutter-left,gutter-top)
	_images[plant_type] = framed
	return framed

static func texture_for(plant_type: String) -> Texture2D:
	plant_type = plant_type if PATHS.has(plant_type) else "Leaf"
	if _textures.has(plant_type): return _textures[plant_type]
	var source: Image = image_for(plant_type)
	if source == null: return null
	var mipmapped: Image = source.duplicate()
	mipmapped.generate_mipmaps()
	var texture := ImageTexture.create_from_image(mipmapped)
	_textures[plant_type] = texture
	return texture

static func clear_cache() -> void:
	_images.clear()
	_textures.clear()
	_composites.clear()
	_frame_offsets.clear()
	_flower_images.clear()
	_flower_textures.clear()
	_flower_heads.clear()
