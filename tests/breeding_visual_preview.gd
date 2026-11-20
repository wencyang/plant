extends SceneTree
## Native review of the actual pollination/fruit/seed/DNA/lifecycle controls.
## Only this temporary garden's timers are fast-forwarded for screenshots.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Display = preload("res://scripts/display_settings.gd")
const Locale = preload("res://scripts/localization.gd")
var game: Control

func _initialize() -> void:
	call_deferred("run")

func snap(name: String) -> void:
	game._localize_ui()
	await create_timer(0.35).timeout
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+name+".png")
	var leftovers: Array[String] = []
	audit(game,leftovers)
	print("BREEDING VISUAL ",name," · ",root.size," · English ",JSON.stringify(leftovers))

func audit(node: Node,result: Array[String]) -> void:
	if (node is Label or node is Button) and node.is_visible_in_tree():
		var value: String = node.text
		var regex := RegEx.new()
		regex.compile("[A-Za-z]{3,}")
		var remaining: String = value.replace("DNA","").replace("ACTG","")
		var bases := RegEx.new()
		bases.compile("^[ACGT \\n]+$")
		if regex.search(remaining) and not value.is_valid_hex_number(false) and not bases.search(value) and not remaining.is_empty():
			var code_regex := RegEx.new()
			code_regex.compile("[0-9A-Fa-f]{6,}")
			remaining = code_regex.sub(remaining,"",true)
			if regex.search(remaining): result.append(value)
	for child in node.get_children(): audit(child,result)

func raise_cross(mother: String,father: String) -> String:
	var result: Dictionary = game.state.pollinate(mother,father)
	if not result.get("ok",false): push_error(str(result)); return ""
	game.state.pollinations[mother].ready_at = 0
	game.state.harvest_fruit(mother)
	var fruit: Dictionary = game.state.fruit_inventory.back()
	game.state.extract_seeds(str(fruit.id))
	var birth: Dictionary = game.state.plant_seed(game.state.seed_bank.size()-1)
	birth.plant.ready_at = 0
	game.state.tick_growth()
	return str(birth.plant.id)

func run() -> void:
	Locale.set_language("zh_CN")
	game = Garden.new()
	game.state = State.new("/tmp/conservatory_breeding_visual_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings = Display.new("/tmp/conservatory_breeding_visual.cfg")
	game.display_settings.configure(root,false)
	game.state.random.seed = 703491
	var mother: String = str(game.state.plant_order[0])
	var father: String = str(game.state.plant_order[1])
	var vine: String = str(game.state.plant_order[2])
	game.parent_a = mother
	game.parent_b = father
	game._open_lab()
	await snap("breeding-laboratory-zh")
	game._crossbreed()
	await snap("breeding-pollination-zh")
	game.state.pollinations[mother].ready_at = 0
	game.nursery_tab = "plants"
	game._open_seeds()
	await snap("breeding-ripe-fruit-zh")
	game._harvest_fruit(mother)
	await snap("breeding-fruit-basket-zh")
	var fruit: Dictionary = game.state.fruit_inventory.back()
	game._extract_fruit(str(fruit.id))
	await snap("breeding-stored-seeds-zh")
	game._plant_saved_seed(game.state.seed_bank.size()-1)
	await create_timer(2.0).timeout
	await snap("breeding-seedling-reveal-zh")
	var g2: String = str(game.state.plant_order.back())
	game.state.get_plant(g2).ready_at = 0
	game.state.tick_growth()
	var g3: String = raise_cross(g2,vine)
	game._close_modal()
	game.selected_id = g3
	game._refresh()
	await snap("breeding-hybrid-garden-zh")
	game._open_dna(g3)
	await snap("breeding-dna-desktop-zh")
	game.modal_scroll.scroll_vertical = 410
	await snap("breeding-dna-genes-zh")
	game._close_modal()
	game.state.get_plant(g3).life_age = 1360.0
	game._open_detail(g3)
	await snap("breeding-aging-plant-zh")
	game._close_modal()
	game.display_settings.enabled = false
	root.size = Vector2i(780,1560)
	root.content_scale_factor = 2
	await create_timer(0.1).timeout
	game._open_dna(g3)
	await snap("breeding-dna-mobile-zh")
	game.modal_scroll.scroll_vertical = 620
	await snap("breeding-dna-genes-mobile-zh")
	game._close_modal()
	game.parent_a = g2
	game.parent_b = vine
	game._open_lab()
	await snap("breeding-laboratory-mobile-zh")
	game.nursery_tab = "seeds"
	game._open_seeds()
	await snap("breeding-seeds-mobile-zh")
	game._close_modal()
	game.state.get_plant(g3).life_age = 1499.0
	game.state.advance_lifecycle(1.0)
	game._open_dna(g3)
	await snap("breeding-withered-dna-mobile-zh")
	game.nursery_tab = "plants"
	game._open_seeds()
	await snap("breeding-final-fruit-mobile-zh")
	print("BREEDING VISUAL COMPLETE: G2 / G3 anatomy + DNA + all fruit stages + natural aging")
	quit()
