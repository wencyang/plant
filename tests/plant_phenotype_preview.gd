extends SceneTree
const Portrait = preload("res://scripts/plant_portrait.gd")
const State = preload("res://scripts/garden_state.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1800,1150)
	root.content_scale_factor = 1
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var bg := ColorRect.new()
	bg.color = Color("10241f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var state := State.new("/tmp/plant_phenotype_preview.json")
	var labels: Array[String] = ["Solid","Striped","Spotted","Gradient","Starburst","Bicolor Ring","Mauve donor graft","Blue pigment / waxy"]
	var baseline: Dictionary = state._create_base(0,821)
	baseline.genes.shape.dominant = "Pointed"
	baseline.genes.form.dominant = "Upright"
	baseline.genes.texture.dominant = "Matte"
	for i in range(labels.size()):
		var specimen: Dictionary = baseline.duplicate(true)
		specimen.genes.pattern.dominant = labels[i] if i<6 else "Solid"
		if i==6:
			specimen.graft_history = [{"success":true,"donor_color":"c275b1"}]
		elif i==7:
			specimen.genes.color.dominant = "7fabb0"
			specimen.genes.texture.dominant = "Waxy"
		var card := Panel.new()
		card.position = Vector2(20+(i%4)*445,20+int(i/4)*555)
		card.size = Vector2(425,535)
		root.add_child(card)
		var portrait := Portrait.new()
		portrait.plant = specimen
		portrait.animate = false
		portrait.position = Vector2(12,8)
		portrait.size = Vector2(401,480)
		card.add_child(portrait)
		var label := Label.new()
		label.text = labels[i]
		label.position = Vector2(18,495)
		label.add_theme_font_size_override("font_size",21)
		card.add_child(label)
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/plants-phenotypes-sheet.png")
	print("PHENOTYPE PREVIEW: six patterns, graft, pigment/surface; same seed and anatomy")
	quit()
