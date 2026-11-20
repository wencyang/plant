extends SceneTree
## Native run verifies the actual GPU-rendered appearance, not just parameters.
const Portrait = preload("res://scripts/plant_portrait.gd")
const Assets = preload("res://scripts/plant_sprite_assets.gd")
const State = preload("res://scripts/garden_state.gd")
var checks: int = 0
var failures: int = 0
var viewport: SubViewport
var portrait: Control
func _initialize() -> void:
	call_deferred("run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func capture(specimen: Dictionary) -> Image:
	portrait.plant = specimen
	portrait.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func pixels_visible(image: Image) -> int:
	var result: int = 0
	var data: PackedByteArray = image.get_data()
	for i in range(3,data.size(),4):
		if data[i]>32: result += 1
	return result
func run() -> void:
	var types: Array[String] = ["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"]
	for plant_type: String in types:
		var image: Image = Portrait.authored_image(plant_type)
		check(image!=null,plant_type+" has authored botanical art")
		if image==null: continue
		check(image.get_width()>=300 and image.get_height()>=430,plant_type+" keeps its high-resolution source")
		check(image.get_pixel(0,0).a==0 and image.get_pixel(image.get_width()-1,image.get_height()-1).a==0,plant_type+" has clear alpha gutters")
		var coverage: float = pixels_visible(image)/float(image.get_width()*image.get_height())
		check(coverage>0.16 and coverage<0.85,plant_type+" is tightly framed with empty space between fine tissue")
		var texture: Texture2D = Portrait.authored_texture(plant_type)
		check(texture==Portrait.authored_texture(plant_type),plant_type+" shares its base texture")
		check(texture.get_image().has_mipmaps(),plant_type+" has real minification mipmaps")
	check(Assets._textures.size()==8,"Exactly eight shared botanical textures serve all genetic variants")
	check(Portrait.authored_texture("Unknown")==Portrait.authored_texture("Leaf") and Assets._textures.size()==8,"Unknown types reuse the Leaf fallback without growing the cache")
	if DisplayServer.get_name()=="headless":
		print("PLANT ART TESTS: ",checks," checks, ",failures," failures; GPU appearance checks require native renderer")
		quit(1 if failures else 0)
		return
	root.size = Vector2i(420,540)
	viewport = SubViewport.new()
	viewport.size = Vector2i(384,512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	portrait = Portrait.new()
	portrait.size = Vector2(384,512)
	portrait.animate = false
	viewport.add_child(portrait)
	var state := State.new("/tmp/conservatory_plant_art_checks.json")
	var baseline: Dictionary = state._create_base(0,821)
	baseline.genes.pattern.dominant = "Solid"
	baseline.genes.shape.dominant = "Pointed"
	baseline.genes.texture.dominant = "Matte"
	var untouched: String = JSON.stringify(baseline)
	var base_image: Image = await capture(baseline)
	var base_hash: int = hash(base_image.get_data())
	var base_visible: int = pixels_visible(base_image)
	check(base_visible>25000,"Authored plant is visible through the OpenGL shader")
	check(base_image.get_pixel(0,0).a<0.01,"GPU appearance keeps transparent corners")
	for pattern: String in State.PATTERNS:
		var specimen: Dictionary = baseline.duplicate(true)
		specimen.genes.pattern.dominant = pattern
		var result: Image = await capture(specimen)
		if pattern!="Solid": check(hash(result.get_data())!=base_hash,pattern+" visibly changes actual tissue pixels")
		check(absi(pixels_visible(result)-base_visible)<32,pattern+" changes pigment without destroying plant anatomy")
	for entry: Array in [["color","aa829b"],["accent","dc8d6a"],["shape","Frilled"],["form","Climbing"],["texture","Waxy"],["glow","Veins"]]:
		var specimen: Dictionary = baseline.duplicate(true)
		# Accent is expressed by inherited variegation rather than replacing all tissue.
		var comparison_hash: int = base_hash
		if entry[0]=="accent":
			specimen.genes.pattern.dominant = "Spotted"
			comparison_hash = hash((await capture(specimen)).get_data())
		specimen.genes[entry[0]].dominant = entry[1]
		var result: Image = await capture(specimen)
		check(hash(result.get_data())!=comparison_hash,str(entry[0])+" visibly changes the rendered specimen")
	var growing: Dictionary = baseline.duplicate(true)
	growing.mature = false
	growing.ready_at = int(Time.get_unix_time_from_system())+12
	check(pixels_visible(await capture(growing))<base_visible*0.65,"Growing specimens are visibly smaller")
	var small: Dictionary = baseline.duplicate(true)
	small.genes.size.dominant = "Small"
	check(pixels_visible(await capture(small))<base_visible*0.85,"Inherited small size visibly changes the specimen")
	var grafted: Dictionary = baseline.duplicate(true)
	grafted.graft_history = [{"success":true,"donor_color":"d782ac"}]
	check(hash((await capture(grafted)).get_data())!=base_hash,"Successful graft changes a lateral branch to donor tissue")
	var deformed: Dictionary = baseline.duplicate(true)
	deformed.deformed = true
	check(hash((await capture(deformed)).get_data())!=base_hash,"Deformity changes silhouette without changing saved genes")
	portrait.alive = false
	check(hash((await capture(baseline)).get_data())!=base_hash,"Withered appearance is visible")
	portrait.alive = true
	portrait.silhouette = true
	var unidentified: Image = await capture(baseline)
	check(hash(unidentified.get_data())!=base_hash,"Undiscovered specimen remains a silhouette")
	check(absi(pixels_visible(unidentified)-base_visible)<32,"Silhouettes retain accurate botanical outlines")
	portrait.silhouette = false
	for i in range(types.size()):
		var specimen: Dictionary = state._create_base(mini(i,6),871+i)
		specimen.type = types[i]
		check(pixels_visible(await capture(specimen))>15000,types[i]+" renders as an actual visible species")
	check(Assets._textures.size()==8,"Genetic variants and state changes never allocate more base-art textures")
	check(JSON.stringify(baseline)==untouched,"Rendering does not alter canonical genes or specimen data")
	print("PLANT ART TESTS: ",checks," checks, ",failures," failures (native GPU)")
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
