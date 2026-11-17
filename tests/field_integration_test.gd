extends SceneTree
## The player-facing route: leave the existing garden, collect real wild genes,
## return without disturbing the beds, and breed a second generation from them.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
var game: Control
var checks: int = 0
var failures: int = 0
var save_path: String
var original_bed: Array
var original_display: Array
var original_order: Array
var collected_id: String = ""
var captured_genes: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)

func settle() -> void:
	for i in range(5): await process_frame

func resize(dimensions: Vector2i) -> void:
	root.size = dimensions
	await settle()
	check(root.get_visible_rect().size.is_equal_approx(Vector2(dimensions)), "actual viewport resized to %s" % dimensions)

func within(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x-2 and rect.position.y >= bounds.position.y-2 and rect.end.x <= bounds.end.x+2 and rect.end.y <= bounds.end.y+2

func horizontal_overflow(node: Node, bounds: Rect2, result: Array[String]) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x < bounds.position.x-2 or rect.end.x > bounds.end.x+2:
			var text: String = node.get_class()
			if node is Label or node is Button: text += " '%s'" % str(node.text).left(36)
			result.append(text+" "+str(rect))
		if node is ScrollContainer and node.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: return
	for child in node.get_children(): horizontal_overflow(child,bounds,result)

func check_modal(context: String) -> void:
	var panel: Control = game.modal.get_node("Panel")
	var rect: Rect2 = panel.get_global_rect()
	check(within(rect,root.get_visible_rect()),context+" modal fits viewport: "+str(rect))
	var overflow: Array[String] = []
	horizontal_overflow(panel,rect,overflow)
	check(overflow.is_empty(),context+" controls fit horizontally: "+"; ".join(overflow.slice(0,6)))

func check_home(context: String) -> void:
	check(within(game.root_column.get_global_rect(),root.get_visible_rect()),context+" garden fits viewport: "+str(game.root_column.get_global_rect()))
	check(within(game.footer_row.get_global_rect(),root.get_visible_rect()),context+" footer fits viewport: "+str(game.footer_row.get_global_rect()))
	check(game.state.bed == original_bed and game.state.display_bed == original_display,context+" preserves exact battle and display beds")

func run() -> void:
	await resize(Vector2i(1440,1000))
	save_path = "/tmp/conservatory_field_integration_%d.json" % Time.get_ticks_usec()
	game = Garden.new()
	game.state = State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	original_bed = game.state.bed.duplicate()
	original_display = game.state.display_bed.duplicate()
	original_order = game.state.plant_order.duplicate()
	check_home("Desktop home")
	game._open_wilderness()
	await settle()
	check(game.exploring and game.wilderness.is_visible_in_tree() and not game.ui_margin.visible,"Explore reveals the field and keeps the garden underneath")
	check(game.wilderness.player_tile == Vector2i(15,18),"explorer begins at the saved trail entrance")
	game._open_field_supplies()
	await settle()
	check(game.wilderness.waiting and not game.wilderness._try_step(Vector2i.UP),"Supplies pauses walking when opened directly from the trail")
	game._close_modal()
	await settle()
	check(not game.wilderness.waiting and game.state.expedition.active_encounter.is_empty(),"closing Supplies restores walking without leaving a blocked encounter")
	check(game.state.bed == original_bed and game.state.display_bed == original_display,"entering wilderness does not rearrange plants")
	for i in range(3):
		check(game.wilderness._try_step(Vector2i.UP),"walkable first route step %d" % (i+1))
	check(game.wilderness.player_tile == Vector2i(15,15) and game.state.expedition.position == [15,15],"walking updates both the avatar and persistent map position")
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.physical_keycode = KEY_E
	interact.pressed = true
	Input.parse_input_event(interact)
	await settle()
	interact = InputEventKey.new()
	interact.keycode = KEY_E
	interact.physical_keycode = KEY_E
	interact.pressed = false
	Input.parse_input_event(interact)
	check(game.modal_kind == "wild_encounter" and game.wilderness.waiting,"E investigates a nearby wild plant through the real world-to-garden signal")
	check_modal("Desktop wild encounter")
	var first_seed: int = game.state.expedition.active_encounter.plant.seed
	var first_chance: float = game.state.capture_odds()
	var kits_before: int = game.state.field_kits
	game._wild_action("observe")
	await settle()
	check(game.state.field_kits == kits_before and game.state.capture_odds() > first_chance,"Study improves odds without using a kit")
	check(game.state.expedition.active_encounter.plant.seed == first_seed,"observation keeps the exact organism")
	check_modal("Desktop studied encounter")
	game.state.save_game()
	game.visible = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var resumed: Control = Garden.new()
	resumed.state = State.new(save_path)
	root.add_child(resumed)
	resumed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	resumed._open_wilderness()
	await settle()
	check(resumed.modal_kind == "wild_encounter" and resumed.wilderness.waiting,"relaunch resumes the saved plant encounter with walking frozen")
	check(resumed.state.expedition.active_encounter.observed and is_equal_approx(resumed.state.capture_odds(),game.state.capture_odds()),"relaunch preserves observation and the exact collection odds")
	resumed.queue_free()
	await process_frame
	game.visible = true
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game._open_field_supplies()
	await settle()
	check_modal("Desktop field supplies")
	check(not game.state.expedition.active_encounter.is_empty(),"opening field supplies preserves the encountered plant")
	game._show_wild_encounter()
	await settle()
	# Odds are real; a rare failed cutting may withdraw, so follow further mapped
	# patches rather than depending on a favorable global random seed.
	var attempts: int = 0
	for site_index in range(game.wilderness.SITES.size()):
		if collected_id != "": break
		if site_index > 0:
			game._leave_wild()
			var site: Dictionary = game.wilderness.SITES[site_index]
			game.wilderness.teleport_to_site(str(site.id))
			game.wilderness.interact()
			await settle()
			if game.modal_kind != "wild_encounter": continue
			game._wild_action("observe")
			await settle()
		for cutting in range(3):
			if game.state.expedition.active_encounter.is_empty(): break
			if game.state.field_kits == 0: game.state.restock_field_kits()
			var expected_genes: Dictionary = game.state.expedition.active_encounter.plant.genes.duplicate(true)
			kits_before = game.state.field_kits
			game._wild_action("gather")
			attempts += 1
			await settle()
			check(game.state.field_kits == kits_before-1,"collection attempt spends exactly one visible field kit")
			if game.modal_kind == "wild_capture":
				collected_id = str(game.state.plant_order.back())
				captured_genes = expected_genes
				break
	check(collected_id != "","field collection produces an owned companion")
	if collected_id == "":
		game.queue_free()
		await process_frame
		quit(1)
		return
	var specimen: Dictionary = game.state.get_plant(collected_id)
	check(specimen.genes == captured_genes and specimen.mature,"collected companion keeps its exact encountered genome and is ready to use")
	check(specimen.origin.kind == "wild" and specimen.origin.biome != "","collected companion records its habitat")
	check(game.state.plant_order.size() == original_order.size()+1,"one collection appends one specimen to the tray")
	check(game.state.bed == original_bed and game.state.display_bed == original_display,"collection leaves the original garden arrangement intact")
	check_modal("Desktop collection reveal")
	await resize(Vector2i(390,780))
	check_modal("Mobile collection reveal")
	game._continue_exploring()
	await settle()
	check(game.exploring and not game.wilderness.waiting,"Keep exploring releases walking control")
	game._open_field_supplies()
	await settle()
	check_modal("Mobile field supplies")
	game._continue_exploring()
	var next_site: Dictionary = game.wilderness.SITES[2]
	game.wilderness.teleport_to_site(str(next_site.id))
	game.wilderness.interact()
	await settle()
	check(game.modal_kind == "wild_encounter","another patch opens a mobile wild encounter")
	check_modal("Mobile wild encounter")
	game._wild_action("observe")
	await settle()
	check_modal("Mobile studied encounter")
	game._leave_wild()
	await settle()
	check(not game.wilderness.waiting and game.state.expedition.active_encounter.is_empty(),"Leave it growing abandons the attempt and restores exploration")
	var saved_position: Array = game.state.expedition.position.duplicate()
	game._return_from_wilderness()
	await settle()
	check(not game.exploring and game.ui_margin.visible and not game.wilderness.visible,"Return home restores the garden interface")
	check_home("Mobile home after collection")
	check(game.tray_row.get_child_count() == original_order.size()+1,"returning home shows the new companion in the specimen tray")
	game.parent_a = ""
	game.parent_b = ""
	game.lab_mode = "Crossbreed"
	game._open_wilderness()
	game._open_detail(collected_id)
	await settle()
	game._breed_from(collected_id)
	await settle()
	check(not game.exploring and game.modal_kind == "lab","breeding a collected companion from its field detail returns home into the laboratory")
	game.parent_b = str(original_order[0])
	game._open_lab()
	await settle()
	check(game.parent_a == collected_id,"wild companion can be carried into the breeding laboratory")
	game._crossbreed()
	await settle()
	var child_id: String = str(game.state.plant_order.back())
	check(game.modal_kind == "reveal" and game.state.get_plant(child_id).parents.has(collected_id),"wild collection closes the loop into a second-generation offspring")
	game._close_modal()
	game.state.save_game()
	var restored: RefCounted = State.new(save_path)
	check(restored.load_game(),"collected garden and expedition reload together")
	check(restored.expedition.position == saved_position,"field map position persists after returning home")
	check(restored.plants[collected_id].origin.kind == "wild" and restored.plants[child_id].parents.has(collected_id),"wild provenance and offspring parentage survive reload")
	check(restored.bed == original_bed and restored.display_bed == original_display,"complete journey preserves saved home beds")
	await resize(Vector2i(1440,1000))
	check_home("Desktop home after collection")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path.get_basename()+".backup.json")
	print("FIELD INTEGRATION TESTS: %d checks, %d failures, %d real collection attempts" % [checks,failures,attempts])
	quit(1 if failures > 0 else 0)
