extends SceneTree
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
var game: Control
func _initialize() -> void:
	call_deferred("run")
func snap(filename: String) -> void:
	for i in range(5): await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/" + filename + ".png")
func run() -> void:
	root.size = Vector2i(1440,1000)
	game = Garden.new()
	game.state = State.new("/tmp/field_visual_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.7).timeout
	await snap("pixel-garden-desktop")
	game._open_wilderness()
	await create_timer(0.3).timeout
	await snap("wilds-desktop")
	game.wilderness.teleport_to_site("moss_01")
	game.wilderness.interact()
	await snap("wild-encounter-desktop")
	game._wild_action("observe")
	game._wild_action("gather")
	await snap("wild-collected-desktop")
	game._continue_exploring()
	game.wilderness.teleport_to_site("fen_01")
	await snap("sporefen-desktop")
	game.wilderness.teleport_to_site("glade_02")
	await snap("sunken-glade-desktop")
	root.size = Vector2i(390,780)
	await create_timer(0.2).timeout
	await snap("wilds-mobile")
	game.wilderness.teleport_to_site("amber_01")
	game.wilderness.interact()
	await snap("wild-encounter-mobile")
	game._leave_wild()
	game._return_from_wilderness()
	await snap("pixel-garden-mobile")
	quit()
