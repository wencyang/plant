extends SceneTree
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Display = preload("res://scripts/display_settings.gd")
var game: Control
func _initialize() -> void:
	call_deferred("run")
func snap(filename: String) -> void:
	await create_timer(0.7).timeout
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.save_png("res://screenshots/"+filename+".png")
	print("NATIVE OUTPUT ",JSON.stringify({"capture":filename,"window":str(root.size),"render_pixels":str(picture.get_size()),"canvas":str(root.get_visible_rect().size),"interface_scale":root.content_scale_factor,"screen":root.current_screen}))
func run() -> void:
	game = Garden.new()
	game.state = State.new("/tmp/conservatory_resolution_preview_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings = Display.new("/tmp/conservatory_resolution_preview.cfg")
	game.display_settings.configure(root,false)
	await snap("large-garden")
	game._open_wilderness()
	await snap("large-wilderness")
	game.wilderness.teleport_to_site("moss_01")
	game.wilderness.interact()
	await snap("large-wild-encounter")
	game._leave_wild()
	game.display_settings.toggle_fullscreen()
	await snap("native-fullscreen-wilderness")
	game.display_settings.toggle_fullscreen()
	game._return_from_wilderness()
	game._open_display_settings()
	await snap("large-display-settings")
	quit()
