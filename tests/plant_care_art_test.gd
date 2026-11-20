extends SceneTree
## Care changes living shape and lifetime without changing inherited anatomy.
const Portrait = preload("res://scripts/plant_portrait.gd")
const Cell = preload("res://scripts/plant_cell.gd")
const Ecology = preload("res://scripts/ecology.gd")
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
		push_error("CARE ART: "+message)

func specimen() -> Dictionary:
	return {"id":"care_art","name":"Sunny","seed":2482,"type":"Leaf","generation":1,"mature":true,
		"measurements":{"height_variation":1.0,"weight_variation":1.0},
		"care":{"height_bonus":0.0,"weight_bonus":0.0,"life_bonus_seconds":0.0},
		"genes":{"color":{"dominant":"829d80"},"accent":{"dominant":"d6cba5"},"pattern":{"dominant":"Solid"},"form":{"dominant":"Upright"},"shape":{"dominant":"Pointed"},"size":{"dominant":"Standard"}}}

func capture(p: Dictionary) -> Image:
	portrait.plant = p
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func bounds(img: Image) -> Rect2i:
	var minimum := Vector2i(img.get_width(),img.get_height())
	var maximum := Vector2i.ZERO
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x,y).a>0.3:
				minimum = minimum.min(Vector2i(x,y))
				maximum = maximum.max(Vector2i(x,y))
	return Rect2i(minimum,maximum-minimum+Vector2i.ONE)

func run() -> void:
	var p: Dictionary = specimen()
	portrait = Portrait.new()
	portrait.plant = p
	check(portrait._individual_scale()==Vector2.ONE,"untreated standard individual has neutral size")
	p.care.height_bonus = 0.6
	portrait.plant = p
	check(portrait._individual_scale().y>1.25,"fertilizer makes an individual taller")
	p.care.weight_bonus = 0.8
	portrait.plant = p
	check(portrait._individual_scale().x>1.15,"compost makes an individual fuller")
	p.life_age = 1600.0
	p.care.life_bonus_seconds = 600.0
	portrait.plant = p
	check(not portrait._naturally_withered() and is_zero_approx(portrait._senescence()),"tonic keeps a 1600-second plant fresh after the usual limit")
	p.life_age = 2000.0
	portrait.plant = p
	check(not portrait._naturally_withered() and portrait._senescence()>0.6,"aging follows the extended lifetime")
	p.life_age = 2100.0
	portrait.plant = p
	check(portrait._naturally_withered(),"extended lifetime still has a natural end")
	portrait.free()
	if DisplayServer.get_name()=="headless":
		print("PLANT CARE ART TESTS: ",checks," checks, ",failures," failures; native GPU required for silhouettes")
		quit(1 if failures else 0)
		return
	root.size = Vector2i(600,650)
	viewport = SubViewport.new()
	viewport.size = Vector2i(480,576)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	portrait = Portrait.new()
	portrait.animate = false
	portrait.size = Vector2(480,576)
	viewport.add_child(portrait)
	p = specimen()
	var original: String = JSON.stringify(p)
	var normal: Image = await capture(p)
	var normal_bounds: Rect2i = bounds(normal)
	var tall: Dictionary = p.duplicate(true)
	tall.care.height_bonus = 0.6
	var tall_bounds: Rect2i = bounds(await capture(tall))
	check(tall_bounds.size.y>normal_bounds.size.y*1.12,"fertilizer visibly increases rendered height")
	var full: Dictionary = p.duplicate(true)
	full.care.weight_bonus = 0.8
	var full_bounds: Rect2i = bounds(await capture(full))
	check(full_bounds.size.x>normal_bounds.size.x*1.10,"compost visibly increases rendered fullness")
	var tiny: Dictionary = p.duplicate(true)
	tiny.measurements.height_variation = 0.86
	var large: Dictionary = p.duplicate(true)
	large.measurements.height_variation = 1.16
	var tiny_bounds: Rect2i = bounds(await capture(tiny))
	var large_bounds: Rect2i = bounds(await capture(large))
	check(large_bounds.size.y>tiny_bounds.size.y*1.15,"individual variation changes actual height for matching DNA")
	var tonic: Dictionary = p.duplicate(true)
	tonic.life_age = 1600.0
	tonic.care.life_bonus_seconds = 600.0
	check(hash((await capture(tonic)).get_data())==hash(normal.get_data()),"extended life uses fresh actual tissue, not the old collapsed crown")
	var dead: Dictionary = p.duplicate(true)
	dead.life_age = 1600.0
	var dead_image: Image = await capture(dead)
	check(bounds(dead_image).size.y<normal_bounds.size.y*0.8,"untreated end-of-life still visibly collapses")
	check(JSON.stringify(p)==original,"rendering never edits the plant or its DNA")
	print("PLANT CARE ART TESTS: ",checks," checks, ",failures," failures (native GPU)")
	quit(1 if failures else 0)
