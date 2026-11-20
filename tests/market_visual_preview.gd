extends SceneTree
## A disposable, silent garden demonstrates real market controls and quotes.
## No player saves, language settings or display preferences are loaded or changed.
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
	print("MARKET VISUAL: ",name," · ",root.size)

func layout(dimensions: Vector2i) -> void:
	game.display_settings.enabled = false
	root.size = dimensions
	root.content_scale_factor = 2
	await settle()
	game._responsive()
	await settle()

func find_action(node: Node,action: String,filters: Dictionary = {}) -> Button:
	if node is Button and str(node.get_meta("market_action",""))==action:
		var matches: bool = true
		for key: String in filters:
			if node.get_meta(key,null)!=filters[key]: matches=false; break
		if matches: return node
	for child: Node in node.get_children():
		var found: Button = find_action(child,action,filters)
		if found!=null: return found
	return null

func press(action: String,filters: Dictionary = {}) -> void:
	var button: Button = find_action(game.modal,action,filters)
	if button==null or button.disabled:
		push_error("MARKET PREVIEW: missing or disabled action "+action+" "+str(filters))
		quit(1)
		return
	button.pressed.emit()
	await settle()

func run() -> void:
	Locale.set_language("en")
	game = Garden.new()
	game.state = State.new("/tmp/conservatory_market_visual_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings = Display.new("/tmp/conservatory_market_visual_display_%d.cfg" % Time.get_ticks_usec())
	game.display_settings.configure(root,false)
	await layout(Vector2i(2880,2000))
	var leaf: String = str(game.state.plant_order[0])
	var flower: String = str(game.state.plant_order[1])
	var favorite: String = str(game.state.plant_order[2])
	game.state.resources.sunlight=400
	# Produce complete-genome fruit and seeds through the real breeding loop.
	game.state.pollinate(leaf,flower)
	game.state.pollinations[leaf].ready_at=int(Time.get_unix_time_from_system())
	game.state.harvest_fruit(leaf)
	var hybrid_fruit: String = str(game.state.fruit_inventory[0].id)
	game.state.fruit_crops[flower].natural_ready_at=int(Time.get_unix_time_from_system())
	game.state.harvest_fruit(flower)
	var natural_fruit: String = ""
	for fruit: Dictionary in game.state.fruit_inventory:
		if str(fruit.get("kind",""))!="hybrid": natural_fruit=str(fruit.id); break
	game.state.extract_seeds(natural_fruit)
	var genome_seed_ref: Variant = game.state.market_ref("seed",game.state.seed_bank.size()-1)
	game.state.apply_care(leaf,"growth")
	game.state.apply_care(leaf,"compost")
	game.state.toggle_favorite(favorite)
	game._refresh()
	game._open_market("plants")
	await snap("market-stall-desktop-en")
	await press("review_sale",{"item_kind":"plant","item_ref":leaf})
	await snap("market-plant-offer-desktop-en")
	game.modal_scroll.scroll_vertical=100000
	await snap("market-plant-offer-details-desktop-en")
	await press("confirm_sale")
	await snap("market-plant-sold-desktop-en")
	game._open_detail(leaf)
	await snap("market-sold-archive-desktop-en")
	game._open_market("fruits")
	await snap("market-fruit-desktop-en")
	await press("review_sale",{"item_kind":"fruit","item_ref":hybrid_fruit})
	await snap("market-fruit-offer-desktop-en")
	await press("confirm_sale")
	game._open_market("seeds")
	await snap("market-seeds-desktop-en")
	await press("review_sale",{"item_kind":"seed","item_ref":genome_seed_ref})
	await snap("market-seed-offer-desktop-en")
	await press("cancel")
	await press("tab",{"market_tab":"shop"})
	await snap("market-shop-desktop-en")
	await press("buy",{"stock_key":"sunlight"})
	await snap("market-purchase-desktop-en")
	await press("buy",{"stock_key":"field_kits"})
	await press("tab",{"market_tab":"history"})
	await snap("market-receipts-desktop-en")
	await press("tab",{"market_tab":"prices"})
	await snap("market-prices-desktop-en")
	game.modal_scroll.scroll_vertical=100000
	await snap("market-prices-details-desktop-en")
	Locale.set_language("zh_CN")
	game._open_market("plants")
	await snap("market-stall-desktop-zh")
	await press("review_sale",{"item_kind":"plant","item_ref":favorite})
	await snap("market-favorite-protected-desktop-zh")
	game._open_market("shop")
	await snap("market-shop-desktop-zh")
	game._open_market("history")
	await snap("market-receipts-desktop-zh")
	Locale.set_language("en")
	await layout(Vector2i(780,1560))
	game._open_market("plants")
	await snap("market-stall-mobile-en")
	await press("review_sale",{"item_kind":"plant","item_ref":flower})
	await snap("market-plant-offer-mobile-en")
	game.modal_scroll.scroll_vertical=100000
	await snap("market-plant-offer-details-mobile-en")
	game._open_market("shop")
	await snap("market-shop-mobile-en")
	game.modal_scroll.scroll_vertical=100000
	await snap("market-shop-bottom-mobile-en")
	game._open_market("history")
	await snap("market-receipts-mobile-en")
	Locale.set_language("zh_CN")
	game._open_market("plants")
	await snap("market-stall-mobile-zh")
	await press("review_sale",{"item_kind":"plant","item_ref":flower})
	await snap("market-plant-offer-mobile-zh")
	game.modal_scroll.scroll_vertical=100000
	await snap("market-plant-offer-details-mobile-zh")
	game._open_market("seeds")
	await press("review_sale",{"item_kind":"seed","item_ref":genome_seed_ref})
	await snap("market-seed-offer-mobile-zh")
	game._open_market("shop")
	await snap("market-shop-mobile-zh")
	game.modal_scroll.scroll_vertical=100000
	await snap("market-shop-bottom-mobile-zh")
	game._open_market("prices")
	await snap("market-prices-mobile-zh")
	game.modal_scroll.scroll_vertical=100000
	await snap("market-prices-bottom-mobile-zh")
	print("MARKET PREVIEW COMPLETE: real quotes / reviewed plant and hybrid fruit sales / two purchases / receipts / prices / protected favorite / archived DNA / English and Chinese desktop and mobile")
	quit()
