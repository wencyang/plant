extends Control
class_name PlantPortrait
## Authored botanical pixel sprites with gene-driven tissue pigments and patterns.
## High-resolution originals are shared; per-specimen shader parameters preserve
## painted anatomy and lighting without rasterizing textures on each idle frame.
## The deterministic procedural renderer remains a fallback for missing assets.
const SpriteAssets = preload("res://scripts/plant_sprite_assets.gd")
const Care = preload("res://scripts/plant_care.gd")
const SCALE: int = 8
const WIDTH: int = 40 * SCALE
const HEIGHT: int = 48 * SCALE
const MAX_TEXTURES: int = 128
const INK := Color("193632")
static var _texture_cache: Dictionary = {}
var _visual_signature: int = 0
var plant: Dictionary = {}:
	set(value):
		plant = value
		_visual_signature = hash(JSON.stringify([plant.get("seed",1),plant.get("species",""),plant.get("type","Leaf"),plant.get("secondary_type",""),plant.get("lineage_mix",{}),plant.get("genes",{}),plant.get("graft_history",[]),plant.get("inherited_graft_records",[]),plant.get("inherited_graft_color",""),plant.get("deformed",false),plant.get("mutation_history",[]),plant.get("mature",true)]))
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
var _art_material: ShaderMaterial
var _material_signature: int = 0
var _authored_sprite: Texture2D
var _authored_signature: int = 0
static var _art_shader: Shader

static func authored_texture(plant_type: String) -> Texture2D:
	return SpriteAssets.texture_for(plant_type)

static func authored_image(plant_type: String) -> Image:
	return SpriteAssets.image_for(plant_type)

static func hybrid_texture(specimen: Dictionary) -> Texture2D:
	return SpriteAssets.texture_for_plant(specimen)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true
	set_process(animate)

func _process(delta: float) -> void:
	_time += delta
	activity = move_toward(activity,0.0,delta*0.55)
	# Reuse the detailed anatomy during gentle breathing; idle motion never
	# rebuilds a large sprite or hops between coarse rasterized silhouettes.
	var new_frame: int = int(_time*24.0)
	if animate and new_frame != _frame:
		_frame = new_frame
		queue_redraw()

func _gene(slot: String, fallback: Variant) -> Variant:
	var data: Variant = plant.get("genes",{}).get(slot,fallback)
	return data.get("dominant",fallback) if data is Dictionary else data

func _draw() -> void:
	if plant.is_empty() or size.x < 1 or size.y < 1: return
	# Long seed collections can have hundreds of packets in a scroller. Load a
	# mixed texture only as its card reaches the viewport, and keep it for idle
	# redraws so the bounded shared LRU never churns once a frame.
	if is_inside_tree() and not get_global_rect().intersects(get_viewport_rect()):
		# Evicted mixed sprites must not be held forever by offscreen tray cards.
		_authored_sprite = null
		_authored_signature = 0
		return
	if _authored_sprite==null or _authored_signature!=_visual_signature:
		_authored_sprite = hybrid_texture(plant)
		_authored_signature = _visual_signature
	var original: Texture2D = _authored_sprite
	if original != null:
		_draw_authored(original)
		return
	material = null
	var charge: int = int(energy/34.0)+int(activity*3.0)
	var key: String = "ultra8:%d:%s:%s:%d:%d:%s" % [_visual_signature,alive,silhouette,charge,roundi(_senescence()*4.0),_naturally_withered()]
	var texture: Texture2D
	if _texture_cache.has(key):
		texture = _texture_cache[key]
		# Updating insertion order gives shared garden/detail portraits one LRU.
		_texture_cache.erase(key)
		_texture_cache[key] = texture
	else:
		_core_level = charge
		var sprite: Image = _make_sprite()
		sprite.fix_alpha_edges()
		sprite.generate_mipmaps()
		texture = ImageTexture.create_from_image(sprite)
		while _texture_cache.size() >= MAX_TEXTURES:
			_texture_cache.erase(_texture_cache.keys()[0])
		_texture_cache[key] = texture
	var factor: float = minf(size.x/float(WIDTH),size.y/float(HEIGHT))
	var breath: float = sin(_time*0.85+float(posmod(int(plant.get("seed",1)),1000)))*0.006 if animate and alive else 0.0
	var measured_scale: Vector2 = _individual_scale()
	var dimensions := Vector2(WIDTH*factor*(1.0+breath*0.35),HEIGHT*factor*(1.0-breath))*measured_scale*0.85
	dimensions *= minf(1.0,minf(size.x/maxf(1,dimensions.x),size.y/maxf(1,dimensions.y)))
	var offset := Vector2((size.x-dimensions.x)*0.5,size.y-dimensions.y)
	draw_texture_rect(texture,Rect2(offset,dimensions),false,Color(1,1,1,clampf(reveal,0,1)))

