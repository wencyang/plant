extends Control
## Original illustrated landscape with the actual, live DNA-driven specimen.
## Backdrops never replace the collectible plant with a baked-in picture.
const Habitat = preload("res://scripts/habitat_catalog.gd")
const Portrait = preload("res://scripts/plant_portrait.gd")
static var _textures: Dictionary = {}
var biome: String = "Mosswood"
var site_id: String = ""
var plant: Dictionary = {}
var portrait: Control
var backdrop: Texture2D
var art_key: String = ""

static func texture_for(biome_name: String) -> Texture2D:
	var key: String = str(Habitat.region(biome_name).get("art_key","forest"))
	if _textures.has(key): return _textures[key]
	var path: String = "res://assets/landscapes/%s.png" % key
	var import_settings:=ConfigFile.new()
	var imported_ready: bool=not OS.has_feature("editor") and ResourceLoader.exists(path)
	if import_settings.load(path+".import")==OK:
		imported_ready=FileAccess.file_exists(str(import_settings.get_value("remap","path","")))
	if imported_ready:
		var imported: Texture2D=load(path) as Texture2D
		if imported!=null:
			_textures[key]=imported
			return imported
	if not FileAccess.file_exists(path): return null
	var image:=Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK or image.is_empty(): return null
	image.generate_mipmaps()
	var result := ImageTexture.create_from_image(image)
	_textures[key]=result
	return result

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art_key=str(Habitat.region(biome).get("art_key","forest"))
	backdrop=texture_for(biome)
	set_meta("habitat_scene",true)
	set_meta("art_key",art_key)
	if not plant.is_empty():
		portrait=Portrait.new()
		portrait.plant=plant
		add_child(portrait)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if is_instance_valid(portrait):
		var height: float=size.y*0.93
		var width: float=minf(size.x*0.54,height*0.90)
		portrait.position=Vector2(size.x*0.63-width*0.5,size.y-height-5)
		portrait.size=Vector2(width,height)
	queue_redraw()

func _draw() -> void:
	if size.x<=0 or size.y<=0: return
	var bounds:=Rect2(Vector2.ZERO,size)
	draw_rect(bounds,Color("afc1a3"))
	if backdrop!=null:
		var source:=Rect2(Vector2.ZERO,backdrop.get_size())
		var crop_ratio: float=size.x/size.y
		if source.size.x/source.size.y>crop_ratio:
			var crop: float=source.size.y*crop_ratio
			source.position.x=(source.size.x-crop)*0.5
			source.size.x=crop
		else:
			var crop: float=source.size.x/crop_ratio
			source.position.y=(source.size.y-crop)*0.5
			source.size.y=crop
		draw_texture_rect_region(backdrop,bounds,source)
	else:
		# Quiet fallback while project assets are importing.
		draw_colored_polygon(PackedVector2Array([Vector2(0,size.y*0.8),Vector2(size.x*0.3,size.y*0.32),Vector2(size.x*0.57,size.y*0.69),Vector2(size.x,0),size,Vector2(0,size.y)]),Color("8d9c71"))
	if not plant.is_empty():
		# A restrained contact shadow grounds the real specimen in the landscape.
		var foot:=Vector2(size.x*0.63,size.y-10)
		draw_set_transform(foot,0,Vector2(1,0.22))
		draw_circle(Vector2.ZERO,minf(size.x*0.11,size.y*0.24),Color(0.15,0.24,0.23,0.18),true,-1,true)
		draw_set_transform(Vector2.ZERO)
	draw_rect(bounds.grow(-0.75),Color("39483e"),false,1.5,true)
