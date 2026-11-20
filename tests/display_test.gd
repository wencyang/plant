extends SceneTree
const Display = preload("res://scripts/display_settings.gd")
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
var checks: int = 0
var failures: int = 0
var game: Control
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(6): await process_frame
func fits(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x-2 and rect.position.y >= bounds.position.y-2 and rect.end.x <= bounds.end.x+2 and rect.end.y <= bounds.end.y+2
func run() -> void:
	check(Display.fitted_size(Vector2i(2880,2000),Vector2i(5120,2820)) == Vector2i(2880,2000),"5K display keeps the large native-size game window")
	var laptop: Vector2i = Display.fitted_size(Vector2i(2880,2000),Vector2i(3024,1898))
	check(laptop.x <= 2944 and laptop.y <= 1798,"A Retina laptop keeps the title bar and whole game on screen")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i.ZERO
	game = Garden.new()
	game.state = State.new("/tmp/conservatory_display_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for physical in [Vector2i(2880,2000),Vector2i(5120,2880),Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1440,1000),Vector2i(1280,850),Vector2i(390,780)]:
		root.size = physical
		root.content_scale_factor = Display.canvas_scale(physical)
		await settle()
		var bounds: Rect2 = root.get_visible_rect()
		var expected := Vector2(physical)/Display.canvas_scale(physical)
		check(bounds.size.distance_to(expected)<2,"Physical output %s retains the intended logical canvas: %s" % [physical,bounds.size])
		check(fits(game.root_column.get_global_rect(),bounds),"Garden fits scaled output %s; rect %s in %s" % [physical,game.root_column.get_global_rect(),bounds])
		check(fits(game.footer_row.get_global_rect(),bounds),"Primary actions fit scaled output %s" % physical)
		game._open_display_settings()
		await settle()
		check(fits(game.modal.get_node("Panel").get_global_rect(),bounds),"Display settings fit output %s" % physical)
		game._close_modal()
	root.size = Vector2i(2880,2000)
	root.content_scale_factor = 2.0
	await settle()
	game._open_wilderness()
	await settle()
	check(fits(game.wilderness._header.get_global_rect(),root.get_visible_rect()),"Exploration header fits the high-density canvas")
	check(fits(game.wilderness._footer.get_global_rect(),root.get_visible_rect()),"Exploration actions fit the high-density canvas")
	game._open_display_settings()
	await settle()
	check(game.wilderness.waiting,"Display settings pause wilderness movement")
	game._close_modal()
	await settle()
	check(not game.wilderness.waiting,"Closing display settings resumes wilderness movement")
	game._return_from_wilderness()
	root.content_scale_factor = 1.0
	game.queue_free()
	await settle()
	print("DISPLAY TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