func _draw_authored(texture: Texture2D) -> void:
	_sync_art_material()
	material = _art_material
	_art_material.set_shader_parameter("reveal_amount",clampf(reveal,0,1))
	_art_material.set_shader_parameter("charge",clampf(energy/100.0+activity*0.30,0,1.3))
	_art_material.set_shader_parameter("living",alive)
	_art_material.set_shader_parameter("unidentified",silhouette)
	_art_material.set_shader_parameter("senescence",_senescence())
	_art_material.set_shader_parameter("naturally_withered",_naturally_withered())
	_art_material.set_shader_parameter("sway_amount",0.0035 if animate and alive and not _naturally_withered() else 0.0)
	var extent: Vector2 = texture.get_size()
	var shape_scale := Vector2.ONE
	match str(_gene("form","Upright")):
		"Rosette": shape_scale = Vector2(1.05,0.88)
		"Trailing": shape_scale = Vector2(1.04,0.90)
		"Climbing": shape_scale = Vector2(0.90,1.06)
	var growth: float = 1.0
	if not bool(plant.get("mature",true)):
		var measured: Dictionary = Care.measurements(plant)
		growth = lerpf(0.48,1.0,float(measured.get("growth_progress",0)))
	if _naturally_withered(): shape_scale *= Vector2(1.04,0.66)
	var size_gene: String = str(_gene("size","Standard"))
	var scale_gene: float = 0.80 if size_gene=="Small" else (1.13 if size_gene=="Large" else 1.0)
	var available := Vector2(maxf(1,size.x-3),maxf(1,size.y-2))
	var fit: float = minf(available.x/extent.x,available.y/extent.y)*0.84
	# Leave room for each individual to get taller or fuller with care.
	# Its inherited silhouette and pigments remain unchanged.
	var dimensions: Vector2 = extent*fit*shape_scale*scale_gene*growth*_individual_scale()
	# Form can change proportions; no leaf or root is allowed outside its cell.
	var constrain: float = minf(1.0,minf(available.x/dimensions.x,available.y/dimensions.y))
	dimensions *= constrain
	var offset := Vector2((size.x-dimensions.x)*0.5,size.y-dimensions.y)
	draw_texture_rect(texture,Rect2(offset,dimensions),false)

func _individual_scale() -> Vector2:
	var individual: Dictionary = plant.get("measurements",{})
	var tending: Dictionary = plant.get("care",{})
	var height: float = clampf(float(individual.get("height_variation",1.0)),0.86,1.16)
	var mass: float = clampf(float(individual.get("weight_variation",1.0)),0.80,1.24)
	# Mass adds fullness while height changes the upright silhouette. Square
	# roots keep cared-for giants recognisable and comfortably inside cards.
	var height_scale: float = pow(height,0.7)*sqrt(1.0+clampf(float(tending.get("height_bonus",0.0)),0,0.60))
	var width_scale: float = pow(mass,0.22)*pow(1.0+clampf(float(tending.get("weight_bonus",0.0)),0,0.80),0.25)
	return Vector2(width_scale,height_scale)

func _naturally_withered() -> bool:
	var limits: Dictionary = Care.life_limits(plant)
	return bool(plant.get("withered",false)) or float(plant.get("life_age",0))>=float(limits.life_limit)

func _senescence() -> float:
	var limits: Dictionary = Care.life_limits(plant)
	return clampf((float(plant.get("life_age",0))-float(limits.aging_at))/maxf(1,float(limits.life_limit)-float(limits.aging_at)),0.0,1.0)

