extends SceneTree
## Follow the actual choose → review → sow flow with a silent disposable save.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Display = preload("res://scripts/display_settings.gd")
const Locale = preload("res://scripts/localization.gd")
var game: Control

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(5): await process_frame

func snap(name: String) -> void:
	game._localize_ui()
	await create_timer(0.35).timeout
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+name+".png")
	print("PLANTING VISUAL: ",name," · ",root.size)
	if name in ["planting-garden-mobile-en","planting-growing-garden-mobile-zh","planting-reloaded-garden-mobile-zh"]:
		var display: Control=game.display_grid.get_child(4)
		print("PLANTING MOBILE BOUNDS: ",name," game=",game.size," column=",game.root_column.size," min=",game.root_column.get_combined_minimum_size()," bed=",game.bed_grid.size," bedcell=",game.bed_grid.get_child(0).size," footer=",game.footer_row.get_global_rect()," display=",display.size," invite=",display.title_label.get_rect()," wrap=",display.title_label.autowrap_mode," font=",display.title_label.get_theme_font_size("font_size"))

func layout(dimensions: Vector2i) -> void:
	game.display_settings.enabled=false
	root.size=dimensions
	root.content_scale_factor=2
	await settle()
	game._responsive()
	await settle()

func find_action(node: Node,action: String,filters: Dictionary = {}) -> Button:
	if node is Button and str(node.get_meta("planting_action",""))==action:
		var matches: bool=true
		for key: String in filters:
			if node.get_meta(key,null)!=filters[key]: matches=false; break
		if matches: return node
	for child: Node in node.get_children():
		var found: Button=find_action(child,action,filters)
		if found!=null: return found
	return null

func press(action: String,filters: Dictionary = {}) -> void:
	var button: Button=find_action(game.modal,action,filters)
	if button==null or button.disabled:
		push_error("PLANTING PREVIEW: missing or disabled action "+action+" "+str(filters))
		quit(1)
		return
	button.pressed.emit()
	await settle()

func prepare_hybrid_seeds() -> void:
	var mother: String=str(game.state.plant_order[0])
	var father: String=str(game.state.plant_order[1])
	game.state.pollinate(mother,father)
	game.state.pollinations[mother].ready_at=int(Time.get_unix_time_from_system())
	game.state.harvest_fruit(mother)
	game.state.extract_seeds(str(game.state.fruit_inventory[0].id))

func run() -> void:
	Locale.set_language("en")
	game=Garden.new()
	game.state=State.new("/tmp/conservatory_planting_visual_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings=Display.new("/tmp/conservatory_planting_visual_display_%d.cfg" % Time.get_ticks_usec())
	game.display_settings.configure(root,false)
	await layout(Vector2i(2880,2000))
	game.state.resources.sunlight=400
	prepare_hybrid_seeds()
	game._refresh()
	await snap("planting-garden-desktop-en")
	# An empty soil cell opens the same visible route as the Plant a seed button.
	game._choose_plant("","bed",0)
	await snap("planting-choose-seed-desktop-en")
	await press("choose_seed",{"seed_index":3})
	await snap("planting-review-desktop-en")
	await press("plant_seed")
	await snap("planting-planted-desktop-en")
	var first: String=str(game.modal.get_meta("planted_id",""))
	await press("watch_grow")
	await snap("planting-growing-garden-desktop-en")
	await create_timer(1.2).timeout
	await snap("planting-countdown-desktop-en")
	Locale.set_language("zh_CN")
	game._localize_ui()
	await snap("planting-growing-garden-desktop-zh")
	game._open_planting(1)
	await snap("planting-choose-seed-desktop-zh")
	await press("choose_seed",{"seed_index":3})
	await snap("planting-review-desktop-zh")
	game._close_modal()
	# The real sunshine lamp completes the seedling so an empty display shelf
	# can offer it alongside other mature plants.
	game.state.apply_care(first,"sunlamp")
	game._refresh()
	game._choose_plant("","display",4)
	await snap("planting-display-chooser-desktop-zh")
	game._close_modal()
	Locale.set_language("en")
	await layout(Vector2i(780,1560))
	game._refresh()
	await snap("planting-garden-mobile-en")
	game._choose_plant("","bed",1)
	await snap("planting-choose-seed-mobile-en")
	await press("choose_seed",{"seed_index":3})
	await snap("planting-review-mobile-en")
	game.modal_scroll.scroll_vertical=100000
	await snap("planting-review-bottom-mobile-en")
	game._close_modal()
	Locale.set_language("zh_CN")
	game._open_planting(1)
	await snap("planting-choose-seed-mobile-zh")
	await press("choose_seed",{"seed_index":3})
	await snap("planting-review-mobile-zh")
	await press("plant_seed")
	await snap("planting-planted-mobile-zh")
	await press("watch_grow")
	await snap("planting-growing-garden-mobile-zh")
	game._choose_plant("","display",4)
	await snap("planting-display-chooser-mobile-zh")
	# Reopen the temporary already-planted garden directly in Chinese. This
	# catches initial CJK minimum sizes, without a prior English layout pass.
	var temporary_save: String=game.state.save_path
	game.state.save_game()
	game.queue_free()
	await process_frame
	game=Garden.new()
	game.state=State.new(temporary_save)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	await snap("planting-reloaded-garden-mobile-zh")
	var footer_bounds: Rect2=game.footer_row.get_global_rect()
	if footer_bounds.end.y>root.get_visible_rect().end.y+1:
		push_error("PLANTING PREVIEW: reloaded Chinese footer outside viewport "+str(footer_bounds))
		quit(1)
		return
	print("PLANTING PREVIEW COMPLETE: empty bed / seed list / full-genome review / actual sowing / live countdown / mature display picker / English and Chinese desktop and mobile")
	quit()
