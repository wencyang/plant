extends SceneTree
const Portrait = preload("res://scripts/plant_portrait.gd")
const TYPES := ["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"]
const COLORS := ["829d80","d7a06d","9dbcb2","9c9471","b5beb5","aa829b","c1b9a0","aa829b"]

func _initialize() -> void:
	call_deferred("run")

func card(specimen: Dictionary,caption: String,index: int,columns: int,extent: Vector2) -> void:
	var panel := Panel.new()
	panel.position = Vector2(12+(index%columns)*extent.x,12+int(index/columns)*extent.y)
	panel.size = extent-Vector2(12,12)
	root.add_child(panel)
	var art := Portrait.new()
	art.plant = specimen
	art.animate = false
	art.position = Vector2(6,4)
	art.size = panel.size-Vector2(12,42)
	panel.add_child(art)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size",17)
	label.position = Vector2(10,panel.size.y-31)
	panel.add_child(label)

func base(index: int,seed_value: int) -> Dictionary:
	return {"id":"visual_%d" % seed_value,"type":TYPES[index],"seed":seed_value,"mature":true,
		"genes":{"color":{"dominant":COLORS[index]},"accent":{"dominant":"c4d2a1"},
		"pattern":{"dominant":"Solid"},"form":{"dominant":"Upright"},"shape":{"dominant":"Pointed"}}}

func snap(path: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	root.size = Vector2i(1960,1400)
	root.content_scale_factor = 1
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var index: int = 0
	for a in range(TYPES.size()):
		for b in range(a+1,TYPES.size()):
			var specimen: Dictionary = base(a,9121+index)
			specimen.lineage_mix = {TYPES[a]:0.5,TYPES[b]:0.5}
			specimen.hybrid = true
			card(specimen,TYPES[a]+" × "+TYPES[b],index,7,Vector2(280,350))
			index += 1
	await snap("res://screenshots/hybrid-all-pairs.png")
	for child in root.get_children(): child.queue_free()
	await process_frame
	root.size = Vector2i(1600,1140)
	var samples: Array[Dictionary] = []
	var g2: Dictionary = base(0,3512)
	g2.lineage_mix = {"Leaf":0.5,"Bloom":0.5}
	samples.append(g2)
	var g3: Dictionary = base(0,3513)
	g3.lineage_mix = {"Leaf":0.25,"Bloom":0.25,"Spore":0.5}
	samples.append(g3)
	var g4: Dictionary = base(4,3514)
	g4.lineage_mix = {"Leaf":0.125,"Bloom":0.125,"Spore":0.25,"Root":0.5}
	samples.append(g4)
	var graft: Dictionary = base(0,3515)
	graft.graft_history = [{"donor_type":"Toxin","donor_color":"aa829b","success":true}]
	samples.append(graft)
	var inherited: Dictionary = base(1,3516)
	inherited.lineage_mix = {"Bloom":0.5,"Vine":0.5}
	inherited.inherited_graft_records = [{"donor_type":"Carnivorous","donor_color":"d7a06d","success":true}]
	samples.append(inherited)
	var complex_graft: Dictionary = base(3,3517)
	complex_graft.lineage_mix = {"Root":0.5,"Vine":0.25,"Spore":0.25}
	complex_graft.graft_history = [{"donor_type":"Bloom","donor_color":"c275b1","success":true}]
	samples.append(complex_graft)
	var captions := ["G2 · Leaf + Bloom","G3 · + Spore","G4 · + Root","Leaf / Toxin graft","Inherited trap branch","Three lineages + graft"]
	for i in range(samples.size()): card(samples[i],captions[i],i,3,Vector2(533,570))
	await snap("res://screenshots/hybrid-generations-grafts.png")
	for child in root.get_children(): child.queue_free()
	await process_frame
	root.size = Vector2i(1800,1120)
	var counts := [3,4,5,6,7,8,10,12]
	for i in range(counts.size()):
		var specimen: Dictionary = base(1,4010+i)
		specimen.genes.petals = {"dominant":counts[i],"recessive":5}
		card(specimen,"Expressed petals: %d" % counts[i],i,4,Vector2(450,560))
	await snap("res://screenshots/hybrid-petal-counts.png")
	for child in root.get_children(): child.queue_free()
	await process_frame
	root.size = Vector2i(1800,560)
	var ages := [0.0,1300.0,1450.0,1500.0]
	var age_labels := ["Mature foliage","Aging · bronze edges","Late life · drooping","Withered rootstock"]
	for i in range(ages.size()):
		var specimen: Dictionary = base(0,4011)
		specimen.life_age = ages[i]
		specimen.withered = ages[i]>=1500
		card(specimen,age_labels[i],i,4,Vector2(450,560))
	await snap("res://screenshots/hybrid-lifecycle.png")
	print("HYBRID VISUAL PREVIEW: 28 cross-species pairs / successive lineage / inherited graft anatomy")
	quit()