func _sync_art_material() -> void:
	if _art_material == null:
		if _art_shader == null:
			_art_shader = Shader.new()
			_art_shader.code = AUTHORED_SHADER
		_art_material = ShaderMaterial.new()
		_art_material.shader = _art_shader
		_material_signature = 0
	var signature: int = hash([_visual_signature,plant.get("graft_shape","")])
	if signature == _material_signature: return
	_material_signature = signature
	var pigment := Color.from_string(str(_gene("color","829d80")),Color("829d80"))
	var accent := Color.from_string(str(_gene("accent","c4d2a1")),Color("c4d2a1"))
	_art_material.set_shader_parameter("pigment",pigment)
	_art_material.set_shader_parameter("accent",accent)
	_art_material.set_shader_parameter("pattern_kind",maxi(0,["Solid","Striped","Spotted","Gradient","Starburst","Bicolor Ring"].find(str(_gene("pattern","Solid")))))
	_art_material.set_shader_parameter("shape_kind",maxi(0,["Round","Pointed","Frilled","Split"].find(str(_gene("shape","Pointed")))))
	_art_material.set_shader_parameter("surface_kind",maxi(0,["Matte","Waxy","Translucent","Fibrous","Wet"].find(str(_gene("texture","Matte")))))
	_art_material.set_shader_parameter("glow_kind",maxi(0,["None","Veins","Spore dust","Pulsing core"].find(str(_gene("glow","None")))))
	_art_material.set_shader_parameter("petal_count",clampf(float(_gene("petals",6)),3,12))
	_art_material.set_shader_parameter("species_kind",maxi(0,["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"].find(str(plant.get("type","Leaf")))))
	_art_material.set_shader_parameter("seed_phase",float(posmod(int(plant.get("seed",1)),997))/997.0*6.283185)
	var deformed: bool = bool(plant.get("deformed",false))
	for record in plant.get("mutation_history",[]):
		if record is Dictionary and str(record.get("outcome","")).to_lower()=="deformity": deformed = true
	_art_material.set_shader_parameter("deformed",deformed)
	var graft_colors: Array[Color] = []
	var graft_records: Array = plant.get("graft_history",[]).duplicate()
	graft_records.append_array(plant.get("inherited_graft_records",[]))
	for record in graft_records:
		if record is Dictionary and bool(record.get("success",true)):
			graft_colors.append(Color.from_string(str(record.get("donor_color",record.get("color",accent.to_html()))),accent))
	if graft_colors.is_empty() and plant.has("inherited_graft_color"):
		graft_colors.append(Color.from_string(str(plant.inherited_graft_color),accent))
	_art_material.set_shader_parameter("graft_count",mini(2,graft_colors.size()))
	_art_material.set_shader_parameter("graft_color_a",graft_colors[0] if not graft_colors.is_empty() else accent)
	_art_material.set_shader_parameter("graft_color_b",graft_colors[1] if graft_colors.size()>1 else accent)

