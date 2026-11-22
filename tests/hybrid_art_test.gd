extends SceneTree
## Native rendering checks for actual combined organs, successive ancestry,
## inherited grafts, literal flower anatomy and visible lifecycle stages.
const Portrait = preload("res://scripts/plant_portrait.gd")
const Assets = preload("res://scripts/plant_sprite_assets.gd")
const TYPES := ["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"]
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

func base(type_name: String,seed_value: int = 723) -> Dictionary:
	return {"type":type_name,"seed":seed_value,"mature":true,"genes":{
		"color":{"dominant":"829d80"},"accent":{"dominant":"d6cba5"},
		"pattern":{"dominant":"Solid"},"form":{"dominant":"Upright"},
		"shape":{"dominant":"Pointed"},"petals":{"dominant":5}}}

func coverage(image: Image) -> int:
	var count: int = 0
	var pixels: PackedByteArray = image.get_data()
	for i in range(3,pixels.size(),4):
		if pixels[i]>32: count += 1
	return count

func capture(specimen: Dictionary) -> Image:
	portrait.plant = specimen
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	var originals: Dictionary = {}
	for type_name: String in TYPES: originals[type_name] = hash(Portrait.authored_image(type_name).get_data())
	for a: String in TYPES:
		for b: String in TYPES:
			if a==b: continue
			var specimen: Dictionary = base(a)
			specimen.lineage_mix = {a:0.5,b:0.5}
			var texture: Texture2D = Portrait.hybrid_texture(specimen)
			check(texture!=null and texture.get_size()==Vector2(480,576),a+" × "+b+" has combined anatomy")
			check(texture==Portrait.hybrid_texture(specimen),a+" × "+b+" reuses its combined sprite")
			var image: Image = texture.get_image()
			check(image.has_mipmaps() and image.get_pixel(0,0).a==0 and image.get_pixel(479,575).a==0,a+" × "+b+" keeps high-quality alpha/minification")
	for type_name: String in TYPES: check(hash(Portrait.authored_image(type_name).get_data())==originals[type_name],type_name+" original tissue remains unchanged after every cross")
	var g2: Dictionary = base("Leaf",224)
	g2.lineage_mix = {"Leaf":0.5,"Bloom":0.5}
	var g3: Dictionary = base("Leaf",225)
	g3.lineage_mix = {"Leaf":0.25,"Bloom":0.25,"Spore":0.5}
	var g4: Dictionary = base("Spore",226)
	g4.lineage_mix = {"Leaf":0.125,"Bloom":0.125,"Spore":0.25,"Root":0.5}
	check(Assets.composition_for(g3).size()==2,"G3 expresses both secondary ancestral organs")
	check(Assets.composition_for(g4).size()==2 and g4.lineage_mix.size()==4,"G4 keeps full ancestry while limiting visible organs to readable anatomy")
	var graft: Dictionary = base("Leaf")
	graft.graft_history = [{"donor_type":"Toxin","donor_color":"b36b9d","success":true}]
	var inherited: Dictionary = base("Bloom")
	inherited.inherited_graft_records = [{"donor_type":"Carnivorous","donor_color":"c7b175","success":true}]
	check(Assets.composition_for(inherited)[0].type=="Carnivorous","Inherited graft retains real trap anatomy")
	check(Portrait.hybrid_texture(graft)!=Portrait.authored_texture("Leaf"),"Graft adds donor anatomy beyond a palette change")
	if DisplayServer.get_name()=="headless":
		print("HYBRID ART TESTS: ",checks," checks, ",failures," failures; native GPU required for expression/lifecycle")
		quit(1 if failures else 0)
		return
	root.size = Vector2i(420,540)
	viewport = SubViewport.new()
	viewport.size = Vector2i(480,576)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	portrait = Portrait.new()
	portrait.animate = false
	portrait.size = Vector2(480,576)
	viewport.add_child(portrait)
	var pure: Image = await capture(base("Leaf"))
	var base_hash: int = hash(pure.get_data())
	var prior: int = base_hash
	for specimen: Dictionary in [g2,g3,g4,graft,inherited]:
		var image: Image = await capture(specimen)
		check(coverage(image)>35000,"Mixed plant organs actually render through the gene shader")
		check(hash(image.get_data())!=prior,"Successive hybrids and grafts visibly change anatomy")
		prior = hash(image.get_data())
	var altered: Dictionary = g3.duplicate(true)
	var before: Image = await capture(g3)
	for entry: Array in [["color","7fabb0"],["pattern","Spotted"],["shape","Frilled"],["form","Climbing"],["size","Small"],["texture","Waxy"]]:
		altered = g3.duplicate(true)
		altered.genes[entry[0]] = {"dominant":entry[1]}
		check(hash((await capture(altered)).get_data())!=hash(before.get_data()),str(entry[0])+" gene changes actual mixed tissue")
	var petal_hashes: Dictionary = {}
	for petals in [3,4,5,6,7,8,10,12]:
		var flower: Dictionary = base("Bloom")
		flower.genes.petals.dominant = petals
		var image: Image = await capture(flower)
		check(coverage(image)>35000,"Authored %d-petal flower is intact" % petals)
		petal_hashes[hash(image.get_data())] = true
	check(petal_hashes.size()==8,"Petal count changes literal flower geometry independently from color/pattern")
	var aging: Dictionary = base("Leaf")
	aging.life_age = 1400.0
	var aged: Image = await capture(aging)
	check(hash(aged.get_data())!=base_hash,"Aging visibly bronzes/droops mature foliage")
	aging.life_age = 1500.0
	aging.withered = true
	var withered: Image = await capture(aging)
	check(hash(withered.get_data())!=hash(aged.get_data()),"Natural withering differs from aging")
	check(coverage(withered)<coverage(pure)*0.8,"Natural withering visibly collapses the dried crown")
	for i in range(70):
		var specimen: Dictionary = base("Leaf",i)
		specimen.lineage_mix = {"Leaf":1.0-0.1-float(i)*0.01,"Bloom":0.1+float(i)*0.01}
		Portrait.hybrid_texture(specimen)
	check(Assets._composites.size()<=Assets.MAX_COMPOSITES,"Long breeding sessions keep a bounded combined-sprite cache")
	print("HYBRID ART TESTS: ",checks," checks, ",failures," failures (native GPU)")
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
