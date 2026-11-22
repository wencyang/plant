extends SceneTree
## Friendly fair visits, real gifts and permanent ribbons in disposable gardens.
## All growing, care and claims use game rules; player saves/settings stay untouched.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Display = preload("res://scripts/display_settings.gd")
const Locale = preload("res://scripts/localization.gd")
var game: Control
var child_id: String = ""
var mother_id: String = ""

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
	print("GARDEN FAIR VISUAL: ",name," · ",root.size)

func layout(dimensions: Vector2i) -> void:
	game.display_settings.enabled=false
	root.size=dimensions
	root.content_scale_factor=2
	await settle()
	game._responsive()
	await settle()

func find_action(node: Node,action: String,filters: Dictionary = {}) -> Button:
	if node is Button and str(node.get_meta("fair_action",""))==action:
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
		push_error("FAIR PREVIEW: missing or disabled action "+action+" "+str(filters))
		quit(1)
		return
	button.pressed.emit()
	await settle()

func choose_plant(id: String) -> void:
	var picker: OptionButton=find_action(game.modal,"choose_plant") as OptionButton
	if picker==null:
		push_error("FAIR PREVIEW: no actual plant picker")
		quit(1)
		return
	for i in range(picker.item_count):
		if str(picker.get_item_metadata(i))==id:
			picker.select(i)
			picker.item_selected.emit(i)
			await settle()
			return
	push_error("FAIR PREVIEW: plant was not in the picker")
	quit(1)

func new_garden(language: String,dimensions: Vector2i) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	Locale.set_language(language)
	game=Garden.new()
	game.state=State.new("/tmp/conservatory_fair_visual_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings=Display.new("/tmp/conservatory_fair_visual_display_%d.cfg" % Time.get_ticks_usec())
	game.display_settings.configure(root,false)
	await layout(dimensions)
	game.state.resources.sunlight=400
	mother_id=str(game.state.plant_order[0])
	var father: String=str(game.state.plant_order[1])
	# The actual ripening spray and sunshine lamp close a breeding loop without
	# changing clocks or inventing a qualifying plant's DNA.
	game.state.pollinate(mother_id,father)
	game.state.apply_care(mother_id,"ripening")
	game.state.harvest_fruit(mother_id)
	game.state.extract_all_seeds()
	var hybrid_index: int=-1
	for i in range(game.state.seed_bank.size()):
		if str(game.state.seed_bank[i].get("kind",""))=="hybrid": hybrid_index=i; break
	var result: Dictionary=game.state.plant_seed(hybrid_index)
	if not result.get("ok",false):
		push_error("FAIR PREVIEW: could not plant the real hybrid seed")
		quit(1)
		return
	child_id=str(result.plant.id)
	game.state.apply_care(child_id,"sunlamp")
	game._refresh()
	await settle()

func run() -> void:
	await new_garden("en",Vector2i(2880,2000))
	await snap("fair-sunny-garden-desktop-en")
	game._open_fair()
	await snap("fair-visitors-desktop-en")
	var welcome: String=str(game.state.fair_requests()[0].key)
	await press("request",{"request_key":welcome})
	await snap("fair-show-plant-desktop-en")
	await choose_plant(child_id)
	await snap("fair-show-hybrid-desktop-en")
	var plant_count: int=game.state.plant_order.size()
	await press("claim_request")
	if game.state.plant_order.size()!=plant_count or not game.state.owns_plant(child_id):
		push_error("FAIR PREVIEW: a friendly visit must keep every plant")
		quit(1)
		return
	await snap("fair-thank-you-gifts-desktop-en")
	await press("continue")
	await press("tab",{"fair_tab":"ribbons"})
	await snap("fair-ribbons-ready-desktop-en")
	await press("claim_ribbon",{"ribbon_key":"first_sprout"})
	await snap("fair-first-ribbon-desktop-en")
	await press("continue")
	await press("claim_ribbon",{"ribbon_key":"first_cross"})
	await press("continue")
	await press("claim_ribbon",{"ribbon_key":"mixed_roots"})
	await press("continue")
	await snap("fair-ribbon-book-desktop-en")
	game.modal_scroll.scroll_vertical=100000
	await snap("fair-ribbon-book-bottom-desktop-en")
	game._open_dna(child_id)
	game.modal_scroll.scroll_vertical=100000
	await snap("fair-inherited-talents-desktop-en")
	game._open_dna_compare(mother_id,child_id)
	game.modal_scroll.scroll_vertical=100000
	await snap("fair-inherited-potential-desktop-en")
	game._open_guide()
	await snap("fair-how-to-play-desktop-en")
	Locale.set_language("zh_CN")
	game._open_fair()
	await snap("fair-visitors-desktop-zh")
	game._show_fair_request(str(game.state.fair_requests()[1].key))
	await snap("fair-visitor-goal-desktop-zh")
	game._open_fair("ribbons")
	await snap("fair-ribbon-book-desktop-zh")
	# A separate phone garden has its own unclaimed daily welcome visit.
	await new_garden("en",Vector2i(780,1560))
	await snap("fair-sunny-garden-mobile-en")
	game._open_fair()
	await snap("fair-visitors-mobile-en")
	game.modal_scroll.scroll_vertical=100000
	await snap("fair-visitors-bottom-mobile-en")
	welcome=str(game.state.fair_requests()[0].key)
	game._show_fair_request(welcome,child_id)
	await snap("fair-show-hybrid-mobile-en")
	game.modal_scroll.scroll_vertical=100000
	await snap("fair-show-hybrid-details-mobile-en")
	Locale.set_language("zh_CN")
	game._show_fair_request(welcome,child_id)
	await snap("fair-show-hybrid-mobile-zh")
	await press("claim_request")
	await snap("fair-thank-you-gifts-mobile-zh")
	game._open_fair("ribbons")
	await snap("fair-ribbons-ready-mobile-zh")
	await press("claim_ribbon",{"ribbon_key":"first_sprout"})
	await snap("fair-first-ribbon-mobile-zh")
	await press("continue")
	game.modal_scroll.scroll_vertical=100000
	await snap("fair-ribbon-book-bottom-mobile-zh")
	game._close_modal()
	game._refresh()
	await snap("fair-sunny-garden-mobile-zh")
	print("GARDEN FAIR PREVIEW COMPLETE: three friendly visitors / actual plant-show gifts / permanent ribbons / kept plants / readable inherited talents / simple instructions / English and Chinese desktop and mobile")
	quit()