const AUTHORED_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 pigment : source_color = vec4(0.51,0.62,0.50,1.0);
uniform vec4 accent : source_color = vec4(0.77,0.82,0.63,1.0);
uniform int species_kind = 0;
uniform int pattern_kind = 0;
uniform int shape_kind = 1;
uniform int surface_kind = 0;
uniform int glow_kind = 0;
uniform float petal_count = 6.0;
uniform float seed_phase = 0.0;
uniform float sway_amount = 0.0;
uniform float reveal_amount = 1.0;
uniform float charge = 0.0;
uniform bool living = true;
uniform bool unidentified = false;
uniform bool deformed = false;
uniform float senescence = 0.0;
uniform bool naturally_withered = false;
uniform int graft_count = 0;
uniform vec4 graft_color_a : source_color;
uniform vec4 graft_color_b : source_color;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
float luminance(vec3 color) { return dot(color,vec3(0.24,0.59,0.17)); }
float random_cell(vec2 point) { return fract(sin(dot(point,vec2(127.1,311.7)))*43758.5453); }
vec3 colored_tissue(vec3 original,vec3 target,float amount) {
	float light = luminance(original);
	// Keep the painted veins and ivory edges while letting daylight reach the midtones.
	vec3 mapped = target/max(luminance(target),0.18)*light;
	mapped = mix(mapped,original,smoothstep(0.72,0.95,light)*0.62);
	float ink = smoothstep(0.10,0.30,light);
	return mix(original,clamp(mapped,0.0,1.0),amount*ink);
}
void fragment() {
	vec2 uv = UV;
	float upper = pow(clamp(1.0-uv.y,0.0,1.0),1.8);
	// Roots stay planted while the upper fronds shift less than half a pixel in cards.
	uv.x += sin(TIME*0.83+seed_phase+uv.y*1.8)*sway_amount*upper;
	uv.y -= senescence*0.045*upper;
	if (naturally_withered) uv.x += sin(uv.y*5.5+seed_phase)*0.045*upper;
	float leaf_zone = (1.0-smoothstep(0.60,0.94,uv.y));
	if (shape_kind==0) uv.x = 0.5+(uv.x-0.5)*(1.0-0.025*sin(uv.y*3.14159)*leaf_zone);
	if (shape_kind==1) uv.x = 0.5+(uv.x-0.5)*(1.0+0.035*upper);
	if (shape_kind==2) uv.x += sin(uv.y*106.0+seed_phase)*0.0035*leaf_zone;
	if (shape_kind==3) uv.x += sin(uv.y*31.0+seed_phase)*0.006*upper;
	if (deformed) {
		float side = 1.0-smoothstep(0.28,0.54,uv.x);
		uv.y += 0.075*upper*side;
		uv.x += sin(uv.y*12.0+seed_phase)*0.018*upper*side;
	}
	vec4 source = texture(TEXTURE,uv);
	if (uv.x<0.0 || uv.x>1.0 || uv.y<0.0 || uv.y>1.0) source.a = 0.0;
	float light = luminance(source.rgb);
	float green = smoothstep(-0.015,0.075,source.g-max(source.r*0.96,source.b*1.02));
	float tissue = smoothstep(0.17,0.34,light)*(1.0-smoothstep(0.91,1.0,light))*leaf_zone;
	float leafy = (species_kind==0 || species_kind==2) ? 1.0 : 0.0;
	vec3 foliage = mix(vec3(0.34,0.59,0.29),pigment.rgb,0.30+leafy*0.43);
	vec3 body = colored_tissue(source.rgb,pigment.rgb,0.70);
	vec3 leaf = colored_tissue(source.rgb,foliage,0.55+leafy*0.12);
	vec3 color = mix(body,leaf,green);
	// Warm wood and tiny bare roots retain their authored bark colors.
	color = mix(source.rgb,color,leaf_zone);
	vec2 pixel_uv = floor(uv/TEXTURE_PIXEL_SIZE/3.0)*TEXTURE_PIXEL_SIZE*3.0;
	float marking = 0.0;
	if (pattern_kind==1) {
		float stripe = sin((pixel_uv.y+pixel_uv.x*0.31)*76.0+sin(pixel_uv.x*19.0)*0.7+seed_phase);
		marking = smoothstep(0.55,0.80,stripe)*0.76;
	} else if (pattern_kind==2) {
		vec2 grid = pixel_uv*vec2(8.0,11.0);
		vec2 id = floor(grid);
		vec2 local = fract(grid)-0.5;
		local += vec2(random_cell(id)-0.5,random_cell(id+19.0)-0.5)*0.30;
		marking = (1.0-smoothstep(0.13,0.22,length(local)))*0.84;
	} else if (pattern_kind==3) {
		marking = (1.0-smoothstep(0.12,0.82,pixel_uv.y))*0.74;
	} else if (pattern_kind==4) {
		vec2 radial = pixel_uv-vec2(0.5,0.58);
		float ray = sin(atan(radial.y,radial.x)*petal_count+length(radial)*17.0);
		marking = smoothstep(0.72,0.90,ray)*0.74;
	} else if (pattern_kind==5) {
		float radius = length((pixel_uv-vec2(0.5,0.52))*vec2(1.0,0.83));
		marking = smoothstep(0.16,0.19,radius)*(1.0-smoothstep(0.24,0.27,radius))*0.88;
	}
	vec3 marked = colored_tissue(color,accent.rgb,0.86);
	// An accent allele carries value as well as hue. Nearby sage/ivory genes
	// must still read as different stripes and spots on detailed native tissue.
	// Multiplying the authored midtones keeps every vein and fold intact.
	float value_direction = luminance(accent.rgb)>=luminance(pigment.rgb) ? 1.0 : -1.0;
	float midtone = smoothstep(0.20,0.42,light)*(1.0-smoothstep(0.76,0.96,light));
	marked *= 1.0+value_direction*0.28*midtone;
	// A seven-percent counter-shade separates variegation from the original
	// pale leaf margins without flattening any painted tissue detail.
	if (pattern_kind>0) color *= 1.0-value_direction*0.07*midtone*tissue;
	color = mix(color,clamp(marked,0.0,1.0),marking*tissue);
	// A graft inherits the donor's pigment in an actual existing lateral branch.
	// The host's detailed veins, outlines and volume remain untouched.
	if (graft_count>0) {
		float branch = smoothstep(0.59,0.69,uv.x)*(1.0-smoothstep(0.72,0.87,uv.y))*smoothstep(0.23,0.37,uv.y);
		color = mix(color,colored_tissue(color,graft_color_a.rgb,0.95),branch*tissue);
	}
	if (graft_count>1) {
		float branch = (1.0-smoothstep(0.31,0.42,uv.x))*(1.0-smoothstep(0.72,0.87,uv.y))*smoothstep(0.29,0.41,uv.y);
		color = mix(color,colored_tissue(color,graft_color_b.rgb,0.95),branch*tissue);
	}
	if (surface_kind==1 || surface_kind==4) {
		float gleam = pow(max(0.0,sin(uv.x*19.0+uv.y*7.0)),14.0)*smoothstep(0.48,0.82,light)*green;
		color = mix(color,vec3(0.94,0.98,0.82),gleam*(surface_kind==4 ? 0.18 : 0.11));
	} else if (surface_kind==2) {
		color = mix(color,accent.rgb,0.12*tissue);
		color += accent.rgb*smoothstep(0.62,0.84,light)*tissue*0.08;
	} else if (surface_kind==3) {
		float fiber = step(0.87,fract((pixel_uv.y+pixel_uv.x*0.10)*150.0));
		color *= 1.0-fiber*tissue*0.055;
	}
	if (glow_kind>0 || charge>0.0) {
		float pulse = 0.85+sin(TIME*1.3+seed_phase)*0.15;
		float vein = smoothstep(0.61,0.86,light)*tissue;
		color += accent.rgb*vein*(0.10*float(glow_kind>0)+charge*0.10)*pulse;
	}
	// A gentle sunlit lift keeps tiny botanical details readable on pale soil.
	float sunlight = smoothstep(0.16,0.46,light)*(1.0-smoothstep(0.77,1.0,light));
	float gray = luminance(color);
	color = mix(vec3(gray),color,1.16);
	color += vec3(0.065,0.071,0.025)*sunlight;
	if (!living) color = mix(color,vec3(luminance(color))*vec3(0.83,0.89,0.70),0.83)*0.67;
	if (senescence>0.0) {
		float edge_light = smoothstep(0.34,0.78,light);
		vec3 bronze = vec3(0.79,0.52,0.20)*max(0.16,luminance(color))*1.62;
		color = mix(color,bronze,senescence*(0.28+edge_light*0.43)*green);
	}
	if (naturally_withered) {
		float dry_value = luminance(color);
		color = mix(color,vec3(0.70,0.49,0.28)*dry_value*1.45,0.91)*0.78;
	}
	if (unidentified) color = vec3(0.16,0.27,0.22)*(0.85+light*0.24);
	COLOR = vec4(clamp(color,0.0,1.0),source.a*reveal_amount)*vertex_tint;
}
"""

func _make_sprite() -> Image:
	_image = Image.create(WIDTH,HEIGHT,false,Image.FORMAT_RGBA8)
	_image.fill(Color.TRANSPARENT)
	_rng.seed = int(plant.get("seed",92))
	_pose = posmod(int(plant.get("seed",92)),3)-1
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
	if _naturally_withered(): return c.lerp(Color("856344"),0.87).darkened(0.30)
	if not alive: return c.lerp(Color("7b8062"),0.84).darkened(0.22)
	if _senescence()>0: return c.lerp(Color("a88947"),_senescence()*0.55)
	return c

func _native_pixel(x: int,y: int,c: Color) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT: _image.set_pixel(x,y,_color(c))

func _px(x: int,y: int,c: Color) -> void:
	# Large tissue masses use anatomical units; membranes below are sampled
	# directly on the full-resolution grid, with one-pixel capillaries.
	_native_rect(x*SCALE,y*SCALE,SCALE,SCALE,c)

func _native_rect(x: int,y: int,w: int,h: int,c: Color) -> void:
	var rect := Rect2i(x,y,w,h).intersection(Rect2i(0,0,WIDTH,HEIGHT))
	if rect.size.x>0 and rect.size.y>0: _image.fill_rect(rect,_color(c))

func _rect(x: int,y: int,w: int,h: int,c: Color) -> void:
	_native_rect(x*SCALE,y*SCALE,w*SCALE,h*SCALE,c)

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
	_native_line(a*SCALE,b*SCALE,c,maxi(1,roundi(width*SCALE*0.42)))

func _stem(a: Vector2i,b: Vector2i,width: int = 1,pale: bool = false) -> void:
	var stem_width: int = maxi(2,roundi(width*SCALE*0.76))
	_native_line(a*SCALE,b*SCALE,INK,stem_width+3)
	var c: Color = _accent.lerp(Color("c8d9ad"),0.5) if pale else _foliage
	_native_line(a*SCALE,b*SCALE,c,stem_width)
	_native_line(a*SCALE+Vector2i(-stem_width/3,0),b*SCALE+Vector2i(-stem_width/3,0),c.lightened(0.22),maxi(1,stem_width/5))
	for j in range(2,18,2):
		var point := Vector2i(Vector2(a*SCALE).lerp(Vector2(b*SCALE),float(j)/19.0))
		_native_rect(point.x+stem_width/3,point.y,1,2,c.darkened(0.22))

func _ellipse(center: Vector2i,radius: Vector2i,c: Color,outline: bool = true,markings: bool = false) -> void:
	var middle := center*SCALE
	var r := radius*SCALE
	for y in range(middle.y-r.y,middle.y+r.y+1):
		for x in range(middle.x-r.x,middle.x+r.x+1):
			var dx: float = float(x-middle.x)/maxf(1,r.x)
			var dy: float = float(y-middle.y)/maxf(1,r.y)
			var distance: float = dx*dx+dy*dy
			if distance > 1: continue
			var tone: float = dx*0.56+dy*0.35
			var step: float = floorf(tone*10.0)/10.0
			var color: Color = c.darkened(step*0.46) if step>0 else c.lightened(-step*0.38)
			if markings: color = _marked(color,Vector2i(x,y),float(y-middle.y+r.y)/maxf(1,r.y*2),dx)
			var edge: bool = pow((absf(x-middle.x)+1.4)/maxf(1,r.x),2)+dy*dy>1.0 or dx*dx+pow((absf(y-middle.y)+1.4)/maxf(1,r.y),2)>1.0
			if outline and edge: color = c.darkened(0.48) if dx < -0.1 else INK
			elif posmod(x*13+y*7+int(plant.get("seed",0)),211)==0: color = color.lightened(0.055)
			_native_pixel(x,y,color)
	if outline:
		_native_line(middle+Vector2i(-r.x/3,-r.y*2/3),middle+Vector2i(-r.x/5,-r.y*3/4),c.lightened(0.26),2)

func _marked(base: Color,p: Vector2i,t: float,side: float) -> Color:
	match _pattern:
		"Striped":
			var band: int = posmod(p.y+p.x/3,5*SCALE)
			if band < SCALE: return base.lerp(_accent,0.82)
			if band < SCALE+2: return base.lerp(_accent.darkened(0.16),0.55)
		"Spotted":
			var spot := Vector2i(posmod(p.x,6*SCALE)-2*SCALE,posmod(p.y,6*SCALE)-int(2.5*SCALE))
			var radius: float = SCALE*1.12
			if spot.length_squared() <= radius*radius: return _accent
			if spot.length_squared() <= pow(radius+1.7,2): return base.lerp(_accent,0.45)
		"Gradient":
			return base.lerp(_accent,floorf(t*24.0)/24.0*0.70)
		"Starburst":
			if absf(side) < 0.055 or posmod(p.x+p.y,7*SCALE) < 2: return _accent
			if absf(side) < 0.12: return base.lerp(_accent,0.35)
		"Bicolor Ring":
			if t > 0.43 and t < 0.60: return _accent
			if t > 0.415 and t < 0.62: return base.lerp(_accent,0.45)
	return base

func _leaf(base: Vector2i,tip_value: Vector2i,width: float,color: Color,patterned: bool = true) -> void:
	var tip: Vector2i = tip_value
	if _deformed and tip.x < 20: tip = Vector2i(Vector2(base).lerp(Vector2(tip),0.72)); width *= 0.75
	var base_hd := Vector2(base)*SCALE
	var tip_hd := Vector2(tip)*SCALE
	var axis: Vector2 = tip_hd-base_hd
	var length: float = axis.length()
	if length < 1: return
	var direction: Vector2 = axis/length
	var normal := Vector2(-direction.y,direction.x)
	var native_width: float = width*SCALE
	var bounds := Rect2(base_hd.min(tip_hd)-Vector2.ONE*(native_width+2),Vector2(absf(axis.x),absf(axis.y))+Vector2.ONE*(native_width*2+4))
	var texture: String = str(_gene("texture","Matte"))
	var seed_value: int = int(plant.get("seed",0))
	for y in range(maxi(0,int(bounds.position.y)),mini(HEIGHT,int(bounds.end.y)+1)):
		for x in range(maxi(0,int(bounds.position.x)),mini(WIDTH,int(bounds.end.x)+1)):
			var delta := Vector2(x,y)-base_hd
			var t: float = delta.dot(direction)/length
			if t < 0 or t > 1: continue
			var half: float = pow(maxf(0,sin(t*PI)),0.45 if _shape == "Round" else 0.85)*native_width
			if _shape == "Frilled": half *= 0.9+0.14*sin(t*35.0)
			var lateral: float = delta.dot(normal)
			if _shape == "Split" and t>0.72 and absf(lateral)<(t-0.72)*native_width*1.8: continue
			if absf(lateral)>half: continue
			var ratio: float = lateral/maxf(1,half)
			var light: float = floorf(ratio*9.0)/9.0
			var c: Color = color.darkened(light*0.26) if light>0 else color.lightened(-light*0.22)
			if patterned: c = _marked(c,Vector2i(x,y),t,ratio)
			var edge: bool = half-absf(lateral)<1.4 or t*length<1.2 or (1.0-t)*length<1.2
			if edge:
				c = color.darkened(0.40) if lateral<0 else INK
			elif posmod(x*13+y*7+seed_value,193)==0:
				c = c.darkened(0.05)
			elif texture=="Fibrous" and posmod(roundi(lateral*1.5)+seed_value,13)<1:
				c = c.lightened(0.055)
			_native_pixel(x,y,c)
	var vein_color: Color = color.lerp(_accent,0.45) if patterned else color.lightened(0.25)
	_native_line(Vector2i(base_hd),Vector2i(tip_hd),vein_color,2)
	# Secondary ribs and branching capillaries are freshly sampled on the
	# 320px source grid. They are not block copies of the former 80px anatomy.
	for j in range(2,15):
		var t: float = float(j)/17.0
		var middle: Vector2 = base_hd.lerp(tip_hd,t)
		var spread: float = sin(t*PI)*native_width*0.79
		for side in [-1,1]:
			var end: Vector2 = middle+normal*spread*side-direction*SCALE*1.4
			_native_line(Vector2i(middle),Vector2i(end),color.lightened(0.13),1)
			for branch in [0.45,0.72]:
				var joint: Vector2 = middle.lerp(end,branch)
				var capillary: Vector2 = joint-direction*SCALE*0.72+normal*side*SCALE*0.35
				_native_line(Vector2i(joint),Vector2i(capillary),color.lerp(_accent,0.12).lightened(0.08),1)
	if texture in ["Waxy","Wet","Translucent"]:
		var start: Vector2 = base_hd.lerp(tip_hd,0.36)-normal*native_width*0.40
		var end: Vector2 = base_hd.lerp(tip_hd,0.73)-normal*native_width*0.34
		_native_line(Vector2i(start),Vector2i(end),color.lerp(_accent,0.25).lightened(0.24),2)
		if texture=="Translucent":
			_native_line(Vector2i(base_hd.lerp(tip_hd,0.25)+normal*SCALE*0.8),Vector2i(base_hd.lerp(tip_hd,0.83)+normal*SCALE*0.8),_accent.lerp(color,0.55),1)

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
	var middle := center*SCALE
	var w: int = width*SCALE
	var h: int = height*SCALE
	var lip: int = maxi(2,roundi(SCALE*1.6))
	for y in range(-h,lip+1):
		for x in range(-w,w+1):
			var norm: float = pow(float(x)/maxf(1,w),2)+pow(float(y)/maxf(1,h),2)
			if y<=0 and norm>1.0: continue
			if y>0 and abs(x)>w-SCALE: continue
			var c: Color = color
			if y>0:
				c = color.darkened(0.28)
				if posmod(x+roundi(y*1.5),maxi(3,SCALE))<2: c = c.lerp(_accent,0.45)
			else:
				var tone: float = float(x)/maxf(1,w)*0.18+float(y+h)/maxf(1,h)*0.12
				var step: float = floorf(tone*24.0)/24.0
				c = color.darkened(step) if step>0 else color.lightened(-step)
			c = _marked(c,middle+Vector2i(x,y),float(y+h)/maxf(1,h+lip),float(x)/maxf(1,w))
			var edge: bool = (norm>0.975 and y<-1) or y==lip or abs(x)==w
			_native_pixel(middle.x+x,middle.y+y,INK if edge else c)
	# Thin radiating gills and cuticle creases survive the high-res detail view.
	for x in range(-w+SCALE,w-SCALE,maxi(3,SCALE)):
		_native_line(middle+Vector2i(x,1),middle+Vector2i(roundi(x*0.82),lip-1),_accent.darkened(0.16),1)
	for i in range(11):
		var offset_x: int = -w/2+i*w/11
		var offset_y: int = -h/2-roundi(sin(float(i)*1.8)*h*0.13)
		_native_rect(middle.x+offset_x,middle.y+offset_y,2,1,color.lightened(0.24))

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
	var base_hd := base*SCALE
	var mouth_hd := mouth*SCALE
	for y in range(height*SCALE):
		var t: float = float(y)/maxf(1,height*SCALE)
		var half: int = maxi(SCALE,roundi(width*SCALE*(0.45+sin(t*PI)*0.55)))
		var center_x: int = roundi(lerpf(float(base_hd.x),float(mouth_hd.x),t))
		for x in range(-half,half+1):
			var side: float = float(x)/maxf(1,half)
			var step: float = floorf(side*12.0)/12.0
			var c: Color = color.darkened(step*0.27) if step>0 else color.lightened(-step*0.18)
			c = _marked(c,Vector2i(center_x+x,base_hd.y-y),t,side)
			if abs(x)>=half-1:
				c = INK
			elif posmod(x+roundi(sin(t*4.0)*SCALE),maxi(3,SCALE*2))<2 and t>0.12 and t<0.90:
				c = c.lightened(0.10)
			elif posmod(x*17+y*11+int(plant.get("seed",0)),173)==0:
				c = c.darkened(0.055)
			_native_pixel(center_x+x,base_hd.y-y,c)
	_ellipse(mouth,Vector2i(width,3),_accent)
	_ellipse(mouth+Vector2i(0,-1),Vector2i(maxi(1,width-2),1),INK,false)
	_leaf(mouth+Vector2i(-width,0),mouth+Vector2i(0,-6),2.3,color)
	_native_line(mouth_hd+Vector2i(-width*SCALE/2,-1),mouth_hd+Vector2i(width*SCALE/2,-1),_accent.lightened(0.24),2)
	for i in range(-width+1,width):
		_native_line(mouth_hd+Vector2i(i*SCALE,-SCALE),mouth_hd+Vector2i(i*SCALE+2,SCALE),_accent.darkened(0.19),1)
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
	if _naturally_withered(): scale_y *= 0.66; scale_x *= 1.04
	if str(_gene("size","Standard"))=="Small": scale_x *= 0.86; scale_y *= 0.86
	if str(_gene("size","Standard"))=="Large": scale_x *= 1.06; scale_y *= 1.04
	match form:
		"Rosette": scale_x *= 1.05; scale_y *= 0.86
		"Trailing": scale_x *= 1.02; scale_y *= 0.88
		"Climbing": scale_x *= 0.88; scale_y *= 1.04
	if is_equal_approx(scale_x,1.0) and is_equal_approx(scale_y,1.0): return _image
	var shaped: Image = _image.duplicate()
	shaped.resize(maxi(1,roundi(WIDTH*scale_x)),maxi(1,roundi(HEIGHT*scale_y)),Image.INTERPOLATE_LANCZOS)
	var result := Image.create(WIDTH,HEIGHT,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var offset := Vector2i(roundi(WIDTH*0.5*(1.0-scale_x)),roundi(44*SCALE*(1.0-scale_y)))
	result.blit_rect(shaped,Rect2i(Vector2i.ZERO,shaped.get_size()),offset)
	return result
