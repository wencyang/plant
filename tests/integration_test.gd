extends SceneTree
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
var game: Control
var check_count: int = 0
var failures: int = 0
var test_save_path: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	check_count += 1
	if not value:
		push_error(message)
		failures += 1

func settle_layout() -> void:
	# Container minimum sizes propagate over more than one deferred sort.
	for i in range(4):
		await process_frame

func resize_viewport(dimensions: Vector2i) -> void:
	root.size = dimensions
	await settle_layout()
	check(root.get_visible_rect().size.is_equal_approx(Vector2(dimensions)),
		"Test resized the actual viewport to %s (got %s)" % [dimensions, root.get_visible_rect().size])

func check_garden_bounds(context: String) -> void:
	var bounds: Rect2 = root.get_visible_rect()
	check(_within(game.root_column.get_global_rect(), bounds),
		"%s garden column extends beyond viewport: %s, viewport %s" % [context, game.root_column.get_global_rect(), bounds])
	check(_within(game.footer_row.get_global_rect(), bounds),
		"%s footer extends beyond viewport: %s, viewport %s" % [context, game.footer_row.get_global_rect(), bounds])

func check_modal_bounds(context: String) -> void:
	var panel: Control = game.modal.get_node("Panel")
	var rect: Rect2 = panel.get_global_rect()
	check(_within(rect, root.get_visible_rect()),
		"%s modal extends beyond viewport: %s, viewport %s" % [context, rect, root.get_visible_rect()])
	var overflow: Array[String] = []
	_find_horizontal_overflow(panel, rect, overflow)
	check(overflow.is_empty(), "%s has horizontal content overflow: %s" % [context, "; ".join(overflow.slice(0, 6))])

