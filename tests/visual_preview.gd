extends SceneTree
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
var game: Control
func _initialize() -> void:
	call_deferred("run")
func snap(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/" + filename + ".png")
func run() -> void:
	game = Garden.new()
	game.state = State.new("/tmp/conservatory_visual_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(1.5).timeout
	await snap("garden-desktop")
	game._open_lab()
	await snap("laboratory-desktop")
	game._close_modal()
	game._open_fair()
	await snap("fair-desktop")
	game._close_modal()
	root.size = Vector2i(390,844)
	await create_timer(0.5).timeout
	await snap("garden-mobile")
	game._open_lab()
	await snap("laboratory-mobile")
	game._close_modal()
	game._open_fair()
	await snap("fair-mobile")
	quit()
