extends SceneTree
## A paper-backed native art sheet: all illustrated families plus inherited
## markings, actual petal counts, mixed anatomy, grafts and natural aging.
const Portrait = preload("res://scripts/plant_portrait.gd")
const TYPES := ["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"]
const COLORS := ["829d80","d7a06d","9dbcb2","9c9471","b5beb5","aa829b","c1b9a0","aa829b"]
var sheet: Control

func _initialize() -> void:
	call_deferred("run")

func specimen(index: int,seed_value: int=723) -> Dictionary:
	return {"id":"illustrated_%d" % seed_value,"type":TYPES[index],"seed":seed_value,"mature":true,
		"genes":{"color":{"dominant":COLORS[index]},"accent":{"dominant":"c4d2a1"},
		"pattern":{"dominant":"Solid"},"form":{"dominant":"Upright"},
		"shape":{"dominant":"Pointed"},"petals":{"dominant":5}}}

func new_sheet() -> void:
	if is_instance_valid(sheet):
		sheet.queue_free()
		await process_frame
	sheet=Control.new()
	root.add_child(sheet)
	var background:=ColorRect.new()
	background.color=Color("f2ebd1")
	background.size=Vector2(root.size)
	sheet.add_child(background)

func card(plant: Dictionary,title: String,index: int) -> void:
	var bounds:=Rect2(Vector2(20+(index%4)*600,20+int(index/4)*750),Vector2(580,730))
	var panel:=Panel.new()
	panel.position=bounds.position
	panel.size=bounds.size
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("e6e7cc") if index%2==0 else Color("e6e6d4")
	style.border_color=Color("536554")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel",style)
	sheet.add_child(panel)
	var art:=Portrait.new()
	art.plant=plant
	art.animate=false
	art.position=Vector2(15,15)
	art.size=Vector2(550,650)
	panel.add_child(art)
	var caption:=Label.new()
	caption.text=title
	caption.add_theme_font_size_override("font_size",25)
	caption.add_theme_color_override("font_color",Color("334d43"))
	caption.position=Vector2(20,680)
	panel.add_child(caption)

func snap(name: String) -> void:
	for i in range(5): await process_frame
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+name+".png")
	print("ILLUSTRATED PLANT VISUAL: ",name)

func run() -> void:
	root.size=Vector2i(2400,1500)
	root.content_scale_factor=1
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await new_sheet()
	for i in range(TYPES.size()): card(specimen(i,500+i),TYPES[i],i)
	await snap("illustrated-plant-families")
	await new_sheet()
	var stripe: Dictionary=specimen(0)
	stripe.genes.pattern.dominant="Striped"
	stripe.genes.accent.dominant="d7a06d"
	card(stripe,"Inherited stripes",0)
	var spots: Dictionary=specimen(0)
	spots.genes.pattern.dominant="Spotted"
	spots.genes.accent.dominant="aa829b"
	card(spots,"Inherited spots",1)
	var three: Dictionary=specimen(1)
	three.genes.petals.dominant=3
	card(three,"Three petals",2)
	var seven: Dictionary=specimen(1)
	seven.genes.petals.dominant=7
	card(seven,"Seven petals",3)
	var g2: Dictionary=specimen(0)
	g2.lineage_mix={"Leaf":0.5,"Bloom":0.5}
	card(g2,"Leaf × Bloom",4)
	var g3: Dictionary=specimen(0)
	g3.lineage_mix={"Leaf":0.25,"Bloom":0.25,"Spore":0.5}
	card(g3,"G3 · fern / flower / spore",5)
	var graft: Dictionary=specimen(0)
	graft.graft_history=[{"donor_type":"Toxin","donor_color":"aa829b","success":true}]
	card(graft,"Grafted orchid branch",6)
	var old: Dictionary=specimen(0)
	old.life_age=1450.0
	card(old,"Aging foliage",7)
	await snap("illustrated-inherited-traits")
	print("ILLUSTRATED PLANT PREVIEW COMPLETE")
	quit()