func _within(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x - 2.0 \
		and rect.position.y >= bounds.position.y - 2.0 \
		and rect.end.x <= bounds.end.x + 2.0 \
		and rect.end.y <= bounds.end.y + 2.0

func _find_horizontal_overflow(node: Node, bounds: Rect2, result: Array[String]) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x < bounds.position.x - 2.0 or rect.end.x > bounds.end.x + 2.0:
			var description: String = str(node.get_class())
			if node is Label or node is Button: description += " '%s'" % str(node.text).left(44)
			result.append("%s rect%s" % [description, rect])
		# Packet trays intentionally extend inside a clipped horizontal viewport.
		# Their ScrollContainer must fit; their scrollable contents need not.
		if node is ScrollContainer and node.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return
	for child: Node in node.get_children():
		_find_horizontal_overflow(child, bounds, result)

func find_parent_slot(node: Node) -> Control:
	if node.get_script() == preload("res://scripts/plant_cell.gd") and node.zone == "parent" and node.index == 0:
		return node
	for child in node.get_children():
		var found: Control = find_parent_slot(child)
		if found != null: return found
	return null

func run() -> void:
	await resize_viewport(Vector2i(1440, 1000))
	game = Garden.new()
	test_save_path = "/tmp/conservatory_integration_%d.json" % Time.get_ticks_usec()
	game.state = State.new(test_save_path)
	if FileAccess.file_exists(game.state.save_path): DirAccess.remove_absolute(game.state.save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle_layout()
	check_garden_bounds("Desktop")
	check(game.state.plants.size() == 5, "Initial specimen archive")
	check(game.bed_grid.get_child_count() == 9, "Nine soil cells")
	check(game.display_grid.get_child_count() == 6, "Six presentation slots")
	game._open_lab()
	await settle_layout()
	check(is_instance_valid(game.lab_pick_a), "Laboratory parent picker")
	var slot: Control = find_parent_slot(game.modal)
	var dragged_id: String = str(game.state.plant_order[2])
	check(slot._can_drop_data(Vector2.ZERO,{"plant_id":dragged_id}),"Parent slots accept specimen drag data")
	slot._drop_data(Vector2.ZERO,{"plant_id":dragged_id})
	await settle_layout()
	check(game.parent_a == dragged_id,"Dropping a specimen prefills the breeding parent")
	var selected_parents: Array = [game.parent_a, game.parent_b]
	check_modal_bounds("Desktop crossbreeding")
	game._crossbreed()
	await process_frame
	check(game.state.plants.size() == 5, "Pollination keeps embryos in fruit rather than creating an owned plant immediately")
	check(game.state.pollinations.has(str(selected_parents[0])), "Crossbreeding starts a fruit on the selected mother")
	if not game.state.pollinations.has(str(selected_parents[0])):
		quit(1)
		return
	game.state.pollinations[str(selected_parents[0])].ready_at = 0
	game._open_seeds()
	await settle_layout()
	game._harvest_fruit(str(selected_parents[0]))
	await settle_layout()
	var crossed_fruit: Dictionary = {}
	for fruit: Dictionary in game.state.fruit_inventory:
		if fruit.kind == "hybrid" and str(fruit.mother_id) == str(selected_parents[0]): crossed_fruit = fruit
	check(not crossed_fruit.is_empty(), "Ripe cross fruit is harvested into the fruit inventory")
	if crossed_fruit.is_empty():
		quit(1)
		return
	var hybrid_seed_index: int = game.state.seed_bank.size()
	game._extract_fruit(str(crossed_fruit.id))
	await settle_layout()
	check(game.state.seed_bank.size() == hybrid_seed_index+2, "Harvested hybrid fruit provides two independent full-genome seeds")
	game._plant_saved_seed(hybrid_seed_index)
	await settle_layout()
	check(game.state.plants.size() == 6, "Crossbreed creates individual")
	check(game.modal_kind == "reveal", "Offspring reveal")
	var child_id: String = str(game.state.plant_order.back())
	check(game.state.get_plant(child_id).parents == selected_parents, "Offspring records the selected parent identities")
	check(int(game.state.get_plant(child_id).generation) == 2, "Founding parents create a second-generation lineage")
	game.state.mature_plant(child_id)
	game.state.rename_plant(child_id, "Glass Hymn")
	game.state.toggle_favorite(child_id)
	game._open_detail(child_id)
	await process_frame
	check(game.modal_kind == "detail", "Full diploid detail")
	game._open_seeds()
	await process_frame
	check(game.modal_kind == "seeds", "Seed archive")
	game._open_codex()
	await process_frame
	check(game.modal_kind == "codex", "Seven species codex")
	game._open_guide()
	await process_frame
	game._close_modal()
	game._choose_plant(child_id,"tray",0)
	game._drop_plant(child_id,"bed",3)
	check(game.state.bed[3] == child_id,"Tap planting persists position")
	game._open_fair()
	await settle_layout()
	check(game.modal_kind == "fair", "The garden fair offers peaceful reasons to grow plants")
	check_modal_bounds("Desktop garden fair")
	check(game.state.plants.size() == 6,"Visiting the fair keeps the complete specimen archive")
	check(not game.has_method("_prepare_battle") and not game.has_method("_start_battle"),"Removed combat has no runtime entry points")
	game._close_modal()
	await resize_viewport(Vector2i(390,844))
	check(not game.sidebar.visible,"Portrait responsive layout")
	check_garden_bounds("Mobile")
	await resize_viewport(Vector2i(390,780))
	check_garden_bounds("Small portrait")
	game._open_display_notes()
	await settle_layout()
	check_modal_bounds("Mobile display rewards")
	game._close_modal()
	game._open_detail(child_id)
	await settle_layout()
	check_modal_bounds("Mobile plant detail")
	game._open_codex()
	await settle_layout()
	check_modal_bounds("Mobile codex")
	game._open_seeds()
	await settle_layout()
	check_modal_bounds("Mobile seed archive")
	for mode: String in ["Crossbreed", "Graft", "Mutate"]:
		game.lab_mode = mode
		game._open_lab()
		await settle_layout()
		check_modal_bounds("Mobile laboratory %s" % mode)
	game._close_modal()
	game._open_fair()
	await settle_layout()
	check_modal_bounds("Mobile garden fair")
	game._close_modal()
	game.state.save_game()
	var restored = State.new(test_save_path)
	check(restored.load_game(), "Saved garden can be loaded independently")
	check(restored.get_plant(child_id).name == "Glass Hymn", "Player's specimen name persists")
	check(bool(restored.get_plant(child_id).favorite), "Favorite protection persists")
	check(restored.get_plant(child_id).parents == selected_parents, "Full parent identities survive saving and fair visits")
	check(restored.bed[3] == child_id, "Exact garden placement survives saving and fair visits")
	check(restored.plant_order == game.state.plant_order, "Specimen tray order persists")
	await resize_viewport(Vector2i(1440,1000))
	check_garden_bounds("Restored desktop layout")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(test_save_path): DirAccess.remove_absolute(test_save_path)
	print("INTEGRATION TESTS: %d checks, %d failures" % [check_count, failures])
	quit(1 if failures > 0 else 0)
